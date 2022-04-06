-- Managing multiple Sandboxes for each Player/Force
local Sandbox = {}

Sandbox.pfx = BPSB.pfx .. "sb-"

-- GUI Dropdown items for Sandboxes
Sandbox.choices = {
    { "sandbox." .. Sandbox.pfx .. "player-lab" },
    { "sandbox." .. Sandbox.pfx .. "force-lab" },
    { "sandbox." .. Sandbox.pfx .. "force-lab-space-exploration" },
    { "sandbox." .. Sandbox.pfx .. "force-orbit-space-exploration" },
}
if not SpaceExploration.enabled then
    Sandbox.choices[3] = { "sandbox." .. Sandbox.pfx .. "space-exploration-disabled" }
    Sandbox.choices[4] = { "sandbox." .. Sandbox.pfx .. "space-exploration-disabled" }
end

-- Constants to represent indexes for Sandbox.choices
Sandbox.player = 1
Sandbox.force = 2
Sandbox.forcePlanetaryLab = 3
Sandbox.forceOrbitalSandbox = 4

-- A unique per-Force Sandbox Name
function Sandbox.NameFromForce(force)
    return Sandbox.pfx .. "f-" .. force.name
end

-- Whether the Force is specific to Blueprint Sandboxes
function Sandbox.IsSandboxForce(force)
    -- return string.sub(force.name, 1, pfxLength) == Sandbox.pfx
    return not not global.sandboxForces[force.name]
end

-- Whether something is any type of Sandbox
function Sandbox.IsSandbox(thingWithName)
    return Lab.IsLab(thingWithName)
            or SpaceExploration.IsSandbox(thingWithName)
end

-- Whether a Sandbox choice is allowed
function Sandbox.IsEnabled(selectedSandbox)
    if selectedSandbox == Sandbox.player then
        return true
    elseif selectedSandbox == Sandbox.force then
        return true
    elseif selectedSandbox == Sandbox.forceOrbitalSandbox then
        return SpaceExploration.enabled
    elseif selectedSandbox == Sandbox.forcePlanetaryLab then
        return SpaceExploration.enabled
    else
        Debug.log("Impossible Choice for Sandbox: " .. selectedSandbox)
        return false
    end
end

-- Which Surface Name to use for this Player based on their Selected Sandbox
function Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    local playerData = global.players[player.index]

    if playerData.selectedSandbox == Sandbox.player
    then
        return Lab.GetOrCreateSurface(playerData.labName, sandboxForce)
    elseif playerData.selectedSandbox == Sandbox.force
    then
        return Lab.GetOrCreateSurface(global.sandboxForces[sandboxForce.name].labName, sandboxForce)
    elseif SpaceExploration.enabled
            and playerData.selectedSandbox == Sandbox.forceOrbitalSandbox
    then
        return SpaceExploration.GetOrCreateOrbitalSurfaceForForce(player, sandboxForce)
    elseif SpaceExploration.enabled
            and playerData.selectedSandbox == Sandbox.forcePlanetaryLab
    then
        return SpaceExploration.GetOrCreatePlanetarySurfaceForForce(player, sandboxForce)
    else
        Debug.log("Impossible Choice for Sandbox: " .. playerData.selectedSandbox)
        return
    end
end

-- Convert the Player to God-mode, save their previous State, and enter Selected Sandbox
function Sandbox.Enter(player)
    local playerData = global.players[player.index]

    if playerData.insideSandbox ~= nil then
        Debug.log("Already inside Sandbox: " .. playerData.insideSandbox)
        return
    end

    SpaceExploration.ExitRemoteView(player)

    local sandboxForce = Init.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        Debug.log("Completely Unknown Sandbox Surface, cannot use")
        return
    end
    Debug.log("Entering Sandbox: " .. surface.name)

    playerData.insideSandbox = playerData.selectedSandbox
    playerData.preSandboxForceName = player.force.name
    playerData.preSandboxCharacter = player.character
    playerData.preSandboxController = player.controller_type
    playerData.preSandboxPosition = player.position
    playerData.preSandboxSurfaceName = player.surface.name

    player.set_controller({ type = defines.controllers.god })
    player.teleport({ 0, 0 }, surface)
    player.cheat_mode = true
    player.force = sandboxForce

    -- TODO: It's unclear why this must happen _after_ the above code
    Research.EnableSandboxSpecificResearch(sandboxForce)
end

-- Convert the Player to their previous State, and leave Selected Sandbox
function Sandbox.Exit(player)
    local playerData = global.players[player.index]

    if playerData.insideSandbox == nil then
        Debug.log("Already outside Sandbox")
        return
    end
    Debug.log("Exiting Sandbox: " .. player.surface.name)

    player.force = playerData.preSandboxForceName
    Sandbox.RecoverPlayerCharacter(player, playerData)
    player.cheat_mode = false

    playerData.insideSandbox = nil
    playerData.preSandboxForceName = nil
    playerData.preSandboxCharacter = nil
    playerData.preSandboxController = nil
    playerData.preSandboxPosition = nil
    playerData.preSandboxSurfaceName = nil
