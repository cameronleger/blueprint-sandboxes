-- Factorissimo related functionality
local Factorissimo = {}

Factorissimo.name = "factorissimo"
function Factorissimo.enabled()
    return not not remote.interfaces[Factorissimo.name]
end

Factorissimo.surfacePfx = "factory-floor-"
local surfacePfxLength = string.len(Factorissimo.surfacePfx)

function Factorissimo.GetAllFactories()
    if Factorissimo.enabled() then
        return remote.call(Factorissimo.name, "get_global", { "factories" })
    else
        return {}
    end
end

-- Whether the Surface is a Factory
function Factorissimo.IsFactory(thingWithName)
    if not Factorissimo.enabled() then
        return false
    end

    return string.sub(thingWithName.name, 1, surfacePfxLength) == Factorissimo.surfacePfx
end

-- Whether the Surface is a Factory inside of a Sandbox
---@param surface LuaSurface
---@param position MapPosition
function Factorissimo.IsFactoryInsideSandbox(surface, position)
    if not Factorissimo.enabled() then
        return false
    end

    local factory = Factorissimo.GetFactory(surface, position)
    if not factory then
        return false
    end

    return Sandbox.IsSandboxForce(factory.force)
end

-- Find a Factory given a Surface and Position (if possible)
---@param surface LuaSurface
---@param position MapPosition
function Factorissimo.GetFactory(surface, position)
    return remote.call(Factorissimo.name, "find_surrounding_factory", surface, position)
end

-- Find a Factory's Outside Surface recursively
---@param surface LuaSurface
---@param position MapPosition
function Factorissimo.GetOutsideSurfaceForFactory(surface, position)
    if not Factorissimo.IsFactory(surface) then
        return nil
    end

    local factory = Factorissimo.GetFactory(surface, position)
    if not factory then
        return nil
    end

    if Factorissimo.IsFactory(factory.outside_surface) then
        return Factorissimo.GetOutsideSurfaceForFactory(factory.outside_surface, {
            x = factory.outside_door_x,
            y = factory.outside_door_y,
        })
    else
        return factory.outside_surface
    end
    return nil
end

return Factorissimo
