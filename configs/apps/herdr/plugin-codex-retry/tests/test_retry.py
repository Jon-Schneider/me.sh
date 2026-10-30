import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("retry", ROOT / "retry.py")
retry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retry)

MESSAGE = "Selected model is at capacity. Please try a different model."
BAD_REQUEST = '■ {"detail":"Bad Request"}'
SCREEN = "› Previous task\n\n■ " + MESSAGE + "\n\n› Ask Codex to do anything\n? for shortcuts\n"


def agent(pane="p1"):
    return {"agent": "codex", "agent_status": "done", "pane_id": pane,
            "terminal_id": "terminal-" + pane, "state_change_seq": 10,
            "agent_session": {"agent": "codex", "kind": "id", "value": "session-" + pane}}


class FakeServer:
    def __init__(self):
        self.agents = [agent()]
        self.screens = {"p1": SCREEN}
        self.foreground = True
        self.prompts = []
        self.lost_reply = False
        self.on_get = None

    def __call__(self, method, **params):
        pane = params.get("pane_id", params.get("target"))
        if method == "agent.list":
            return {"agents": copy.deepcopy(self.agents)}
        if method == "pane.read":
            return {"read": {"text": self.screens[pane]}}
        if method == "pane.process_info":
            return {"process_info": {"foreground_processes": [
                {"name": "codex" if self.foreground else "zsh", "pid": 42}]}}
        if method == "agent.get":
            if self.on_get:
                self.on_get()
            return {"agent": copy.deepcopy(next(a for a in self.agents if a["pane_id"] == pane))}
        if method == "agent.prompt":
            self.prompts.append((pane, params["text"]))
            if self.lost_reply:
                raise OSError("reply lost after write")
            return {}
        raise AssertionError(method)


