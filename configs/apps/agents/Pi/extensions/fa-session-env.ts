/**
 * fa-session-env — make `fa` work frictionlessly from pi's `!` bang commands.
 *
 * Why: pi 0.84.2 has a bug where the interactive agent loop never passes the
 * tool ctx, so bash tools (and `!` commands) never receive PI_SESSION_ID —
 * even though the docs promise it. `fa` therefore can't tell WHICH session
 * to fork and refuses when several exist for the cwd.
 *
 * Fix: intercept the `user_bash` event, and when the command invokes `fa`,
 * prepend the TUI's own session identity (PI_SESSION_ID / PI_SESSION_FILE)
 * to the command line. `fa` picks it up like any other env var, so
 * `!fa` forks THIS session — no id pasting, no guessing.
 *
 * Scope (deliberately narrow):
 *   - only `!` / `!!` commands (user_bash), not agent bash tool calls
 *   - only when the first simple command is `fa` (leading VAR=val assignments
 *     are fine, so `!FA_DEBUG=1 fa` works too)
 *   - skipped if the command already sets PI_SESSION_ID (explicit override wins)
 *   - skipped for ephemeral sessions (no id)
 *
 * Debug:  !FA_DEBUG=1 fa   → should print  agent=pi  and  pi --fork <this session id>
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createLocalBashOperations } from "@earendil-works/pi-coding-agent";

/** Matches `fa` as the first simple command, after any leading VAR=val assignments. */
const LEADING_ENV_ASSIGNMENTS = /^(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|[^\s]*)\s+)*/;

function isFaInvocation(command: string): boolean {
	return /^fa(?:\s|$)/.test(command.replace(LEADING_ENV_ASSIGNMENTS, ""));
}

export default function (pi: ExtensionAPI) {
	const local = createLocalBashOperations();

	pi.on("user_bash", (event, ctx) => {
		const command = event.command.trim();
		if (!isFaInvocation(command)) return;

		const sessionId = ctx.sessionManager.getSessionId();
		if (!sessionId) return; // ephemeral session — nothing to inject

		// Explicit override in the command line wins; don't touch it.
		if (/PI_SESSION_ID=/.test(command)) return;

		const sessionFile = ctx.sessionManager.getSessionFile() ?? "";
		const prefix = `PI_SESSION_ID='${sessionId}' PI_SESSION_FILE='${sessionFile.replace(/'/g, `'\\''`)}'`;

		return {
			operations: {
				exec: (cmd, cwd, options) => local.exec(`${prefix} ${cmd}`, cwd, options),
			},
		};
	});
}
