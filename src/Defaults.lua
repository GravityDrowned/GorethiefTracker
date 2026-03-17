--[[
    Gorethief Tracker
    Defaults.lua - Default configuration values
    
    This file exports the default configuration for SavedVariables.
    These values are used when:
    - The user installs the addon for the first time
    - The user clicks "Reset to Defaults" in settings
    - SavedVariables are corrupted or missing
    
    Note: Currently, Main.lua duplicates these defaults inline. This file
    is available for future refactoring to centralize default management.
    
    Usage (future):
        local defaults = require("src/Defaults")
        -- or --
        local defaults = GTC.Defaults
]]

--------------------------------------------------------------------------------
-- DEFAULT CONFIGURATION VALUES
--------------------------------------------------------------------------------

--- Default values for all SavedVariables settings
-- @table defaults
-- @field enabled boolean Master enable/disable toggle (default: true)
-- @field alwaysShow boolean Show display even at 0 stacks (default: false)
-- @field unlocked boolean Allow dragging to reposition (default: false)
-- @field size number Display size in pixels, range 32-128 (default: 64)
-- @field positionLeft number X position from left edge (default: center)
-- @field positionTop number Y position from top edge (default: center+200)
-- @field debugMode boolean Enable verbose logging (default: false)
return {
    -- Master toggle: when false, addon does nothing and UI is hidden
    enabled = true,
    
    -- Always show: when true, display is visible even with 0 stacks
    -- Useful for positioning or always seeing the tracker
    alwaysShow = false,
    
    -- Position unlocked: when true, user can drag the display
    -- When false, display is locked in place
    unlocked = false,
    
    -- Display size: icon and container dimensions in pixels
    -- Configurable via slider (min: 32, max: 128, step: 8)
    size = 64,
    
    -- Position: default is center-bottom of screen
    -- GuiRoot dimensions give us the screen size
    positionLeft = GuiRoot:GetWidth() / 2,
    positionTop = GuiRoot:GetHeight() / 2 + 200,
    
    -- Debug mode: when true, logs verbose information to chat
    -- Useful for troubleshooting tracking issues
    debugMode = false,
}
