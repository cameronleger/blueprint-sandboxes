-- Managing multiple Sandboxes for each Player/Force
local Sandbox = {}

Sandbox.pfx = BPSB.pfx .. "sb-"

-- GUI Dropdown items for Sandboxes
Sandbox.choices = {
    { "sandbox." .. Sandbox.pfx .. "player-lab" },
    { "sandbox." .. Sandbox.pfx .. "force-lab" },
}
if SpaceExploration.enabled() then
    Sandbox.choices[3] = { "sandbox." .. Sandbox.pfx .. "force-lab-space-exploration" }
    Sandbox.choices[4] = { "sandbox." .. Sandbox.pfx .. "force-orbit-space-exploration" }
end

-- Constants to represent indexes for Sandbox.choices
Sandbox.player = 1
Sandbox.force = 2
Sandbox.forcePlanetaryLab = 3
Sandbox.forceOrbitalSandbox = 4

-- A unique per-Force Sandbox Name
---@param force LuaForce
function Sandbox.NameFromForce(force)
    return Sandbox.pfx .. "f-" .. force.name
end

-- Whether the Force is specific to Blueprint Sandboxes
---@param force LuaForce
function Sandbox.IsSandboxForce(force)
    -- return string.sub(force.name, 1, pfxLength) == Sandbox.pfx
    return not not storage.sandboxForces[force.name]
end

-- Whether something is any type of Sandbox
function Sandbox.IsSandbox(thingWithName)
    return Lab.IsLab(thingWithName)
            or SpaceExploration.IsSandbox(thingWithName)
end

-- Whether something is any type of Sandbox
---@param player LuaPlayer
function Sandbox.IsPlayerInsideSandbox(player)
    return Sandbox.IsSandbox(player.surface)
end

-- Whether a Sandbox choice is allowed
function Sandbox.IsEnabled(selectedSandbox)
    if selectedSandbox == Sandbox.player then
        return true
    elseif selectedSandbox == Sandbox.force then
        return true
    elseif selectedSandbox == Sandbox.forceOrbitalSandbox then
        return SpaceExploration.enabled()
    elseif selectedSandbox == Sandbox.forcePlanetaryLab then
        return SpaceExploration.enabled()
    else
        log("Impossible Choice for Sandbox: " .. selectedSandbox)
        return false
    end
end

-- Which Surface Name to use for this Player based on their Selected Sandbox
---@param player LuaPlayer
---@return LuaSurface | nil
function Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    local playerData = storage.players[player.index]

    if playerData.selectedSandbox == Sandbox.player
    then
        return Lab.GetOrCreateSurface(playerData.labName, sandboxForce)
    elseif playerData.selectedSandbox == Sandbox.force
    then
        return Lab.GetOrCreateSurface(storage.sandboxForces[sandboxForce.name].labName, sandboxForce)
    elseif SpaceExploration.enabled()
            and playerData.selectedSandbox == Sandbox.forceOrbitalSandbox
    then
        return SpaceExploration.GetOrCreateOrbitalSurfaceForForce(player, sandboxForce)
    elseif SpaceExploration.enabled()
            and playerData.selectedSandbox == Sandbox.forcePlanetaryLab
    then
        return SpaceExploration.GetOrCreatePlanetarySurfaceForForce(player, sandboxForce)
    else
        log("Impossible Choice for Sandbox: " .. playerData.selectedSandbox)
        return
    end
end

