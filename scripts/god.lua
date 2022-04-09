-- Custom Extensions to the God-Controller
local God = {}

-- Whether the Entity or Tile is a Ghost (can be revived)
function God.IsGhost(entity)
    return entity.valid
            and (entity.type == "tile-ghost" or entity.type == "entity-ghost")
end

-- Immediately destroy an Entity (and perhaps related Entities)
function God.Destroy(entity)
    if entity.valid
            and entity.can_be_destroyed()
            and entity.to_be_deconstructed()
    then

        -- If the Entity has Transport Lines, also delete any Items on it
        if entity.prototype.belt_speed ~= nil then
            for i = 1, entity.get_max_transport_line_index() do
                entity.get_transport_line(i).clear()
            end
        end

        -- If the Entity represents a Hidden Tile underneath
        if entity.type == "deconstructible-tile-proxy" then
            local hiddenTile = entity.surface.get_hidden_tile(entity.position)
            entity.surface.set_tiles {
                {
                    name = hiddenTile,
                    position = entity.position,
                }
            }
        end

        entity.destroy({ raise_destroy = true })
    end
end

-- Immediately Revive a Ghost Entity
function God.Revive(entity)
    if entity.valid then
        if entity.type == "tile-ghost" then
            -- Tiles are simple Revives
            entity.revive({ raise_revive = true })
        elseif entity.type == "entity-ghost" then
            -- Entities might also want Items after Reviving
            _, revived, request = entity.silent_revive({
                return_item_request_proxy = true,
                raise_revive = true
            })

            if not revived then return end

            -- Insert any Requested Items (like Modules, Fuel)
            if request then
                for name, count in pairs(request.item_requests) do
                    request.proxy_target.insert({
                        name = name,
                        count = count,
                    })
                end
                request.destroy()
            end
        end
    end
end

-- Immediately turn one Entity into another
function God.Upgrade(entity)
    if entity.valid
            and entity.to_be_upgraded()
    then
        local target = entity.get_upgrade_target()
        local direction = entity.get_upgrade_direction()

        local options = {
            name = target.name,
            position = entity.position,
            direction = direction or entity.direction,
            force = entity.force,
            fast_replace = true,
            spill = false,
            raise_built = true,
        }

        -- Otherwise it fails to place "output" sides (it defaults to "input")
        if entity.type == "underground-belt" then
            options.type = entity.belt_to_ground_type
        end

        local result = entity.surface.create_entity(options)

        if result == nil then
            Debug.log("Upgrade Failed, Cancelling: " .. entity.name)
            entity.cancel_upgrade(entity.force)
        end
    end
end

-- Ensure the God's Inventory is kept in-sync
function God.OnInventoryChanged(event)
    local player = game.players[event.player_index]
    local playerData = global.players[event.player_index]
    if playerData.insideSandbox ~= nil then
        God.StoreInventory(player)
    end
end

