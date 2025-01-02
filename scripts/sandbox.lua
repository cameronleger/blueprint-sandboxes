-- Managing multiple Sandboxes for each Player/Force
local Sandbox = {}

Sandbox.pfx = BPSB.pfx .. "sb-"

-- GUI Dropdown items for Sandboxes
Sandbox.choices = {
    { "sandbox." .. Sandbox.pfx .. "player-lab" },
    { "sandbox." .. Sandbox.pfx .. "force-lab" },
}

-- Constants to represent indexes for Sandbox.choices
Sandbox.player = 1
Sandbox.force = 2

-- A unique per-Force Sandbox Name
---@param force LuaForce
function Sandbox.NameFromForce(force)
    return Sandbox.pfx .. "f-" .. force.name
end

-- Whether the Force is specific to Blueprint Sandboxes
---@param force LuaForce
function Sandbox.IsSandboxForce(force)
    -- return string.sub(force.name, 1, pfxLength) == Sandbox.pfx
    return not not storage.sandboxForces[force.name]
end

-- Whether something is any type of Sandbox
function Sandbox.IsSandbox(thingWithName)
    return Lab.IsLab(thingWithName)
end

-- Whether something is any type of Sandbox
---@param player LuaPlayer
function Sandbox.IsPlayerInsideSandbox(player)
    return Sandbox.IsSandbox(player.surface)
end

-- Whether a Sandbox choice is allowed
function Sandbox.IsEnabled(selectedSandbox)
    if selectedSandbox == Sandbox.player then
        return true
    elseif selectedSandbox == Sandbox.force then
        return true
    else
        log("Impossible Choice for Sandbox: " .. selectedSandbox)
        return false
    end
end

-- Which Surface Name to use for this Player based on their Selected Sandbox
---@param player LuaPlayer
---@return LuaSurface | nil
function Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    local playerData = storage.players[player.index]

    if playerData.selectedSandbox == Sandbox.player
    then
        return Lab.GetOrCreateSurface(playerData.labName, sandboxForce)
    elseif playerData.selectedSandbox == Sandbox.force
    then
        return Lab.GetOrCreateSurface(storage.sandboxForces[sandboxForce.name].labName, sandboxForce)
    else
        log("Impossible Choice for Sandbox: " .. playerData.selectedSandbox)
        return
    end
end

---@param player LuaPlayer
local function StoreCursorBlueprint(player, playerData)
    if playerData.transitionaryBlueprintString == nil then
        playerData.transitionaryBlueprintString = Inventory.GetCursorBlueprintString(player)
    end
end

---@param player LuaPlayer
local function RestoreCursorBlueprint(player, playerData)
    if playerData.transitionaryBlueprintString ~= nil then
        if Inventory.WasCursorSafelyCleared(player) then
            player.cursor_stack.import_stack(playerData.transitionaryBlueprintString)
            player.cursor_stack_temporary = true
            playerData.transitionaryBlueprintString = nil
        end
    end
end

---@param player LuaPlayer
local function StorePreSandboxStateBeforeEntrance(player, playerData)
    playerData.preSandboxSurfaceName = player.surface.name
    playerData.preSandboxPosition = player.position
    playerData.preSandboxController = player.controller_type

    if playerData.preSandboxCharacter == nil or player.character ~= nil then
        playerData.preSandboxCharacter = player.character
    end

    -- Sometimes a Player has a volatile Inventory that needs restoring later
    if Inventory.ShouldPersist(player.controller_type) then
        log(player.name .. " has a volatile inventory; must persist it before entrance")
        playerData.preSandboxInventory = Inventory.Persist(
                player.get_main_inventory(),
                playerData.preSandboxInventory
        )
    else
        if playerData.preSandboxInventory then
            playerData.preSandboxInventory.destroy()
            playerData.preSandboxInventory = nil
        end
    end

    if not Controllers.IsSandboxCompatible(player) then
        StoreCursorBlueprint(player, playerData)

        --[[
        Otherwise, there is a Factorio "bug" that can destroy what was in the Cursor.
        It seems to happen with something from the Inventory being in the Stack, then
        entering the Sandbox, then copying something from the Sandbox, then exiting the
        Sandbox. At this point, the Cursor Stack is still fine and valid, but it seems
        to have lost its original location, so "clearing" it out will destroy it.
        ]]
        player.clear_cursor()
    end
