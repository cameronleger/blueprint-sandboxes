PlannerIcons = require("scripts.planner-icons")
Tiles = require("scripts.tiles")

-- Helpers for Tile Planners
function shouldSkipTilePlanner(tile)
    if tile.fluid then
        return false
    elseif tile.name == "empty-space" then
        return false
    end
    return true
end

function createTilePlannerPrototypes(tile)
    local localisedName = tile.localised_name or { "tile-name." .. tile.name }
    local icons = PlannerIcons.CreateLayeredIcon(tile)
    return {
        {
            type = "item",
            name = Tiles.pfx .. tile.name,
            localised_name = localisedName,
            icons = icons,
            subgroup = Tiles.name,
            order = tile.order,
            hidden_in_factoriopedia = true,
            stack_size = 1000,
            place_as_tile = {
                result = tile.name,
                condition = {
                    -- TODO: New requirement, investigate: file:///home/cameron/src/factorio/factorio_expansion/doc-html/types/CollisionMaskConnector.html
                    layers = {}
                },
                condition_size = 1,
            },
        },
        {
            type = "recipe",
            name = Tiles.pfx .. tile.name,
            localised_name = localisedName,
            icons = icons,
            hidden_in_factoriopedia = true,
            energy_required = 1,
            enabled = false,
            ingredients = {},
            results = {
                { type = "item", name = Tiles.pfx .. tile.name, amount = 1 },
            },
            hide_from_stats = true,
            hide_from_signal_gui = true,
        }
    }
end

-- New Items/Recipes for Tile Planners
for _, tile in pairs(data.raw.tile) do
    -- Some Tiles are better left alone
    if not shouldSkipTilePlanner(tile) then
        data:extend(createTilePlannerPrototypes(tile))
    end
end
