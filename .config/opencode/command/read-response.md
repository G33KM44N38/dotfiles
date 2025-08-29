# Read Response

Read the last assistant response out loud using text-to-speech.

```bash
# Get the last assistant message from session state
session_file=".opencode/state/session.json"

if [ ! -f "$session_file" ]; then
    echo "No session file found"
    exit 1
fi

# Extract last assistant message and clean it for TTS
content=$(jq -r '
    .messages // [] | 
    map(select(.role == "assistant" and (.content | length) > 0)) |
    last |
    .content // empty
' "$session_file" 2>/dev/null)

if [ -z "$content" ]; then
    echo "No assistant response found"
    exit 1
fi

# Clean up content for TTS
cleaned_content=$(echo "$content" | \
    sed 's/```[^`]*```/[code block]/g' | \
    sed 's/`[^`]*`/[code]/g' | \
    sed 's/\*\*\([^*]*\)\*\*/\1/g' | \
    sed 's/\*\([^*]*\)\*/\1/g' | \
    sed 's/^#{1,6} //g' | \
    tr '\n' '.' | \
    sed 's/\.\+/. /g' | \
    cut -c1-500)

if [ -n "$cleaned_content" ]; then
    echo "Reading response..."
    say "$cleaned_content"
else
    echo "No content to read"
fi
```