end

-- Convert the Player to Remote-view, save their previous State, and view Selected Sandbox
---@param player LuaPlayer
function Sandbox.View(player)
    local playerData = storage.players[player.index]
    if Sandbox.IsPlayerInsideSandbox(player) then return end

    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        log("Completely Unknown Sandbox Surface, cannot use")
        return
    end

    -- Store the Player's previous State (that must be referenced to Exit)
    StorePreSandboxStateBeforeEntrance(player, playerData)
    Controllers.StoreRemoteView(player, playerData)

    -- Harmlessly begin by Remotely Viewing the Sandbox
    player.set_controller({
        type = defines.controllers.remote,
        surface = surface,
        position = playerData.lastSandboxPositions[surface.name],
    })
end

-- Convert the Player to God-mode, save their previous State, and enter Selected Sandbox
---@param player LuaPlayer
function Sandbox.Enter(player)
    local playerData = storage.players[player.index]
    if Sandbox.IsPlayerInsideSandbox(player) then return end

    local canBeSafelyReplaced = Controllers.CanBeSafelyReplaced(player)
    if canBeSafelyReplaced ~= true then
        player.print("Your current character/controller is not stable, so you cannot enter a Sandbox: " .. canBeSafelyReplaced)
        return
    end

    Controllers.StoreRemoteView(player, playerData)
    if not Controllers.SafelyCloseRemoteView(player) then
        player.print("You are using a remote view that cannot be safely closed, so you cannot enter a Sandbox. Return to your Character first.")
        return
    end

    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        log("Completely Unknown Sandbox Surface, cannot use")
        return
    end

    -- Store the Player's previous State (that must be referenced to Exit)
    StorePreSandboxStateBeforeEntrance(player, playerData)

    -- Harmlessly detach the Player from their Character
    local character = player.character
    player.set_controller({ type = defines.controllers.god })
    if character and not character.associated_player then
        player.associate_character(character)
    end

    -- Harmlessly teleport their God-body to the Sandbox
    Teleport.ToPositionOnSurface(player, surface, playerData.lastSandboxPositions[surface.name] or { 0, 0 })
end

-- Convert the Player to their previous State, and leave Selected Sandbox
---@param player LuaPlayer
function Sandbox.Exit(player)
    local playerData = storage.players[player.index]

    if not Sandbox.IsPlayerInsideSandbox(player) then
        log("Already outside Sandbox")
        return
    end

    -- Remember where they left off
    playerData.lastSandboxPositions[player.surface.name] = player.position

    if not Controllers.IsUsingRemoteView(player) and not playerData.preSandboxSurfaceName then
        log(player.name .. " has no last known Surface, so they cannot exit the Sandbox normally")
        player.print("You must not have come into the Sandbox in an expected way, because it does not know where you came from. What happens next might be unexpected.")
        Controllers.RestoreLastController(player, playerData)
        return
    end

    -- Harmlessly teleport them out of the Sandbox
    Teleport.ToPositionOnSurface(
        player,
        playerData.preSandboxSurfaceName,
        playerData.preSandboxPosition or { 0, 0 }
    )
    Controllers.SafelyCloseRemoteView(player)
end

-- Keep a Player's God-state, but change between Selected Sandboxes
---@param player LuaPlayer
function Sandbox.Transfer(player)
    local playerData = storage.players[player.index]

    if not Sandbox.IsPlayerInsideSandbox(player) then
        log(player.name .. " was outside Sandbox, so cannot be transferred")
        return
    end

    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    local surface = Sandbox.GetOrCreateSandboxSurface(player, sandboxForce)
    if surface == nil then
        log("Completely Unknown Sandbox Surface, cannot use")
        return
    end

    log(player.name .. " transferring Sandboxes: " .. player.surface.name .. " -> " .. surface.name)
    playerData.lastSandboxPositions[player.surface.name] = player.position
    Teleport.ToPositionOnSurface(player, surface, playerData.lastSandboxPositions[surface.name] or { 0, 0 })
