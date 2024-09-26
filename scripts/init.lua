-- First-time Setup for new Games and new Players
local Init = {}

-- Setup Player, if necessary
function Init.Player(player)
    if storage.players[player.index] then
        log("Skip Init.Player: " .. player.name)
        return
    end

    log("Init.Player: " .. player.name)
    local playerLabName = Lab.NameFromPlayer(player)
    local sandboxForceName = Sandbox.NameFromForce(player.force)
    storage.players[player.index] = {
        forceName = player.force.name,
        labName = playerLabName,
        sandboxForceName = sandboxForceName,
        selectedSandbox = Sandbox.player,
        sandboxInventory = nil,
        insideSandbox = nil,
        lastSandboxPositions = {},
    }
    ToggleGUI.Init(player)
end

-- Reset all Mod data
function Init.FirstTimeInit()
    log("Init.FirstTimeInit")
    storage.version = Migrate.version
    storage.forces = {}
    storage.players = {}
    storage.labSurfaces = {}
    storage.sandboxForces = {}
    storage.seSurfaces = {}
    storage.equipmentInProgress = {}
    storage.asyncCreateQueue = Queue.New()
    storage.asyncUpgradeQueue = Queue.New()
    storage.asyncDestroyQueue = Queue.New()
    storage.lastSettingForAsyncGodTick = settings.global[Settings.godAsyncTick].value

    -- Warning: do not rely on this alone; new Saves have no Players/Forces yet
    for _, force in pairs(game.forces) do
        Force.Init(force)
    end
    for _, player in pairs(game.players) do
        Init.Player(player)
    end
end

return Init
