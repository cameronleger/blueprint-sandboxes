-- Code for Factorio's new Remote controller
local RemoteView = {}

-- When a Surface is created, hide it from all Sandboxes
function RemoteView.HideFromAllSandboxes(surface)
    log("Hiding a new Surface from all Sandbox Forces: " .. surface.name)
    for _, force in pairs(game.forces) do
        if Sandbox.IsSandboxForce(force) then
            RemoteView.Hide(surface, force)
        end
    end
end

-- When a Sandbox is created, hide it from everyone
function RemoteView.HideSandboxFromEveryone(surface)
    log("Hiding a new Sandbox from all Forces: " .. surface.name)
    for _, force in pairs(game.forces) do
        RemoteView.Hide(surface, force)
    end
end

-- When a Force is created, hide all Sandboxes from them
function RemoteView.HideAllSandboxes(force)
    log("Hiding all Sandboxes from new Force: " .. force.name)
    for _, surface in pairs(game.surfaces) do
        if Sandbox.IsSandbox(surface) then
            RemoteView.Hide(surface, force)
        end
    end
end

-- When a Sandbox Force is created, hide all Surfaces from them
function RemoteView.HideEverythingInSandboxes(sandboxForce)
    log("Hiding everything from Sandbox Force: " .. sandboxForce.name)
    for _, surface in pairs(game.surfaces) do
        RemoteView.Hide(surface, sandboxForce)
    end
end

-- When a Sandbox Force is created, hide all Surfaces from them
function RemoteView.IsUsingRemoteView(player)
    return player.controller_type == defines.controllers.remote
end

function RemoteView.Hide(surface, force)
    force.set_surface_hidden(surface, true)
end

return RemoteView
