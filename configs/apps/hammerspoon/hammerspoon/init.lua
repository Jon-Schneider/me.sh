-- Automatically reload configuration
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

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