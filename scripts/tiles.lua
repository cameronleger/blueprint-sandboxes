-- Custom Planners to set some special Tiles
local Tiles = {}

Tiles.name = BPSB.pfx .. "sandbox-tiles"
Tiles.pfx = BPSB.pfx .. "sbt-"
local pfxLength = string.len(Tiles.pfx)

Tiles.labTilePlanner = Tiles.pfx .. "lab-tile-planner"

-- Whether the Thing is a Tile Planner
function Tiles.IsTilePlanner(name)
    return string.sub(name, 1, pfxLength) == Tiles.pfx
end

-- Extract the Tile Name from a Tile Planner
function Tiles.GetTileName(name)
    return string.sub(name, pfxLength + 1)
end

-- Fix checkerboards when a Planner is used
---@param event EventData.on_player_selected_area | EventData.on_player_alt_selected_area
function Tiles.OnAreaSelected(event)
    if (Lab.IsLab(event.surface) or SpaceExploration.IsSandbox(event.surface)) then
        if event.item == Tiles.labTilePlanner then
            event.surface.build_checkerboard(event.area)
            return true
        elseif Tiles.IsTilePlanner(event.item) then
            Tiles.SetTilesInArea(event.surface, event.area, Tiles.GetTileName(event.item))
            return true
        end
    end
end

-- Set all Tiles in a certain area
---@param surface LuaSurface
---@param area BoundingBox
---@param name string
function Tiles.SetTilesInArea(surface, area, name)
    local tiles = {} --[[@as (Tile)[] ]]
    for x = area.left_top.x, area.right_bottom.x do
        for y = area.left_top.y, area.right_bottom.y do
            table.insert(tiles, { name = name, position = { x, y }})
        end
    end
    surface.set_tiles(tiles, true, true, true, true)
end

return Tiles
