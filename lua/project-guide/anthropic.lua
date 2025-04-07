local M = {}
local curl = require("plenary.curl")
local config = require("project-guide.config")
local scan = require("plenary.scandir")

-- Function to make a request to the Anthropic API
function M.generate_suggestions()
  -- Get API key from config or environment variable
  local api_key = config.options.anthropic and config.options.anthropic.api_key

  -- If not in config, try to get from environment variable
  if not api_key or api_key == "" then
    api_key = vim.env.ANTHROPIC_API_KEY
  end

  -- Check if API key is available
  if not api_key or api_key == "" then
    return {
      "Error: Anthropic API key not configured.",
      "Either:",
      "1. Set ANTHROPIC_API_KEY environment variable, or",
      "2. Add your API key in the setup function:",
      "   require('project-guide').setup({",
      "     anthropic = {",
      "       api_key = 'your-api-key-here',",
      "     }",
      "   })",
    }
  end

  -- Get project context and check if config file exists
  local has_config_file, project_context = M.get_project_context()

  -- Disable suggestions if no config file exists
  if not has_config_file and not config.options.enable_suggestions_without_config then
    return {
      "Suggestions are disabled for this project.",
      "Create a .project-guide.lua or .project-guide.json file to enable them.",
      "",
      "You can also enable suggestions globally without config files by adding:",
      "require('project-guide').setup({",
      "  enable_suggestions_without_config = true",
      "})",
    }
  end

  -- Check if we should use Claude Code CLI instead of API
  if config.options.anthropic and config.options.anthropic.use_claude_cli then
    vim.notify("Using Claude Code CLI to fetch suggestions", vim.log.levels.DEBUG)
    return M.generate_suggestions_with_claude_cli()
  end

  vim.notify("Fetching suggestions", vim.log.levels.DEBUG)

  -- Prepare the prompt for Claude based on project type
  local prompt = [[
  You are helping a developer who is working on a project. Based on the context of their current project,
  suggest 10 potential next steps or features they could implement.

  Format your response as a numbered list with brief, actionable suggestions.
  Each suggestion should be concise (one line) and directly relevant to improving or extending their project.

  Example format:
  1. Add feature X to improve Y
  2. Implement Z functionality for better user experience

  Keep suggestions practical and specific to the type of project they're working on.
  Focus on what would be most valuable for them to work on next.

  Here is the context of the current project:
  ]] .. project_context

  -- Make the API request
  local response = curl.post("https://api.anthropic.com/v1/messages", {
    headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = api_key,
      ["anthropic-version"] = "2023-06-01",
    },
    body = vim.fn.json_encode({
      model = config.options.anthropic.model or "claude-3-5-haiku-20241022",
      max_tokens = 1024,
      messages = {
        {
          role = "user",
          content = prompt,
        },
      },
    }),
  })

  -- Handle the response
  if response.status ~= 200 then
    return {
      "Error connecting to Anthropic API: " .. (response.status or "unknown error"),
      "Check your API key and internet connection.",
    }
  end

  -- Parse the response
  local success, result = pcall(vim.fn.json_decode, response.body)
  if not success or not result or not result.content or #result.content == 0 then
    return {
      "Error parsing Anthropic API response.",
      "Response may be malformed or empty.",
    }
  end

  -- Extract the suggestions from the response
  local content = result.content[1].text
  local suggestions = {}

  -- Process the response into individual lines
  for line in content:gmatch("[^\r\n]+") do
    -- Only include lines that look like numbered suggestions
    if line:match("^%d+%.") then
      table.insert(suggestions, line)
    end
  end

  -- If we couldn't extract suggestions, return an error
  if #suggestions == 0 then
    return {
      "No valid suggestions found in the Anthropic API response.",
      "Try again later or check your API configuration.",
    }
  end

  -- Limit to 10 suggestions if we got more
  if #suggestions > 10 then
    local limited = {}
    for i = 1, 10 do
      table.insert(limited, suggestions[i])
    end
    suggestions = limited
  end

  vim.notify("Suggestions fetched", vim.log.levels.DEBUG)

  return suggestions
end

