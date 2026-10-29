"""Local Cmd+W handler and its transient Herdr confirmation popup."""

import curses
import json
import os
from pathlib import Path
import sys
import unicodedata

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from herdr_api import api


def running_job(info, pane):
    """Only the pane's own shell PID is idle; shell scripts are jobs too."""
    if pane.get("agent"):
        return pane["agent"]
    processes = info.get("foreground_processes", [])
    if not info.get("shell_pid") or not processes:
        return "an unknown process"
    jobs = [p for p in processes if p.get("pid") != info["shell_pid"]]
    return ", ".join(sorted({p.get("name") or "an unknown process" for p in jobs}))


def close_target(pane_id, terminal_id):
    # Focus and topology may have changed during confirmation. Pin the original
    # terminal, and recalculate the cascade using its current pane record.
    pane = api("pane.get", pane_id=pane_id)["pane"]
    if pane["terminal_id"] != terminal_id:
        raise RuntimeError("The pane's terminal changed; keeping it open")
    workspace, tab = pane["workspace_id"], pane["tab_id"]
    info = api("workspace.get", workspace_id=workspace)["workspace"]
    panes = api("pane.list", workspace_id=workspace)["panes"]
    if not any(p["pane_id"] == pane_id and p["tab_id"] == tab for p in panes):
        raise RuntimeError("The pane moved or closed; keeping the workspace open")
    if sum(p["tab_id"] == tab for p in panes) > 1:
        api("pane.close", pane_id=pane_id)
    elif info["tab_count"] > 1:
        api("tab.close", tab_id=tab)
    else:
        api("workspace.close", workspace_id=workspace)


def request_close():
    context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}")
    pane_id = (context.get("focused_pane_id")
               or os.environ.get("HERDR_ACTIVE_PANE_ID")
               or os.environ["HERDR_PANE_ID"])
    info = api("pane.process_info", pane_id=pane_id)["process_info"]
    apps = {p.get("name") for p in info.get("foreground_processes", [])}
    if apps & {"micro", "xlent"}:
        api("pane.send_text", pane_id=pane_id, text="\x17")
        return

    pane = api("pane.get", pane_id=pane_id)["pane"]
    job = running_job(info, pane)
    if job:
        api("plugin.pane.open", plugin_id="me.confirm-close", entrypoint="confirm",
            placement="popup", env={
                "ME_CONFIRM_PANE_ID": pane_id,
                "ME_CONFIRM_TERMINAL_ID": pane["terminal_id"],
                "ME_CONFIRM_JOB": job,
                "ME_CONFIRM_TITLE": (pane.get("label") or pane.get("title")
                                     or pane.get("terminal_title_stripped")
                                     or pane.get("terminal_title") or pane_id),
            })
    else:
        close_target(pane_id, pane["terminal_id"])


def fit_line(text, width):
    """Keep titles on one line and clip by terminal cells, including CJK."""
    result = []
    cells = 0
    for char in " ".join(text.split()):
        if not char.isprintable():
            continue
        size = 0 if unicodedata.combining(char) else (2 if unicodedata.east_asian_width(char) in "WF" else 1)
        if cells + size > width:
            while result and cells > width - 1:
                cells -= result.pop()[1]
            return "".join(char for char, _ in result) + "…"
        result.append((char, size))
        cells += size
    return "".join(char for char, _ in result)


def confirmation_ui(screen):
    curses.curs_set(0)
    curses.set_escdelay(25)
    screen.keypad(True)
    curses.mousemask(curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED)
    curses.mouseinterval(0)
    heading_style = curses.A_BOLD
    selected_style = curses.A_REVERSE | curses.A_BOLD
    button_style = curses.A_BOLD
    if curses.has_colors():
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_WHITE, -1)
        curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_WHITE)
        curses.init_pair(3, curses.COLOR_WHITE, 8 if curses.COLORS >= 16 else curses.COLOR_BLACK)
        screen.bkgd(" ", curses.color_pair(1))
        heading_style |= curses.color_pair(1)
        selected_style = curses.color_pair(2) | curses.A_BOLD
        button_style |= curses.color_pair(3)
    selected = 0
    # Strip terminal controls from process names before displaying them.
    job = "".join(c for c in os.environ["ME_CONFIRM_JOB"] if c.isprintable())
    title = os.environ.get("ME_CONFIRM_TITLE") or os.environ["ME_CONFIRM_PANE_ID"]
    while True:
        screen.erase()
        rows, cols = screen.getmaxyx()
        padding = 4 if cols >= 40 else 2
        for row, text, style in [
            (1, "Close this pane?", heading_style),
            (3, title, curses.A_BOLD),
            (4, job + " is still running.", curses.A_NORMAL),
            (8, "Left/Right select  Enter choose  y close / n / Esc keep", curses.A_DIM),
        ]:
            if row < rows and cols > padding * 2:
                screen.addstr(row, padding, fit_line(text, cols - padding * 2), style)
        labels = ("  Confirm  ", "  Cancel  ")
        col = max(padding, (cols - sum(map(len, labels)) - 4) // 2)
        button_bounds = []
        for index, label in enumerate(labels):
            if rows > 6 and col < cols - padding:
                style = selected_style if index == selected else button_style
                screen.addnstr(6, col, label, cols - col - padding, style)
                button_bounds.append((index, col, min(col + len(label), cols - padding)))
            col += len(label) + 4
        screen.refresh()
        key = screen.get_wch()
        if key in (curses.KEY_LEFT, curses.KEY_RIGHT):
            selected = 1 - selected
        elif key == curses.KEY_MOUSE:
            _, x, y, _, state = curses.getmouse()
            if y == 6 and state & (curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED):
                for index, start, end in button_bounds:
                    if start <= x < end:
                        return index == 0
        elif key in ("\n", "\r", curses.KEY_ENTER):
            return selected == 0
        elif key != curses.KEY_RESIZE:
            # Direct shortcuts bypass selection; repeated Ctrl+W cancels.
            return key in ("y", "Y")


def main():
    if sys.argv[1:] == ["--prompt"]:
        if curses.wrapper(confirmation_ui):
            close_target(os.environ["ME_CONFIRM_PANE_ID"],
                         os.environ["ME_CONFIRM_TERMINAL_ID"])
    elif not sys.argv[1:]:
        request_close()
    else:
        raise SystemExit("usage: close.py [--prompt]")


if __name__ == "__main__":
    main()
