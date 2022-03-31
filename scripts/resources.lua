-- Custom Planners to add/remove Resources
local Resources = {}

Resources.name = BPSB.pfx .. "sandbox-resources"
Resources.pfx = BPSB.pfx .. "sbr-"
local pfxLength = string.len(Resources.pfx)

-- Whether the Thing is a Resource Planner
function Resources.IsResourcePlanner(name)
    return string.sub(name, 1, pfxLength) == Resources.pfx
end

-- Extract the Resource Name from a Resource Planner
function Resources.GetResourceName(name)
    return string.sub(name, pfxLength + 1)
end

-- Add Resources when a Resource Planner is used
function Resources.OnAreaSelectedForAdd(event)
    local resourceName = Resources.GetResourceName(event.item)
    for x = event.area.left_top.x, event.area.right_bottom.x do
        for y = event.area.left_top.y, event.area.right_bottom.y do
            event.surface.create_entity({
                name = resourceName,
                position = { x = x, y = y },
                amount = 100000,
                raise_built = true,
            })
        end
    end
end

-- Removed Resources when a Resource Planner is used
function Resources.OnAreaSelectedForRemove(event)
    for _, entity in pairs(event.entities) do
        entity.destroy({ raise_destroy = true })
    end
end

-- Add/Remove Resources when a Resource Planner is used
function Resources.OnAreaSelected(event, add)
    if (Lab.IsLab(event.surface) or SpaceExploration.IsSandbox(event.surface))
            and Resources.IsResourcePlanner(event.item)
    then
        if add then
            Resources.OnAreaSelectedForAdd(event)
        else
            Resources.OnAreaSelectedForRemove(event)
        end
    end
end

return Resources