-- Function to generate suggestions using Claude Code CLI
function M.generate_suggestions_with_claude_cli()
  -- Check if claude executable is available
  local claude_path = config.options.anthropic.claude_path or "claude"
  local handle = io.popen("which " .. claude_path .. " 2>/dev/null")
  local result = handle:read("*a")
  handle:close()

  if result == "" then
    return {
      "Error: Claude Code CLI not found in PATH.",
      "Please install Claude Code CLI or specify its path in the config:",
      "require('project-guide').setup({",
      "  anthropic = {",
      "    use_claude_cli = true,",
      "    claude_path = '/path/to/claude',",
      "  }",
      "})",
    }
  end

  -- Prepare the prompt for Claude (as a single line to avoid newline issues)
  local prompt =
  "Generate 10 potential next steps or features for this project. Format as a numbered list with brief, actionable suggestions. Each suggestion should be concise (one line) and directly relevant. Only output the numbered list with no additional text."

  local command = claude_path .. ' --print "' .. prompt .. '"'

  local claude_output = ""
  local success = false

  -- Run the command and capture the output
  claude_output = vim.fn.system(command)

  vim.notify("Suggestions fetched", vim.log.levels.DEBUG)

  -- Check if the command succeeded (no error in output)
  if
      not claude_output:match("error:")
      and not claude_output:match("Error:")
      and not claude_output:match("usage:")
  then
    success = true
  end

  if not success then
    return { "Failed to generate suggestions using Claude CLI", claude_output }
  end

  -- Process the response into individual lines
  local suggestions = {}
  for line in claude_output:gmatch("[^\r\n]+") do
    -- Only include lines that look like numbered suggestions
    if line:match("^%d+%.") then
      table.insert(suggestions, line)
    end
  end

  -- If we couldn't extract suggestions, try a more direct approach as a last resort
  if #suggestions == 0 and not success then
    -- Fall back to direct pipe
    vim.notify("Trying direct pipe to Claude", vim.log.levels.DEBUG)
    local cmd = "printf '" .. prompt:gsub("'", "'\\''") .. "' | " .. claude_path
    -- Use vim.fn.system instead of io.popen to avoid prompts
    claude_output = vim.fn.system(cmd)

    -- Process the response again
    for line in claude_output:gmatch("[^\r\n]+") do
      if line:match("^%d+%.") then
        table.insert(suggestions, line)
      end
    end
  end

  -- If we still couldn't extract suggestions, return an error
  if #suggestions == 0 then
    -- Replace newlines with spaces to avoid buffer errors
    local safe_output = claude_output:gsub("\n", " "):gsub("\r", " ")

    -- Check if we got any output at all
    if safe_output:match("^%s*$") then
      return {
        "No output received from Claude CLI.",
        "Please check that Claude Code CLI is installed correctly and try again.",
      }
    else
      return {
        "No valid suggestions found in the Claude CLI output.",
        "Raw output: " .. safe_output:sub(1, 100) .. (safe_output:len() > 100 and "..." or ""),
      }
    end
  end

  -- Limit to 10 suggestions if we got more
  if #suggestions > 10 then
    local limited = {}
    for i = 1, 10 do
      table.insert(limited, suggestions[i])
    end
    suggestions = limited
  end

  return suggestions
end

