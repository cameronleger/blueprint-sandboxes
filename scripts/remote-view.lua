-- Code for Factorio's new Remote controller
local RemoteView = {}

RemoteView.chartAllSandboxesTick = 300

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

---@param surface LuaSurface
---@param force LuaForce
function RemoteView.Hide(surface, force)
    force.set_surface_hidden(surface, true)
end

-- Charts each Sandbox that a Player is currently inside of
function RemoteView.ChartAllOccupiedSandboxes()
    local charted = {}
    for _, player in pairs(game.players) do
        local hash = player.force.name .. player.surface.name
        if Sandbox.IsSandbox(player.surface) and not charted[hash] then
            player.force.chart_all(player.surface)
            charted[hash] = true
        end
    end
end

return RemoteView
