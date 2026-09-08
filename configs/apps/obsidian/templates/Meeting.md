<%*
const date = tp.date.now("YYYY-MM-DD");

await tp.file.rename(date);

// Let Obsidian/Templater finish processing the rename first.
setTimeout(() => {
    // Put the inline title into editing mode.
    app.commands.executeCommandById("workspace:edit-file-title");

    requestAnimationFrame(() => {
        const titleEl =
            app.workspace.activeLeaf?.view?.containerEl
                ?.querySelector(".inline-title");
    
        if (!titleEl) return;
    
        titleEl.focus();
    
        // Move caret to end of title.
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(titleEl);
        range.collapse(false);
    
        selection.removeAllRanges();
        selection.addRange(range);
    
        // Give you the separator before the meeting name.
        document.execCommand("insertText", false, " ");
    });
}, 100);
%>