-- Function to get project context dynamically
function M.get_project_context()
  local context = {}
  local has_config_file = false

  local root_dir = vim.fn.getcwd()

  -- Check if project has a project-guide config file
  local config_files = {
    root_dir .. "/.project-guide.lua", -- Prefer Lua format (native to Neovim)
    root_dir .. "/.project-guide.json", -- JSON as fallback
  }

  local project_config = nil
  for _, config_path in ipairs(config_files) do
    if vim.fn.filereadable(config_path) == 1 then
      has_config_file = true
      if config_path:match("%.json$") then
        local file = io.open(config_path, "r")
        if file then
          local content = file:read("*all")
          file:close()
          local success, decoded = pcall(vim.fn.json_decode, content)
          if success then
            project_config = decoded
          else
            vim.notify("Failed to parse JSON config: " .. config_path, vim.log.levels.WARN)
          end
        end
      elseif config_path:match("%.lua$") then
        -- Load Lua config file
        local success, result = pcall(dofile, config_path)
        if success then
          project_config = result
        else
          vim.notify("Failed to load Lua config: " .. config_path, vim.log.levels.WARN)
        end
      end
      break
    end
  end

  -- If we have a project config with a description, use it
  if project_config and project_config.description then
    table.insert(context, "PROJECT DESCRIPTION:")
    table.insert(context, project_config.description)
    table.insert(context, "")
  else
    -- Try to infer project type and add a generic description
    table.insert(context, "PROJECT DESCRIPTION:")

    -- Check for common project identifiers
    local is_node = vim.fn.filereadable(root_dir .. "/package.json") == 1
    local is_python = vim.fn.filereadable(root_dir .. "/setup.py") == 1
        or vim.fn.filereadable(root_dir .. "/pyproject.toml") == 1
    local is_rust = vim.fn.filereadable(root_dir .. "/Cargo.toml") == 1
    local is_go = vim.fn.filereadable(root_dir .. "/go.mod") == 1
    local is_ruby = vim.fn.filereadable(root_dir .. "/Gemfile") == 1
    local is_java = vim.fn.glob(root_dir .. "/**/*.java", false, true)[1] ~= nil
    local is_cpp = vim.fn.glob(root_dir .. "/**/*.cpp", false, true)[1] ~= nil
        or vim.fn.glob(root_dir .. "/**/*.hpp", false, true)[1] ~= nil
    local is_c = vim.fn.glob(root_dir .. "/**/*.c", false, true)[1] ~= nil
        or vim.fn.glob(root_dir .. "/**/*.h", false, true)[1] ~= nil
    local is_lua = vim.fn.glob(root_dir .. "/**/*.lua", false, true)[1] ~= nil

    -- Add project type to description
    if is_node then
      table.insert(context, "This appears to be a JavaScript/Node.js project.")
    elseif is_python then
      table.insert(context, "This appears to be a Python project.")
    elseif is_rust then
      table.insert(context, "This appears to be a Rust project.")
    elseif is_go then
      table.insert(context, "This appears to be a Go project.")
    elseif is_ruby then
      table.insert(context, "This appears to be a Ruby project.")
    elseif is_java then
      table.insert(context, "This appears to be a Java project.")
    elseif is_cpp then
      table.insert(context, "This appears to be a C++ project.")
    elseif is_c then
      table.insert(context, "This appears to be a C project.")
    elseif is_lua then
      table.insert(context, "This appears to be a Lua project.")
    else
      table.insert(context, "This is a software development project.")
    end
    table.insert(context, "")
  end

  -- Get file structure (limit to certain file types and max files)
  table.insert(context, "PROJECT STRUCTURE:")

  -- Define file patterns to include based on project type or config
  local include_patterns = project_config and project_config.include_patterns
      or {
        "%.lua$",
        "%.js$",
        "%.ts$",
        "%.py$",
        "%.go$",
        "%.rs$",
        "%.java$",
        "%.c$",
        "%.h$",
        "%.cpp$",
        "%.hpp$",
        "%.rb$",
        "%.ex$",
        "%.exs$",
      }

  -- Define patterns to exclude
  local exclude_dirs = project_config and project_config.exclude_dirs
      or {
        "node_modules",
        "dist",
        "build",
        "target",
        "venv",
        ".git",
        "__pycache__",
        ".pytest_cache",
        ".vscode",
        ".idea",
      }

  -- Scan directory with limited depth
  local max_depth = project_config and project_config.max_depth or 3
  local max_files = project_config and project_config.max_files or 50

  local files = scan.scan_dir(root_dir, {
    hidden = false,
    depth = max_depth,
    add_dirs = false,
    respect_gitignore = true,
  })

  -- Filter files based on patterns and exclusions
  local filtered_files = {}
  for _, file in ipairs(files) do
    local rel_path = file:gsub("^" .. vim.pesc(root_dir) .. "/", "")

    -- Check if file should be excluded (in excluded directory)
    local exclude = false
    for _, exclude_dir in ipairs(exclude_dirs) do
      if rel_path:match("^" .. exclude_dir .. "/") then
        exclude = true
        break
      end
    end

    -- Check if file matches include patterns
    local include = false
    if not exclude then
      for _, pattern in ipairs(include_patterns) do
        if rel_path:match(pattern) then
          include = true
          break
        end
      end
    end

    if include then
      table.insert(filtered_files, rel_path)
    end
  end

  -- Sort and limit files
  table.sort(filtered_files)
  if #filtered_files > max_files then
    filtered_files = vim.list_slice(filtered_files, 1, max_files)
    table.insert(filtered_files, "... and more files (truncated)")
  end

  -- Add file list to context
  for _, file in ipairs(filtered_files) do
    table.insert(context, "- " .. file)
  end
  table.insert(context, "")

  -- Try to get README content for more context
  local readme_paths = {
    root_dir .. "/README.md",
    root_dir .. "/README",
    root_dir .. "/readme.md",
    root_dir .. "/Readme.md",
  }

  for _, readme_path in ipairs(readme_paths) do
    if vim.fn.filereadable(readme_path) == 1 then
      local readme_file = io.open(readme_path, "r")
      if readme_file then
        local readme_content = readme_file:read("*all")
        readme_file:close()

        -- Extract a summary from the README (first few lines or all if unlimited)
        local readme_lines = {}
        local line_count = 0
        local max_lines = project_config and project_config.max_readme_lines or 15
        local unlimited = max_lines == 0 or max_lines == "unlimited" or max_lines == "inf"

        for line in readme_content:gmatch("[^\r\n]+") do
          -- Skip empty lines and markdown headers at the beginning
          if line_count > 0 or (line ~= "" and not line:match("^#")) then
            table.insert(readme_lines, line)
            line_count = line_count + 1
            if not unlimited and line_count >= max_lines then
              break
            end
          end
        end

        if #readme_lines > 0 then
          table.insert(context, "README SUMMARY:")
          for _, line in ipairs(readme_lines) do
            table.insert(context, line)
          end
          table.insert(context, "")
        end

        break -- Stop after finding first README
      end
    end
  end

  -- Join all context elements with newlines
  return has_config_file, table.concat(context, "\n")