-- Convert the Player to God-mode, save their previous State, and enter Selected Sandbox
---@param player LuaPlayer
function Sandbox.Enter(player)
    local playerData = storage.players[player.index]

    if Sandbox.IsPlayerInsideSandbox(player) then
        log("Already inside Sandbox: " .. playerData.insideSandbox)
        return
    end

    if not RemoteView.EnsureSafeExit(player) then
        player.print("You are using a remote view that cannot be safely closed, so you cannot enter a Sandbox. Return to your Character first.")
        return
    end

    if player.controller_type == defines.controllers.cutscene then
        player.print("You are watching a cutscene, so you cannot enter a Sandbox. Wait for it to end first.")
        return
    end

    if player.driving and player.character and not player.vehicle then
        player.print("You are riding a rocket, so you cannot enter a Sandbox. Land on a planet first.")
        return
    end

    if player.character and player.character.name == "character-jetpack" then
        player.print("You are using a Jetpack, so you cannot enter a Sandbox. Land on the ground first.")
        return
    end

    if player.stashed_controller_type
            and player.stashed_controller_type ~= defines.controllers.editor
    then
        player.print("You are already detached from your Character, so you cannot enter a Sandbox. Return to your Character first.")
        return
    end

    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        log("Completely Unknown Sandbox Surface, cannot use")
        return
    end
    log("Entering Sandbox: " .. surface.name)

    -- Store some temporary State to use once inside the Sandbox
    local inputBlueprint = Inventory.GetCursorBlueprintString(player)

    --[[
    Otherwise, there is a Factorio "bug" that can destroy what was in the Cursor.
    It seems to happen with something from the Inventory being in the Stack, then
    entering the Sandbox, then copying something from the Sandbox, then exiting the
    Sandbox. At this point, the Cursor Stack is still fine and valid, but it seems
    to have lost its original location, so "clearing" it out will destroy it.
    ]]
    player.clear_cursor()

    -- Store the Player's previous State (that must be referenced to Exit)
    playerData.preSandboxForceName = player.force.name
    playerData.preSandboxCharacter = player.character
    playerData.preSandboxController = player.controller_type
    playerData.preSandboxPosition = player.position
    playerData.preSandboxSurfaceName = player.surface.name
    playerData.preSandboxCheatMode = player.cheat_mode
    if player.permission_group then
        playerData.preSandboxPermissionGroupId = player.permission_group.name
    end

    -- Sometimes a Player has a volatile Inventory that needs restoring later
    if Inventory.ShouldPersist(playerData.preSandboxController) then
        playerData.preSandboxInventory = Inventory.Persist(
                player.get_main_inventory(),
                playerData.preSandboxInventory
        )
    else
        if playerData.preSandboxInventory then
            playerData.preSandboxInventory.destroy()
            playerData.preSandboxInventory = nil
        end
    end

    -- Harmlessly detach the Player from their Character
    local character = player.character
    player.set_controller({ type = defines.controllers.god })
    if character and not character.associated_player then
        player.associate_character(character)
    end

    -- Harmlessly teleport their God-body to the Sandbox
    player.teleport(playerData.lastSandboxPositions[surface.name] or { 0, 0 }, surface)

    -- Swap to the new Force; it has different bonuses!
    player.force = sandboxForce

    -- Since the Sandbox might have Cheat Mode enabled, EditorExtensions won't receive an Event for this otherwise
    if player.cheat_mode then
        player.cheat_mode = false
    end

    -- Enable Cheat mode _afterwards_, since EditorExtensions will alter the Force (now the Sandbox Force) based on this
    player.cheat_mode = true

    -- Set some Permissions so the Player cannot affect their other Surfaces
    local newPermissions = Permissions.GetOrCreate(player)
    if newPermissions then
        player.permission_group = newPermissions
    end

    -- Harmlessly ensure our own Recipes are enabled
    -- TODO: It's unclear why this must happen _after_ the above code
    Research.EnableSandboxSpecificResearch(sandboxForce)

    -- Now that everything has taken effect, restoring the Inventory is safe
    Inventory.Restore(
            playerData.sandboxInventory,
            player.get_main_inventory()
    )

    -- Then, restore the Blueprint in the Cursor
    if inputBlueprint then
        player.cursor_stack.import_stack(inputBlueprint)
        player.cursor_stack_temporary = true
    end
end

-- Convert the Player to their previous State, and leave Selected Sandbox
---@param player LuaPlayer
function Sandbox.Exit(player)
    local playerData = storage.players[player.index]

    if not Sandbox.IsPlayerInsideSandbox(player) then
        log("Already outside Sandbox")
        return
    end

    -- Capture the cursor's blueprint to reimport it after exiting, if necessary
    local outputBlueprint = nil
    if not RemoteView.IsUsingRemoteView(player) then
        outputBlueprint = Inventory.GetCursorBlueprintString(player)
    end

    -- Remember where they left off
    playerData.lastSandboxPositions[player.surface.name] = player.position

    -- Attach the Player back to their original Character (also changes force)
    Sandbox.RecoverPlayerCharacter(player, playerData)

    -- Sometimes a Player is already a God (like in Sandbox), and their Inventory wasn't on a body
    if Inventory.ShouldPersist(playerData.preSandboxController) then
        Inventory.Restore(
                playerData.preSandboxInventory,
                player.get_main_inventory()
        )
    end

    -- Reset the Player's previous State
    if playerData.preSandboxInventory then
        playerData.preSandboxInventory.destroy()
        playerData.preSandboxInventory = nil
    end

    -- Potentially, restore the Blueprint in the Cursor
    if outputBlueprint and Inventory.WasCursorSafelyCleared(player) then
        player.cursor_stack.import_stack(outputBlueprint)
        player.cursor_stack_temporary = true
    end
