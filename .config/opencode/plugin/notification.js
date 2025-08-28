// import type { Plugin } from "@opencode-ai/plugin"

export const NotificationPlugin = async ({ client, $ }) => {

  console.log("Plugin initialized!")
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`say "task complete waiting for the user"`
      }
    },
  }
}
