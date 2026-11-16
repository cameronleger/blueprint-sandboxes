-- Custom Extensions to the God-Controller
local God = {}

God.preventEntitiesByType = {
    ["lab"] = true,
}

God.onBuiltEntityFilters = {
    { filter = "type", type = "tile-ghost" },
    { filter = "type", type = "entity-ghost" },
    { filter = "type", type = "item-request-proxy" },
}

for type, _ in pairs(God.preventEntitiesByType) do
    table.insert(God.onBuiltEntityFilters, { filter = "type", type = type })
end

-- TODO: Perhaps this can be determined by flags?
God.skipHandlingEntities = {
    ["logistic-train-stop-input"] = true,
    ["logistic-train-stop-output"] = true,
    ["tl-dummy-entity"] = true,
    ["si-in-world-drop-entity"] = true,
    ["si-in-world-pickup-entity"] = true,
}

-- Ghost name -> hidden Entity that must already exist when the Ghost is revived
--
-- Some mods pair a placeable proxy with a hidden Entity that they create themselves the instant the
-- proxy is built. se-legacy-cargo-landing-pad is one: on build it creates a hidden
-- "cargo-landing-pad" beside its proxy and immediately indexes the result without checking it
-- (control.lua:47). When that creation fails the error is raised inside our own silent_revive and
-- takes the save down.
--
-- Making the companion first means the mod's own find_entities_filtered locates it, so it never
-- runs its own create, adopts ours instead, and registers the same deathrattle it always would.
-- Removing the proxy therefore still destroys the companion through the mod's normal cleanup, so
-- nothing is left behind to inflate any count.
God.companionEntities = {
    ["cargo-landing-pad-proxy"] = "cargo-landing-pad",
}

-- The build handler must also wake for the proxies themselves, not just Ghosts
for proxyName, _ in pairs(God.companionEntities) do
    table.insert(God.onBuiltEntityFilters, { filter = "name", name = proxyName })
end

-- Entities to revive without raising script_raised_revive
--
-- Space Exploration refuses to let these exist on a Surface with no Zone: each of its build
-- handlers calls cancel_creation_when_invalid, which destroys the Entity and spills the item back
-- onto the floor. That is why pasting a rocket silo into a Lab left a hole in the blueprint with an
-- item lying in it rather than a crash.
--
-- A Lab never has a Zone, so raising the event here can only ever end that way. Reviving silently
-- means SE's handler never runs, and silent_revive still carries over everything the blueprint held
-- -- recipe, filters, wires, modules. The cost is that SE does not register them, so their
-- SE-specific GUI panel is missing. SE handles that by itself: gui_open returns early when the
-- struct is absent, and without a Zone there is no destination to configure anyway.
--
-- Taken from the ten cancel_creation_when_invalid call sites in Space Exploration 0.7.57. Names it
-- does not recognise are simply never matched, so this list is safe without SE installed.
God.silentReviveEntities = {
    ["rocket-silo"] = true,
    ["se-rocket-launch-pad"] = true,
    ["se-space-probe-rocket-silo"] = true,
    ["se-space-elevator"] = true,
    ["se-delivery-cannon"] = true,
    ["se-delivery-cannon-weapon"] = true,
    ["se-energy-beam-defence"] = true,
    ["se-energy-transmitter-chamber"] = true,
    ["se-energy-transmitter-injector"] = true,
    ["se-energy-transmitter-emitter"] = true,
    ["se-meteor-defence-container"] = true,
    ["se-meteor-point-defence-container"] = true,
    ["se-spaceship-console"] = true,
}

-- Immediately destroy an Entity (and perhaps related Entities)
---@param entity LuaEntity
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

-- TODO: Insert Requests when pasting new Entity that generates new Requests
-- But... what is the Event?

