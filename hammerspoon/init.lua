-- Automatically reload configuration
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Defeat Pasteblocking and paste without retaining formatting
hs.hotkey.bind({"cmd", "alt"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- Disable Lunette bindings I don't need
hs.loadSpoon("Lunette")
windowManagementBindings = {
    center = false,
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