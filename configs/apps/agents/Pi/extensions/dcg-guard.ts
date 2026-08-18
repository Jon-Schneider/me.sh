// dcg-guard.ts — block destructive shell commands with dcg
// https://github.com/Dicklesworthstone/destructive_command_guard
import { spawn } from "node:child_process";

const DCG_BIN = process.env.DCG_BIN ?? "dcg";

function dcgDecision(command: string): Promise<{ deny: boolean; reason: string }> {
  return new Promise((resolve) => {
    const child = spawn(DCG_BIN, ["--robot", "test", command], {
      stdio: ["ignore", "pipe", "ignore"],
    });

    let stdout = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    // Fail open if dcg can't be found / spawned, so a broken install never
    // wedges Pi. Flip this to resolve({ deny: true, ... }) to fail closed.
    child.on("error", () => resolve({ deny: false, reason: "" }));

    child.on("close", (code) => {
      if (code === 1) {
        // Denied. The reason lives in the robot-mode JSON.
        let reason = "Blocked by dcg (destructive command).";
        try {
          const parsed = JSON.parse(stdout);
          if (parsed?.reason) reason = parsed.reason;
          if (parsed?.rule_id) reason += ` [${parsed.rule_id}]`;
        } catch {
          /* keep the default reason */
        }
        resolve({ deny: true, reason });
      } else {
        // 0 = allowed; >=3 = dcg error -> fail open.
        resolve({ deny: false, reason: "" });
      }
    });
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const command = String(event.input?.command ?? "");
    if (!command.trim()) return;

    const { deny, reason } = await dcgDecision(command);
    if (deny) {
      return { block: true, reason };
    }
  });
}