-- Immediately Insert an Entity's Requests
---@param entity LuaEntity
function God.InsertRequests(entity)
    if entity.valid
        and entity.type == "item-request-proxy"
        and entity.proxy_target then
        -- Remove any Requested Items
        for _, plan in pairs(entity.removal_plan) do
            if plan.items.in_inventory then
                for _, position in pairs(plan.items.in_inventory) do
                    local inventory = entity.proxy_target.get_inventory(position.inventory)
                    local decrement = position.count or 1
                    if inventory and inventory.valid and inventory.index == position.inventory then
                        local stack = inventory[position.stack + 1]
                        if stack.count > 0 then
                            stack.count = math.max(0, stack.count - decrement)
                        end
                    end
                end
            end
        end
        -- Insert any Requested Items
        for _, plan in pairs(entity.insert_plan) do
            if plan.items.in_inventory then
                for _, position in pairs(plan.items.in_inventory) do
                    local inventory = entity.proxy_target.get_inventory(position.inventory)
                    local increment = position.count or 1
                    if inventory and inventory.valid
                    and inventory.index == position.inventory
                    and #inventory > position.stack
                    then
                        local stack = inventory[position.stack + 1]
                        if stack.count > 0 then
                            stack.count = stack.count + increment
                        else
                            stack.set_stack {
                                name = plan.id.name,
                                quality = plan.id.quality,
                                count = increment,
                            }
                        end
                    end
                end
            end
        end
        entity.destroy()
    end
end

-- Report a Ghost that could not be Revived, and get rid of it
--
-- Reviving raises script_raised_revive, so every other Mod's build handler runs inside the call.
-- Some of those handlers assume a real Surface: se-legacy-cargo-landing-pad, for one, creates a
-- hidden "cargo-landing-pad" next to its proxy and indexes the result without checking it, which
-- is nil in a Lab. A Sandbox is a scratch Surface and is never worth taking the save down for, so
-- the failure is contained here and reported instead. The Ghost is destroyed rather than requeued,
-- because a queued retry would simply raise the same error on the next tick, forever.
---@param entity LuaEntity
---@param err any Error raised by whichever Mod's handler failed
function God.ReportRevivalFailure(entity, err)
    local name = "unknown"
    local player = nil
    if entity.valid then
        name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
        player = entity.last_user --[[@as LuaPlayer | nil]]
    end

    log("Could not revive " .. name .. " in a Sandbox: " .. tostring(err))

    if player then
        player.print({ "messages.revival-failed", name, tostring(err) })
    end

    if entity.valid then
        entity.destroy()
    end
end

-- Create the hidden companion Entity a Ghost's mod will expect to find, if it needs one
--
-- Deliberately raises no build event. The owning mod adopts this Entity a moment later from inside
-- its own handler, and keeping the event quiet means nothing else registers it as a real, newly
-- built structure just because it was made in a Sandbox.
---@param surface LuaSurface
---@param position MapPosition Where the proxy is, or is about to be
---@param force LuaForce | string
---@param proxyName string
---@return string | nil failure Why the companion could not be made, if it could not
---@return LuaEntity | nil created The companion, if this call made it
function God.EnsureCompanionAt(surface, position, force, proxyName)
    local companionName = God.companionEntities[proxyName]
    if not companionName or not prototypes.entity[companionName] then
        return nil, nil
    end

    local existing = surface.find_entities_filtered {
        name = companionName,
        position = position,
        radius = 1,
    }[1]
    if existing then
        return nil, nil
    end

    local ok, created = pcall(surface.create_entity, {
        name = companionName,
        position = position,
        force = force,
        force_build = true,
    })

    if not ok then
        return companionName .. " could not be created: " .. tostring(created), nil
    end
    if not created then
        return "the game refused to create a " .. companionName .. " on this surface", nil
    end

    return nil, created
end

---@param entity LuaEntity Ghost about to be revived
---@return string | nil failure Why the companion could not be made, if it could not
---@return LuaEntity | nil created The companion, if this call made it
function God.EnsureCompanion(entity)
    return God.EnsureCompanionAt(entity.surface, entity.position, entity.force, entity.ghost_name)
end

-- Hand-placing never becomes a Ghost, so God.Create is not involved and the owning mod's build
-- handler may well run before any of ours. on_pre_build is the only hook early enough to get the
-- companion in place first, and it is cheap: it only inspects the cursor.
---@param event EventData.on_pre_build
function God.OnPreBuild(event)
    local player = game.players[event.player_index]
    if not player or not player.valid then return end
    if not Lab.IsLab(player.surface) then return end

    local stack = player.cursor_stack
    if not (stack and stack.valid_for_read) then return end

    local tile = stack.prototype.place_as_tile_result
    if tile and Lab.spaceOnlyTiles[tile.result.name] then
        return God.GuardSpaceTileInventory(player)
    end

    local placed = stack.prototype.place_result
    if placed and God.silentReviveEntities[placed.name] then
        return God.QueueHandBuild(player, placed.name, stack, event)
    end

    if not placed or not God.companionEntities[placed.name] then return end

    God.EnsureCompanionAt(player.surface, event.position, player.force, placed.name)
