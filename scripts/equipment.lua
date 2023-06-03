-- Equipment-related methods
local Equipment = {}

-- Initializes an Inventory for the default equipment Blueprint(s)
function Equipment.Init(default)
    local equipment = game.create_inventory(1)
    Equipment.Set(equipment, default)
    return equipment
end

-- Updates the default equipment Blueprint(s)
function Equipment.Set(equipment, default)
    equipment[1].import_stack(default)
end

-- Applies an Equipment Blueprint to a Surface
function Equipment.Place(stack, surface, forceName, fixTiles)
    if stack.is_blueprint then
        -- We need to know how many Chunks must be generated to fit this Blueprint
        local radius = 0
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
        local chunkRadius = math.ceil(radius / 32)
        surface.request_to_generate_chunks({ x = 0, y = 0 }, chunkRadius)
        surface.force_generate_chunk_requests()

        --[[
        This is great: the lab-tile setting _isn't_ respected during that,
        so these chunks have definitely just been generated incorrectly.
        We need to fix those tiles, and the entities on top of them.
        ]]
        radius = (chunkRadius + 1) * 32
        for _, entity in pairs(surface.find_entities()) do
            entity.destroy({ raise_destroy = true })
        end
        surface.destroy_decoratives({
            { { -radius, -radius }, { radius, radius } },
            { 0, 0 },
        })
        fixTiles(radius)

        -- Finally, we can place the Blueprint; twice, because of tiles!
        for i = 1, 2 do
            stack.build_blueprint({
                surface = surface.name,
                force = forceName,
                position = { 0, 0 },
                force_build = true,
                skip_fog_of_war = true,
                raise_built = true,
            })
        end
    end
end

return Equipment
