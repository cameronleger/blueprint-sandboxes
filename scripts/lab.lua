-- Manage the Lab-like Surfaces
local Lab = {}

Lab.pfx = BPSB.pfx .. "lab-"
local pfxLength = string.len(Lab.pfx)

-- Space Labs carry an extra leading prefix purely so that Space Exploration classifies the
-- Surface as being in space. SE has no API to register a Zone for a foreign Surface, but its
-- is_surface_space() falls back to `string.starts(surface.name, "Space Factory")` (its
-- Factorissimo compatibility path), so the name is the only lever available. Without this, SE
-- swaps every space machine built here to its hidden "-grounded" variant, which has all of the
-- "space-" crafting categories stripped, and no space recipe can be selected.
Lab.spacePfx = "Space Factory " .. Lab.pfx
local spacePfxLength = string.len(Lab.spacePfx)

-- A Space Lab is floored with Space Exploration's empty space instead of Lab Tiles, so that
-- scaffolding and plating can be laid on it exactly as in orbit. Lab Tiles are ground, and SE's
-- platform items refuse to be placed on ground.
Lab.spaceTile = "se-space"
Lab.spaceFloorTile = "se-space-platform-scaffold"

-- Tiles that only exist in space. SE turns any of these into dirt, or cancels them outright,
-- when it hears about them being placed on a Surface without a Zone, which a Lab never has.
Lab.spaceOnlyTiles = {
    ["se-space"] = true,
    ["se-asteroid"] = true,
    ["se-space-platform-scaffold"] = true,
    ["se-space-platform-plating"] = true,
}

-- Whether Space Labs can be floored with space at all
function Lab.HasSpaceTiles()
    return prototypes.tile[Lab.spaceTile] ~= nil
            and prototypes.tile[Lab.spaceFloorTile] ~= nil
end

Lab.equipmentString = "0eNqFkdFqhDAQRf9lnuOi2WbB/EopQd3RDsRRkrjUSv69iQtSikvzNrlzz51MNmjtgrMjDqA3oG5iD/p9A08DNzbfcTMiaECLXXDUFcjohrVIDnR90yFEAcR3/AJdRXHibGkoDvc82d8OGT8EIAcKhM/gvVgNL2OLLiHFa4yAefLJOXFOS7RSwAq6kDHP8Qckxf8veQEs07zt0vfojKfvhKjK45wkXY8k4p44SUX3iT6c4C9qD5AXta/k2W08hkA8+NzlcJweaJak2TQm3g0FHJMU3IIxby/XeT3HPwp4oPN7irrJ+q2ulZLqdpVVjD/mj6gB"

-- A unique per-Player Lab Name
---@param player LuaPlayer
function Lab.NameFromPlayer(player)
    return Lab.pfx .. "p-" .. player.name
end

-- A unique per-Force Lab Name
---@param force LuaForce
function Lab.NameFromForce(force)
    return Lab.pfx .. "f-" .. force.name
end

-- A unique per-Player Space Lab Name
---@param player LuaPlayer
function Lab.SpaceNameFromPlayer(player)
    return Lab.spacePfx .. "s-" .. player.name
end

-- Whether the Surface (or Force) is a Space Lab
function Lab.IsSpaceLab(thingWithName)
    return string.sub(thingWithName.name, 1, spacePfxLength) == Lab.spacePfx
end

-- Whether the Surface (or Force) is specific to a Lab
function Lab.IsLab(thingWithName)
    return string.sub(thingWithName.name, 1, pfxLength) == Lab.pfx
            or Lab.IsSpaceLab(thingWithName)
end

-- A human-readable Lab Name
---@param labName string
---@return LocalisedString
function Lab.LocalisedNameFromLabName(labName)
    -- Space Labs are prefixed, so every offset below shifts by that much
    local offset = pfxLength
    if Lab.IsSpaceLab({ name = labName }) then offset = spacePfxLength end

    local identifier = string.sub(labName, offset + 3)

    local type = string.sub(labName, offset + 1, offset + 1)
    local marker = ""
    if type == "p" then type = "[img=" .. BPSB.pfx .. "player]"
    elseif type == "f" then type = "[img=" .. BPSB.pfx .. "force]"
    elseif type == "s" then
        type = "[img=" .. BPSB.pfx .. "player]"
        marker = { "", { "sandbox." .. BPSB.pfx .. "sb-space-marker" }, " " }
    else type = "" end

    return {
        "",
        "[img=shortcut." .. ToggleGUI.toggleShortcut .. "]",
        " ",
        marker,
        identifier,
        type,
    }
end

-- Create a new Lab Surface, if necessary
---@param labName string
---@param forceName string
---@param sandboxForceName string
function Lab.GetOrCreateSurface(labName, forceName, sandboxForceName)
    local surface = game.surfaces[labName]

    if not Lab.IsLab({ name = labName }) then
        log("Not a Lab, won't Create: " .. labName)
        return
    end

    if surface then
        if storage.labSurfaces[labName] then
            return surface
        end
        log("Found a Lab Surface, but not the Data; recreating it for safety")
    end

    log("Creating Lab: " .. labName)
    storage.labSurfaces[labName] = {
        forceName = forceName,
        sandboxForceName = sandboxForceName,
        equipmentBlueprints = Equipment.Init(Lab.equipmentString),
    }
    if not surface then
        surface = game.create_surface(labName, {
            default_enable_all_autoplace_controls = false,
            cliff_settings = { cliff_elevation_0 = 1024 },
        })
    end

    return surface
end

