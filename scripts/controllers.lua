-- Managing multiple overlapping Controllers for each Player
local Controllers = {}

-- Determine if the Remote View is being used
---@param player LuaPlayer
---@return boolean
function Controllers.IsUsingRemoteView(player)
    return player.controller_type == defines.controllers.remote
end

-- Determine if the Editor is being used
---@param player LuaPlayer
---@return boolean
function Controllers.IsUsingEditor(player)
    return player.controller_type == defines.controllers.editor
end

-- Determine if the Character is riding a Rocket from/to a Platform
---@param player LuaPlayer
---@return boolean
function Controllers.IsRidingRocket(player)
    return player.driving and player.character ~= nil and player.vehicle == nil
end

---@param player LuaPlayer
---@param reason string
local function LogUnstablePlayer(player, reason)
    log("Player " .. player.name .. " is not stable because: " .. reason)
    return reason
end

-- Determine if the current state is stable enough to revert back to later on
---@param player LuaPlayer
---@param skipRetry true | nil
---@return true | string stable
function Controllers.CanBeSafelyReplaced(player, skipRetry)
    if player.controller_type == defines.controllers.cutscene then
        return LogUnstablePlayer(player, "watching a cutscene")
    end

    -- Jetpacks are a different, temporary type of character, and we're not fully integrated with those types of mods
    if player.character and player.character.name == "character-jetpack" then
        return LogUnstablePlayer(player, "using a jetpack")
    end

    -- Using the Editor, so the real state isn't accessible
    if Controllers.IsUsingEditor(player) then
        player.toggle_map_editor()
        if skipRetry then
            return LogUnstablePlayer(player, "using the editor")
        else
            return Controllers.CanBeSafelyReplaced(player, true)
        end
    end

    -- Has an important stashed controller that might be lost (like in the remote view, but while an editor)
    if player.stashed_controller_type and player.stashed_controller_type ~= defines.controllers.editor then
        return LogUnstablePlayer(player, "primary controller is stashed")
    end

    -- Some funny business will occur soon: transferring surfaces, controller swapping, etc
    if Controllers.IsRidingRocket(player) then
        return LogUnstablePlayer(player, "riding a rocket")
    end

    -- Some Remote Views are more stable than others
    if Controllers.IsUsingRemoteView(player) then
        -- Swapping back to non-Characters will "purge" or "initialize" their inventories
        if player.physical_controller_type ~= nil
            and player.physical_controller_type ~= defines.controllers.character
        then
            return LogUnstablePlayer(player, "physical controller is not a physical character while using remote view")
        end

        -- The character might be recreated/teleported soon, but swapping back to it does not "insert" them into the platform anyway
        if player.physical_surface.platform ~= nil then
            return LogUnstablePlayer(player, "riding a platform")
        end

        -- Swapping back to this character will place them on the surface, not in the vehicle
        if player.driving or (player.character and player.character.driving) then
            return LogUnstablePlayer(player, "driving while remotely viewing")
        end
    end

    return true
end

-- Store the last known Remote View state for potentially returning later
---@param player LuaPlayer
---@return boolean stored
function Controllers.StoreRemoteView(player, playerData)
    if not Controllers.IsUsingRemoteView(player) then
        return false
    end
    if Sandbox.IsSandbox(player.surface) then
        return false
    end
    playerData.preSandboxRemotePosition = player.position
    playerData.preSandboxRemoteSurfaceName = player.surface.name
    return true
end

-- Store the last known Remote View state for potentially returning later
---@param player LuaPlayer
---@return boolean restored
function Controllers.RestoreRemoteView(player, playerData)
    if not playerData.preSandboxRemotePosition
        or not playerData.preSandboxRemoteSurfaceName
        or not game.surfaces[playerData.preSandboxRemoteSurfaceName]
    then
        return false
    end
    local preSandboxRemotePosition = playerData.preSandboxRemotePosition
    local preSandboxRemoteSurfaceName = playerData.preSandboxRemoteSurfaceName
    playerData.preSandboxRemotePosition = nil
    playerData.preSandboxRemoteSurfaceName = nil
    player.set_controller({
        type = defines.controllers.remote,
        surface = preSandboxRemoteSurfaceName,
        position = preSandboxRemotePosition,
    })
    return true
end