end

-- Update Sandboxes Player if a Player actually changes Forces (outside of this mod)
---@param player LuaPlayer
function Sandbox.OnPlayerForceChanged(player)
    local playerData = storage.players[player.index]
    if not playerData then return end
    ---@type LuaForce
    local force = player.force
    if not Sandbox.IsSandboxForce(force)
            and playerData.forceName ~= force.name
    then
        log("Storing changed Player's Force: " .. player.name .. " -> " .. force.name)
        playerData.forceName = force.name

        local sandboxForceName = Sandbox.NameFromForce(force)

        playerData.sandboxForceName = sandboxForceName
        local labData = storage.labSurfaces[playerData.labName]
        if labData then
            labData.sandboxForceName = sandboxForceName
        end

        local labForce = Force.GetOrCreateSandboxForce(force)
        if Sandbox.IsPlayerInsideSandbox(player) then
            if Sandbox.GetSandboxChoiceFor(player, player.surface) ~= Sandbox.player then
                player.print("Your Force changed, so you have been removed from a Sandbox that you are no longer allowed in")
                playerData.preSandboxForceName = force.name
                Sandbox.Exit(player)
            else
                player.force = labForce
            end
        end

        local labSurface = game.surfaces[Lab.NameFromPlayer(player)]
        if labSurface then
            Lab.AssignEntitiesToForce(labSurface, labForce)
        end
    end
end

-- Determine whether the Player is inside a known Sandbox
---@param player LuaPlayer
---@param surface LuaSurface
function Sandbox.GetSandboxChoiceFor(player, surface)
    local playerData = storage.players[player.index]
    if surface.name == playerData.labName then
        return Sandbox.player
    elseif surface.name == storage.sandboxForces[playerData.sandboxForceName].labName then
        return Sandbox.force
    elseif Factorissimo.IsFactory(surface) then
        local outsideSurface = Factorissimo.GetOutsideSurfaceForFactory(
                surface,
                player.position
        )
        if outsideSurface then
            return Sandbox.GetSandboxChoiceFor(player, outsideSurface)
        end
    end
    return nil
end

---@param player LuaPlayer
local function StorePreSandboxStateOnArrival(player, playerData)
    if playerData.preSandboxForceName == nil then
        if Sandbox.IsSandboxForce(player.force) then
            log(player.name .. " entered a Sandbox as the Sandbox Force; assuming the player force")
            playerData.preSandboxForceName = "player"
        else
            playerData.preSandboxForceName = player.force.name
        end
    end

    if player.permission_group then
        if Permissions.IsSandboxPermissions(player.permission_group.name) then
            log(player.name .. " entered a Sandbox with the Sandbox Permissions; assuming none")
            playerData.preSandboxPermissionGroupId = nil
        else
            playerData.preSandboxPermissionGroupId = player.permission_group.name
        end
    else
        playerData.preSandboxPermissionGroupId = nil
    end

    if playerData.preSandboxCheatMode == nil then
        playerData.preSandboxCheatMode = player.cheat_mode
    end

    if playerData.preSandboxSurfaceList == nil then
        playerData.preSandboxSurfaceList = player.game_view_settings.show_surface_list
    end
end

---@param player LuaPlayer
local function EnableSandboxFeatures(player, playerData)
    -- Swap to the new Force; it has different bonuses!
    local sandboxForce = Force.GetOrCreateSandboxForce(game.forces[playerData.forceName])
    player.force = sandboxForce

    -- Since the Sandbox might have Cheat Mode enabled, EditorExtensions won't receive an Event for this otherwise
    if player.cheat_mode then player.cheat_mode = false end
    -- Enable Cheat mode _afterwards_, since EditorExtensions will alter the Force (now the Sandbox Force) based on this
    player.cheat_mode = true

    -- Harmlessly ensure our own Recipes are enabled
    Research.EnableSandboxSpecificResearch(sandboxForce)
end

