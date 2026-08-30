/**
 * issue-pane-title — pi's half of the agent-issue-hook wiring.
 *
 * Claude Code and Codex reach ~/bin/agent-issue-hook through their own
 * UserPromptSubmit hooks; pi has no equivalent, so this extension feeds
 * before_agent_start's prompt to the same script in the same payload shape.
 * All detection and classification lives there, not here.
 *
 * Fire-and-forget: the script's own fast path returns immediately and does the
 * slow work detached, so nothing is awaited and nothing is injected into the
 * turn.
 */

import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HOOK = `${process.env.HOME}/bin/agent-issue-hook`;

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", (event, ctx) => {
		let child;
		try {
			child = spawn(HOOK, { stdio: ["pipe", "ignore", "ignore"], detached: true });
		} catch {
			return; // hook not installed on this machine
		}
		child.on("error", () => {});
		child.unref();
		child.stdin?.on("error", () => {});
		child.stdin?.end(
			JSON.stringify({
				hook_event_name: "UserPromptSubmit",
				prompt: event.prompt,
				session_id: ctx.sessionManager.getSessionId(),
				cwd: ctx.cwd,
			}),
		);
	});
}