end

---@param player LuaPlayer
---@param character LuaEntity
local function AttachPlayerToCharacter(player, character)
    player.teleport(character.position, character.surface)
    player.set_controller({
        type = defines.controllers.character,
        character = character
    })
end

-- Ensure the Player has a Character to go back to
---@param player LuaPlayer
function Sandbox.RecoverPlayerCharacter(player, playerData)
    -- The Remote View is an easy exit
    if player.controller_type == defines.controllers.remote
        and player.physical_controller_type == defines.controllers.character
    then
        if RemoteView.EnsureSafeExit(player) then
            return
        end
    end

    -- Hopeful situation: we directly know about the last valid character
    if playerData.preSandboxController == defines.controllers.character
        and playerData.preSandboxCharacter
        and playerData.preSandboxCharacter.valid
    then
        AttachPlayerToCharacter(player, playerData.preSandboxCharacter)
        return
    end

    -- Still hopeful situation: the player was associated to the character somehow
    local characters = player.get_associated_characters()
    if #characters > 0 then
        if #characters > 1 then
            player.print("Warning: you have multiple associated characters but the Sandbox does not know exactly which one you wanted")
        end
        for _, character in ipairs(characters) do
            if character.valid and not character.player then
                AttachPlayerToCharacter(player, character)
                return
            end
        end
    end

    -- Still hopeful situation: we know about the last non-character controller and location
    if playerData.preSandboxController
        and playerData.preSandboxController ~= defines.controllers.character
        and playerData.preSandboxPosition
        and playerData.preSandboxSurfaceName
    then
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        player.set_controller({ type = playerData.preSandboxController })
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
    if playerData.preSandboxController == defines.controllers.character
        and playerData.preSandboxPosition
        and playerData.preSandboxSurfaceName
        and game.surfaces[playerData.preSandboxSurfaceName]
    then
        player.print("Unfortunately, your previous Character was lost, so it had to be recreated.")
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        local recreated = game.surfaces[playerData.preSandboxSurfaceName].create_entity {
            name = "character",
            position = playerData.preSandboxPosition,
            force = playerData.preSandboxForceName or "player",
            raise_built = true,
        }
        player.set_controller({
            type = defines.controllers.character,
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
        force = playerData.preSandboxForceName or "player",
        raise_built = true,
    }
    player.set_controller({
        type = defines.controllers.character,
        character = recreated
    })
end

-- Keep a Player's God-state, but change between Selected Sandboxes
---@param player LuaPlayer
function Sandbox.Transfer(player)
    local playerData = storage.players[player.index]

    if not Sandbox.IsPlayerInsideSandbox(player) then
        log("Outside Sandbox, cannot transfer")
        return
    end

    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        log("Completely Unknown Sandbox Surface, cannot use")
        return
    end

    log("Transferring to Sandbox: " .. surface.name)
    playerData.lastSandboxPositions[player.surface.name] = player.position
    Teleport.ToPositionOnSurface(player, surface, playerData.lastSandboxPositions[surface.name] or { 0, 0 })
end

-- Update Sandboxes Player if a Player actually changes Forces (outside of this mod)
---@param player LuaPlayer
function Sandbox.OnPlayerForceChanged(player)
    local playerData = storage.players[player.index]
    local force = player.force
    if not Sandbox.IsSandboxForce(force)
            and playerData.forceName ~= force.name
    then
        log("Storing changed Player's Force: " .. player.name .. " -> " .. force.name)
        playerData.forceName = force.name

        local sandboxForceName = Sandbox.NameFromForce(force)

        playerData.sandboxForceName = sandboxForceName
        local labData = storage.labSurfaces[playerData.labName]
        if labData then
            labData.sandboxForceName = sandboxForceName
        end

        local labForce = Force.GetOrCreateSandboxForce(force)
        if Sandbox.IsPlayerInsideSandbox(player) then
            if Sandbox.GetSandboxChoiceFor(player, player.surface) ~= Sandbox.player then
                player.print("Your Force changed, so you have been removed from a Sandbox that you are no longer allowed in")
                playerData.preSandboxForceName = force.name
                Sandbox.Exit(player)
            else
                player.force = labForce
            end
        end

        local labSurface = game.surfaces[Lab.NameFromPlayer(player)]
        if labSurface then
            Lab.AssignEntitiesToForce(labSurface, labForce)
        end
    end
end

-- Determine whether the Player is inside a known Sandbox
---@param player LuaPlayer
---@param surface LuaSurface
function Sandbox.GetSandboxChoiceFor(player, surface)
    local playerData = storage.players[player.index]
    if surface.name == playerData.labName then
        return Sandbox.player
    elseif surface.name == storage.sandboxForces[playerData.sandboxForceName].labName then
        return Sandbox.force
    elseif surface.name == storage.sandboxForces[playerData.sandboxForceName].seOrbitalSandboxZoneName then
        return Sandbox.forceOrbitalSandbox
    elseif surface.name == storage.sandboxForces[playerData.sandboxForceName].sePlanetaryLabZoneName then
        return Sandbox.forcePlanetaryLab
    elseif Factorissimo.IsFactory(surface) then
        local outsideSurface = Factorissimo.GetOutsideSurfaceForFactory(
                surface,
                player.position
        )
        if outsideSurface then
            return Sandbox.GetSandboxChoiceFor(player, outsideSurface)
        end
    end
    return nil
end

-- Update whether the Player is inside a known Sandbox
---@param player LuaPlayer
function Sandbox.OnPlayerSurfaceChanged(player)
    local playerData = storage.players[player.index]
    local insideSandbox = Sandbox.GetSandboxChoiceFor(player, player.surface)
    local lastKnownSandbox = storage.players[player.index].insideSandbox

    local wasInSandbox = lastKnownSandbox ~= nil
    local nowInSandbox = not not insideSandbox

    if not wasInSandbox and nowInSandbox then
        log("Entered a Sandbox: " .. player.surface.name)
    elseif wasInSandbox and not nowInSandbox then
        log("Exiting last known Sandbox " .. lastKnownSandbox .. " to new Surface: " .. player.surface.name)

        -- Don't let anyone attempt to edit Surface Properties of other Surfaces!
        SurfacePropsGUI.Destroy(player)

        -- Swap to their original Force (in case they're not sent back to a Character)
        if playerData.preSandboxForceName and player.force.name ~= playerData.preSandboxForceName then
            player.force = playerData.preSandboxForceName
        end
    
        -- Toggle Cheat mode _afterwards_, just in case EditorExtensions ever listens to this Event
        local desiredCheatMode = playerData.preSandboxCheatMode or false
        if player.cheat_mode ~= desiredCheatMode then
            player.cheat_mode = desiredCheatMode
        end

        -- Swap to their original Permissions
        if playerData.preSandboxPermissionGroupId then
            player.permission_group = game.permissions.get_group(playerData.preSandboxPermissionGroupId)
        else
            player.permission_group = nil
        end

        -- Cleanup some restored states that may go stale and cannot be relied on later
        playerData.preSandboxForceName = nil
        playerData.preSandboxCheatMode = nil
        playerData.preSandboxPermissionGroupId = nil

        -- Cleanup some unused states that may go stale and cannot be relied on later
        playerData.preSandboxCharacter = nil
        playerData.preSandboxController = nil
        playerData.preSandboxPosition = nil
        playerData.preSandboxSurfaceName = nil
    end

    playerData.insideSandbox = insideSandbox
end

-- Enter, Exit, or Transfer a Player across Sandboxes
function Sandbox.Toggle(player_index)
    local player = game.players[player_index]
    local playerData = storage.players[player.index]

    if Factorissimo.IsFactoryInsideSandbox(player.surface, player.position) then
        player.print("You are inside of a Factory, so you cannot change Sandboxes")
        return
    end

    if not Sandbox.IsEnabled(playerData.selectedSandbox) then
        playerData.selectedSandbox = Sandbox.player
    end

    if Sandbox.IsPlayerInsideSandbox(player)
            and playerData.insideSandbox ~= playerData.selectedSandbox
    then
        Sandbox.Transfer(player)
    elseif Sandbox.IsPlayerInsideSandbox(player) then
        Sandbox.Exit(player)
    else
        SpaceExploration.ExitRemoteView(player)
        Sandbox.Enter(player)
    end
end

-- Whether the Global Electrical Network of a Sandbox exists
---@param surface LuaSurface
---@return boolean
function Sandbox.HasGlobalElectricalNetwork(surface)
    if Lab.IsLab(surface) or SpaceExploration.IsSandbox(surface) then
        return surface.has_global_electric_network
    else
        return false
    end
end

-- Toggle the Global Electrical Network of a Sandbox
---@param surface LuaSurface
---@return boolean | nil
function Sandbox.ToggleGlobalElectricalNetwork(surface)
    if Lab.IsLab(surface) or SpaceExploration.IsSandbox(surface) then
        if surface.has_global_electric_network then
            surface.destroy_global_electric_network()
            return false
        else
            surface.create_global_electric_network()
            return true
        end
    end
end

return Sandbox
