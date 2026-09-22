-- Automatically reload configuration
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Ghostty cannot pass Command through terminal mouse reporting. Translate
-- Cmd-click to Ctrl-click so Herdr opens pane links for every TUI.
local ghosttyLinkClick = false
ghosttyLinkClickTap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.leftMouseDragged,
    hs.eventtap.event.types.leftMouseUp,
}, function(event)
    local kind = event:getType()
    local app = hs.application.frontmostApplication()
    local inGhostty = app and app:bundleID() == "com.mitchellh.ghostty"
    if kind == hs.eventtap.event.types.leftMouseDown then
        local flags = event:getFlags()
        ghosttyLinkClick = inGhostty and flags.cmd and not (flags.ctrl or flags.alt or flags.shift)
    end
    if ghosttyLinkClick and inGhostty then
        local flags = event:getFlags()
        flags.cmd = false
        flags.ctrl = true
        event:setFlags(flags)
    end
    if kind == hs.eventtap.event.types.leftMouseUp then ghosttyLinkClick = false end
end)
ghosttyLinkClickTap:start()

-- Restore shortcuts that Device Hub dropped when it replaced Simulator.
-- Device Hub's device windows are missing from the macOS Accessibility window
-- list. Its Dock menu still lists every device across Spaces and marks the
-- active one, so use that as the source of truth.
local function deviceHubDockWindow(action)
    local ok, result = hs.osascript.applescript([[
        tell application "System Events"
            -- AXShowMenu toggles an existing menu closed, so always dismiss first.
            key code 53
            delay 0.1

            tell process "Dock"
                set dockItem to first UI element of list 1 whose name is "Device Hub"
                perform action "AXShowMenu" of dockItem

                repeat 20 times
                    if exists menu 1 of dockItem then exit repeat
                    delay 0.05
                end repeat
                if not (exists menu 1 of dockItem) then error "Device Hub Dock menu did not appear"

                set deviceItems to {}
                repeat with menuItem in menu items of menu 1 of dockItem
                    if name of menuItem is missing value then exit repeat
                    set end of deviceItems to menuItem
                end repeat

                set activeIndex to 0
                repeat with itemIndex from 1 to count of deviceItems
                    try
                        if value of attribute "AXMenuItemMarkChar" of item itemIndex of deviceItems is "✓" then
                            set activeIndex to itemIndex
                            exit repeat
                        end if
                    end try
                end repeat

                if "]] .. action .. [[" is "cycle" then
                    if (count of deviceItems) > 1 then
                        set nextIndex to activeIndex + 1
                        if nextIndex > count of deviceItems then set nextIndex to 1
                        -- Retain the menu-item reference, dismiss the visible
                        -- menu, then invoke it while hidden.
                        set nextItem to item nextIndex of deviceItems
                        key code 53
                        delay 0.01
                        perform action "AXPress" of nextItem
                        return true
                    end if
                else if activeIndex > 0 then
                    set activeName to name of item activeIndex of deviceItems
                    key code 53
                    return activeName
                end if

                key code 53
                return missing value
            end tell
        end tell
    ]])

    if not ok then
        hs.alert.show("Could not read Device Hub windows from the Dock")
        return nil
    end
    return result
end

local function cycleDeviceHubWindow()
    deviceHubDockWindow("cycle")
end

local function toggleFocusedSimulatorAppearance()
    local dockTitle = deviceHubDockWindow("title")
    if not dockTitle then return end
    local deviceName = dockTitle:match("^(.-) %([^()]+%)$") or dockTitle

    hs.task.new("/usr/bin/xcrun", function(exitCode, stdout)
        if exitCode ~= 0 then
            hs.alert.show("Could not list booted simulators")
            return
        end

        local decoded = hs.json.decode(stdout)
        local matches = {}
        for _, devices in pairs(decoded.devices or {}) do
            for _, device in ipairs(devices) do
                if device.state == "Booted" and device.name == deviceName then
                    table.insert(matches, device.udid)
                end
            end
        end

        if #matches ~= 1 then
            hs.alert.show(#matches == 0
                and "Could not match focused Device Hub window to a simulator"
                or "More than one booted simulator is named " .. deviceName)
            return
        end

        local udid = matches[1]
        hs.task.new("/usr/bin/xcrun", function(status, appearance)
            if status ~= 0 then
                hs.alert.show("Could not read simulator appearance")
                return
            end

            local current = appearance:match("^%s*(.-)%s*$")
            local target = current == "dark" and "light" or "dark"
            hs.task.new("/usr/bin/xcrun", function(setStatus)
                if setStatus ~= 0 then hs.alert.show("Could not change simulator appearance") end
            end, {"simctl", "ui", udid, "appearance", target}):start()
        end, {"simctl", "ui", udid, "appearance"}):start()
    end, {"simctl", "list", "devices", "booted", "--json"}):start()
