-- Illusion magic for swapping real/complex entities with fake/simple variants
local Illusion = {}

Illusion.pfx = BPSB.pfx .. "ils-"
local pfxLength = string.len(Illusion.pfx)

-- Full list of Entities that require Illusions
Illusion.mappings = {
    -- { "type", "entity-name", "item-name" },
    { "ammo-turret", "se-meteor-defence-container", "se-meteor-defence" },
    { "ammo-turret", "se-meteor-point-defence-container", "se-meteor-point-defence" },
    { "assembling-machine", "se-delivery-cannon", "se-delivery-cannon" },
    { "assembling-machine", "se-delivery-cannon-weapon", "se-delivery-cannon-weapon" },
    { "assembling-machine", "se-energy-transmitter-injector", "se-energy-transmitter-injector" },
    { "assembling-machine", "se-energy-transmitter-emitter", "se-energy-transmitter-emitter" },
    { "assembling-machine", "se-space-elevator", "se-space-elevator" },
    { "boiler", "se-energy-transmitter-chamber", "se-energy-transmitter-chamber" },
    { "container", "se-rocket-launch-pad", "se-rocket-launch-pad" },
    { "container", "se-rocket-landing-pad", "se-rocket-landing-pad" },
    { "electric-energy-interface", "se-energy-beam-defence", "se-energy-beam-defence" },
    { "mining-drill", "se-core-miner-drill", "se-core-miner" },
}

Illusion.realToIllusionMap = {}
for _, mapping in ipairs(Illusion.mappings) do
    Illusion.realToIllusionMap[mapping[2]] = Illusion.pfx .. mapping[2]
end

Illusion.realNameFilters = {}
for realEntityName, illusionName in pairs(Illusion.realToIllusionMap) do
    table.insert(Illusion.realNameFilters, realEntityName)
end

-- Whether the Thing is an Illusion
function Illusion.IsIllusion(name)
    return string.sub(name, 1, pfxLength) == Illusion.pfx
end

-- Extract the Name from an Illusion
function Illusion.GetActualName(name)
    return string.sub(name, pfxLength + 1)
end

-- Extract the Name from an Entity
function Illusion.GhostOrRealName(entity)
    local realName = entity.name
    if entity.type == "entity-ghost" then
        realName = entity.ghost_name
    end
    return realName
end

-- Convert a built Entity into an Illusion (if possible)
function Illusion.ReplaceIfNecessary(entity)
    if not entity.valid then
        return
    end

    local realName = Illusion.GhostOrRealName(entity)
    local illusionName = Illusion.realToIllusionMap[realName]
    if illusionName == nil then
        return
    end

    local options = {
        name = illusionName,
        position = entity.position,
        direction = entity.direction,
        force = entity.force,
        fast_replace = true,
        spill = false,
        raise_built = true,
    }

    local result = entity.surface.create_entity(options)

    if result == nil then
        Debug.log("Could not replace " .. realName .. " with " .. illusionName)
    else
        Debug.log("Replaced " .. realName .. " with " .. illusionName)
    end
end

-- Convert an entire Blueprint's contents from Illusions (if possible)
function Illusion.OnBlueprintSetup(event)
    local player = game.players[event.player_index]
    local playerData = global.players[event.player_index]
    if not Sandbox.IsPlayerInsideSandbox(player) then
        return
    end

    local blueprint = nil
    if player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read then
        blueprint = player.blueprint_to_setup
    elseif player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint then
        blueprint = player.cursor_stack
    end
    if not blueprint or not blueprint.is_blueprint_setup() then
        return
    end

    local entities = blueprint.get_blueprint_entities()
    local mapping = event.mapping.get()
    if not entities or not event.mapping.valid then
        return
    end

    local replaced = 0
    for _, bpEntity in pairs(entities) do
        local entity = mapping[bpEntity.entity_number]
        if entity then
            if Illusion.IsIllusion(bpEntity.name) then
                bpEntity.name = Illusion.GetActualName(bpEntity.name)
                replaced = replaced + 1
            end
        end
    end
    blueprint.set_blueprint_entities(entities)
    Debug.log("Replaced " .. replaced .. " entities in Sandbox Blueprint")
end

return Illusion