end

-- Structures from God.silentReviveEntities placed by hand
--
-- A hand build is real straight away, so SE's handler sees it, and SE runs before us. With no
-- Zone it cancels it, mining it back into the inventory and saying construction was denied. A
-- Ghost (shift-placing) never has that problem, because God.Create revives it quietly. So a hand
-- build is noted here, and on the next God tick it is put back the same quiet way and the item
-- SE refunded is taken back.
---@param player LuaPlayer
---@param name string
---@param stack LuaItemStack
---@param event EventData.on_pre_build
function God.QueueHandBuild(player, name, stack, event)
    local playerData = storage.players[player.index]
    if not playerData then return end

    playerData.pendingHandBuilds = playerData.pendingHandBuilds or {}
    table.insert(playerData.pendingHandBuilds, {
        name = name,
        item = stack.name,
        quality = stack.quality.name,
        surfaceIndex = player.surface.index,
        position = event.position,
        direction = event.direction,
        mirror = event.mirror,
    })
end

function God.HandlePendingHandBuilds()
    for playerIndex, playerData in pairs(storage.players) do
        local pending = playerData.pendingHandBuilds
        if pending then
            playerData.pendingHandBuilds = nil
            local player = game.players[playerIndex]
            for _, build in pairs(pending) do
                God.ReplaceCancelledHandBuild(player, build)
            end
        end
    end
end

---@param player LuaPlayer
---@param build table As queued by God.QueueHandBuild
function God.ReplaceCancelledHandBuild(player, build)
    local surface = game.surfaces[build.surfaceIndex]
    if not (player and player.valid and surface and Lab.IsLab(surface)) then return end

    -- Still standing, so SE did not cancel it after all, or something else took the spot
    if not surface.can_place_entity {
        name = build.name,
        position = build.position,
        direction = build.direction,
        force = player.force,
    } then
        return
    end

    local ok, created = pcall(surface.create_entity, {
        name = build.name,
        position = build.position,
        direction = build.direction,
        mirror = build.mirror,
        quality = build.quality,
        force = player.force,
        player = player,
        create_build_effect_smoke = false,
        raise_built = false,
    })
    if not (ok and created) then
        log("Could not replace a hand-built " .. build.name .. " in a Sandbox: " .. tostring(created))
        return
    end

    -- SE mined the cancelled one back into the inventory
    local inventory = player.get_main_inventory()
    if inventory then
        inventory.remove({ name = build.item, quality = build.quality, count = 1 })
    end
end

-- Entities another mod finds by scanning every Surface, rather than by listening for builds
--
-- se-cargo-rocket-construction-helper rescans all Surfaces for launch pads whenever the mod
-- configuration changes, Sandboxes included. Every 10 seconds it then looks up the pad's hidden
-- silo and reads it without checking. SE never made that silo, because it cancels every launch pad
-- on a Surface with no Zone before creating any part of it, so the lookup is nil and the save
-- crashes a few seconds after loading. This mod loads after the helper (an optional dependency),
-- so right after its rescan each such pad in a Lab is rebuilt as a fresh Entity. The helper's entry
-- then points at a destroyed one, which it drops without a word on its next pass.
God.rescannedEntities = {
    "se-rocket-launch-pad",
}