class DetectionTests(unittest.TestCase):
    def test_with_or_without_decoration_and_line_wrapping(self):
        for prefix in ("■ ", "", "⚠ ", "◆ "):
            for message in (MESSAGE, MESSAGE.replace(" ", "\n")):
                with self.subTest(prefix=prefix, message=message):
                    self.assertTrue(retry.retryable_error(prefix + message + "\n\n› Ask Codex to do anything"))

    def test_bad_request_error_with_json_spacing_and_wrapping(self):
        for message in (BAD_REQUEST, '■ { "detail" : "Bad Request" }',
                        '■ {\n  "detail":\n"Bad Request"\n}'):
            with self.subTest(message=message):
                self.assertTrue(retry.retryable_error(
                    message + "\n\n› Ask Codex to do anything"))

    def test_bad_request_in_tool_output_or_quotes_is_not_a_failure(self):
        for message in ('{"detail":"Bad Request"}', '• ' + BAD_REQUEST,
                        '> ' + BAD_REQUEST, "`" + BAD_REQUEST + "`",
                        BAD_REQUEST + ' extra output', '■ {"detail":"Unauthorized"}'):
            with self.subTest(message=message):
                self.assertFalse(retry.retryable_error(
                    message + "\n\n› Ask Codex to do anything"))

    def test_latest_error_of_either_kind_must_still_be_current(self):
        for first, last in (("■ " + MESSAGE, BAD_REQUEST),
                            (BAD_REQUEST, "■ " + MESSAGE)):
            with self.subTest(last=last):
                text = first + "\n› go\n" + last
                self.assertTrue(retry.retryable_error(text + "\n› Ask Codex to do anything"))
                for tail in ("• Done", "› go", "■ Authentication failed",
                             "• Working (5s • esc to interrupt)"):
                    self.assertFalse(retry.retryable_error(
                        text + "\n" + tail + "\n› Ask Codex to do anything"))

    def test_normal_completion_and_other_errors(self):
        for text in ("• Done", "■ Authentication failed", "■ You've hit your usage limit"):
            self.assertFalse(retry.retryable_error(text + "\n› Ask Codex to do anything"))

    def test_quoted_message_is_not_a_failure(self):
        self.assertFalse(retry.retryable_error('• The server said "' + MESSAGE + '"\n› Ask Codex to do anything'))

    def test_old_error_followed_by_new_response_or_prompt(self):
        for tail in ("• Completed the task", "› go", "• Working (5s • esc to interrupt)"):
            self.assertFalse(retry.retryable_error(MESSAGE + "\n" + tail + "\n› Ask Codex to do anything"))

    def test_typed_input_is_preserved(self):
        self.assertFalse(retry.retryable_error(SCREEN.replace("› Ask Codex to do anything", "› My next task")))

    def test_subagent_completion_notice_does_not_clear_capacity_error(self):
        text = ("■ Selected model is at capacity. Please try a\ndifferent model.\n\n"
                "• Completed `/root/verify_ask_mac`\n\n"
                "• Completed `/root/check/second_pass`\n\n"
                "› Ask Codex to do anything\n")
        self.assertTrue(retry.retryable_error(text))

    def test_response_or_prompt_after_subagent_notice_clears_error(self):
        for tail in ("• Completed the task", "• The check passed", "› go",
                     "■ Authentication failed", "• Completed `/root/check` and fixed it"):
            with self.subTest(tail=tail):
                text = (MESSAGE + "\n• Completed `/root/verify_ask_mac`\n"
                        + tail + "\n› Ask Codex to do anything\n")
                self.assertFalse(retry.retryable_error(text))

    def test_empty_composer_does_not_consume_footer(self):
        self.assertTrue(retry.retryable_error(
            MESSAGE + "\n\n› \n\n  GPT-6.1-Sol high · Context 17% used\n"))

    def test_multiline_typed_input_is_preserved(self):
        self.assertFalse(retry.retryable_error(
            MESSAGE + "\n\n› \n  My next task\n\n  GPT-6.1-Sol high\n"))


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name)
        self.server = FakeServer()
        self.now = 0
        self.monitor = retry.Monitor(self.path, self.server, lambda: self.now)

    def step(self, now):
        self.now = now
        self.monitor.step()

    def test_waits_30_seconds_and_submits_exactly_one_go(self):
        self.step(0)
        self.step(29.9)
        self.assertEqual(self.server.prompts, [])
        self.step(30)
        self.step(60)
        self.assertEqual(self.server.prompts, [("p1", "go")])

    def test_bad_request_uses_same_timer_and_deduplication(self):
        self.server.screens["p1"] = SCREEN.replace("■ " + MESSAGE, BAD_REQUEST)
        self.step(0)
        self.step(29.9)
        self.assertEqual(self.server.prompts, [])
        self.step(30)
        self.step(60)
        self.assertEqual(self.server.prompts, [("p1", "go")])
        self.server.agents[0]["state_change_seq"] += 2
        self.step(62)
        self.step(91)
        self.assertEqual(len(self.server.prompts), 1)
        self.step(92)
        self.assertEqual(self.server.prompts, [("p1", "go"), ("p1", "go")])

    def test_bad_request_typed_input_cancels_retry(self):
        self.server.screens["p1"] = SCREEN.replace("■ " + MESSAGE, BAD_REQUEST)
        self.step(0)
        self.server.screens["p1"] = self.server.screens["p1"].replace(
            "› Ask Codex to do anything", "› hold on")
        self.step(30)
        self.assertEqual(self.server.prompts, [])
        self.assertFalse(self.monitor.pending)

    def test_manual_resume_cancels_pending_retry(self):
        self.step(0)
        self.server.agents[0]["agent_status"] = "working"
        self.step(20)
        self.server.agents[0].update(agent_status="done", state_change_seq=12)
        self.server.screens["p1"] = "• Done\n› Ask Codex to do anything"
        self.step(60)
        self.assertEqual(self.server.prompts, [])

    def test_subagent_notice_during_delay_does_not_cancel_retry(self):
        self.step(0)
        self.server.screens["p1"] = SCREEN.replace(
            "\n\n› Ask", "\n\n• Completed `/root/verify_ask_mac`\n\n› Ask")
        self.step(20)
        self.step(30)
        self.step(60)
        self.assertEqual(self.server.prompts, [("p1", "go")])

    def test_repeated_capacity_failure_gets_another_30_seconds(self):
        self.step(0)
        self.step(30)
        self.server.agents[0]["state_change_seq"] += 2
        self.step(32)
        self.step(61)
        self.assertEqual(len(self.server.prompts), 1)
        self.step(62)
        self.assertEqual(len(self.server.prompts), 2)

    def test_replaced_session_starts_a_new_timer(self):
        self.step(0)
        self.server.agents[0]["agent_session"]["value"] = "replacement"
        self.step(30)
        self.assertEqual(self.server.prompts, [])
        self.step(60)
        self.assertEqual(len(self.server.prompts), 1)

    def test_closed_pane_cancels(self):
        self.step(0)
        self.server.agents = []
        self.step(30)
        self.assertFalse(self.monitor.pending)
        self.assertEqual(self.server.prompts, [])

    def test_suspended_codex_does_not_receive_input(self):
        self.step(0)
        self.server.foreground = False
        self.step(30)
        self.assertEqual(self.server.prompts, [])

    def test_blocked_unknown_and_non_codex_are_ignored(self):
        for field, value in (("agent_status", "blocked"), ("agent_status", "unknown"), ("agent", "claude")):
            with self.subTest(field=field, value=value):
                self.server.agents = [agent()]
                self.server.agents[0][field] = value
                self.step(0)
                self.step(30)
                self.assertEqual(self.server.prompts, [])

    def test_state_change_during_final_recheck_cancels(self):
        self.step(0)
        self.server.on_get = lambda: self.server.agents[0].update(agent_status="working")
        self.step(30)
        self.assertEqual(self.server.prompts, [])

    def test_missing_error_or_typed_input_cancels(self):
        self.step(0)
        self.server.screens["p1"] = SCREEN.replace("› Ask Codex to do anything", "› hold on")
        self.step(30)
        self.assertEqual(self.server.prompts, [])
        self.assertFalse(self.monitor.pending)

    def test_lost_reply_and_watcher_restart_do_not_duplicate_prompt(self):
        self.server.lost_reply = True
        self.step(0)
        self.step(30)
        self.monitor = retry.Monitor(self.path, self.server, lambda: self.now)
        self.step(31)
        self.step(62)
        self.assertEqual(self.server.prompts, [("p1", "go")])

    def test_multiple_panes_have_independent_timers(self):
        self.step(0)
        self.server.agents.append(agent("p2"))
        self.server.screens["p2"] = SCREEN
        self.step(10)
        self.step(30)
        self.assertEqual(self.server.prompts, [("p1", "go")])
        self.step(40)
        self.assertEqual(self.server.prompts, [("p1", "go"), ("p2", "go")])


