import { runAppleScript } from "run-applescript";

export const openArcWebsite = async (url: string): Promise<void> => {
  try {
    await runAppleScript(`
      set websiteURL to "${url}"
      
      tell application "System Events"
        if not (exists (processes where name is "Arc")) then
          do shell script "open -a Arc " & quoted form of websiteURL
        else
          tell application "Arc"
            activate
            if (count of windows) is 0 then
              make new window
              tell front window
                make new tab with properties {URL:websiteURL}
              end tell
            else
              set found to false
              repeat with w in windows
                repeat with t in tabs of w
                  if URL of t contains websiteURL then
                    set found to true
                    set index of w to 1
                    tell w
                      set active tab index to index of t
                    end tell
                    exit repeat
                  end if
                end repeat
                if found then exit repeat
              end repeat
              
              if not found then
                tell front window
                  make new tab with properties {URL:websiteURL}
                end tell
              end if
            end if
          end tell
        end if
      end tell
    `);
  } catch (error) {
    console.error("Error in openArcWebsite:", error);
    throw error;
  }
};
