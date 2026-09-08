const { Plugin, MarkdownView, Notice } = require("obsidian");

const NOTEBOOK_NAVIGATOR_OPEN_COMMAND = "notebook-navigator:open";
const NOTEBOOK_NAVIGATOR_VIEW = "notebook-navigator";

module.exports = class EscapeToNotebookNavigatorPlugin extends Plugin {
  async onload() {
    this._missingNavigatorNoticeShown = false;

    /*
     * Use capture phase so we can override Obsidian's own Escape behavior:
     *
     *   editor    + Esc -> Notebook Navigator list
     *   navigator + Esc -> stay in navigator
     *
     * Text-entry/transient UI keeps normal Escape behavior.
     */
    this.registerDomEvent(
      window,
      "keydown",
      (event) => this.handleKeydown(event),
      { capture: true }
    );

    // Diagnostic/manual command.
    this.addCommand({
      id: "focus-notebook-navigator",
      name: "Focus Notebook Navigator",
      callback: () => this.focusNotebookNavigator()
    });
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return;
    if (event.isComposing || event.repeat) return;
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;

    const target = event.target;
    if (!(target instanceof Element)) return;

    // Let Escape dismiss modal UI, menus, suggestions, etc.
    if (this.hasVisibleTransientUI()) return;

    // 1. Escape from the Markdown editor means "stop editing".
    if (this.isMarkdownEditorTarget(target)) {
      this.consume(event);
      this.focusNotebookNavigator();
      return;
    }

    // 2. Escape while already in Notebook Navigator must NOT send focus
    //    back to the editor. Obsidian core normally does that for sidebars.
    if (this.isNotebookNavigatorTarget(target)) {
      // Preserve Escape for Navigator's search box, inline rename fields,
      // and any other text-entry control where Escape means cancel/close.
      if (this.isTextEntryTarget(target)) return;

      // Otherwise: stay exactly where we are in Navigator.
      this.consume(event);
    }
  }

  isMarkdownEditorTarget(target) {
    const view = this.app.workspace.getActiveViewOfType(MarkdownView);
    if (!view) return false;

    const editorTarget =
      target.closest(".cm-editor") ||
      target.closest(".markdown-source-view");

    return !!editorTarget && view.containerEl.contains(editorTarget);
  }

  isNotebookNavigatorTarget(target) {
    // Preferred: determine it from the workspace leaf containing the event.
    const leafEl = target.closest(".workspace-leaf");
    if (leafEl) {
      const contentEl = leafEl.querySelector(".workspace-leaf-content");
      if (contentEl?.getAttribute("data-type") === NOTEBOOK_NAVIGATOR_VIEW) {
        return true;
      }
    }

    // Fallback: when keyboard focus makes the Navigator leaf active.
    const activeLeaf = this.app.workspace.activeLeaf;
    const viewType = activeLeaf?.view?.getViewType?.();
    return viewType === NOTEBOOK_NAVIGATOR_VIEW;
  }

  isTextEntryTarget(target) {
    if (target.closest("input, textarea, select")) return true;

    const editable = target.closest("[contenteditable='true']");
    return !!editable;
  }

  consume(event) {
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }
  }

  focusNotebookNavigator() {
    const commands = this.app.commands;
    const commandExists = commands?.listCommands?.().some(
      (command) => command.id === NOTEBOOK_NAVIGATOR_OPEN_COMMAND
    );

    if (!commandExists) {
      if (!this._missingNavigatorNoticeShown) {
        this._missingNavigatorNoticeShown = true;
        new Notice(
          'Escape to Notebook Navigator: "Notebook Navigator" is not installed/enabled, or its Open command is unavailable.'
        );
      }
      return;
    }

    this._missingNavigatorNoticeShown = false;
    commands.executeCommandById(NOTEBOOK_NAVIGATOR_OPEN_COMMAND);
  }

  hasVisibleTransientUI() {
    const selectors = [
      ".modal-container",
      ".suggestion-container",
      ".menu",
      ".prompt",
      ".popover",
      ".hover-popover"
    ];

    return selectors.some((selector) =>
      Array.from(document.querySelectorAll(selector)).some((el) => this.isVisible(el))
    );
  }

  isVisible(el) {
    const style = window.getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden") return false;
    if (Number(style.opacity) === 0) return false;
    return el.getClientRects().length > 0;
  }
};