end

-- Ensure the Player has a Character to go back to
function Sandbox.RecoverPlayerCharacter(player, playerData)
    -- Typical situation, there wasn't a Character, or there was a valid one
    if (not playerData.preSandboxCharacter) or playerData.preSandboxCharacter.valid then
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        player.set_controller({
            type = playerData.preSandboxController,
            character = playerData.preSandboxCharacter
        })
        return
    end

    -- Space Exploration deletes and recreates Characters; check that out next
    local fromSpaceExploration = SpaceExploration.GetPlayerCharacter(player)
    if fromSpaceExploration and fromSpaceExploration.valid then
        player.teleport(fromSpaceExploration.position, fromSpaceExploration.surface.name)
        player.set_controller({
            type = defines.controllers.character,
            character = fromSpaceExploration
        })
        return
    end

    -- We might at-least have a Surface to go back to
    if playerData.preSandboxSurfaceName and game.surfaces[playerData.preSandboxSurfaceName] then
        player.print("Unfortunately, your previous Character was lost, so it had to be recreated.")
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        local recreated = game.surfaces[playerData.preSandboxSurfaceName].create_entity {
            name = "character",
            position = playerData.preSandboxPosition,
            force = playerData.preSandboxForceName,
            raise_built = true,
        }
        player.set_controller({
            type = playerData.preSandboxController,
            character = recreated
        })
        return
    end

    -- Otherwise, we need a completely clean slate :(
    player.print("Unfortunately, your previous Character was completely lost, so you must start anew.")
    player.teleport({ 0, 0 }, "nauvis")
    local recreated = game.surfaces["nauvis"].create_entity {
        name = "character",
        position = { 0, 0 },
        force = playerData.preSandboxForceName,
        raise_built = true,
    }
    player.set_controller({
        type = playerData.preSandboxController,
        character = recreated
    })
end

-- Keep a Player's God-state, but change between Selected Sandboxes
function Sandbox.Transfer(player)
    local playerData = global.players[player.index]

    if playerData.insideSandbox == nil then
        Debug.log("Outside Sandbox, cannot transfer")
        return
    end

    local sandboxForce = Init.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        Debug.log("Completely Unknown Sandbox Surface, cannot use")
        return
    end
    Debug.log("Transferring to Sandbox: " .. surface.name)
    player.teleport({ 0, 0 }, surface)

    playerData.insideSandbox = playerData.selectedSandbox
end

-- Update Sandboxes Player if a Player actually changes Forces (outside of this mod)
function Sandbox.OnPlayerForceChanged(player)
    local playerData = global.players[player.index]
    local force = player.force
    if not Sandbox.IsSandboxForce(force)
            and playerData.forceName ~= force.name
    then
        Debug.log("Storing changed Player's Force: " .. player.name .. " -> " .. force.name)
        playerData.forceName = force.name

        local sandboxForceName = Sandbox.NameFromForce(force)

        playerData.sandboxForceName = sandboxForceName
        local labData = global.labSurfaces[playerData.labName]
        if labData then
            labData.sandboxForceName = sandboxForceName
        end

        if playerData.insideSandbox ~= nil then
            player.print("Your Force changed, so you have been removed from your Sandbox")
            playerData.preSandboxForceName = force.name
            Sandbox.Exit(player)
        end
        player.print("Your Force changed, so you might have to Reset your Lab")
    end
end

-- Update whether the Player is inside a known Sandbox
function Sandbox.OnPlayerSurfaceChanged(player)
    local playerData = global.players[player.index]
    local surfaceName = player.surface.name
    if surfaceName == playerData.labName then
        playerData.insideSandbox = Sandbox.player
    elseif surfaceName == global.sandboxForces[playerData.sandboxForceName].labName then
        playerData.insideSandbox = Sandbox.force
    elseif surfaceName == global.sandboxForces[playerData.sandboxForceName].seOrbitalSandboxZoneName then
        playerData.insideSandbox = Sandbox.forceOrbitalSandbox
    elseif surfaceName == global.sandboxForces[playerData.sandboxForceName].sePlanetaryLabZoneName then
        playerData.insideSandbox = Sandbox.forcePlanetaryLab
    else
        playerData.insideSandbox = nil
    end
end

-- Enter, Exit, or Transfer a Player across Sandboxes
function Sandbox.Toggle(player_index)
    local player = game.players[player_index]
    local playerData = global.players[player.index]

    if not Sandbox.IsEnabled(playerData.selectedSandbox) then
        playerData.selectedSandbox = Sandbox.player
    end

    if playerData.insideSandbox ~= nil
            and playerData.insideSandbox ~= playerData.selectedSandbox
    then
        Sandbox.Transfer(player)
    elseif playerData.insideSandbox ~= nil then
        Sandbox.Exit(player)
    else
        Sandbox.Enter(player)
    end
end

return Sandbox