function God.DetachFromRescans()
    local names = {}
    for _, name in pairs(God.rescannedEntities) do
        if prototypes.entity[name] then
            names[#names + 1] = name
        end
    end
    if #names == 0 then return end

    for _, surface in pairs(game.surfaces) do
        if Lab.IsLab(surface) then
            for _, entity in pairs(surface.find_entities_filtered { name = names }) do
                God.Rebuild(entity)
            end
        end
    end
end

-- Replace an Entity with an identical new one, raising nothing, so nobody's registration follows it
--
-- Carries over what a blueprint of it would: contents, the inventory limit and circuit wires.
---@param entity LuaEntity
function God.Rebuild(entity)
    local surface = entity.surface
    local spec = {
        name = entity.name,
        position = entity.position,
        direction = entity.direction,
        quality = entity.quality.name,
        force = entity.force,
        create_build_effect_smoke = false,
        raise_built = false,
    }
    local lastUser = entity.last_user

    local saved = nil
    local bar = nil
    local inventory = entity.get_inventory(defines.inventory.chest)
    if inventory then
        saved = game.create_inventory(#inventory)
        for i = 1, #inventory do
            saved[i].set_stack(inventory[i])
        end
        if inventory.supports_bar() then
            bar = inventory.get_bar()
        end
    end

    local wires = {}
    for id, connector in pairs(entity.get_wire_connectors(false)) do
        for _, connection in pairs(connector.connections) do
            if connection.target.owner ~= entity then
                wires[#wires + 1] = { id = id, target = connection.target, origin = connection.origin }
            end
        end
    end

    entity.destroy()
    local rebuilt = surface.create_entity(spec)
    if not rebuilt then
        log("Could not rebuild " .. spec.name .. " in a Sandbox; it has been removed")
        if saved then saved.destroy() end
        return
    end

    if lastUser and lastUser.valid then
        rebuilt.last_user = lastUser
    end

    local rebuiltInventory = rebuilt.get_inventory(defines.inventory.chest)
    if saved then
        if rebuiltInventory then
            for i = 1, math.min(#saved, #rebuiltInventory) do
                rebuiltInventory[i].set_stack(saved[i])
            end
            if bar then
                rebuiltInventory.set_bar(bar)
            end
        end
        saved.destroy()
    end

    local connectors = rebuilt.get_wire_connectors(true)
    for _, wire in pairs(wires) do
        if connectors[wire.id] and wire.target.valid then
            connectors[wire.id].connect_to(wire.target, false, wire.origin)
        end
    end
end

-- Items that place a space-only tile, by name
---@return string[]
function God.SpaceTileItems()
    local items = {}
    for tileName, _ in pairs(Lab.spaceOnlyTiles) do
        local tile = prototypes.tile[tileName]
        if tile and tile.items_to_place_this then
            for _, item in pairs(tile.items_to_place_this) do
                items[#items + 1] = item.name
            end
        end
    end
    return items
end

-- Space tiles laid by hand in a Space Lab
--
-- SE's own on_player_built_tile handler runs first, because we load after it. With no Zone it
-- treats the Lab as land and cancels the placement. Its cancel puts back the tile that was there
-- before, and when that tile came from an item (plating over scaffolding, say) it takes one such
-- item out of the player's inventory to pay for it. Without one it falls back to the hidden tile,
-- empty space, and mines every Entity standing there. The inventory is topped up here first so
-- that the fallback never runs, then God.OnBuiltTile puts the tiles back and undoes every item SE
-- moved, leaving the inventory exactly as the build itself left it.
---@param player LuaPlayer
function God.GuardSpaceTileInventory(player)
    if not Lab.IsSpaceLab(player.surface) then return end
    local inventory = player.get_main_inventory()
    if not inventory then return end

    -- A previous guard whose build never happened still has its top-up in the inventory
    God.RestoreSpaceTileInventory(player)

    -- Inventory.Prune spills the last stack onto the floor once nothing is empty, so the top-up
    -- must never be what fills the inventory
    local items = God.SpaceTileItems()
    if inventory.count_empty_stacks() <= #items then return end

    local counts = {}
    for _, itemName in pairs(items) do
        counts[itemName] = inventory.get_item_count(itemName)
        inventory.insert({ name = itemName, count = prototypes.item[itemName].stack_size })
    end
    storage.players[player.index].spaceTileGuard = counts
end

-- Put back the space tiles SE just cancelled, see God.GuardSpaceTileInventory
---@param event EventData.on_player_built_tile
function God.OnBuiltTile(event)
    local player = game.players[event.player_index]
    local surface = game.surfaces[event.surface_index]

    if surface and Lab.IsSpaceLab(surface) and Lab.spaceOnlyTiles[event.tile.name] then
        local tiles = {}
        for _, placed in pairs(event.tiles) do
            tiles[#tiles + 1] = { name = event.tile.name, position = placed.position }
        end
        -- Keep whatever already stands here, and raise nothing, or SE would cancel it again
        surface.set_tiles(tiles, true, false, true, false)
    end

    if player then
        God.RestoreSpaceTileInventory(player)
    end
end

-- Return the space tile items to the counts recorded before the build, and drop the record
---@param player LuaPlayer
function God.RestoreSpaceTileInventory(player)
    local playerData = storage.players[player.index]
    local counts = playerData and playerData.spaceTileGuard
    if not counts then return end
    playerData.spaceTileGuard = nil

    local inventory = player.get_main_inventory()
    if not inventory then return end
    for itemName, count in pairs(counts) do
        local difference = inventory.get_item_count(itemName) - count
        if difference > 0 then
            inventory.remove({ name = itemName, count = difference })
        elseif difference < 0 then
            inventory.insert({ name = itemName, count = -difference })
        end
    end
end

-- A proxy whose companion exists but was never registered by its owning mod cannot show that mod's
-- GUI, and opening it would make the mod index a GUI that was never built. Space Exploration
-- refuses to register a landing pad on a Surface with no Zone, and a Lab has none, so there is
-- nothing to configure anyway. Leaving the proxy un-openable is the difference between a Sandbox
-- you can lay out and a save that dies on a click.
---@param event EventData.on_built_entity | EventData.script_raised_built
---@return boolean handled Whether this was a companion proxy, and so needs nothing else
function God.OnBuiltCompanionProxy(event)
    local entity = event.entity
    if not (entity and entity.valid) then return false end
    if not God.companionEntities[entity.name] then return false end
    if not Lab.IsLab(entity.surface) then return false end

    God.MakeProxyUnopenable(entity)
    return true
end

-- Shared by the hand-placed and Ghost-revived paths
---@param entity LuaEntity The proxy itself, already built
function God.MakeProxyUnopenable(entity)
    if entity and entity.valid then
        entity.operable = false
    end
end

-- Immediately Revive a Ghost Entity
---@param entity LuaEntity
function God.Create(entity)
    if entity.valid then
        if entity.type == "tile-ghost" then
            -- Tiles are simple Revives. Space tiles revive quietly: a tile revival raises
            -- script_raised_set_tiles, and SE answers that on a Zone-less Surface by turning
            -- scaffolding and plating into dirt.
            local ok, collided, revived = pcall(entity.silent_revive, {
                raise_revive = not Lab.spaceOnlyTiles[entity.ghost_name]
            })
            if not ok then
                -- `collided` holds the error message when pcall fails
                return God.ReportRevivalFailure(entity, collided)
            end
            if not revived and entity.valid then
                Queue.Push(storage.asyncCreateQueue, entity)
            end
        elseif entity.type == "item-request-proxy" then
            -- Requests are simple
            God.InsertRequests(entity)
        elseif entity.type == "entity-ghost" then
            -- Some Ghosts belong to a mod that expects a hidden partner Entity to exist
            local isCompanionProxy = God.companionEntities[entity.ghost_name] ~= nil
            local companionFailure, companion = God.EnsureCompanion(entity)
            if companionFailure then
                return God.ReportRevivalFailure(entity, companionFailure)
            end

            -- Entities might also want Items after Reviving
            local ok, collided, revived, request = pcall(entity.silent_revive, {
                raise_revive = not God.silentReviveEntities[entity.ghost_name]
            })

            if not ok then
                -- Do not strand the companion we just made without the proxy that owns it
                if companion and companion.valid then
                    companion.destroy()
                end
                -- `collided` holds the error message when pcall fails
                return God.ReportRevivalFailure(entity, collided)
            end

            if revived and request then
                God.InsertRequests(request)
            end

            if revived and isCompanionProxy then
                God.MakeProxyUnopenable(revived)
            end

            if not revived then
                -- The Ghost is still a Ghost, so its companion has nothing to belong to yet.
                -- EnsureCompanion makes it again on the retry.
                if companion and companion.valid then
                    companion.destroy()
                end
                if entity.valid then
                    Queue.Push(storage.asyncCreateQueue, entity)
                end
            end
        end
    end
end

-- Immediately turn one Entity into another
---@param entity LuaEntity
function God.Upgrade(entity)
    if entity.valid and entity.to_be_upgraded() then
        local result = entity.apply_upgrade()

        if result == nil then
            if entity.valid then
                log("Upgrade Failed, Cancelling: " .. entity.name)
                entity.cancel_upgrade(entity.force)
            else
                log("Upgrade Failed, Old Entity Gone too!")
            end
        end
    end
end

-- Ensure the God's Inventory is kept in-sync
---@param event EventData.on_player_main_inventory_changed
function God.OnInventoryChanged(event)
    if Isolation.IsNone() then return end
    local player = game.players[event.player_index]
    if Sandbox.IsPlayerInsideSandbox(player) and Inventory.ShouldPersist(player.controller_type) then
        Inventory.Prune(player)
        local playerData = storage.players[event.player_index]
        playerData.sandboxInventory = Inventory.Persist(
                player.get_main_inventory(),
                playerData.sandboxInventory
        )
    end
end

-- Ensure newly-crafted Items are put into the Cursor for use
---@param event EventData.on_player_crafted_item
function God.OnPlayerCraftedItem(event)
    local player = game.players[event.player_index]
    if Sandbox.IsPlayerInsideSandbox(player)
            and Controllers.IsGod(player)
            and Isolation.IsFull()
            and player.cursor_stack
            and player.cursor_stack.valid
            and event.item_stack.valid
            and event.item_stack.valid_for_read
            and event.recipe.valid
            and (
            #event.recipe.products == 1
                    or (
                    event.recipe.prototype.main_product
                            and event.recipe.prototype.main_product.name == event.item_stack.name
            )
    )
            and player.mod_settings[Settings.craftToCursor].value
    then
        event.item_stack.count = event.item_stack.prototype.stack_size
        player.cursor_stack.clear()
        player.cursor_stack.transfer_stack(event.item_stack)
    end
end

---@param entity LuaEntity
function God.AsyncWrapper(setting, queue, handler, entity)
    if settings.global[setting].value == 0 then
        handler(entity)
    else
        Queue.Push(queue, entity)
    end
end

---@param entity LuaEntity
function God.ShouldHandleEntity(entity)
    if not entity.valid then return false end

    if not (Lab.IsLab(entity.surface)
            or (Factorissimo.IsFactory(entity.surface)
                and Factorissimo.IsFactoryInsideSandbox(entity.surface, entity.position)))
    then
        return false
    end

    local isEntityGhost = entity.type == "entity-ghost"
    if God.preventEntitiesByType[entity.type] or (isEntityGhost and God.preventEntitiesByType[entity.ghost_type]) then
        local player = entity.last_user --[[@as LuaPlayer | nil]]
        if player then
            player.create_local_flying_text({
                text = {"messages.cannot-build-in-sandbox"},
                position = player.position,
            })
        end
        entity.destroy({ raise_destroy = true })
        return false
    end

    if not settings.global[Settings.godBuilding].value then
        return false
    end

    local name = entity.name
    if isEntityGhost then name = entity.ghost_name end

    if God.skipHandlingEntities[name] then
        return false
    end

    return true
end

-- Ensure new Orders are handled
---@param event EventData.on_marked_for_deconstruction
function God.OnMarkedForDeconstruct(event)
    if God.ShouldHandleEntity(event.entity) then
        God.AsyncWrapper(
                Settings.godAsyncDeleteRequestsPerTick,
                storage.asyncDestroyQueue,
                God.Destroy,
                event.entity
        )
    end
end

-- Ensure new Orders are handled
---@param event EventData.on_marked_for_upgrade
function God.OnMarkedForUpgrade(event)
    if God.ShouldHandleEntity(event.entity) then
        God.AsyncWrapper(
                Settings.godAsyncUpgradeRequestsPerTick,
                storage.asyncUpgradeQueue,
                God.Upgrade,
                event.entity
        )
    end
end

-- Ensure new Ghosts are handled
---@param event EventData.on_built_entity | EventData.script_raised_built
function God.OnBuiltEntity(event)
    if God.OnBuiltCompanionProxy(event) then
        return
    end

    if God.ShouldHandleEntity(event.entity) then
        God.AsyncWrapper(
                Settings.godAsyncCreateRequestsPerTick,
                storage.asyncCreateQueue,
                God.Create,
                event.entity
        )
    end
end

-- Ensure remaining Ghosts are handled
---@param player LuaPlayer
---@param deleteRequests number
---@param upgradeRequests number
---@param createRequests number
function God.QueueUnhandledEntities(player, deleteRequests, upgradeRequests, createRequests)
    local surface = player.surface
    local radius = 32 * 6 -- 6 chunk radius

    if deleteRequests > 0 then
        local deconstructs = surface.find_entities_filtered({
            position = player.position,
            radius = radius,
            force = player.force,
            to_be_deconstructed = true,
            to_be_upgraded = false,
            limit = 100,
        })
        for _, entity in pairs(deconstructs) do
            if God.ShouldHandleEntity(entity) then
                God.AsyncWrapper(
                    Settings.godAsyncDeleteRequestsPerTick,
                    storage.asyncDestroyQueue,
                    God.Destroy,
                    entity
                )
            end
        end
    end

    if upgradeRequests > 0 then
        local upgrades = surface.find_entities_filtered({
            position = player.position,
            radius = radius,
            force = player.force,
            to_be_deconstructed = false,
            to_be_upgraded = true,
            limit = 100,
        })
        for _, entity in pairs(upgrades) do
            if God.ShouldHandleEntity(entity) then
                God.AsyncWrapper(
                    Settings.godAsyncUpgradeRequestsPerTick,
                    storage.asyncUpgradeQueue,
                    God.Upgrade,
                    entity
                )
            end
        end
    end

    if createRequests > 0 then
        local ghosts = surface.find_entities_filtered({
            position = player.position,
            radius = radius,
            force = player.force,
            type = {
                "tile-ghost",
                "entity-ghost",
                "item-request-proxy",
            },
            to_be_deconstructed = false,
            to_be_upgraded = false,
            limit = 100,
        })
        for _, entity in pairs(ghosts) do
            if God.ShouldHandleEntity(entity) then
                God.AsyncWrapper(
                    Settings.godAsyncCreateRequestsPerTick,
                    storage.asyncCreateQueue,
                    God.Create,
                    entity
                )
            end
        end
    end
end

-- TODO: This is basically only necessary because of missing item-request-proxy and super-force-building events
-- Ensure remaining Ghosts are handled
---@param deleteRequests number
---@param upgradeRequests number
---@param createRequests number
function God.QueueUnhandledEntitiesInOccupiedSandboxes(deleteRequests, upgradeRequests, createRequests)
    for _, player in pairs(game.players) do
        if player.connected and Sandbox.IsSandbox(player.surface) then
            God.QueueUnhandledEntities(player, deleteRequests, upgradeRequests, createRequests)
        end
    end
end

-- For each known Sandbox Surface, handle any async God functionality
---@param event EventData.on_tick
function God.HandleAllSandboxRequests(event)
    God.HandlePendingHandBuilds()

    local createRequestsPerTick = math.max(1, settings.global[Settings.godAsyncCreateRequestsPerTick].value)
    local upgradeRequestsPerTick = math.max(1, settings.global[Settings.godAsyncUpgradeRequestsPerTick].value)
    local deleteRequestsPerTick = math.max(1, settings.global[Settings.godAsyncDeleteRequestsPerTick].value)

    local destroyRequestsHandled = 0
    while Queue.Size(storage.asyncDestroyQueue) > 0
            and deleteRequestsPerTick > 0
    do
        God.Destroy(Queue.Pop(storage.asyncDestroyQueue))
        destroyRequestsHandled = destroyRequestsHandled + 1
        deleteRequestsPerTick = deleteRequestsPerTick - 1
    end
    if Queue.Size(storage.asyncDestroyQueue) == 0
            and destroyRequestsHandled > 0
    then
        storage.asyncDestroyQueue = Queue.New()
    end

    local upgradeRequestsHandled = 0
    while Queue.Size(storage.asyncUpgradeQueue) > 0
            and upgradeRequestsPerTick > 0
    do
        God.Upgrade(Queue.Pop(storage.asyncUpgradeQueue))
        upgradeRequestsHandled = upgradeRequestsHandled + 1
        upgradeRequestsPerTick = upgradeRequestsPerTick - 1
    end
    if Queue.Size(storage.asyncUpgradeQueue) == 0
            and upgradeRequestsHandled > 0
    then
        storage.asyncUpgradeQueue = Queue.New()
    end

    local createRequestsHandled = 0
    while Queue.Size(storage.asyncCreateQueue) > 0
            and createRequestsPerTick > 0
    do
        God.Create(Queue.Pop(storage.asyncCreateQueue))
        createRequestsHandled = createRequestsHandled + 1
        createRequestsPerTick = createRequestsPerTick - 1
    end
    if Queue.Size(storage.asyncCreateQueue) == 0
            and createRequestsHandled > 0
    then
        storage.asyncCreateQueue = Queue.New()
    end

    if (deleteRequestsPerTick + upgradeRequestsPerTick + createRequestsPerTick) > 0 then
        God.QueueUnhandledEntitiesInOccupiedSandboxes(deleteRequestsPerTick, upgradeRequestsPerTick, createRequestsPerTick)
    end
end

return God
