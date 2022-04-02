-- Space Exploration related functionality
local SpaceExploration = {}

SpaceExploration.name = "space-exploration"
SpaceExploration.enabled = not not remote.interfaces[SpaceExploration.name]

-- Whether the Surface has been taken as a Space Sandbox
function SpaceExploration.IsSandbox(surface)
    return SpaceExploration.enabled
            and global.seSurfaces[surface.name]
end

-- Whether the Surface has been taken as a Planetary Lab Sandbox
function SpaceExploration.IsPlanetarySandbox(surface)
    return SpaceExploration.enabled
            and global.seSurfaces[surface.name]
            and not global.seSurfaces[surface.name].orbital
end

-- Chooses a non-home-system Star for a Force's Space Sandbox, if necessary
-- Notably, Star _Orbits_ are "usable" Zones, but not Stars themselves
-- In other words, these should be completely safe and invisible outside of this mod!
function SpaceExploration.ChooseZoneForForce(player, sandboxForce)
    if not SpaceExploration.enabled then
        return
    end

    for _, zone in pairs(remote.call(SpaceExploration.name, "get_zone_index", {})) do
        if zone.type == "star"
                and zone.special_type ~= "homesystem"
                and not global.seSurfaces[zone.name]
        then
            Debug.log("Choosing SE Zone " .. zone.name .. " as Sandbox for " .. sandboxForce.name)
            remote.call(SpaceExploration.name, "discover_zone", {
                force_name = sandboxForce.name,
                zone_name = zone.name,
                surface = "force-satellite-failures",
            })
            return zone.name
        end
    end
end

function SpaceExploration.GetOrCreateSurface(zoneName)
    if not SpaceExploration.enabled then
        return
    end

    local surface = remote.call(SpaceExploration.name, "zone_get_make_surface", {
        zone_index = remote.call(SpaceExploration.name, "get_zone_from_name", {
            zone_name = zoneName,
        }).index,
    })
    surface.always_day = true
    surface.show_clouds = false
    return surface
end

-- Chooses a non-home-system Star for a Force's Space Sandbox, if necessary
function SpaceExploration.GetOrCreatePlanetarySurfaceForForce(player, sandboxForce)
    if not SpaceExploration.enabled then
        return
    end

    local zoneName = global.sandboxForces[sandboxForce.name].sePlanetaryLabZoneName
    if zoneName == nil then
        zoneName = SpaceExploration.ChooseZoneForForce(player, sandboxForce)
        global.sandboxForces[sandboxForce.name].sePlanetaryLabZoneName = zoneName
        global.seSurfaces[zoneName] = {
            sandboxForceName = sandboxForce.name,
            orbital = false,
        }
    end

    local surface = SpaceExploration.GetOrCreateSurface(zoneName)
    surface.generate_with_lab_tiles = true

    return surface
end

-- Chooses a non-home-system Star for a Force's Planetary Sandbox, if necessary
function SpaceExploration.GetOrCreateOrbitalSurfaceForForce(player, sandboxForce)
    if not SpaceExploration.enabled then
        return
    end

    local zoneName = global.sandboxForces[sandboxForce.name].seOrbitalSandboxZoneName
    if zoneName == nil then
        zoneName = SpaceExploration.ChooseZoneForForce(player, sandboxForce)
        global.sandboxForces[sandboxForce.name].seOrbitalSandboxZoneName = zoneName
        global.seSurfaces[zoneName] = {
            sandboxForceName = sandboxForce.name,
            orbital = true,
        }
    end

    local surface = SpaceExploration.GetOrCreateSurface(zoneName)
    surface.generate_with_lab_tiles = false

    return surface
end

-- Reset the Space Sandbox a Player is currently in
function SpaceExploration.Reset(player)
    if not SpaceExploration.enabled then
        return
    end

    if SpaceExploration.IsSandbox(player.surface) then
        Debug.log("Resetting SE Sandbox: " .. player.surface.name)
        player.teleport({ 0, 0 }, player.surface.name)
        player.surface.clear(false)
        return true
    else
        Debug.log("Not a SE Sandbox, won't Reset: " .. player.surface.name)
        return false
    end
end

-- Delete a Space Sandbox and return it to the available Zones
function SpaceExploration.DeleteSandbox(zoneName)
    if not SpaceExploration.enabled or not zoneName then
        return
    end

    if global.seSurfaces[zoneName] then
        Debug.log("Deleting SE Sandbox: " .. zoneName)
        global.seSurfaces[zoneName] = nil
        game.delete_surface(zoneName)
        return true
    else
        Debug.log("Not a SE Sandbox, won't Delete: " .. zoneName)
        return false
    end
end

-- Add some helpful initial Entities to a Space Sandbox
function SpaceExploration.Equip(surface)
    if not SpaceExploration.enabled then
        return
    end

    local surfaceData = global.seSurfaces[surface.name]
    if not surfaceData then
        Debug.log("Not a SE Sandbox, won't Equip: " .. surface.name)
        return false
    end

    Debug.log("Equipping SE Sandbox: " .. surface.name)

    if (surfaceData.orbital) then
        -- Otherwise it will fill with Empty Space on top of the Tiles
        surface.request_to_generate_chunks({ x = 0, y = 0 }, 1)
        surface.force_generate_chunk_requests()

        local tiles = {}
        for y = -16, 16, 1 do
            for x = -16, 16, 1 do
                table.insert(tiles, {
                    name = "se-space-platform-scaffold",
                    position = { x = x, y = y }
                })
            end
        end
        surface.set_tiles(tiles)
    end

    electricInterface = surface.create_entity {
        name = "electric-energy-interface",
        position = { 0, 0 },
        force = surfaceData.sandboxForceName
    }
    electricInterface.minable = true

    bigPole = surface.create_entity {
        name = "big-electric-pole",
        position = { 0, -2 },
        force = surfaceData.sandboxForceName
    }
    bigPole.minable = true

    return true
end

--[[ Ensure that NavSat is not active
NOTE: This was not necessary in SE < 0.5.109 (the NavSat QoL Update)
Now, without this, the Inventory-differences after entering a Sandbox while
in the Navigation Satellite would be persisted, and without any good way
to undo that override.
--]]
function SpaceExploration.ExitRemoteView(player)
    if not SpaceExploration.enabled then
        return
    end
    remote.call(SpaceExploration.name, "remote_view_stop", { player = player })
end

return SpaceExploration
