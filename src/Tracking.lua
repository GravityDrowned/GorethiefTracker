--[[
    Gorethief Tracker
    Tracking.lua - Event handling and stack logic
    
    This module is responsible for:
    - Registering and handling ESO combat events
    - Detecting player direct damage
    - Managing Gorethief buff stack state
    - Detecting Roll Dodge and Bash attacks
    - Synchronizing with the game's effect system
    
    The core mechanic: Gorethief is a weapon set that procs on damage and applies
    a stacking buff to the player with each direct damage hit. At 10 stacks, the 
    set procs. This module reads the buff stacks directly from the player.
]]

--------------------------------------------------------------------------------
-- MODULE INITIALIZATION
--------------------------------------------------------------------------------

--- Tracking module namespace
-- @table GTC.Tracking
GTC.Tracking = GTC.Tracking or {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

--- Maximum number of stacks before the set procs
local MAX_STACKS = 10

--- Ability ID for Gorethief buff on player
-- Verified ID: 260047 (this is the buff that stacks on player)
local GORETHIEF_ABILITY_ID = 260047

--- Last time we polled for buff stacks (throttling mechanism)
local lastPollTime = 0

--- How often to poll for buff updates (milliseconds)
local POLL_INTERVAL_MS = 100  -- Poll every 100ms

--- Cooldown state tracking
-- These track whether the set is on cooldown after proccing
local cooldownActive = false     -- Is the set currently on cooldown?
local cooldownEndTime = 0        -- Game time (ms) when cooldown ends

--- Cooldown duration constants
local COOLDOWN_DURATION_MS = 4000  -- 4 seconds total cooldown (actual ESO set cooldown)
local SKELETON_DELAY_MS = 1000     -- 1 second until skeleton spawns

--------------------------------------------------------------------------------
-- STATE VARIABLES
--------------------------------------------------------------------------------

-- These are initialized in Initialize() and stored on the GTC global table
-- for access by other modules:
--
-- GTC.currentStacks   - number: Stack count for player (0-10)
-- GTC.buffTimeRemaining - number: Time remaining on buff in seconds
-- GTC.MAX_STACKS      - number: Exposed constant for other modules
-- GTC.GORETHIEF_ABILITY_ID - number: Exposed constant for other modules

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initializes the tracking module
-- Sets up state variables, registers event handlers.
-- Called once during addon initialization from Main.lua.
function GTC.Tracking.Initialize()
    -- Initialize state variables on the global GTC table
    GTC.currentStacks = 0       -- No stacks initially
    GTC.buffTimeRemaining = 0   -- No buff time initially
    
    -- Expose constants for other modules
    GTC.MAX_STACKS = MAX_STACKS
    GTC.GORETHIEF_ABILITY_ID = GORETHIEF_ABILITY_ID
    
    -- Expose cooldown constants for Interface module
    GTC.COOLDOWN_DURATION_MS = COOLDOWN_DURATION_MS
    GTC.SKELETON_DELAY_MS = SKELETON_DELAY_MS

    -- Register event handlers
    -- Combat events: detect direct damage and special attacks
    EVENT_MANAGER:RegisterForEvent(
        "GTC_CombatEvent", 
        EVENT_COMBAT_EVENT, 
        GTC.Tracking.OnCombatEvent
    )
    
    -- Effect changes: sync with game's effect system
    EVENT_MANAGER:RegisterForEvent(
        "GTC_EffectChanged", 
        EVENT_EFFECT_CHANGED, 
        GTC.Tracking.OnEffectChanged
    )
    
    -- Register continuous polling for buff stacks
    -- This runs every frame but is throttled internally to 100ms
    EVENT_MANAGER:RegisterForUpdate(
        "GTC_PollStacks",
        0,  -- Every frame (throttled internally)
        GTC.Tracking.PollPlayerBuff
    )
    
    if GTC.variables.debugMode then
        d("[GTC] Tracking module initialized")
    end
end

--------------------------------------------------------------------------------
-- BUFF POLLING
--------------------------------------------------------------------------------

--- Scans the player for existing Gorethief buff stacks
-- Returns the current stack count and time remaining from the game's effect system
-- @return number Stack count (0 if no buff found)
-- @return number Time remaining in seconds (0 if no buff found)
function GTC.Tracking.GetPlayerBuffStacks()
    for i = 1, GetNumBuffs("player") do
        local name, startTime, endTime, buffSlot, stackCount, iconFilename, 
              buffType, effectType, abilityType, statusEffectType, abilityId, 
              canClickOff, castByPlayer = GetUnitBuffInfo("player", i)
        
        if abilityId == GTC.GORETHIEF_ABILITY_ID then
            local timeRemaining = endTime - GetGameTimeSeconds()
            return stackCount or 0, math.max(0, timeRemaining)
        end
    end
    
    return 0, 0
end

--- Updates stack count by polling the player's buffs
-- Called periodically to ensure we catch all changes, including when
-- the buff is consumed at 10 stacks (proc).
-- Throttled to avoid performance impact.
function GTC.Tracking.PollPlayerBuff()
    -- Throttle polling
    local currentTime = GetGameTimeMilliseconds()
    if currentTime - lastPollTime < POLL_INTERVAL_MS then
        return
    end
    lastPollTime = currentTime
    
    -- Check if cooldown just expired (will update cooldownActive internally)
    local cooldownBefore = cooldownActive
    local cooldownRemaining = GTC.Tracking.GetCooldownRemaining()
    
    -- If cooldown just ended, update UI
    if cooldownBefore and not cooldownActive then
        GTC.Interface.UpdateUI()
    end
    
    -- Poll actual buff stacks
    local actualStacks, timeRemaining = GTC.Tracking.GetPlayerBuffStacks()
    
    -- Update if changed
    if actualStacks ~= GTC.currentStacks or timeRemaining ~= GTC.buffTimeRemaining then
        local previousStacks = GTC.currentStacks
        GTC.currentStacks = actualStacks
        GTC.buffTimeRemaining = timeRemaining
        
        if GTC.variables.debugMode then
            d("[GTC] Poll update: " .. previousStacks .. " -> " .. actualStacks .. " stacks, " .. math.floor(timeRemaining) .. "s remaining")
        end
        
        -- Detect proc (stacks consumed)
        -- Check for >= 9 stacks because the 10th stack is consumed atomically
        -- and we often see 9->0 instead of 10->0 due to polling timing
        if previousStacks >= (GTC.MAX_STACKS - 1) and actualStacks == 0 then
            GTC.Tracking.OnProcTriggered()
        end
        
        GTC.Interface.UpdateUI()
    end
end

--- Gets the remaining cooldown time in milliseconds
-- Also updates cooldown state if it has expired
-- @return number Remaining cooldown in milliseconds (0 if not on cooldown)
function GTC.Tracking.GetCooldownRemaining()
    if not cooldownActive then
        return 0
    end
    
    local currentTime = GetGameTimeMilliseconds()
    local remaining = cooldownEndTime - currentTime
    
    if remaining <= 0 then
        -- Cooldown expired
        cooldownActive = false
        cooldownEndTime = 0
        
        if GTC.variables.debugMode then
            d("[GTC] Cooldown ended - ready to proc again!")
        end
        
        return 0
    end
    
    return remaining
end

--- Checks if the set is currently on cooldown
-- @return boolean True if on cooldown, false otherwise
function GTC.Tracking.IsOnCooldown()
    GTC.Tracking.GetCooldownRemaining()  -- Updates state if expired
    return cooldownActive
end

--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

--- Handles combat events to detect direct damage, Roll Dodge, and Bash
-- This is the primary tracking mechanism. We filter for player direct damage
-- and track stack changes. We also detect special abilities.
--
-- @param eventCode number Event identifier
-- @param sourceUnitTag string "player", "group1", etc.
-- @param sourceName string Localized source name
-- @param sourceDisplayName string Source @name
-- @param targetUnitTag string Target unit tag
-- @param targetName string Localized target name
-- @param targetDisplayName string Target @name
-- @param abilityName string Name of the ability
-- @param abilityId number Ability ID
-- @param actionSlotType number Action slot type
-- @param result number Action result code (damage, heal, etc.)
-- @param isError boolean Error flag
-- @param hitValue number Damage/heal value
-- @param powerType number Power type
-- @param powerValue number Power value
-- @param damageType number Damage type
-- @param damageOverTime boolean DoT flag
-- @param critical boolean Critical hit flag
-- @param glancing boolean Glancing blow flag
-- @param crushing boolean Crushing blow flag
-- @param missType number Miss type
-- @param abilityActionSlotType number Ability action slot type
-- @param abilityIdDuplicate number Duplicate ability ID (ESO API quirk)
-- @param sourceUnit number Source unit ID
-- @param targetUnit number Target unit ID
function GTC.Tracking.OnCombatEvent(eventCode, sourceUnitTag, sourceName, 
    sourceDisplayName, targetUnitTag, targetName, targetDisplayName, 
    abilityName, abilityId, actionSlotType, result, isError, hitValue, 
    powerType, powerValue, damageType, damageOverTime, critical, glancing, 
    crushing, missType, abilityActionSlotType, abilityIdDuplicate, 
    sourceUnit, targetUnit)
    
    -- Early exit: addon disabled
    if not GTC.variables.enabled then 
        return 
    end

    -- Only process player actions (not pets, companions, etc.)
    if sourceUnitTag ~= "player" then 
        return 
    end

    -- Check for Roll Dodge (consumes 1 stack)
    if GTC:IsRollDodge(abilityId, abilityName) and GTC.currentStacks > 0 then
        if GTC.variables.debugMode then
            d("[GTC] Roll Dodge - consuming 1 stack")
        end
        return
    end
    
    -- Check for Bash at max stacks (triggers AoE bleed)
    if GTC:IsBash(abilityId, abilityName, abilityActionSlotType) and 
       GTC.currentStacks == GTC.MAX_STACKS then
        if GTC.variables.debugMode then
            d("[GTC] Bash at max stacks - AoE bleed!")
        end
        GTC.Tracking.OnProcTriggered()
        return
    end
    
    -- Check if this combat event represents direct damage (not DoT)
    if GTC:IsDirectDamage(result, damageOverTime) then
        local actualStacks, timeRemaining = GTC.Tracking.GetPlayerBuffStacks()
        
        -- Update tracking
        if actualStacks ~= GTC.currentStacks then
            local previousStacks = GTC.currentStacks
            GTC.currentStacks = actualStacks
            GTC.buffTimeRemaining = timeRemaining
            
            if GTC.variables.debugMode then
                d("[GTC] Stacks: " .. previousStacks .. " -> " .. actualStacks)
            end
            
            -- Check if set procced (stacks consumed: was at 9-10, now 0)
            if previousStacks >= (GTC.MAX_STACKS - 1) and actualStacks == 0 then
                GTC.Tracking.OnProcTriggered()
            end
            
            GTC.Interface.UpdateUI()
        end
    end
end

--- Handles effect changes to sync with game's effect system
-- This provides a fallback for buff tracking on the player.
--
-- @param eventCode number Event identifier
-- @param unitTag string Affected unit tag
-- @param effectName string Effect name
-- @param effectId number Effect ability ID
-- @param result number EFFECT_RESULT_* constant
-- @param stackCount number Current stack count from game
function GTC.Tracking.OnEffectChanged(eventCode, unitTag, effectName, effectId, result, stackCount)
    -- Early exit: addon disabled
    if not GTC.variables.enabled then 
        return 
    end

    -- Only track the buff on the player
    if unitTag ~= "player" then
        return
    end

    -- Only process the Gorethief buff
    if effectId ~= GTC.GORETHIEF_ABILITY_ID then 
        return 
    end
    
    if result == EFFECT_RESULT_GAINED or result == EFFECT_RESULT_UPDATED then
        -- Buff gained or stacks updated: sync directly from game
        local previousStacks = GTC.currentStacks
        GTC.currentStacks = stackCount
        
        if GTC.variables.debugMode and previousStacks ~= stackCount then
            d("[GTC] Buff stacks on player: " .. previousStacks .. " -> " .. stackCount)
        end
        
        GTC.Interface.UpdateUI()
        
    elseif result == EFFECT_RESULT_FADED then
        -- Buff faded: reset stacks (buff expired)
        if GTC.variables.debugMode then
            d("[GTC] Buff faded - stacks reset")
        end
        
        GTC.currentStacks = 0
        GTC.buffTimeRemaining = 0
        GTC.Interface.UpdateUI()
    end
end

--------------------------------------------------------------------------------
-- ABILITY DETECTION
--------------------------------------------------------------------------------

--- Determines if a combat event represents direct damage (not DoT)
-- @param result number Combat action result code
-- @param damageOverTime boolean DoT flag
-- @return boolean True if this event represents direct damage
function GTC:IsDirectDamage(result, damageOverTime)
    local isDamageResult = (result == ACTION_RESULT_DAMAGE or 
                           result == ACTION_RESULT_CRITICAL_DAMAGE)
    return isDamageResult and not damageOverTime
end

--- Determines if an ability is a Roll Dodge
-- @param abilityId number Ability ID
-- @param abilityName string Ability name
-- @return boolean True if this is a Roll Dodge
function GTC:IsRollDodge(abilityId, abilityName)
    return abilityId == 28549
end

--- Determines if an ability is a Bash attack
-- @param abilityId number Ability ID
-- @param abilityName string Ability name
-- @param abilityActionSlotType number Action slot type
-- @return boolean True if this is a Bash
function GTC:IsBash(abilityId, abilityName, abilityActionSlotType)
    return abilityActionSlotType == ACTION_SLOT_TYPE_BASH
end

--------------------------------------------------------------------------------
-- STACK MANAGEMENT
--------------------------------------------------------------------------------

--- Called when the set procs (10 stacks reached)
-- Starts the cooldown timer and schedules skeleton spawn notification.
function GTC.Tracking.OnProcTriggered()
    local currentTime = GetGameTimeMilliseconds()
    
    -- Start cooldown timer
    cooldownActive = true
    cooldownEndTime = currentTime + COOLDOWN_DURATION_MS
    
    if GTC.variables.debugMode then
        d("[GTC] *** SET PROCCED! ***")
        d("[GTC] Cooldown started: Duration=" .. COOLDOWN_DURATION_MS .. "ms")
        d("[GTC] Current time: " .. currentTime .. ", End time: " .. cooldownEndTime)
        d("[GTC] Cooldown active: " .. tostring(cooldownActive))
    end
    
    -- Schedule skeleton spawn notification (optional)
    zo_callLater(function()
        if GTC.variables.debugMode then
            d("[GTC] Skeleton spawning!")
        end
        -- Extension point: add skeleton spawn visual/sound effects
    end, SKELETON_DELAY_MS)
    
    -- Update UI to show cooldown overlay
    GTC.Interface.UpdateUI()
    
    -- Extension point: add proc effects here
    -- Examples:
    --   PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
    --   CreateProcAnimation()
    --   FireCustomEvent("GTC_SET_PROCCED")
end

--- Alias for backward compatibility
-- The original function name was ProcSet
GTC.Tracking.ProcSet = GTC.Tracking.OnProcTriggered

--- Resets the stack count to 0
-- Can be called via slash command or programmatically.
function GTC.Tracking.ResetStacks()
    local previousStacks = GTC.currentStacks
    GTC.currentStacks = 0
    GTC.buffTimeRemaining = 0
    
    if GTC.variables.debugMode then
        d("[GTC] Stacks reset: " .. previousStacks .. " -> 0")
    end
    
    -- Update UI to reflect reset
    GTC.Interface.UpdateUI()
end