-- Sync the God's Inventory
function God.StoreInventory(player)
    local playerData = global.players[player.index]
    local inventory = player.get_main_inventory()
    playerData.sandboxInventory.resize(#inventory)
    for i = 1, #inventory do
        playerData.sandboxInventory[i].set_stack(inventory[i])
    end
end

-- Load the God's Inventory
function God.RestoreInventory(player)
    local playerData = global.players[player.index]
    local inventory = player.get_main_inventory()
    playerData.sandboxInventory.resize(#inventory)
    for i = 1, #inventory do
        inventory[i].set_stack(playerData.sandboxInventory[i])
    end
end

-- Ensure newly-crafted Items are put into the Cursor for use
function God.OnPlayerCraftedItem(event)
    local player = game.players[event.player_index]
    local playerData = global.players[event.player_index]
    if playerData.insideSandbox ~= nil and player.cursor_stack then
        event.item_stack.count = event.item_stack.prototype.stack_size
        player.cursor_stack.clear()
        player.cursor_stack.transfer_stack(event.item_stack)
    end
end

function God.HandlerWrapper(setting, surfaceGroup, handler, entity)
    surfaceGroup[entity.surface.name].hasRequests = true
    if settings.global[setting].value == 0 then
        handler(entity)
    end
end

-- Ensure new Orders are handled
function God.OnMarkedForDeconstruct(event)
    if Lab.IsLab(event.entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncDeleteRequestsPerTick,
                global.labSurfaces,
                God.Destroy,
                event.entity
        )
    elseif SpaceExploration.IsSandbox(event.entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncDeleteRequestsPerTick,
                global.seSurfaces,
                God.Destroy,
                event.entity
        )
    end
end

-- Ensure new Orders are handled
function God.OnMarkedForUpgrade(event)
    if Lab.IsLab(event.entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncUpgradeRequestsPerTick,
                global.labSurfaces,
                God.Upgrade,
                event.entity
        )
    elseif SpaceExploration.IsSandbox(event.entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncUpgradeRequestsPerTick,
                global.seSurfaces,
                God.Upgrade,
                event.entity
        )
    end
end

-- Ensure new Ghosts are handled
function God.OnBuiltEntity(event)
    if not God.IsGhost(event.created_entity) then
        return
    end
    if Lab.IsLab(event.created_entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncCreateRequestsPerTick,
                global.labSurfaces,
                God.Revive,
                event.created_entity
        )
    elseif SpaceExploration.IsSandbox(event.created_entity.surface) then
        God.HandlerWrapper(
                Settings.godAsyncCreateRequestsPerTick,
                global.seSurfaces,
                God.Revive,
                event.created_entity
        )
    end
end

-- For each known Sandbox Surface, handle any async God functionality
function God.HandleSandboxRequests(surfaces)
    local createRequestsPerTick = settings.global[Settings.godAsyncCreateRequestsPerTick].value
    local upgradeRequestsPerTick = settings.global[Settings.godAsyncUpgradeRequestsPerTick].value
    local deleteRequestsPerTick = settings.global[Settings.godAsyncDeleteRequestsPerTick].value
    for surfaceName, surfaceData in pairs(surfaces) do
        if surfaceData.hasRequests then
            local surface = game.surfaces[surfaceName]
            local requestsHandled = 0

            local requestedDeconstructions = surface.find_entities_filtered({
                to_be_deconstructed = true,
                limit = deleteRequestsPerTick,
            })
            for _, request in pairs(requestedDeconstructions) do
                requestsHandled = requestsHandled + 1
                God.Destroy(request)
            end

            local requestedUpgrades = surface.find_entities_filtered({
                to_be_upgraded = true,
                limit = upgradeRequestsPerTick,
            })
            for _, request in pairs(requestedUpgrades) do
                requestsHandled = requestsHandled + 1
                God.Upgrade(request)
            end

            local requestedRevives = surface.find_entities_filtered({
                type = "entity-ghost",
                limit = createRequestsPerTick,
            })
            for _, request in pairs(requestedRevives) do
                requestsHandled = requestsHandled + 1
                God.Revive(request)
            end

            requestedRevives = surface.find_entities_filtered({
                type = "tile-ghost",
                limit = createRequestsPerTick,
            })
            for _, request in pairs(requestedRevives) do
                requestsHandled = requestsHandled + 1
                God.Revive(request)
            end

            if requestsHandled == 0 then
                surfaceData.hasRequests = false
            end
        end
    end
end

-- Wrapper for Event Handlers
function God.HandleAllSandboxRequests(event)
    God.HandleSandboxRequests(global.labSurfaces)
    God.HandleSandboxRequests(global.seSurfaces)
end

-- Charts each Sandbox that a Player is currently inside of
function God.ChartAllOccupiedSandboxes()
    if settings.global[Settings.scanSandboxes].value then
        local charted = {}
        for _, player in pairs(game.players) do
            local hash = player.force.name .. player.surface.name
            if Sandbox.IsSandbox(player.surface) and not charted[hash] then
                player.force.chart_all(player.surface)
                charted[hash] = true
            end
        end
    end
end

return God
