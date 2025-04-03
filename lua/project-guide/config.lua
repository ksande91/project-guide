local M = {}

-- Default configuration
M.defaults = {
  auto_open = false, -- Whether to open project guide buffer on VimEnter
  suggestions = {
    enabled = true, -- Whether to show suggested next steps
  },
  explanations = {
    markdown = true,          -- Whether to format explanations as markdown
    syntax_highlighting = true, -- Whether to enable syntax highlighting for markdown
  },
  anthropic = {
    api_key = nil,                     -- Anthropic API key (required for Claude API suggestions)
    model = "claude-3-5-haiku-20241022", -- Default model to use
    include_context = true,            -- Whether to include project context in the prompt
    use_claude_cli = false,            -- Whether to use Claude Code CLI instead of API
    claude_path = "claude",            -- Path to Claude Code CLI executable
  },
  window = {
    clean = true,                           -- Whether to use clean window settings
  },
  enable_suggestions_without_config = false, -- Whether to enable suggestions without a config file
}

-- User configuration (will be populated in setup)
M.options = {}

-- Initialize configuration with user options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
