PlannerIcons = require("scripts.planner-icons")
Resources = require("scripts.resources")

local function startsWith(str, beginning)
    return str:sub(1, #beginning) == beginning
end

local function endsWith(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

-- Helpers for Resource Planners
function shouldSkipResourcePlanner(resource)
    local skipCoreMining = true
    if mods["space-exploration"]
            and startsWith(mods["space-exploration"], "0.6")
    then
        skipCoreMining = false
    end
    return (resource.category == "se-core-mining" and skipCoreMining)
            or (resource.category == "se-core-mining" and endsWith(resource.name, "-sealed"))
end

function createResourcePlannerPrototypes(resource)
    -- First, find a way to name the Planner based on the mining result
    local localisedName = resource.localised_name
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

    -- Finally, create the Selection Tool and its Recipe
    return {
        {
            type = "selection-tool",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            icons = PlannerIcons.CreateLayeredIcon(resource),
            subgroup = Resources.name,
            order = resource.order,
            hidden_in_factoriopedia = true,
            stack_size = 1,
            select = {
                border_color = { r = 0, g = 1, b = 0 },
                cursor_box_type = "pair",
                mode = { "any-tile" },
            },
            alt_select = {
                border_color = { r = 1, g = 0, b = 0 },
                cursor_box_type = "pair",
                mode = { "any-entity" },
                entity_filters = { resource.name },
            },
            always_include_tiles = true,
            flags = { "not-stackable", "only-in-cursor" },
        },
        {
            type = "recipe",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            hidden_in_factoriopedia = true,
            energy_required = 1,
            enabled = false,
            ingredients = {},
            results = {
                { type = "item", name = Resources.pfx .. resource.name, amount = 1 },
            },
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