---@param player LuaPlayer
local function EnforceSandboxPermissions(player)
    -- Set some Permissions so the Player cannot affect their other Surfaces
    local newPermissions = Permissions.GetOrCreate(player)
    if newPermissions then
        log("Setting new Player Permissions: " .. player.name .. " -> " .. newPermissions.name)
        player.permission_group = newPermissions
    end

    -- This list allows creating platforms (which is blocked by permissions) and no other surfaces (since this isn't their force)
    player.game_view_settings.show_surface_list = false
end

---@param player LuaPlayer
local function RestoreSandboxState(player, playerData)
    if Controllers.IsGod(player) then
        if not playerData.sandboxInventory then
            playerData.sandboxInventory = Inventory.Initialize(player.get_main_inventory())
        end
        Inventory.Restore(
                playerData.sandboxInventory,
                player.get_main_inventory()
        )
    end

    RestoreCursorBlueprint(player, playerData)
end

---@param player LuaPlayer
local function RestorePreSandboxController(player, playerData)
    -- When exiting directly to a Remote View, we first need to restore the physical settings (if they exist)
    if Controllers.IsUsingRemoteView(player) and player.physical_controller_type ~= playerData.preSandboxController then
        Controllers.StoreRemoteView(player, playerData)
        Controllers.SafelyCloseRemoteView(player)
    end
    Controllers.RestoreLastController(player, playerData)

    -- Sometimes a Player is already a God (like in Sandbox), and their Inventory wasn't on a body
    if Inventory.ShouldPersist(player.controller_type) and playerData.preSandboxInventory then
        Inventory.Restore(
                playerData.preSandboxInventory,
                player.get_main_inventory()
        )
    end
    if playerData.preSandboxInventory then
        playerData.preSandboxInventory.destroy()
        playerData.preSandboxInventory = nil
    end
end

---@param player LuaPlayer
local function RestorePreSandboxPermissions(player, playerData)
    -- Don't let anyone attempt to edit Surface Properties of other Surfaces!
    SurfacePropsGUI.Destroy(player)

    -- Swap to their original Force (in case they're not sent back to a Character)
    if playerData.preSandboxForceName and player.force.name ~= playerData.preSandboxForceName then
        player.force = playerData.preSandboxForceName
    end

    -- Toggle Cheat mode _afterwards_, just in case EditorExtensions ever listens to this Event
    local desiredCheatMode = playerData.preSandboxCheatMode or false
    if player.cheat_mode ~= desiredCheatMode then
        player.cheat_mode = desiredCheatMode
    end

    -- Swap to their original Permissions
    if playerData.preSandboxPermissionGroupId then
        log("Restoring Player Permissions: " .. player.name .. " -> " .. playerData.preSandboxPermissionGroupId)
        player.permission_group = game.permissions.get_group(playerData.preSandboxPermissionGroupId)
    else
        log("Removing Player Permissions: " .. player.name)
        player.permission_group = nil
    end

    -- Swap to their original surface-list setting
    local desiredSurfaceList = playerData.preSandboxSurfaceList or true
    if player.game_view_settings.show_surface_list ~= desiredSurfaceList then
        player.game_view_settings.show_surface_list = desiredSurfaceList
    end
end

local function CleanStates(playerData)
    -- Cleanup some restored states that may go stale and cannot be relied on later
    playerData.preSandboxForceName = nil
    playerData.preSandboxCheatMode = nil
    playerData.preSandboxSurfaceList = nil
    playerData.preSandboxPermissionGroupId = nil

    -- Cleanup some unused states that may go stale and cannot be relied on later
    playerData.preSandboxCharacter = nil
    playerData.preSandboxController = nil
    playerData.preSandboxPosition = nil
    playerData.preSandboxSurfaceName = nil
end

-- Is it likely that Swap to God can work?
---@param player LuaPlayer
---@return boolean
function Sandbox.CanEnter(player)
    if player.physical_controller_type ~= defines.controllers.character then return false end
    return Controllers.IsUsingRemoteView(player)
end

-- Convert the Player to God-mode, save their previous State, and enter Selected Sandbox
---@param player LuaPlayer
function Sandbox.SwapToGod(player)
    local playerData = storage.players[player.index]
    if not Sandbox.IsPlayerInsideSandbox(player) then return end

    -- Remember where they left off
    local surface = player.surface
    playerData.lastSandboxPositions[surface.name] = player.position
    StoreCursorBlueprint(player, playerData)

    -- Get back to their real/physical controllers so we can save them
    local canBeSafelyReplaced = Controllers.CanBeSafelyReplaced(player)
    if canBeSafelyReplaced ~= true then
        player.print("Your current character/controller is not stable, so you cannot enter a Sandbox: " .. canBeSafelyReplaced)
        return
    end
    if not Controllers.SafelyCloseRemoteView(player) then
        player.print("You are using a remote view that cannot be safely closed, so you cannot enter a Sandbox. Return to your Character first.")
        return
    end

    -- Store the Player's previous State (that must be referenced to Exit)
    StorePreSandboxStateBeforeEntrance(player, playerData)

    -- Harmlessly detach the Player from their Character
    local character = player.character
    player.set_controller({ type = defines.controllers.god })
    if character and not character.associated_player then
        player.associate_character(character)
    end

    -- Harmlessly teleport their God-body back to the Sandbox
    Teleport.ToPositionOnSurface(player, surface, playerData.lastSandboxPositions[surface.name] or { 0, 0 })

    -- Restore states again
    RestoreSandboxState(player, playerData)
end

-- Update whether the Player is inside a known Sandbox
---@param player LuaPlayer
function Sandbox.OnPlayerSurfaceChanged(player)
    local playerData = storage.players[player.index]
    local insideSandbox = Sandbox.GetSandboxChoiceFor(player, player.surface)
    local lastKnownSandbox = playerData.insideSandbox

    local wasInSandbox = lastKnownSandbox ~= nil
    local nowInSandbox = not not insideSandbox

    playerData.insideSandbox = insideSandbox

    if not wasInSandbox and nowInSandbox then
        log(player.name .." entered a Sandbox: " .. player.surface.name)

        if not Controllers.IsSandboxSupported(player) then
            log(player.name .. " entered a Sandbox with the Controller ID " .. player.controller_type .. "; bailing out.")
            player.print("WARNING: You have entered a Sandbox in an odd way, and using an unsupported Controller. You are on your own.")
        end

        StorePreSandboxStateOnArrival(player, playerData)
        EnableSandboxFeatures(player, playerData)
        EnforceSandboxPermissions(player)
        RestoreSandboxState(player, playerData)
        player.force.chart_all(player.surface)

    elseif wasInSandbox and not nowInSandbox then
        log(player.name .. " exiting last known Sandbox " .. lastKnownSandbox .. " to new Surface: " .. player.surface.name)

        StoreCursorBlueprint(player, playerData)
        RestorePreSandboxController(player, playerData)
        RestorePreSandboxPermissions(player, playerData)
        RestoreCursorBlueprint(player, playerData)
        Controllers.RestoreRemoteView(player, playerData)
        CleanStates(playerData)

    elseif wasInSandbox and nowInSandbox then
        log(player.name .. " transferred from last known Sandbox " .. lastKnownSandbox .. " to new Surface: " .. player.surface.name)

        player.force.chart_all(player.surface)
    end
end

-- Enter, Exit, or Transfer a Player across Sandboxes
function Sandbox.Toggle(player_index)
    local player = game.players[player_index]
    local playerData = storage.players[player.index]

    if Factorissimo.IsFactoryInsideSandbox(player.surface, player.position) then
        player.print{"messages.factorissimo-cannot-change-sandbox"}
        return
    end

    if not Sandbox.IsEnabled(playerData.selectedSandbox) then
        playerData.selectedSandbox = Sandbox.player
    end

    if Sandbox.IsPlayerInsideSandbox(player)
            and playerData.insideSandbox ~= playerData.selectedSandbox
    then
        Sandbox.Transfer(player)
    elseif Sandbox.IsPlayerInsideSandbox(player) then
        Sandbox.Exit(player)
    else
        Sandbox.View(player)
    end
end

return Sandbox
