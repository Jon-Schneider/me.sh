// tmux-agent-status.ts — Update tmux window status with pi agent state
//
// Drives the @agent_status window option (via ~/bin/set_tmux_agent_status,
// the same chokepoint the Claude Code / Codex hooks use) which the tmux
// window-status formats render as `#I:#W [status]`.
//
// States: ready, running, running-tool, needs-input, done, "" (cleared)
import { execFileSync, spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_SCRIPT = "/Users/jsc/bin/set_tmux_agent_status";
const SUBMARINE_SOUND = "/System/Library/Sounds/Submarine.aiff";
const FUNK_SOUND = "/System/Library/Sounds/Funk.aiff";

let currentStatus: string = "";
let readyTimer: ReturnType<typeof setTimeout> | null = null;

function runScript(args: string[]): Promise<void> {
  return new Promise((resolve) => {
    const child = spawn(args[0], args.slice(1), { stdio: "ignore" });
    child.on("close", () => resolve());
    child.on("error", () => resolve());
  });
}

function isRunningStatus(status: string): boolean {
  return status === "running" || status === "running-tool";
}

async function setStatus(nextStatus: string) {
  if (currentStatus === nextStatus) return;
  currentStatus = nextStatus;

  // A new run supersedes any pending done->ready fallback.
  if (isRunningStatus(nextStatus) && readyTimer) {
    clearTimeout(readyTimer);
    readyTimer = null;
  }

  await runScript([STATUS_SCRIPT, nextStatus]);

  if (nextStatus === "done") {
    readyTimer = setTimeout(() => {
      readyTimer = null;
      void setStatus("ready");
    }, 2000);
    await runScript(["afplay", SUBMARINE_SOUND]);
  } else if (nextStatus === "needs-input") {
    await runScript(["afplay", FUNK_SOUND]);
  }
}

export default function (pi: ExtensionAPI) {
  function guard(handler: (ctx: ExtensionContext) => void) {
    return async (_event: unknown, ctx: ExtensionContext) => {
      handler(ctx);
    };
  }

  pi.on("session_start", guard(() => void setStatus("ready")));

  pi.on("before_agent_start", guard(() => void setStatus("running")));
  pi.on("agent_start", guard(() => void setStatus("running")));
  pi.on("turn_start", guard(() => void setStatus("running")));
  pi.on("message_start", async (event) => {
    if (event.message.role === "user") await setStatus("running");
  });

  pi.on("tool_execution_start", guard(() => void setStatus("running-tool")));
  pi.on("tool_execution_end", guard(() => void setStatus("running")));

  pi.on("tool_call", async (event) => {
    if (event.toolName === "question" || event.toolName === "permission") {
      await setStatus("needs-input");
    }
  });

  pi.on("agent_settled", guard((ctx) => {
    if (!ctx.isIdle()) return; // another run already took over
    void setStatus("done");
  }));

  pi.on("turn_end", guard((ctx) => {
    if (ctx.isIdle()) void setStatus("done");
  }));

  pi.on("session_shutdown", guard(() => {
    currentStatus = "";
    if (readyTimer) {
      clearTimeout(readyTimer);
      readyTimer = null;
    }
    // Synchronous so the clear lands before the process exits (the async
    // spawn path can be cut off by exit).
    const pane = process.env.TMUX_PANE;
    if (!pane) return;
    try {
      execFileSync("tmux", ["set-window-option", "-q", "-t", pane, "@agent_status", ""], {
        stdio: "ignore",
      });
    } catch {
      // tmux unavailable/dying — nothing to clear.
    }
  }));
}