-- Delete a Lab Surface, if present
function Lab.DeleteLab(surfaceName)
    if game.surfaces[surfaceName] and storage.labSurfaces[surfaceName] then
        log("Deleting Lab: " .. surfaceName)
        local equipmentBlueprints = storage.labSurfaces.equipmentBlueprints
        if equipmentBlueprints and equipmentBlueprints.valid() then
            equipmentBlueprints.destroy()
        end
        storage.labSurfaces[surfaceName] = nil
        game.delete_surface(surfaceName)
        return true
    else
        log("Not a Lab, won't Delete: " .. surfaceName)
        return false
    end
end

-- Set the Lab's equipment Blueprint for a Surface
---@param surface LuaSurface
---@return string
function Lab.GetEquipmentBlueprint(surface)
    local surfaceData = storage.labSurfaces[surface.name]
    if Lab.IsLab(surface) and surfaceData then
        ---@type LuaItemStack
        local blueprint = surfaceData.equipmentBlueprints[1]
        return blueprint.export_stack()
    else
        return Lab.equipmentString
    end
end

-- Set the Lab's equipment Blueprint for a Surface
---@param surface LuaSurface
function Lab.SetEquipmentBlueprint(surface, equipmentString)
    if Lab.IsLab(surface) then
        log("Setting Lab equipment: " .. surface.name)
        Equipment.Set(
                storage.labSurfaces[surface.name].equipmentBlueprints,
                equipmentString
        )
        return true
    else
        log("Not a Lab, won't Set equipment: " .. surface.name)
        return false
    end
end

-- Reset the Lab a Player is currently in
---@param player LuaPlayer
function Lab.Reset(player)
    if not Lab.IsLab(player.surface) then
        log("Not a Lab, won't Reset: " .. player.surface.name)
        return false
    end
    log("Resetting Lab: " .. player.surface.name)
    Teleport.ToCenterOfSurface(player)
    player.surface.clear(false)
    return true
end

-- Remote calls to exclude a Lab from mods that manually generate features
---@param surface LuaSurface
function Lab.ExcludeFromMods(surface)
    log("Excluding surface from other mods: " .. surface.name)

    if remote.interfaces["RSO"] then
        pcall(remote.call, "RSO", "ignoreSurface", surface.name)
    end

    if remote.interfaces["dangOreus"] then
        pcall(remote.call, "dangOreus", "toggle", surface.name)
    end

    if remote.interfaces["AbandonedRuins"] then
        pcall(remote.call, "AbandonedRuins", "exclude_surface", surface.name)
    end
end

-- Set some important Surface settings for a Lab
---@param surface LuaSurface
function Lab.AfterCreate(surface)
    if not Lab.IsLab(surface) then
        log("Not a Lab, won't handle Creation: " .. surface.name)
        return false
    end

    log("Handling Creation of Lab: " .. surface.name)

    Lab.ExcludeFromMods(surface)

    surface.freeze_daytime = true
    surface.daytime = 0.95
    surface.show_clouds = false
    surface.generate_with_lab_tiles = true
    surface.ignore_surface_conditions = true
    surface.localised_name = Lab.LocalisedNameFromLabName(surface.name)

    return true
end

-- Replace the freshly generated Lab Tiles of a Space Lab with empty space
--
-- Only Lab Tiles are touched, so anything already laid down -- the scaffold pad under the
-- equipment, or a Blueprint's own tiles -- survives even if this event arrives after them.
---@param event EventData.on_chunk_generated
function Lab.OnChunkGenerated(event)
    local surface = event.surface
    if not (surface and surface.valid and Lab.IsSpaceLab(surface)) then return end
    if not Lab.HasSpaceTiles() then return end

    local tiles = {}
    for _, tile in pairs(surface.find_tiles_filtered {
        area = event.area,
        name = { "lab-dark-1", "lab-dark-2" },
    }) do
        tiles[#tiles + 1] = { name = Lab.spaceTile, position = tile.position }
    end

    if #tiles > 0 then
        -- No event: SE would otherwise see space tiles on a Surface with no Zone and undo them
        surface.set_tiles(tiles, true, true, true, false)
    end
end

-- Add some helpful initial Entities to a Lab
---@param surface LuaSurface
function Lab.Equip(surface)
    local surfaceData = storage.labSurfaces[surface.name]
    if not surfaceData then
        log("Not a Lab, won't Equip: " .. surface.name)
        return false
    end

    local forceName = nil
    if Isolation.IsFull() then
        forceName = Force.GetOrCreateSandboxForce(game.forces[surfaceData.forceName]).name
    else
        forceName = surfaceData.forceName
    end

    -- Nothing stands on empty space, so the equipment needs a platform under it
    local floorTile = nil
    if Lab.IsSpaceLab(surface) and Lab.HasSpaceTiles() then
        floorTile = Lab.spaceFloorTile
    end

    Equipment.Place(
            surfaceData.equipmentBlueprints[1],
            surface,
            forceName,
            floorTile
    )

    return true
end

-- Update all Entities in Lab with a new Force
---@param surface LuaSurface
---@param force LuaForce
function Lab.AssignEntitiesToForce(surface, force)
    if not Lab.IsLab(surface) then
        log("Not a Lab, won't Reassign: " .. surface.name)
        return false
    end

    log("Reassigning Lab to: " .. surface.name .. " -> " .. force.name)

    for _, entity in pairs(surface.find_entities_filtered {
        force = force,
        invert = true,
    }) do
        if entity.valid then entity.force = force end
    end

    return true
end

return Lab
