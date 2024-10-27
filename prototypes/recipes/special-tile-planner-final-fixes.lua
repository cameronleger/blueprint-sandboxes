PlannerIcons = require("scripts.planner-icons")
Tiles = require("scripts.tiles")

data:extend({
    {
        type = "selection-tool",
        name = Tiles.labTilePlanner,
        icons = PlannerIcons.CreateLayeredIcon(data.raw.tile["lab-dark-1"]),
        subgroup = Tiles.name,
        order = "0",
        hidden_in_factoriopedia = true,
        stack_size = 1,
        select = {
            border_color = { r = 0, g = 0, b = 1 },
            cursor_box_type = "pair",
            mode = { "any-tile" },
            tile_filters = { "lab-dark-1", "lab-dark-2" },
            tile_filter_mode = "blacklist",
        },
        alt_select = {
            border_color = { r = 0, g = 0, b = 1 },
            cursor_box_type = "pair",
            mode = { "any-tile" },
            tile_filters = { "lab-dark-1", "lab-dark-2" },
            tile_filter_mode = "blacklist",
        },
        always_include_tiles = true,
        flags = { "not-stackable", "only-in-cursor" },
    },
    {
        type = "recipe",
        name = Tiles.labTilePlanner,
        hidden_in_factoriopedia = true,
        energy_required = 1,
        enabled = false,
        ingredients = {},
        results = {
            { type = "item", name = Tiles.labTilePlanner, amount = 1 },
        },
        hide_from_stats = true,
        hide_from_signal_gui = true,
    }
})

---@param tile data.TilePrototype
function createTilePlannerPrototypes(tile)
    local localisedName = tile.localised_name or { "tile-name." .. tile.name }
    local icons = PlannerIcons.CreateLayeredIcon(tile)
    return {
        {
            type = "selection-tool",
            name = Tiles.pfx .. tile.name,
            localised_name = localisedName,
            icons = icons,
            subgroup = Tiles.name,
            order = tile.order,
            hidden_in_factoriopedia = true,
            stack_size = 1,
            select = {
                border_color = { r = 0, g = 1, b = 0 },
                cursor_box_type = "pair",
                mode = { "any-tile" },
                tile_filters = { tile.name },
                tile_filter_mode = "blacklist",
            },
            alt_select = {
                border_color = { r = 0, g = 1, b = 0 },
                cursor_box_type = "pair",
                mode = { "any-tile" },
                tile_filters = { tile.name },
                tile_filter_mode = "blacklist",
            },
            always_include_tiles = true,
            flags = { "not-stackable", "only-in-cursor" },
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

if data.raw.tile["empty-space"] then
    data:extend(createTilePlannerPrototypes(data.raw.tile["empty-space"]))
end