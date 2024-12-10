-- Equipment-related methods
local Equipment = {}

-- Initializes an Inventory for the default equipment Blueprint(s)
---@param default string
function Equipment.Init(default)
    local equipment = game.create_inventory(1)
    Equipment.Set(equipment, default)
    return equipment
end

-- Updates the default equipment Blueprint(s)
---@param equipment LuaInventory
---@param default string
function Equipment.Set(equipment, default)
    equipment[1].import_stack(default)
end

--[[
Before 1.1.87, there was a bug that did not correctly forcefully generate
chunks for surfaces with the Lab Tiles setting, which required us to
fix those tiles after generation but before placing the Blueprint.
This but was fixed in 1.1.87, however, it introduced another bug where
building a blueprint then did not immediately work on those tiles,
but building entities seemed to. So, the workaround is to delay the blueprint
building, so we do some work when the surface is generated, then the rest
as soon as possible (aligning to generated chunks seems faster (in ticks)
than waiting any number of specific ticks).
]]
---@param stack LuaItemStack
---@param surface LuaSurface
---@param forceName ForceID
function Equipment.Place(stack, surface, forceName)
    if stack.is_blueprint then
        log("Beginning Equipment Placement")
        Equipment.Prepare(stack, surface)

        storage.equipmentInProgress[surface.name] = {
            stack = stack,
            surface = surface,
            forceName = forceName,
            retries = 500,
        }
        Equipment.BuildBlueprint(stack, surface, forceName)
    else
        storage.equipmentInProgress[surface.name] = nil
    end
    return true
end

-- Prepares a Surface for an Equipment Blueprint
---@param stack LuaItemStack
---@param surface LuaSurface
function Equipment.Prepare(stack, surface)
    -- We need to know how many Chunks must be generated to fit this Blueprint
    local radius = 0
    ---@param thing BlueprintEntity | Tile
    local function updateRadius(thing)
        local x = math.abs(thing.position.x)
        local y = math.abs(thing.position.y)
        radius = math.max(radius, x, y)
    end
    local entities = stack.get_blueprint_entities()
    local tiles = stack.get_blueprint_tiles()
    if entities then
        for _, thing in pairs(entities) do
            updateRadius(thing)
        end
    end
    if tiles then
        for _, thing in pairs(tiles) do
            updateRadius(thing)
        end
    end

    -- Then, we can forcefully generate the necessary Chunks
    local chunkRadius = 1 + math.ceil(radius / 32)
    log("Requesting Chunks for Blueprint Placement: " .. chunkRadius)
    surface.request_to_generate_chunks({ x = 0, y = 0 }, chunkRadius)
    surface.force_generate_chunk_requests()
    -- TODO: depend on 2.0.24 and clean up a lot of this code
    log("Chunks allegedly generated")
end

-- Applies an Equipment Blueprint to a Surface
---@param stack LuaItemStack
---@param surface LuaSurface
function Equipment.IsReadyForBlueprint(stack, surface)
    local entities = stack.get_blueprint_entities()
    local tiles = stack.get_blueprint_tiles()
    ---@param thing BlueprintEntity | Tile
    local function is_chunk_generated(thing)
        return surface.is_chunk_generated({
            thing.position.x / 32,
            thing.position.y / 32,
        })
    end
    if entities then
        for _, thing in pairs(entities) do
            if not is_chunk_generated(thing) then
                return false
            end
        end
    end
    if tiles then
        for _, thing in pairs(tiles) do
            if not is_chunk_generated(thing) then
                return false
            end
        end
    end
    return true
end

-- Applies an Equipment Blueprint to a Surface
---@param stack LuaItemStack
---@param surface LuaSurface
---@param forceName ForceID
function Equipment.BuildBlueprint(stack, surface, forceName)
    local logRetryInterval = 100
    local equipmentData = storage.equipmentInProgress[surface.name]

    -- Skip retrying if we've hit our limit
    if equipmentData.retries <= 0 then
        log("No ghosts created, but we've exceeded retry limit, ending repeated attempts")
        surface.print("Failed to place Equipment Blueprint after too many retries")
        storage.equipmentInProgress[surface.name] = nil
        return false
    end

    -- Let's check if the Chunks are ready for us
    if not Equipment.IsReadyForBlueprint(stack, surface) then
        if equipmentData.retries % logRetryInterval == 0 then
            log("Chunks are not ready for Blueprint, retries remaining: " .. equipmentData.retries)
        end
        equipmentData.retries = equipmentData.retries - 1
        return false
    end

    -- Then, place the Tiles ourselves since it might prevent placing the Blueprint
    local tiles = stack.get_blueprint_tiles()
    if tiles then
        surface.set_tiles(tiles, true, true, true, true)
    end

    -- Finally, we can place the Blueprint
    local ghosts = stack.build_blueprint({
        surface = surface.name,
        force = forceName,
        position = { 0, 0 },
        skip_fog_of_war = true,
        raise_built = true,
    })

    -- Since we may have changed the ghosts into real entities, we need to simply count entities
    local surfaceEntityCount = surface.count_entities_filtered({})
    local blueprintEntityCount = stack.get_blueprint_entity_count()
    if equipmentData.retries % logRetryInterval == 0 then
        log("Surface has " .. surfaceEntityCount .. " entities, Blueprint has " .. blueprintEntityCount .. " entities")
    end

    -- But that may have not been successful, despite our attempts to ensure it!
    if surfaceEntityCount >= blueprintEntityCount then
        log("Surface has more entities than the Blueprint does; assuming Blueprint is placed")
        storage.equipmentInProgress[surface.name] = nil
        return true
    elseif #ghosts > 0 then
        log("Some ghosts created, ending repeated attempts; assuming Blueprint is placed")
        storage.equipmentInProgress[surface.name] = nil
        return true
    elseif equipmentData.retries <= 0 then
        log("No ghosts created, but we've exceeded retry limit, ending repeated attempts")
        surface.print("Failed to place Equipment Blueprint after too many retries")
        storage.equipmentInProgress[surface.name] = nil
        return false
    else
        if equipmentData.retries % logRetryInterval == 0 then
            log("No amount of ghosts listed, retries remaining: " .. equipmentData.retries)
        end
        equipmentData.retries = equipmentData.retries - 1
        return false
    end
end

return Equipment
