-- Code for Factorio's new Remote controller
local RemoteView = {}

-- When initialized, setup default hidden states
function RemoteView.Init()
    for _, force in pairs(game.forces) do
        RemoteView.HideAllSandboxes(force)
        if Sandbox.IsSandboxForce(force) then
            RemoteView.HideEverythingInSandboxes(force)
        end
    end
end

-- When a Surface is created, hide it from all Sandboxes
---@param surface LuaSurface
function RemoteView.HideFromAllSandboxes(surface)
    log("Hiding a new Surface from all Sandbox Forces: " .. surface.name)
    for _, force in pairs(game.forces) do
        if Sandbox.IsSandboxForce(force) then
            RemoteView.Hide(surface, force)
        end
    end
end

-- When a Sandbox is created, hide it from everyone
---@param surface LuaSurface
function RemoteView.HideSandboxFromEveryone(surface)
    log("Hiding a new Sandbox from all Forces: " .. surface.name)
    for _, force in pairs(game.forces) do
        RemoteView.Hide(surface, force)
    end
end

-- When a Force is created, hide all Sandboxes from them
---@param force LuaForce
function RemoteView.HideAllSandboxes(force)
    log("Hiding all Sandboxes from new Force: " .. force.name)
    for _, surface in pairs(game.surfaces) do
        if Sandbox.IsSandbox(surface) then
            RemoteView.Hide(surface, force)
        end
    end
end

-- When a Sandbox Force is created, hide all Surfaces from them
---@param sandboxForce LuaForce
function RemoteView.HideEverythingInSandboxes(sandboxForce)
    log("Hiding everything from Sandbox Force: " .. sandboxForce.name)
    for _, surface in pairs(game.surfaces) do
        RemoteView.Hide(surface, sandboxForce)
    end
end

-- Determine if the Remote View is being used
---@param player LuaPlayer
function RemoteView.IsUsingRemoteView(player)
    return player.controller_type == defines.controllers.remote
end

-- If using Remote View, attempt to go back to the Character
---@param player LuaPlayer
function RemoteView.EnsureSafeExit(player)
    if not RemoteView.IsUsingRemoteView(player) then
        return true
    end
    if player.physical_controller_type == defines.controllers.character then
        local character = player.character
        if not character then
            -- Cannot close a Remote View without a real Character
            return false
        end
        if character.surface.platform then
            -- Being on a Platform means the Remote View must remain open
            return false
        end
        if character.driving then
            -- Somehow swapping to the Character while driving exits the vehicle
            return false
        end
        
        if character.surface_index ~= player.surface_index then
            Teleport.ToPositionOnSurface(player, character.surface, character.position)
        end
        player.set_controller({
            type = defines.controllers.character,
            character = character,
        })
        return true
    else
        player.set_controller({
            type = player.physical_controller_type,
        })
    end
end

---@param surface LuaSurface
---@param force LuaForce
function RemoteView.Hide(surface, force)
    force.set_surface_hidden(surface, true)
end

return RemoteView