end

local function afterShortcutReleased(action)
    hs.timer.waitUntil(function()
        local modifiers = hs.eventtap.checkKeyboardModifiers()
        return not (modifiers.cmd or modifiers.shift or modifiers.alt
            or modifiers.ctrl or modifiers.fn)
    end, action, 0.01)
end

hs.hotkey.bind({}, "F17", function()
    afterShortcutReleased(toggleFocusedSimulatorAppearance)
end)
hs.hotkey.bind({}, "F18", function()
    -- Device Hub can leave Hammerspoon's modifier snapshot stale until the
    -- next application event, so don't use afterShortcutReleased here.
    hs.timer.doAfter(0.12, cycleDeviceHubWindow)
end)

-- Defeat Pasteblocking and paste without retaining formatting
hs.hotkey.bind({"ctrl", "option", "cmd"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- Paste Markdown table template I use most often in Chrome or Safari
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", function()
    local app = hs.application.frontmostApplication()
    local name = app:name()
    if name == "Google Chrome" or name == "Safari" then
        local lines = {
            "| Before  | After |",
            "| ------------- | ------------- |",
            "|  |  |"
        }
        for _, line in ipairs(lines) do
            hs.eventtap.keyStrokes(line)
            hs.eventtap.keyStroke({}, "return") -- simulate pressing Enter
        end
    end
end)

-- Disable Lunette bindings I don't need
hs.loadSpoon("Lunette")
windowManagementBindings = {
	topHalf = false,
	bottomHalf = false,
    topLeft = false,
    bottomLeft = false,
    topRight = false,
    bottomRight = false,
    nextThird = false,
    prevThird = false,
    enlarge = false,
    shrink = false,
    undo = false,
    redo = false
}
spoon.Lunette:bindHotkeys(windowManagementBindings)

-- Get rid of cursed Global Protect Disconnected Window
hs.window.filter.new('GlobalProtect')
  :subscribe(hs.window.filter.windowCreated, function(window)
    if window:title() == 'GlobalProtect' then
      -- Small delay to ensure window is fully rendered
      hs.timer.doAfter(0.3, function()
        window:close()
      end)
    end
  end)

--local HOLD_THRESHOLD = 0.5
--local saveHotkeyPressTime = nil
--local saveHotkeyPreviousApp = nil
--
--local function isChromeFrontmost()
--    local app = hs.application.frontmostApplication()
--    return app and app:name() == "Google Chrome"
--end
--
--local function currentChromeURL()
--    local ok, result = hs.osascript.applescript([[
--        tell application "Google Chrome"
--            if (count of windows) = 0 then
--                return ""
--            end if
--            return URL of active tab of front window
--        end tell
--    ]])
--
--    if not ok then
--        hs.alert.show("Could not read Chrome URL")
--        return nil
--    end
--
--    if result == nil or result == "" then
--        hs.alert.show("No active Chrome tab")
--        return nil
--    end
--
--    return result
--end
--
--hs.hotkey.bind({"cmd", "shift"}, "S",
--    function() -- pressed
--        if not isChromeFrontmost() then
--            return
--        end
--
--        local url = currentChromeURL()
--        if not url then
--            return
--        end
--
--        saveHotkeyPressTime = hs.timer.secondsSinceEpoch()
--        saveHotkeyPreviousApp = hs.application.frontmostApplication()
--
--        local deeplink = "stache-reader://x-callback-url/save?url=" .. hs.http.encodeForQuery(url)
--        hs.urlevent.openURL(deeplink)
--    end,
--
--    function() -- released
--        if not saveHotkeyPressTime then
--            return
--        end
--
--        local heldFor = hs.timer.secondsSinceEpoch() - saveHotkeyPressTime
--        local previousApp = saveHotkeyPreviousApp
--
--        saveHotkeyPressTime = nil
--        saveHotkeyPreviousApp = nil
--
--        if heldFor < HOLD_THRESHOLD then
--            hs.timer.doAfter(0.1, function()
--                if previousApp and previousApp:isRunning() then
--                    previousApp:activate()
--                end
--            end)
--        end
--        -- else: held long enough, stay in the deeplinked app
--    end
--)
