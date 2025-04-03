local M = {}
local config = require("project-guide.config")

-- Function to get suggestions based on configuration
function M.get_suggestions()
  -- Check if suggestions are enabled
  if not config.options.suggestions.enabled then
    return {
      "",
      "--- Suggestions are disabled ---",
      "",
      "To enable AI-powered suggestions, add the following to your config:",
      "",
      "require('project-guide').setup({",
      "  suggestions = {",
      "    enabled = true,",
      "  },",
      "  anthropic = {",
      "    -- Choose one of these options:",
      "    api_key = 'your_anthropic_api_key',  -- For API access",
      "    -- OR --",
      "    use_claude_cli = true,  -- To use the Claude CLI",
      "  }",
      "})",
      "",
    }
  end

  -- Execute in protected mode to ensure settings are restored
  local ok, result = pcall(function()
    local anthropic = require("project-guide.anthropic")
    return anthropic.get_formatted_suggestions()
  end)

  if ok then
    return result
  else
    return {
      "",
      "--- Error generating suggestions ---",
      "Error: " .. tostring(result),
      "",
      "To fix this issue:",
      config.options.anthropic.use_claude_cli and "1. Ensure Claude CLI is properly installed and configured"
      or "1. Check your Anthropic API key in configuration",
      "2. Ensure you have an active internet connection",
      "3. Try using a different model in your configuration",
      "",
    }
  end
end

-- Function to format suggestions with a header
function M.get_formatted_suggestions()
  return M.get_suggestions()
end

return M

