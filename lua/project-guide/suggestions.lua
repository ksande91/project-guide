local M = {}
local config = require("project-guide.config")

-- Function to get suggestions based on configuration
function M.get_suggestions()
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
