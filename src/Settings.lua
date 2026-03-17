--[[
    Gorethief Tracker
    Settings.lua - Settings panel integration
    
    This module is responsible for:
    - Registering the addon panel with LibAddonMenu-2.0
    - Defining all user-configurable settings
    - Handling setting changes and callbacks
    
    Depends on: LibAddonMenu-2.0 (LAM)
    If LAM is not installed, the settings panel simply won't appear,
    but the addon will still function with defaults/SavedVariables.
]]

--------------------------------------------------------------------------------
-- MODULE INITIALIZATION
--------------------------------------------------------------------------------

--- Settings module namespace
-- @table GTC.Settings
GTC.Settings = GTC.Settings or {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

--- Addon metadata for the settings panel
local ADDON_NAME = "Gorethief Tracker"
local ADDON_AUTHOR = "YourName"
local ADDON_VERSION = "1.0.0"
local ADDON_WEBSITE = ""  -- Add ESOUI link when published

--- LAM panel identifiers
local PANEL_NAME = "GTC_SettingsPanel"
local CONTROLS_NAME = "GTC_Settings"

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initializes the settings module
-- Registers the addon panel and controls with LibAddonMenu-2.0.
-- Called once during addon initialization from Main.lua.
function GTC.Settings.Initialize()
    -- Check if LibAddonMenu is available
    if not LibAddonMenu2 then
        -- LAM not installed - settings panel won't be available
        -- Addon still works via slash commands and SavedVariables
        if GTC.variables.debugMode then
            d("[GTC] LibAddonMenu-2.0 not found - settings panel disabled")
        end
        return
    end
    
    -- Create the addon panel (appears in Settings > Addons)
    local panelData = GTC.Settings.CreatePanelData()
    LibAddonMenu2:RegisterAddonPanel(PANEL_NAME, panelData)
    
    -- Create the settings controls
    local optionsData = GTC.Settings.CreateOptionsData()
    LibAddonMenu2:RegisterOptionControls(PANEL_NAME, optionsData)
    
    if GTC.variables.debugMode then
        d("[GTC] Settings module initialized")
    end
end

--------------------------------------------------------------------------------
-- PANEL CONFIGURATION
--------------------------------------------------------------------------------

--- Creates the panel data for LibAddonMenu
-- This defines the addon's entry in the Settings > Addons menu.
--
-- @return table Panel configuration for LAM
function GTC.Settings.CreatePanelData()
    return {
        type = "panel",
        name = ADDON_NAME,
        displayName = "|cFFD700" .. ADDON_NAME .. "|r",  -- Gold color
        author = ADDON_AUTHOR,
        version = ADDON_VERSION,
        website = ADDON_WEBSITE,
        feedback = ADDON_WEBSITE,
        donation = "",
        
        -- Enable refresh and defaults functionality
        registerForRefresh = true,
        registerForDefaults = true,
        
        -- Reset to defaults callback
        resetFunc = function()
            -- Reset all settings to defaults
            GTC.variables.enabled = true
            GTC.variables.alwaysShow = false
            GTC.variables.unlocked = false
            GTC.variables.size = 64
            GTC.variables.positionLeft = GuiRoot:GetWidth() / 2
            GTC.variables.positionTop = GuiRoot:GetHeight() / 2 + 200
            GTC.variables.debugMode = false
            
            -- Apply changes
            GTC.Interface.SetSize(64)
            GTC.Interface.ResetPosition()
            GTC.Interface.UpdateUI()
        end,
    }
end

--------------------------------------------------------------------------------
-- SETTINGS CONTROLS
--------------------------------------------------------------------------------

--- Creates the options data for LibAddonMenu
-- Defines all user-configurable settings with their controls.
--
-- @return table Array of control definitions for LAM
function GTC.Settings.CreateOptionsData()
    return {
        -- Section: General Settings
        {
            type = "header",
            name = "General Settings",
        },
        
        -- Enable/Disable toggle
        {
            type = "checkbox",
            name = "Enable Addon",
            tooltip = "Master toggle to enable or disable the addon entirely. "
                   .. "When disabled, no tracking occurs and the display is hidden.",
            getFunc = function() 
                return GTC.variables.enabled 
            end,
            setFunc = function(value) 
                GTC.variables.enabled = value
                GTC.Interface.UpdateUI()
            end,
            default = true,
            width = "full",
        },
        
        -- Always show display
        {
            type = "checkbox",
            name = "Always Show Display",
            tooltip = "When enabled, the display remains visible even when you have 0 stacks. "
                   .. "Useful for positioning or keeping the tracker always visible.",
            getFunc = function() 
                return GTC.variables.alwaysShow 
            end,
            setFunc = function(value) 
                GTC.variables.alwaysShow = value
                GTC.Interface.UpdateUI()
            end,
            default = false,
            width = "full",
        },
        
        -- Section: Display Settings
        {
            type = "header",
            name = "Display Settings",
        },
        
        -- Unlock position
        {
            type = "checkbox",
            name = "Unlock Position",
            tooltip = "When enabled, you can drag the display to reposition it. "
                   .. "Disable to lock the display in place.",
            getFunc = function() 
                return not GTC.variables.unlocked  -- Note: inverted logic
            end,
            setFunc = function(value)
                local unlocked = not value
                GTC.variables.unlocked = unlocked
                GTC.container:SetMovable(unlocked)
                GTC.container:SetMouseEnabled(unlocked)
            end,
            default = true,  -- Default is locked (unlocked = false)
            width = "full",
        },
        
        -- Reset position button
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Reset the display position to the center-bottom of the screen.",
            func = function()
                GTC.Interface.ResetPosition()
            end,
            width = "half",
        },
        
        -- Display size slider
        {
            type = "slider",
            name = "Display Size",
            tooltip = "Adjust the size of the stack counter display (in pixels).",
            min = 32,
            max = 128,
            step = 8,
            getFunc = function() 
                return GTC.variables.size 
            end,
            setFunc = function(value)
                GTC.Interface.SetSize(value)
            end,
            default = 64,
            width = "full",
        },
        
        -- Section: Debug
        {
            type = "header",
            name = "Debug",
        },
        
        -- Debug mode toggle
        {
            type = "checkbox",
            name = "Debug Mode",
            tooltip = "Enable verbose debug logging to the chat window. "
                   .. "Useful for troubleshooting tracking issues.",
            getFunc = function() 
                return GTC.variables.debugMode 
            end,
            setFunc = function(value) 
                GTC.variables.debugMode = value
                if value then
                    d("[GTC] Debug mode enabled")
                end
            end,
            default = false,
            width = "full",
        },
        
        -- Section: About
        {
            type = "header",
            name = "About",
        },
        
        -- Description
        {
            type = "description",
            text = "Gorethief Tracker monitors your direct damage attacks and displays "
                .. "the current stack count for the Gorethief item set (10-stack buff).\n\n"
                .. "After dealing direct damage 10 times, the set will proc with "
                .. "bonus effects. The display color changes as you approach 10 stacks:\n"
                .. "  - |c00FF00Green|r: 1-3 stacks (building)\n"
                .. "  - |cFFFF00Yellow|r: 4-7 stacks (almost ready)\n"
                .. "  - |cFF0000Red|r: 8-10 stacks (procced!)\n\n"
                .. "Use /gtc in chat for quick controls.",
            width = "full",
        },
        
        -- Slash commands reference
        {
            type = "description",
            title = "Slash Commands",
            text = "/gtc - Show addon status\n"
                .. "/gtc toggle - Enable/disable addon\n"
                .. "/gtc reset - Reset stack count\n"
                .. "/gtc debug - Toggle debug mode",
            width = "full",
        },
    }
end
