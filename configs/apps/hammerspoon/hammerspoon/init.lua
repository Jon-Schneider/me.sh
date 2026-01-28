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