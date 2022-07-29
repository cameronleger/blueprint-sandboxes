local Migrate = {}

Migrate.version = 010902

function Migrate.Run()
    if not global.version then
        global.version = 0
    end

    if global.version < Migrate.version then
        if global.version < 010003 then Migrate.v1_0_3() end
        if global.version < 010100 then Migrate.v1_1_0() end
        if global.version < 010401 then Migrate.v1_4_1() end
        if global.version < 010500 then Migrate.v1_5_0() end
        if global.version < 010600 then Migrate.v1_6_0() end
        if global.version < 010700 then Migrate.v1_7_0() end
        if global.version < 010703 then Migrate.v1_7_3() end
        if global.version < 010704 then Migrate.v1_7_4() end
    end

    global.version = Migrate.version
end

function Migrate.RecreateGuis()
    for _, player in pairs(game.players) do
        ToggleGUI.Destroy(player)
        ToggleGUI.Init(player)
    end
end

function Migrate.v1_0_3()
    --[[
    It was discovered that in on_configuration_changed Space Exploration would
    "fix" all Tiles for all Zones that it knows of, which causes problems
    specifically for the Planetary Sandbox, which initially used Stars.
    At this point, we unfortunately have to completely remove those Sandboxes,
    which is unavoidable because by the nature of this update we would have
    triggered the complete-reset of that Surface anyway.
    ]]

    Debug.log("Migration 1.0.3 Starting")

    if SpaceExploration.enabled then
        local planetaryLabId = 3
        local planetaryLabsOnStars = {}
        local playersToKickFromPlanetaryLabs = {}

        for name, surfaceData in pairs(global.seSurfaces) do
            if (not surfaceData.orbital) and SpaceExploration.IsStar(name) then
                table.insert(planetaryLabsOnStars, {
                    zoneName = name,
                    sandboxForceName = surfaceData.sandboxForceName,
                })
            end
        end

        for index, player in pairs(game.players) do
            local playerData = global.players[index]
            if playerData.insideSandbox == planetaryLabId
                    and SpaceExploration.IsStar(player.surface.name)
            then
                table.insert(playersToKickFromPlanetaryLabs, player)
            end
        end

        for _, player in pairs(playersToKickFromPlanetaryLabs) do
            Debug.log("Kicking Player out of Planetary Lab: " .. player.name)
            Sandbox.Exit(player)
        end

        for _, surfaceData in pairs(planetaryLabsOnStars) do
            Debug.log("Destroying Planetary Lab inside Star: " .. surfaceData.zoneName)
            SpaceExploration.DeleteSandbox(
                    global.sandboxForces[surfaceData.sandboxForceName],
                    surfaceData.zoneName
            )
        end
    end

    Debug.log("Migration 1.0.3 Finished")
end

function Migrate.v1_1_0()
    --[[
    A "persistent" Sandbox Inventory was created for each Player.
    ]]

    Debug.log("Migration 1.1.0 Starting")

    for index, player in pairs(game.players) do
        local playerData = global.players[index]
        playerData.sandboxInventory = game.create_inventory(#player.get_main_inventory())
        if playerData.insideSandbox ~= nil then
            Debug.log("Player inside Sandbox, fully-syncing the inventory.")
            Inventory.Persist(
                    player.get_main_inventory(),
                    playerData.sandboxInventory
            )
        end
    end

    Debug.log("Migration 1.1.0 Finished")
end

function Migrate.v1_4_1()
    --[[
    The levels for level-based Research wasn't being synchronized.
    ]]

    Debug.log("Migration 1.4.1 Starting")

    Research.SyncAllForces()

    Debug.log("Migration 1.4.1 Finished")
end

function Migrate.v1_5_0()
    --[[
    Bonus Slots for Sandbox Force Inventories were added.
    ]]

    Debug.log("Migration 1.5.0 Starting")

    Force.SyncAllForces()

    Debug.log("Migration 1.5.0 Finished")
end

function Migrate.v1_6_0()
    --[[
    Last-known positions inside Sandboxes were added.
    ]]

    Debug.log("Migration 1.6.0 Starting")

    for index, _ in pairs(game.players) do
        local playerData = global.players[index]
        playerData.lastSandboxPositions = {}
    end

    Debug.log("Migration 1.6.0 Finished")
end

function Migrate.v1_7_0()
    --[[
    Configurable-per-Sandbox daytime was added.
    ]]

    Debug.log("Migration 1.7.0 Starting")

    for surfaceName, _ in pairs(global.labSurfaces) do
        local surface = game.surfaces[surfaceName]
        if surface then
            surface.always_day = false
            surface.freeze_daytime = true
            surface.daytime = 0.95
            global.labSurfaces[surfaceName].daytime = 0.95
        end
    end

    for surfaceName, _ in pairs(global.seSurfaces) do
        local surface = game.surfaces[surfaceName]
        if surface then
            surface.always_day = false
            surface.freeze_daytime = true
            surface.daytime = 0.95
            global.seSurfaces[surfaceName].daytime = 0.95
        end
    end

    Migrate.RecreateGuis()

    Debug.log("Migration 1.7.0 Finished")
end

function Migrate.v1_7_3()
    --[[
    The daylight portrait icon had the same name as the Reset Button.
    ]]

    Debug.log("Migration 1.7.3 Starting")

    Migrate.RecreateGuis()

    Debug.log("Migration 1.7.3 Finished")
end

function Migrate.v1_7_4()
    --[[
    The 1.7.3 migration wasn't correctly applied to 1.7.x
    Allow-all-Tech was incorrectly applying the existing Force's bonuses
    ]]

    Migrate.v1_7_3()

    Debug.log("Migration 1.7.4 Starting")

    if settings.global[Settings.allowAllTech].value then
        game.print("Blueprint Sandboxes Notice: You had the Unlock-all-Technologies " ..
                "Setting enabled, but there was a bug pre-1.7.4 that was incorrectly " ..
                "overriding some of the bonuses from leveled-research. You should " ..
                "disable, then re-enable this setting in order to fix that.")
    end

    Debug.log("Migration 1.7.4 Finished")
end

return Migrate
