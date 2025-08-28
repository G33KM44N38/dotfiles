import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import type { Event } from "@opencode-ai/sdk"

export const NotificationPlugin: Plugin = async ({ client, $ }: PluginInput) => {
  console.log("Plugin initialized!")
  return {
    event: async ({ event }: { event: Event }) => {
      $`say "task complete waiting for the user"`
      // Send notification on session completion
      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "Session completed!" with title "opencode"'`
      }
    },
  }
}
