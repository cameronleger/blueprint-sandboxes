Resources = require("scripts.resources")

-- Move Loaders to our Tab (only if they exist)
if data.raw.recipe[BPSB.pfx .. "loader"] then
    data.raw.item["loader"].subgroup = BPSB.pfx .. "loaders"
    data.raw.item["loader"].order = "a-a"

    data.raw.item["fast-loader"].subgroup = BPSB.pfx .. "loaders"
    data.raw.item["fast-loader"].order = "a-b"

    data.raw.item["express-loader"].subgroup = BPSB.pfx .. "loaders"
    data.raw.item["express-loader"].order = "a-c"
end

-- Move Infinity Entities to our Tab
data.raw.item["electric-energy-interface"].subgroup = BPSB.pfx .. "infinity"
data.raw.item["electric-energy-interface"].order = "a-a"

data.raw.item["infinity-chest"].subgroup = BPSB.pfx .. "infinity"
data.raw.item["infinity-chest"].order = "a-b"

data.raw.item["infinity-pipe"].subgroup = BPSB.pfx .. "infinity"
data.raw.item["infinity-pipe"].order = "a-c"

-- Helpers for Resource Planners
function shouldSkipResourcePlanner(resource)
    return resource.category == "se-core-mining"
end

function createResourcePlannerPrototypes(resource)
    -- First, find a way to name the Planner based on the mining result
    local localisedName
    if resource.minable.result then
        localisedName = { "item-name." .. resource.minable.result }
    elseif resource.minable.results then
        local firstResult = resource.minable.results[1]
        if firstResult then
            if firstResult.type == "item" then
                localisedName = { "item-name." .. firstResult.name }
            elseif firstResult.type == "fluid" then
                localisedName = { "fluid-name." .. firstResult.name }
            end
        end
    end

    -- Then, create a layered icon to represent this Planner
    local backgroundIconSize = 64
    local overallLayeredIconScale = 0.4

    local layeredIcons = {
        {
            icon = BPSB.path .. "/graphics/icon-x64.png",
            icon_size = backgroundIconSize,
            icon_mipmaps = 3,
            tint = { r = 0.75, g = 0.75, b = 0.75, a = 1 },
        },
    }

    if not resource.icons then
        -- The simpler Icon approach
        table.insert(layeredIcons, {
            icon = resource.icon,
            icon_size = resource.icon_size,
            icon_mipmaps = resource.icon_mipmaps,
            scale = overallLayeredIconScale * (backgroundIconSize / resource.icon_size),
        })
    else
        -- Or the complex Icons approach (layer but re-scale each)
        for _, icon in pairs(resource.icons) do
            local thisIconScale = 1.0
            if icon.scale then
                thisIconScale = icon.scale
            end
            table.insert(layeredIcons, {
                icon = icon.icon,
                icon_size = icon.icon_size or resource.icon_size,
                tint = icon.tint,
                shift = icon.shift,
                scale = thisIconScale * overallLayeredIconScale * (backgroundIconSize / (icon.icon_size or resource.icon_size)),
                icon_mipmaps = icon.icon_mipmaps,
            })
        end
    end

    -- Finally, create the Selection Tool and its Recipe
    return {
        {
            type = "selection-tool",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            icons = layeredIcons,
            subgroup = Resources.name,
            order = resource.order,
            stack_size = 1,
            stackable = false,
            selection_color = { r = 0, g = 1, b = 0 },
            alt_selection_color = { r = 1, g = 0, b = 0 },
            selection_mode = { "any-tile" },
            alt_selection_mode = { "any-entity" },
            selection_cursor_box_type = "pair",
            alt_selection_cursor_box_type = "pair",
            alt_entity_filters = { resource.name },
            always_include_tiles = true,
        },
        {
            type = "recipe",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            energy_required = 1,
            enabled = false,
            ingredients = {},
            result = Resources.pfx .. resource.name,
            hide_from_stats = true,
        }
    }
end

-- New Items/Recipes for Resource Planners
for _, resource in pairs(data.raw.resource) do
    -- Some Resources are better left alone
    if not shouldSkipResourcePlanner(resource) then
        data:extend(createResourcePlannerPrototypes(resource))
    end
end
