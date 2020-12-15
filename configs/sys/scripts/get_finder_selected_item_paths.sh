#!/usr/bin/env osascript
set AppleScript's text item delimiters to linefeed

tell application "Finder"
   set fSelection to selection as text
   set thisPOSIXPath to (the POSIX path of fSelection)
end tell