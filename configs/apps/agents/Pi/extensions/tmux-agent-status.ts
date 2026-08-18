// tmux-agent-status.ts — Update tmux window status with pi agent state
import { spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_SCRIPT = "/Users/jsc/bin/set_tmux_agent_status";
const SUBMARINE_SOUND = "/System/Library/Sounds/Submarine.aiff";
const FUNK_SOUND = "/System/Library/Sounds/Funk.aiff";

let currentStatus: string = "";

function runScript(args: string[]): Promise<void> {
  return new Promise((resolve) => {
    const child = spawn(args[0], args.slice(1), { stdio: "ignore" });
    child.on("close", () => resolve());
    child.on("error", () => resolve());
  });
}

async function setStatus(nextStatus: string) {
  if (currentStatus === nextStatus) return;
  currentStatus = nextStatus;

  await runScript([STATUS_SCRIPT, nextStatus]);

  if (nextStatus === "done") {
    await runScript(["afplay", SUBMARINE_SOUND]);
  } else if (nextStatus === "needs-input") {
    await runScript(["afplay", FUNK_SOUND]);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    await setStatus("ready");
  });

  pi.on("agent_start", async (_event, ctx) => {
    await setStatus("running");
  });

  pi.on("agent_settled", async (_event, ctx) => {
    await setStatus("done");
    setTimeout(() => setStatus("ready"), 2000);
  });

  pi.on("turn_start", async (_event, ctx) => {
    await setStatus("running");
  });

  pi.on("turn_end", async (_event, ctx) => {
    if (ctx.isIdle()) {
      await setStatus("done");
      setTimeout(() => setStatus("ready"), 2000);
    }
  });

  pi.on("message_start", async (event, ctx) => {
    if (event.message.role === "user") {
      await setStatus("running");
    }
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "question" || event.toolName === "permission") {
      await setStatus("needs-input");
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    await setStatus("");
  });
}