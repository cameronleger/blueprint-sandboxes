-- Manage the Lab-like Surfaces
local Lab = {}

Lab.pfx = BPSB.pfx .. "lab-"
local pfxLength = string.len(Lab.pfx)

Lab.chartAllLabsTick = 300

-- A unique per-Player Lab Name
function Lab.NameFromPlayer(player)
    return Lab.pfx .. "p-" .. player.name
end

-- A unique per-Force Lab Name
function Lab.NameFromForce(force)
    return Lab.pfx .. "f-" .. force.name
end

-- Whether the Surface (or Force) is specific to a Lab
function Lab.IsLab(thingWithName)
    return string.sub(thingWithName.name, 1, pfxLength) == Lab.pfx
    -- return not not global.labSurfaces[thingWithName.name]
end

-- Create a new Lab Surface, if necessary
function Lab.GetOrCreateSurface(labName, sandboxForce)
    local surface = game.surfaces[labName]

    if not Lab.IsLab({ name = labName }) then
        Debug.log("Not a Lab, won't Create: " .. labName)
        return
    end

    if surface then
        if global.labSurfaces[labName] then
            return surface
        end
        Debug.log("Found a Lab Surface, but not the Data; recreating it for safety")
    end

    Debug.log("Creating Lab: " .. labName)
    global.labSurfaces[labName] = {
        sandboxForceName = sandboxForce.name,
        daytime = 0.95,
    }
    if not surface then
        surface = game.create_surface(labName, {
            default_enable_all_autoplace_controls = false,
            cliff_settings = { cliff_elevation_0 = 1024 },
        })
    end

    if remote.interfaces["RSO"] then
        pcall(remote.call, "RSO", "ignoreSurface", labName)
    end

    if remote.interfaces["dangOreus"] then
        pcall(remote.call, "dangOreus", "toggle", labName)
    end

    if remote.interfaces["AbandonedRuins"] then
        pcall(remote.call, "AbandonedRuins", "exclude_surface", labName)
    end

    surface.freeze_daytime = true
    surface.daytime = 0.95
    surface.show_clouds = false
    surface.generate_with_lab_tiles = true

    return surface
end

-- Set a Lab's Daytime to a specific value
function Lab.SetDayTime(player, surface, daytime)
    if Lab.IsLab(surface) then
        surface.freeze_daytime = true
        surface.daytime = daytime
        global.labSurfaces[surface.name].daytime = daytime
        Events.SendDaylightChangedEvent(player.index, surface.name, daytime)
        return true
    else
        return false
    end
end

-- Delete a Lab Surface, if present
function Lab.DeleteLab(surfaceName)
    if game.surfaces[surfaceName] and global.labSurfaces[surfaceName] then
        Debug.log("Deleting Lab: " .. surfaceName)
        global.labSurfaces[surfaceName] = nil
        game.delete_surface(surfaceName)
        return true
    else
        Debug.log("Not a Lab, won't Delete: " .. surfaceName)
        return false
    end
end

-- Reset the Lab a Player is currently in
function Lab.Reset(player)
    if Lab.IsLab(player.surface) then
        Debug.log("Resetting Lab: " .. player.surface.name)
        player.teleport({ 0, 0 }, player.surface.name)
        player.surface.clear(false)
        return true
    else
        Debug.log("Not a Lab, won't Reset: " .. player.surface.name)
        return false
    end
end

-- Add some helpful initial Entities to a Lab
function Lab.Equip(surface)
    local surfaceData = global.labSurfaces[surface.name]
    if not surfaceData then
        Debug.log("Not a Lab, won't Equip: " .. surface.name)
        return false
    end

    Debug.log("Equipping Lab: " .. surface.name)

    electricInterface = surface.create_entity {
        name = "electric-energy-interface",
        position = { 0, 0 },
        force = surfaceData.sandboxForceName,
    }
    electricInterface.minable = true

    bigPole = surface.create_entity {
        name = "big-electric-pole",
        position = { 0, -2 },
        force = surfaceData.sandboxForceName,
    }
    bigPole.minable = true

    trashCan = surface.create_entity {
        name = "infinity-chest",
        position = { 0, 2 },
        force = surfaceData.sandboxForceName,
    }
    trashCan.remove_unfiltered_items = true
    trashCan.minable = true

    return true
end

return Lab
