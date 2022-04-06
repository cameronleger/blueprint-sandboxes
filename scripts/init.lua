-- First-time Setup for new Games, new Players, and new Forces
local Init = {}

-- Setup Force, if necessary
function Init.Force(force)
    if global.forces[force.name]
            or Sandbox.IsSandboxForce(force)
            or #force.players < 1
    then
        Debug.log("Skip Init.Force: " .. force.name)
        return
    end

    Debug.log("Init.Force: " .. force.name)
    local forceLabName = Lab.NameFromForce(force)
    local sandboxForceName = Sandbox.NameFromForce(force)
    global.forces[force.name] = {
        sandboxForceName = sandboxForceName,
    }
    global.sandboxForces[sandboxForceName] = {
        forceName = force.name,
        hiddenItemsUnlocked = false,
        labName = forceLabName,
        sePlanetaryLabZoneName = nil,
        seOrbitalSandboxZoneName = nil,
    }
end

-- Delete Force's information, if necessary
function Init.MergeForce(oldForceName, newForce)
    -- Double-check we know about this Force
    local oldForceData = global.forces[oldForceName]
    local newForceData = global.forces[newForce.name]
    if not oldForceData or not newForceData then
        Debug.log("Skip Init.MergeForce: " .. oldForceName .. " -> " .. newForce.name)
        return
    end
    local sandboxForceName = oldForceData.sandboxForceName
    local oldSandboxForceData = global.sandboxForces[sandboxForceName]
    local oldSandboxForce = game.forces[sandboxForceName]

    -- Bounce any Players currently using the older Sandboxes
    if oldSandboxForce then
        for _, player in pairs(oldSandboxForce.players) do
            local playerData = global.players[player.index]
            if playerData.insideSandbox then
                Debug.log("Init.MergeForce must manually change Sandbox Player's Force: " .. player.name .. " -> " .. newForce.name)
                player.force = newForce
            end
        end
    end

    -- Delete the old Force-related Surfaces/Forces
    Lab.DeleteLab(oldSandboxForceData.labName)
    SpaceExploration.DeleteSandbox(oldSandboxForceData, oldSandboxForceData.sePlanetaryLabZoneName)
    SpaceExploration.DeleteSandbox(oldSandboxForceData, oldSandboxForceData.seOrbitalSandboxZoneName)
    if oldSandboxForce then
        Debug.log("Init.MergeForce must merge Sandbox Forces: " .. oldSandboxForce.name .. " -> " .. newForceData.sandboxForceName)
        game.merge_forces(oldSandboxForce, newForceData.sandboxForceName)
    end

    -- Delete the old Force's data
    global.forces[oldForceName] = nil
    global.sandboxForces[sandboxForceName] = nil
end

-- Configure Sandbox Force
function Init.ConfigureSandboxForce(force, sandboxForce)
    -- Ensure the two Forces don't attack each other
    force.set_cease_fire(sandboxForce, true)
    sandboxForce.set_cease_fire(force, true)

    -- Counteract Space Exploration's slow Mining Speed for Gods
    sandboxForce.manual_mining_speed_modifier = 1000000000

    -- Why should you Research in here?
    sandboxForce.laboratory_speed_modifier = -0.999

    return sandboxForce
end

-- Create Sandbox Force, if necessary
function Init.GetOrCreateSandboxForce(force)
    local sandboxForceName = global.forces[force.name].sandboxForceName
    local sandboxForce = game.forces[sandboxForceName]
    if sandboxForce then
        Init.ConfigureSandboxForce(force, sandboxForce)
        return sandboxForce
    end

    Debug.log("Creating Sandbox Force: " .. sandboxForceName)
    sandboxForce = game.create_force(sandboxForceName)
    Init.ConfigureSandboxForce(force, sandboxForce)
    Research.Sync(force, sandboxForce)
    return sandboxForce
end

-- Setup Player, if necessary
function Init.Player(player)
    if global.players[player.index] then
        Debug.log("Skip Init.Player: " .. player.name)
        return
    end

    Debug.log("Init.Player: " .. player.name)
    local playerLabName = Lab.NameFromPlayer(player)
    local sandboxForceName = Sandbox.NameFromForce(player.force)
    global.players[player.index] = {
        forceName = player.force.name,
        labName = playerLabName,
        sandboxForceName = sandboxForceName,
        selectedSandbox = Sandbox.player,
        insideSandbox = nil,
    }
    ToggleGUI.Init(player)
end

-- Reset all Mod data
function Init.FirstTimeInit()
    global.forces = {}
    global.players = {}
    global.labSurfaces = {}
    global.sandboxForces = {}
    global.seSurfaces = {}
    global.lastSettingForAsyncGodTick = settings.global[Settings.godAsyncTick].value

    -- Warning: do not rely on this alone; new Saves have no Players/Forces yet
    for _, force in pairs(game.forces) do
        Init.Force(force)
    end
    for _, player in pairs(game.players) do
        Init.Player(player)
    end
end

return Init
