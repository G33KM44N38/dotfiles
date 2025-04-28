local function escape_json_string(str)
	return str:gsub('"', '\\"')
	    :gsub('\\', '\\\\')
	    :gsub('\n', '\\n')
	    :gsub('\r', '\\r')
	    :gsub('\t', '\\t')
	    :gsub('\b', '\\b') 
	    :gsub('\f', '\\f') 
end

local function parse_json(json_string)
	
	json_string = json_string:gsub('"([^"]+)"%s*:', "%1 =") 
	json_string = json_string:gsub('"%s*', "'")            
	json_string = json_string:gsub('"%s*', "'")            
	json_string = json_string:gsub('"%s*', "'")            
	json_string = json_string:gsub('false', "false")       
	json_string = json_string:gsub('true', "true")         
	json_string = json_string:gsub('null', "nil")          

	
	local func, err = load("return {" .. json_string .. "}")
	if not func then
		error("Error loading JSON: " .. err)
	end

	return func()
end

local preprompt = [[
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
-    Use imperative mood
-    Capitalize first letter
-    No period at the end of the summary
-    Use code block formatting for code or script references
-    Highlight key points with bullet points

**Tone and Style:**
-    Professional and technical
-    Clear and concise
-    Focus on the "what" and "why" of the changes
-    Avoid unnecessary technical jargon

**Example Template:**

type(scope): Brief, descriptive summary

Detailed explanation of changes
Changes include:
    • Specific feature 1
    • Specific feature 2
Motivation:
    • Reason for change
    • Expected improvement

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
]]

local function commit()
	
	local staged_files = vim.fn.systemlist("git diff --staged --name-only")
	if #staged_files == 0 then
		print("No staged files to commit.")
		return
	end

	
	local prompt = "Write a commit message for the following files:\n\n"
	local file_prompts = {}
	for _, file in ipairs(staged_files) do
		table.insert(file_prompts, file)
	end
	prompt = prompt .. table.concat(file_prompts, "\n") .. "\n"

	
	local json_payload = string.format(
		'{"model": "deepseek-r1:1.5b", "prompt": "%s", "system": "%s", "max_tokens": 100}',
		escape_json_string(prompt), escape_json_string(preprompt)
	)

	
	local api_endpoint = "http://localhost:11434/api/generate"
	local response = vim.fn.system("curl -X POST -H 'Content-Type: application/json' -d '" ..
		json_payload .. "' " .. api_endpoint)

	if vim.v.shell_error ~= 0 then
		print("Error calling API: " .. response)
		return
	end

	if response == "" then
		print("Error: Received empty response from API.")
		return
	end

	local decoded_response
	local success, err = pcall(function()
		decoded_response = parse_json(response)
	end)
	if not success then
		print("Error decoding JSON response: " .. err)
		return
	end

	
	if decoded_response.error then
		print("API Error: " .. decoded_response.error)
		return
	end

	
	print(decoded_response.response or "No response received.") 
end


vim.api.nvim_create_user_command("Commiter", function()
	commit()
end, {})


vim.api.nvim_set_keymap("n", "<leader>co", ":Commiter<CR>", { noremap = true, silent = true })