end

-- Function to format suggestions with a header
function M.get_formatted_suggestions()
  local result = {
    "",
    "--- Suggested Next Steps (via Claude AI) ---",
    "--- Press <Enter> or 'e' on a suggestion for a markdown-formatted explanation ---",
    "",
  }

  -- Try to get suggestions from the API
  local suggestions = M.generate_suggestions()

  -- Add each suggestion to the result
  for _, suggestion in ipairs(suggestions) do
    table.insert(result, suggestion)
  end

  return result
end

-- Function to get a detailed explanation of a suggestion
function M.explain_suggestion(suggestion)
  -- Disable 'more' setting to prevent "Press ENTER" prompts
  local saved_more = vim.opt.more:get()
  vim.opt.more = false

  -- Also disable notifying messages from command line
  local saved_cmdheight = vim.opt.cmdheight:get()
  vim.opt.cmdheight = 0

  -- Prepare prompt for explanation
  local prompt = [[I have the following suggestion for a software project: ]]
      .. suggestion
      .. [[.

Please provide a detailed explanation of:
1. Why this suggestion is valuable
2. How I might implement it
3. What specific benefits it would bring
4. Any potential challenges or considerations

Format your response in Markdown with:
- Clear section headers using ## headings
- Code examples in code blocks (using 3 backticks) where appropriate
- Bullet points and numbered lists where relevant
- Bold and italic text for emphasis

Your explanation should be well-structured with proper Markdown formatting.]]

  local explanation

  -- Check which method to use
  if vim.tbl_get(require("project-guide.config").options, "anthropic", "use_claude_cli") then
    -- Use Claude CLI
    local claude_path = vim.tbl_get(require("project-guide.config").options, "anthropic", "claude_path") or "claude"

    -- Escape backticks and other special shell characters for CLI usage
    local escaped_prompt = prompt:gsub("(['\"`$\\])", "\\%1")
    local command = claude_path .. ' --print "' .. escaped_prompt .. '"'

    local output = vim.fn.system(command)

    -- Process the output into lines
    explanation = {}
    for line in output:gmatch("[^\r\n]+") do
      table.insert(explanation, line)
    end
  else
    -- Use API if configured
    local api_key = vim.tbl_get(require("project-guide.config").options, "anthropic", "api_key")
    if not api_key or api_key == "" then
      api_key = vim.env.ANTHROPIC_API_KEY
    end

    if not api_key or api_key == "" then
      return {
        "Error: Anthropic API key not configured.",
        "Please configure your API key to get detailed explanations.",
      }
    end

    -- Make the API request
    local curl = require("plenary.curl")
    local response = curl.post("https://api.anthropic.com/v1/messages", {
      headers = {
        ["Content-Type"] = "application/json",
        ["x-api-key"] = api_key,
        ["anthropic-version"] = "2023-06-01",
      },
      body = vim.fn.json_encode({
        model = vim.tbl_get(require("project-guide.config").options, "anthropic", "model")
            or "claude-3-5-haiku-20241022",
        max_tokens = 1024,
        messages = {
          {
            role = "user",
            content = prompt,
          },
        },
      }),
    })

    -- Handle the response
    if response.status ~= 200 then
      return {
        "Error connecting to Anthropic API: " .. (response.status or "unknown error"),
        "Check your API key and internet connection.",
      }
    end

    -- Parse the response
    local success, result = pcall(vim.fn.json_decode, response.body)
    if not success or not result or not result.content or #result.content == 0 then
      return {
        "Error parsing Anthropic API response.",
        "Response may be malformed or empty.",
      }
    end

    -- Extract the content
    local content = result.content[1].text

    -- Process the content into lines
    explanation = {}
    for line in content:gmatch("[^\r\n]+") do
      table.insert(explanation, line)
    end
  end

  -- Restore original settings
  vim.opt.more = saved_more
  vim.opt.cmdheight = saved_cmdheight

  -- Return empty list if no explanation was generated
  if not explanation or #explanation == 0 then
    return { "No explanation could be generated." }
  end

  return explanation
end

return M
