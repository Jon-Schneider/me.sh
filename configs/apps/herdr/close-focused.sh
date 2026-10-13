#!/usr/bin/python3
"""Cmd+W: pass through to editors, else close the pane, tab, or workspace."""

import os

from herdr_api import api


def main():
    workspace = os.environ["HERDR_ACTIVE_WORKSPACE_ID"]
    tab = os.environ["HERDR_ACTIVE_TAB_ID"]
    pane = os.environ["HERDR_ACTIVE_PANE_ID"]
    info = api("pane.process_info", pane_id=pane)["process_info"]
    apps = {process.get("name") for process in info.get("foreground_processes", [])}
    if apps & {"micro", "xlent"}:
        api("pane.send_text", pane_id=pane, text="\x17")
        return

    info = api("workspace.get", workspace_id=workspace)["workspace"]
    panes = api("pane.list", workspace_id=workspace)["panes"]
    if sum(member["tab_id"] == tab for member in panes) > 1:
        api("pane.close", pane_id=pane)
    elif info["tab_count"] > 1:
        api("tab.close", tab_id=tab)
    else:
        api("workspace.close", workspace_id=workspace)


if __name__ == "__main__":
    main()
