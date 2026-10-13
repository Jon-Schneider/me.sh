"""Call the running Herdr session without depending on the installed CLI version."""

import json
import os
from pathlib import Path
import socket


def api(method: str, **params) -> dict:
    config = Path(os.environ.get("HERDR_CONFIG_PATH") or "~/.config/herdr/config.toml").expanduser()
    path = os.environ.get("HERDR_SOCKET_PATH") or str(config.with_name("herdr.sock"))
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(path)
        with sock.makefile("rwb") as stream:
            request = {"id": "me.shortcuts", "method": method, "params": params}
            stream.write((json.dumps(request) + "\n").encode())
            stream.flush()
            response = json.loads(stream.readline())
    if "error" in response:
        raise RuntimeError(f"{method}: {response['error']}")
    return response["result"]
