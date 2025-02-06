#!/bin/bash

# Constants
THINKING_END_BALISE="</think>"
COMMIT_FILE_NAME="MESSAGE"
URL="http://localhost:11434/api/generate"
MODEL="deepseek-r1:1.5b"

# Function to read a file and return its content
read_file_content() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Error: $file file does not exist."
        exit 1
    fi
    content=$(<"$file")
    if [[ -z "$content" ]]; then
        echo "Error: $file file is empty."
        exit 1
    fi
    echo "$content"
}

# Read MESSAGE and PREPROMPT files
message=$(read_file_content "$COMMIT_FILE_NAME")
preprompt="
You are an AI assistant specialized in generating concise, informative Git commit messages. When presented with a set of changes, follow these guidelines:

**Commit Message Structure:**
1. Start with a clear, descriptive type and scope
   - Use conventional commit types: feat, fix, refactor, docs, chore, etc.
   - Include a specific scope if applicable (e.g., feat(neovim), refactor(scripts))

2. Write a brief summary line explaining the primary change

3. Provide a detailed description with:
   - Key changes
   - Motivation behind the changes
   - Specific improvements or additions

4. Optional sections:
   - List of new features
   - Reasoning for the changes
   - Potential impact on the system

**Formatting Rules:**
-  Use imperative mood
-  Capitalize first letter
-  No period at the end of the summary
-  Use code block formatting for code or script references
-  Highlight key points with bullet points

**Tone and Style:**
-  Professional and technical
-  Clear and concise
-  Focus on the "what" and "why" of the changes
-  Avoid unnecessary technical jargon

**Example Template:**

type(scope): Brief, descriptive summary

Detailed explanation of changes
Changes include:
	•	Specific feature 1
	•	Specific feature 2
Motivation:
	•	Reason for change
	•	Expected improvement

When generating the commit message:
1. Analyze the entire changeset
2. Identify the primary purpose of the changes
3. Extract key modifications
4. Explain the rationale behind the changes
5. Create a structured, informative message

Respond only with the commit message, following the guidelines above.

---

**Example Commit Message:**

feat(user): Add endpoint to update user bio

Introduce a new API endpoint for updating user bio in the user profile. This change enhances user personalization features by allowing users to modify their bio.

Key changes include:
	• Added POST /user/bio endpoint to update user bio
	• Implemented request and response models for bio updates
	• Updated Swagger documentation to reflect the new endpoint and its usage
	• Modified User model to include a bio field

Motivation:
	• Enable users to personalize their profiles with a bio
	• Improve user engagement and satisfaction by providing more customization options
"

# Construct JSON payload
json_data=$(jq -n --arg model "$MODEL" --arg prompt "$message" --arg system "$preprompt" \
    '{model: $model, prompt: $prompt, system: $system}')

# Send POST request
echo "Sending request to: $URL"
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json_data" "$URL")

# Check response status
status_code=$(echo "$response" | jq -r '.status_code // empty')
if [[ "$status_code" != "200" ]]; then
    echo "Error: received status code $status_code"
    exit 1
fi

# Process the response
echo "Response received:"
finish_thinking=false

# Read response chunks
echo "$response" | jq -c '.response' | while read -r res; do
    if [[ "$finish_thinking" == true ]]; then
        echo -n "$res"
    elif [[ "$res" == *"$THINKING_END_BALISE"* ]]; then
        finish_thinking=true
        echo -n "$res"
    else
        echo -n "Thinking..."
        echo -ne "\r"
    fi
done

echo