class SocketIntegrationTests(unittest.TestCase):
    def test_watcher_uses_socket_api_and_exits_when_plugin_disabled(self):
        import os
        import socket
        import threading

        # Keep AF_UNIX paths below macOS's 104-byte limit.
        with tempfile.TemporaryDirectory(dir="/tmp") as directory:
            endpoint = str(Path(directory) / "herdr.sock")
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.addCleanup(server.close)
            server.bind(endpoint)
            server.listen()
            server.settimeout(8)
            calls = []
            failures = []

            def serve():
                try:
                    for _ in range(3):
                        with server.accept()[0] as conn, conn.makefile("rwb") as stream:
                            request = json.loads(stream.readline())
                            calls.append(request["method"])
                            result = ({"agents": []} if request["method"] == "agent.list" else
                                      {"plugins": [{"plugin_id": retry.PLUGIN_ID, "enabled": len(calls) == 1}]})
                            stream.write((json.dumps({"id": request["id"], "result": result}) + "\n").encode())
                            stream.flush()
                except Exception as error:
                    failures.append(error)

            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            env = dict(os.environ, HERDR_SOCKET_PATH=endpoint, HERDR_PLUGIN_STATE_DIR=directory)
            result = subprocess.run([sys.executable, str(ROOT / "retry.py"), "--watch"],
                                    env=env, capture_output=True, text=True, timeout=10)
            thread.join(timeout=1)
            self.assertFalse(failures)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls, ["plugin.list", "agent.list", "plugin.list"])
            self.assertTrue(list(Path(directory).glob("sessions/*/status.json")))


if __name__ == "__main__":
    unittest.main()
