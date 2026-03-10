const STATUS_SCRIPT = "/Users/jsc/bin/set_tmux_agent_status";

export const TmuxAgentStatusPlugin = async ({ $ }) => {
  let currentStatus;

  const setStatus = async (nextStatus) => {
    if (currentStatus === nextStatus) {
      return;
    }

    currentStatus = nextStatus;
    await $`${STATUS_SCRIPT} ${nextStatus}`.quiet().nothrow();
  };

  await setStatus("ready");

  return {
    async "chat.message"() {
      await setStatus("running");
    },

    async event({ event }) {
      switch (event.type) {
        case "server.connected":
        case "session.created":
          await setStatus("ready");
          break;

        case "permission.asked":
        case "question.asked":
          await setStatus("needs-input");
          break;

        case "session.status":
          if (event.properties.status.type === "busy" || event.properties.status.type === "retry") {
            await setStatus("running");
            break;
          }

          if (event.properties.status.type === "idle") {
            await setStatus("done");
          }
          break;

        case "session.idle":
          await setStatus("done");
          break;

        case "tui.prompt.append":
          await setStatus("ready");
          break;

        case "server.instance.disposed":
        case "global.disposed":
          await setStatus("");
          break;
      }
    },
  };
};
