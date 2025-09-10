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
    let message = "OpenCode finished"
    let details = []
    
    // Extract the most recent completed task with specific details
    if (shared?.task_progress) {
      const { completed_tasks, total_tasks, current_task, recent_completions } = shared.task_progress
      
      // Get the most recently completed task
      if (recent_completions && recent_completions.length > 0) {
        const lastTask = recent_completions[recent_completions.length - 1]
        message = `OpenCode completed task: ${lastTask}`
      } else if (current_task && current_task !== 'Task description') {
        message = `OpenCode completed: ${current_task}`
      }
      
      // Add progress context
      if (total_tasks > 0) {
        details.push(`${completed_tasks} of ${total_tasks} tasks done`)
      }
    }
    
    // Get specific file operations from session messages
    let fileOperations = []
    if (session?.messages) {
      const lastFewMessages = session.messages.slice(-10) // Check last 10 messages
      
      for (const msg of lastFewMessages) {
        if (msg.role === 'assistant' && msg.tool_calls) {
          for (const toolCall of msg.tool_calls) {
            const toolName = toolCall.function?.name || toolCall.name
            const args = toolCall.function?.arguments ? JSON.parse(toolCall.function.arguments) : toolCall.arguments
            
            switch (toolName) {
              case 'Edit':
              case 'MultiEdit':
                if (args?.file_path) {
                  const fileName = args.file_path.split('/').pop()
                  fileOperations.push(`edited ${fileName}`)
                }
                break
              case 'Write':
                if (args?.file_path) {
                  const fileName = args.file_path.split('/').pop()
                  fileOperations.push(`created ${fileName}`)
                }
                break
              case 'Bash':
                if (args?.description) {
                  fileOperations.push(`ran: ${args.description}`)
                } else if (args?.command) {
                  const cmd = args.command.split(' ')[0]
                  fileOperations.push(`executed ${cmd}`)
                }
                break
              case 'TodoWrite':
                fileOperations.push('updated task list')
                break
            }
          }
        }
      }
    }
    
    // Add file operations to details
    if (fileOperations.length > 0) {
      // Remove duplicates and limit to last 3 operations
      const uniqueOps = [...new Set(fileOperations)].slice(-3)
      details.push(`Actions: ${uniqueOps.join(', ')}`)
    }
    
    // Look for test results
    if (shared?.tests_run) {
      const { passed = 0, failed = 0 } = shared.tests_run
      if (passed > 0 || failed > 0) {
        details.push(`Tests: ${passed} passed, ${failed} failed`)
      }
    }
    
    // Add commit or git operations
    if (fileOperations.some(op => op.includes('git') || op.includes('commit'))) {
      details.push('committed changes')
    }
    
    // Feature-specific context
    if (session?.feature && session.feature !== 'feature-name-placeholder') {
      details.unshift(`Feature: ${session.feature}`)
    }
    
    // Agent context
    if (session?.current_agent && session.current_agent !== 'none') {
      details.unshift(`Agent: ${session.current_agent}`)
    }
    
    // Build final message
    if (details.length > 0) {
      message += `. ${details.join('. ')}`
    }
    
    // Ensure message isn't too long for TTS
    if (message.length > 200) {
      message = message.substring(0, 197) + '...'
    }
    
    return message
  }

  const readLastResponse = async () => {
    try {
      // Try to get the last assistant message from session state
      const sessionPath = '.opencode/state/session.json'
      if (!existsSync(sessionPath)) return
      
      const session = JSON.parse(readFileSync(sessionPath, 'utf8'))
      const messages = session.messages || []
      
      // Find the last assistant message
      const lastAssistantMessage = messages
        .slice()
        .reverse()
        .find((msg: any) => msg.role === 'assistant' && msg.content?.length > 0)
      
      if (lastAssistantMessage && lastAssistantMessage.content) {
        // Clean up the content for TTS (remove markdown, code blocks, etc.)
        let content = lastAssistantMessage.content
        content = content.replace(/```[\s\S]*?```/g, '[code block]') // Replace code blocks
        content = content.replace(/`[^`]*`/g, '[code]') // Replace inline code
        content = content.replace(/\*\*(.*?)\*\*/g, '$1') // Remove bold
        content = content.replace(/\*(.*?)\*/g, '$1') // Remove italic
        content = content.replace(/#{1,6}\s/g, '') // Remove headers
        content = content.replace(/\n+/g, '. ') // Replace newlines with periods
        content = content.substring(0, 500) // Limit length for TTS
        
        if (content.trim()) {
          await $`say "${content}"`
        }
      }
    } catch (error) {
      console.log('Could not read last response:', error)
    }
  }

  return {
    event: async ({ event }: { event: Event }) => {
      // Only send notifications on session completion
      if (event.type === "session.idle") {
        const stateInfo = getStateInfo()
        const message = createDetailedMessage(stateInfo)
        
        // Voice notification with detailed context
        await $`say "${message}"`
        
        // Optionally read the last response too (uncomment to enable)
        // await readLastResponse()
        
        // Send macOS notification
        // const subtitle = stateInfo?.session?.current_phase || 'Development'
        // await $`osascript -e 'display notification "${message}" with title "OpenCode" subtitle "${subtitle}"'`
      }
    },
    
    // Expose commands for manual use
    commands: {
      'read-response': async () => {
        await readLastResponse()
      },
      'session-summary': async () => {
        const stateInfo = getStateInfo()
        const message = createDetailedMessage(stateInfo)
        await $`say "${message}"`
        console.log(message)
      }
    }
  }
}
