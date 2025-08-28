export const NotificationPlugin = async ({ client, $ }) => {
    console.log("Plugin initialized!");
    return {
        event: async ({ event }) => {
            $ `say "task complete waiting for the user"`;
            // Send notification on session completion
            if (event.type === "session.idle") {
                await $ `osascript -e 'display notification "Session completed!" with title "opencode"'`;
            }
        },
    };
};
