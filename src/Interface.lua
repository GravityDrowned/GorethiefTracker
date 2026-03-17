--[[
    Gorethief Tracker
    Interface.lua - UI rendering and display
    
    This module is responsible for:
    - Creating and configuring UI elements
    - Updating the display based on current state
    - Handling user positioning (drag and drop)
    - Managing visibility based on settings and state
    
    UI Structure:
    - GTCContainer (TopLevelWindow): Main container, movable
      - GTC_Texture (CT_TEXTURE): Icon background, color-coded
      - GTC_Label (CT_LABEL): Stack count text overlay
]]

--------------------------------------------------------------------------------
-- MODULE INITIALIZATION
--------------------------------------------------------------------------------

--- Interface module namespace
-- @table GTC.Interface
GTC.Interface = GTC.Interface or {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

--- Texture path for the display icon (using ESO built-in icon)
-- Using a generic buff icon since Gorethief specific icon path may vary
local TEXTURE_PATH = "/esoui/art/icons/ability_armor_009.dds"

--- Fallback texture (same as primary for simplicity)
local FALLBACK_TEXTURE = "/esoui/art/icons/ability_armor_009.dds"

--- Font for the stack count label
local STACK_FONT = "ZoFontWinH2"  -- Larger heading font

--- Color definitions for different stack levels
-- Each entry is {red, green, blue, alpha}
local COLORS = {
    LOW = {0, 1, 0, 1},      -- Green: 1-3 stacks (building)
    MEDIUM = {1, 1, 0, 1},   -- Yellow: 4-7 stacks (getting close)
    HIGH = {1, 0, 0, 1},     -- Red: 8-10 stacks (proc imminent!)
    DEFAULT = {1, 1, 1, 1},  -- White: default/text color
}

--- Debug throttling - prevents spam in chat
local lastDebugTime = 0
local DEBUG_THROTTLE_MS = 500  -- Only log every 500ms during cooldown

--------------------------------------------------------------------------------
-- UI ELEMENT REFERENCES
--------------------------------------------------------------------------------

-- These are stored on the GTC global for access by other modules:
--
-- GTC.container - TopLevelWindow: Main container
-- GTC.texture   - CT_TEXTURE: Icon texture
-- GTC.label     - CT_LABEL: Stack count text
-- GTC.cooldown  - CT_COOLDOWN: Circular cooldown overlay

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initializes the interface module
-- Creates all UI elements and configures their initial state.
-- Called once during addon initialization from Main.lua.
function GTC.Interface.Initialize()
    -- Create the main container window
    GTC.container = WINDOW_MANAGER:CreateTopLevelWindow("GTCContainer")
    
    -- Configure container properties
    GTC.container:SetDimensions(GTC.variables.size, GTC.variables.size)
    GTC.container:SetClampedToScreen(true)  -- Prevent dragging off-screen
    GTC.container:SetMouseEnabled(not GTC.variables.unlocked)  -- Enable drag when unlocked
    GTC.container:SetMovable(not GTC.variables.unlocked)       -- Note: logic is inverted in settings
    
    -- Create the icon texture
    -- This provides visual feedback and color-coding
    GTC.texture = WINDOW_MANAGER:CreateControl("GTC_Texture", GTC.container, CT_TEXTURE)
    GTC.texture:SetAnchor(TOPLEFT, GTC.container, TOPLEFT, 0, 0)
    GTC.texture:SetDimensions(GTC.variables.size, GTC.variables.size)
    
    -- Try to set custom texture, fall back if missing
    -- Note: SetTexture will silently fail if file doesn't exist
    GTC.texture:SetTexture(TEXTURE_PATH)
    
    -- Create the circular cooldown overlay
    -- This provides the "pie slice" cooldown animation like ability icons
    GTC.cooldown = WINDOW_MANAGER:CreateControl("GTC_Cooldown", GTC.container, CT_COOLDOWN)
    GTC.cooldown:SetAnchor(CENTER, GTC.container, CENTER, 0, 0)
    GTC.cooldown:SetDimensions(GTC.variables.size, GTC.variables.size)
    GTC.cooldown:SetDrawLevel(2)  -- Above texture, below label
    GTC.cooldown:SetHidden(true)  -- Hidden by default
    
    -- Create the stack count label
    -- This overlays the texture to show the numeric count
    GTC.label = WINDOW_MANAGER:CreateControl("GTC_Label", GTC.container, CT_LABEL)
    GTC.label:SetAnchor(CENTER, GTC.container, CENTER, 0, 0)
    GTC.label:SetFont(STACK_FONT)
    GTC.label:SetColor(unpack(COLORS.DEFAULT))
    GTC.label:SetText("")
    
     -- Ensure proper layering: texture (1) < cooldown (2) < label (3)
    GTC.label:SetDrawLevel(3)
    GTC.texture:SetDrawLevel(1)

    -- Position the container based on saved settings
    GTC.container:ClearAnchors()
    GTC.container:SetAnchor(
        TOPLEFT, 
        GuiRoot, 
        TOPLEFT, 
        GTC.variables.positionLeft, 
        GTC.variables.positionTop
    )

    -- Hide initially - UpdateUI will show when appropriate
    GTC.container:SetHidden(true)

    -- Register handler for position changes (drag and drop)
    GTC.container:SetHandler("OnMoveStop", function()
        GTC.Interface.OnPositionChanged()
    end)
    
    -- Register OnUpdate for cooldown animation updates
    -- This ensures the cooldown overlay and timer text update smoothly every frame
    GTC.container:SetHandler("OnUpdate", function()
        if GTC.Tracking.IsOnCooldown() then
            -- Throttled debug output (every 500ms)
            if GTC.variables.debugMode then
                local now = GetGameTimeMilliseconds()
                if not lastDebugTime or (now - lastDebugTime) > DEBUG_THROTTLE_MS then
                    local remaining = GTC.Tracking.GetCooldownRemaining()
                    d("[GTC] OnUpdate: Cooldown remaining: " .. remaining .. "ms (" .. string.format("%.1f", remaining/1000) .. "s)")
                    lastDebugTime = now
                end
            end
            GTC.Interface.UpdateUI()
        end
    end)
    
    if GTC.variables.debugMode then
        d("[GTC] Interface module initialized")
    end
end

--------------------------------------------------------------------------------
-- DISPLAY UPDATE
--------------------------------------------------------------------------------

--- Updates the UI display based on current state
-- This is the main update function, called whenever state changes:
-- - Stack count changes
-- - Settings changes (enabled, alwaysShow)
-- - Cooldown state changes
-- - Duration changes
--
-- Determines visibility and applies color-coding based on stack level.
-- During cooldown, shows a circular overlay with remaining time.
function GTC.Interface.UpdateUI()
    -- Safety check: ensure UI elements exist
    if not GTC.container then 
        return 
    end
    
    -- If addon is disabled, hide everything
    if not GTC.variables.enabled then
        GTC.container:SetHidden(true)
        return
    end

    -- Check if on cooldown using the tracking module's authoritative method
    local isOnCooldown = GTC.Tracking.IsOnCooldown()
    local cooldownRemaining = 0
    if isOnCooldown then
        cooldownRemaining = GTC.Tracking.GetCooldownRemaining()
    end
    
    -- Determine visibility:
    -- Show if we have stacks OR if alwaysShow is enabled OR if on cooldown
    local shouldShow = GTC.currentStacks > 0 or GTC.variables.alwaysShow or isOnCooldown
    
    if shouldShow then
        -- Show the display
        GTC.container:SetHidden(false)
        
        if isOnCooldown then
            -- === COOLDOWN STATE ===
            
            -- Show cooldown overlay with remaining time
            GTC.cooldown:SetHidden(false)
            
            -- Debug log the StartCooldown call
            if GTC.variables.debugMode then
                d("[GTC] StartCooldown called: remaining=" .. cooldownRemaining .. 
                  "ms, duration=" .. GTC.COOLDOWN_DURATION_MS .. "ms")
            end
            
            GTC.cooldown:StartCooldown(
                cooldownRemaining,                    -- Remaining time in ms
                GTC.COOLDOWN_DURATION_MS,            -- Total duration in ms
                CD_TYPE_RADIAL,                       -- Radial "pie slice" style
                CD_TIME_TYPE_TIME_UNTIL,             -- Count down to zero
                NO_LEADING_EDGE                       -- No leading edge line
            )
            
            -- Dim the icon texture during cooldown
            GTC.texture:SetColor(0.4, 0.4, 0.4, 1)
            
            -- Show cooldown time as text with better precision
            local seconds = cooldownRemaining / 1000
            if seconds >= 10 then
                GTC.label:SetText(string.format("%.0f", seconds))  -- "10", "11" etc
            elseif seconds >= 1 then
                GTC.label:SetText(string.format("%.1f", seconds))  -- "5.3", "2.1" etc
            else
                GTC.label:SetText(string.format("%.1f", seconds))  -- "0.9", "0.1" etc
            end
            GTC.label:SetColor(1, 1, 1, 1)  -- White text for visibility
            
        else
            -- === NORMAL STATE (tracking stacks) ===
            
            -- Hide cooldown overlay
            GTC.cooldown:SetHidden(true)
            
            -- Update the stack count text with duration if available
            local stacks, timeRemaining = GTC.Tracking.GetPlayerBuffStacks()
            if timeRemaining > 0 then
                local seconds = math.floor(timeRemaining)
                GTC.label:SetText(stacks .. " (" .. seconds .. "s)")
            else
                GTC.label:SetText(tostring(stacks))
            end
            
            -- Color-code icon based on stack count
            local color = GTC.Interface.GetColorForStacks(GTC.currentStacks)
            GTC.texture:SetColor(unpack(color))
            
            -- Set text color to white for readability
            GTC.label:SetColor(1, 1, 1, 1)
        end
    else
        -- Hide the display entirely
        GTC.container:SetHidden(true)
        GTC.cooldown:SetHidden(true)
    end
end

--- Gets the appropriate color for a given stack count
-- Color coding provides at-a-glance status:
-- - Green (1-3): Building stacks
-- - Yellow (4-7): Getting close
-- - Red (8-10): Proc imminent!
--
-- @param stacks number Current stack count (0-10)
-- @return table Color as {r, g, b, a}
function GTC.Interface.GetColorForStacks(stacks)
    if stacks == 10 then
        return {1, 0.84, 0, 1}  -- Gold (max stacks)
    elseif stacks >= 7 then
        return {1, 0, 0, 1}     -- Red (7-9 stacks)
    elseif stacks >= 4 then
        return {1, 1, 0, 1}     -- Yellow (4-6 stacks)
    elseif stacks >= 1 then
        return {0, 1, 0, 1}     -- Green (1-3 stacks)
    else
        return {1, 1, 1, 1}     -- White (0 stacks)
    end
end

--------------------------------------------------------------------------------
-- POSITION HANDLING
--------------------------------------------------------------------------------

--- Handles position changes when user drags the display
-- Saves the new position to SavedVariables for persistence.
function GTC.Interface.OnPositionChanged()
    -- Only save if position unlocked (user can drag)
    if GTC.variables.unlocked then
        return  -- Note: This check seems inverted, see notes below
    end
    
    -- Get current position
    local _, _, _, _, offsetX, offsetY = GTC.container:GetAnchor(0)
    
    -- Fallback: get position directly if anchor method fails
    if not offsetX or not offsetY then
        offsetX = GTC.container:GetLeft()
        offsetY = GTC.container:GetTop()
    end
    
    -- Save to SavedVariables
    if offsetX and offsetY then
        GTC.variables.positionLeft = offsetX
        GTC.variables.positionTop = offsetY
        
        if GTC.variables.debugMode then
            d("[GTC] Position saved: " .. offsetX .. ", " .. offsetY)
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Resets the display position to default (center-bottom of screen)
-- Called from settings panel "Reset Position" button.
function GTC.Interface.ResetPosition()
    -- Calculate default position
    local defaultLeft = GuiRoot:GetWidth() / 2
    local defaultTop = GuiRoot:GetHeight() / 2 + 200
    
    -- Update SavedVariables
    GTC.variables.positionLeft = defaultLeft
    GTC.variables.positionTop = defaultTop
    
    -- Update display position
    GTC.container:ClearAnchors()
    GTC.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, defaultLeft, defaultTop)
    
    if GTC.variables.debugMode then
        d("[GTC] Position reset to default")
    end
end

--- Updates the display size
-- Called when size setting changes.
--
-- @param newSize number New size in pixels (32-128)
function GTC.Interface.SetSize(newSize)
    -- Validate size
    newSize = math.max(32, math.min(128, newSize))
    
    -- Update SavedVariables
    GTC.variables.size = newSize
    
    -- Resize container, texture, and cooldown overlay
    GTC.container:SetDimensions(newSize, newSize)
    GTC.texture:SetDimensions(newSize, newSize)
    GTC.cooldown:SetDimensions(newSize, newSize)
    
    if GTC.variables.debugMode then
        d("[GTC] Size set to " .. newSize)
    end
end

--- Sets whether the display position is locked
-- When unlocked, user can drag the display.
--
-- @param locked boolean True to lock position, false to allow dragging
function GTC.Interface.SetPositionLocked(locked)
    GTC.container:SetMovable(not locked)
    GTC.container:SetMouseEnabled(not locked)
    GTC.variables.unlocked = not locked
    
    if GTC.variables.debugMode then
        d("[GTC] Position " .. (locked and "locked" or "unlocked"))
    end
end
