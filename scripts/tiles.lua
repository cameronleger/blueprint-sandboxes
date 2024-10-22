-- Custom Planners to add/remove Resources
local Tiles = {}

Tiles.name = BPSB.pfx .. "sandbox-tiles"
Tiles.pfx = BPSB.pfx .. "sbt-"
local pfxLength = string.len(Tiles.pfx)

Tiles.labTilePlanner = Tiles.pfx .. "lab-tile-planner"

-- Whether the Thing is a Tile Planner
function Tiles.IsTilePlanner(name)
    return string.sub(name, 1, pfxLength) == Tiles.pfx
end

-- Fix checkerboards when a Planner is used
function Tiles.OnAreaSelected(event)
    if (Lab.IsLab(event.surface) or SpaceExploration.IsSandbox(event.surface))
            and event.item == Tiles.labTilePlanner
    then
        event.surface.build_checkerboard(event.area)
        return true
    end
end

return Tiles
