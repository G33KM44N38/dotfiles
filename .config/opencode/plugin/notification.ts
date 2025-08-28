import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import type { Event } from "@opencode-ai/sdk"
import { readFileSync, existsSync } from "fs"

export const NotificationPlugin: Plugin = async ({ client, $ }: PluginInput) => {
  console.log("Plugin initialized!")
  
  const getStateInfo = () => {
    try {
      const sessionPath = '.opencode/state/session.json'
      const sharedPath = '.opencode/state/shared.json'
      const taskQueuePath = '.opencode/state/workflow/task-queue.json'
      
      const session = existsSync(sessionPath) ? 
        JSON.parse(readFileSync(sessionPath, 'utf8')) : null
      const shared = existsSync(sharedPath) ? 
        JSON.parse(readFileSync(sharedPath, 'utf8')) : null
      const taskQueue = existsSync(taskQueuePath) ? 
        JSON.parse(readFileSync(taskQueuePath, 'utf8')) : null
        
      return { session, shared, taskQueue }
    } catch (error) {
      console.log('Could not read state files:', error)
      return null
    }
  }

  const createDetailedMessage = (stateInfo: any) => {
    if (!stateInfo) {
      return "OpenCode session completed - waiting for user"
    }
    
    const { session, shared, taskQueue } = stateInfo
    
    // Feature-specific notification
    if (session?.feature && session.feature !== 'feature-name-placeholder') {
      return `OpenCode completed: ${session.feature}`
    }
    
    // Task progress notification
    if (shared?.task_progress) {
      const { completed_tasks, total_tasks, current_task } = shared.task_progress
      if (total_tasks > 0) {
        return `OpenCode: ${completed_tasks} of ${total_tasks} tasks completed`
      }
      if (current_task && current_task !== 'Task description') {
        return `OpenCode completed: ${current_task}`
      }
    }
    
    // Phase-specific notification
    if (session?.current_phase && session.current_phase !== 'planning') {
      return `OpenCode: ${session.current_phase} phase completed`
    }
    
    // Agent-specific notification
    if (session?.current_agent && session.current_agent !== 'none') {
      return `OpenCode: ${session.current_agent} finished work`
    }
    
    return "OpenCode session completed - waiting for user"
  }

  return {
    event: async ({ event }: { event: Event }) => {
      // Only send notifications on session completion
      if (event.type === "session.idle") {
        const stateInfo = getStateInfo()
        const message = createDetailedMessage(stateInfo)
        
        // Voice notification with detailed context
        await $`say "${message}"`
        
        // Send macOS notification
        const subtitle = stateInfo?.session?.current_phase || 'Development'
        await $`osascript -e 'display notification "${message}" with title "OpenCode" subtitle "${subtitle}"'`
      }
    },
  }
}
