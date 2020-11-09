hs.loadSpoon("Lunette")
spoon.Lunette:bindHotkeys()

-- Defeat Pasteblocking
hs.hotkey.bind({"cmd", "alt"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)