-- If using Remote View, attempt to go back to the Character
---@param player LuaPlayer
---@return boolean success
function Controllers.SafelyCloseRemoteView(player, playerData)
    if not Controllers.IsUsingRemoteView(player) then
        return true
    end
    Controllers.StoreRemoteView(player, playerData)
    if player.physical_controller_type == defines.controllers.character then
        local character = player.character
        -- Cannot close a Remote View without a real Character
        if not character then return false end
        -- Being on a Platform means the Remote View must remain open
        if character.surface.platform then return false end
        -- Somehow swapping to the Character while driving exits the vehicle
        if character.driving then return false end

        if character.surface_index ~= player.surface_index then
            Teleport.ToPositionOnSurface(player, character.surface, character.position)
        end
        player.set_controller({
            type = defines.controllers.character,
            character = character,
        })
        return true
    else
        return false
    end
end

---@param player LuaPlayer
---@param character LuaEntity
local function AttachPlayerToCharacter(player, character)
    player.teleport(character.position, character.surface)
    player.set_controller({
        type = defines.controllers.character,
        character = character
    })
end

-- Ensure the Player has a Character (or similar) to go back to
---@param player LuaPlayer
---@return boolean restored
function Controllers.RestoreLastController(player, playerData)
    -- It's possible there's nothing to do
    if player.controller_type == defines.controllers.character then return true end

    -- The Remote View is an easy exit
    if Controllers.IsUsingRemoteView(player)
        and player.physical_controller_type == defines.controllers.character
    then
        if Controllers.SafelyCloseRemoteView(player, playerData) then
            return true
        end
    end

    if Controllers.IsUsingEditor(player) then
        -- The Editor might be how they came in
        if playerData.preSandboxController == nil then
            return true
        end

        -- The Editor needs another layer of exiting otherwise
        player.toggle_map_editor()
    end

    -- Hopeful situation: we directly know about the last valid character
    if playerData.preSandboxController == defines.controllers.character
        and playerData.preSandboxCharacter
        and playerData.preSandboxCharacter.valid
    then
        AttachPlayerToCharacter(player, playerData.preSandboxCharacter)
        return true
    end

    -- Still hopeful situation: the player was associated to the character somehow
    local characters = player.get_associated_characters()
    if #characters > 0 then
        if #characters > 1 then
            player.print("Warning: you have multiple associated characters but the Sandbox does not know exactly which one you wanted")
        end
        for _, character in ipairs(characters) do
            if character.valid and not character.player then
                AttachPlayerToCharacter(player, character)
                return true
            end
        end
    end

    -- Still hopeful situation: we know about the last non-character controller and location
    if playerData.preSandboxController
        and playerData.preSandboxController ~= defines.controllers.character
        and playerData.preSandboxPosition
        and playerData.preSandboxSurfaceName
    then
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        player.set_controller({ type = playerData.preSandboxController })
        return true
    end

    -- Space Exploration deletes and recreates Characters; check that out next
    local fromSpaceExploration = SpaceExploration.GetPlayerCharacter(player)
    if fromSpaceExploration and fromSpaceExploration.valid then
        player.teleport(fromSpaceExploration.position, fromSpaceExploration.surface.name)
        player.set_controller({
            type = defines.controllers.character,
            character = fromSpaceExploration
        })
        return true
    end

    -- We might at-least have a Surface to go back to
    if playerData.preSandboxController == defines.controllers.character
        and playerData.preSandboxPosition
        and playerData.preSandboxSurfaceName
        and game.surfaces[playerData.preSandboxSurfaceName]
    then
        player.print("Unfortunately, your previous Character was lost, so it had to be recreated.")
        player.teleport(playerData.preSandboxPosition, playerData.preSandboxSurfaceName)
        local recreated = game.surfaces[playerData.preSandboxSurfaceName].create_entity {
            name = "character",
            position = playerData.preSandboxPosition,
            force = playerData.preSandboxForceName or "player",
            raise_built = true,
        }
        player.set_controller({
            type = defines.controllers.character,
            character = recreated
        })
        return true
    end

    -- Otherwise, we need a completely clean slate :(
    player.print("Unfortunately, your previous Character was completely lost, so you must start anew.")
    player.teleport({ 0, 0 }, "nauvis")
    local recreated = game.surfaces["nauvis"].create_entity {
        name = "character",
        position = { 0, 0 },
        force = playerData.preSandboxForceName or "player",
        raise_built = true,
    }
    player.set_controller({
        type = defines.controllers.character,
        character = recreated
    })
    return true
end

return Controllers