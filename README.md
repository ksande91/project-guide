# ProjectGuide

A Neovim plugin to create a project guide with AI-powered suggestions for project development.

## Features

- Provides AI-powered project-specific suggestions for next steps
- Supports both Claude API and Claude Code CLI for generating suggestions
- Detailed markdown-formatted explanations for each suggestion

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'ksande91/project-guide',
  requires = { 'nvim-lua/plenary.nvim' }
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'ksande91/project-guide',
  dependencies = { 'nvim-lua/plenary.nvim' }
}
```

## Configuration

### Plugin Configuration

```lua
require('project-guide').setup({
  -- Auto-open the project guide when Neovim starts
  auto_open = false,

  -- Claude configuration
  anthropic = {
    -- API key for Claude API (can also use ANTHROPIC_API_KEY env var)
    api_key = nil,
    -- Model to use for suggestions
    model = "claude-3-5-haiku-20241022",
    -- Whether to include project context in the prompt
    include_context = true,
    -- Whether to use Claude Code CLI instead of API
    use_claude_cli = false,
    -- Path to Claude Code CLI executable
    claude_path = "claude",
  },

  -- Window display settings
  window = {
    clean = true,
  },

  -- Enable suggestions without a project config file
  enable_suggestions_without_config = false,
})
```

## Project-Specific Configuration

The ProjectGuide plugin can be configured on a per-project basis to provide more relevant suggestions:

### Custom Project Context

By default, AI suggestions are only enabled for projects with a configuration file. This ensures that suggestions are only generated for projects where you've explicitly opted in.

To enable suggestions for your project, create a configuration file in your project root:

#### JSON Configuration (`.project-guide.json`)

```json
{
  "description": "A detailed description of your project goes here",
  "include_patterns": ["\\.js$", "\\.ts$", "\\.py$"],
  "exclude_dirs": ["node_modules", "dist", ".git"],
  "max_depth": 3,
  "max_files": 50,
  "max_readme_lines": 15
}
```

#### Lua Configuration (`.project-guide.lua`)

```lua
return {
  description = "A detailed description of your project goes here",
  include_patterns = {
    "%.js$",
    "%.ts$",
    "%.py$"
  },
  exclude_dirs = {
    "node_modules",
    "dist",
    ".git"
  },
  max_depth = 3,
  max_files = 50,
  max_readme_lines = 15
}
```

### Configuration Options

| Option             | Description                                                                                     |
| ------------------ | ----------------------------------------------------------------------------------------------- |
| `description`      | A detailed description of your project                                                          |
| `include_patterns` | Lua patterns for files to include in context                                                    |
| `exclude_dirs`     | Directories to exclude from scanning                                                            |
| `max_depth`        | Maximum directory scan depth                                                                    |
| `max_files`        | Maximum number of files to include in context                                                   |
| `max_readme_lines` | Maximum number of README lines to include (set to 0, "unlimited", or "inf" for unlimited lines) |

## Using Claude Code CLI

To use Claude Code CLI for suggestions:

1. Install Claude Code CLI on your system
2. Configure the plugin to use it:

```lua
require('project-guide').setup({
  suggestions = {
    enabled = true,
  },
  anthropic = {
    use_claude_cli = true,
    -- Optionally specify path if 'claude' is not in your PATH
    claude_path = "/path/to/claude",
  },
})
```

This uses the Claude Code CLI to generate suggestions based on your project context, leveraging Claude's understanding of the entire codebase and giving better context-aware suggestions.

## Key Mappings

When viewing the project guide buffer:

| Key       | Action                                          |
| --------- | ----------------------------------------------- |
| `j`       | Navigate to next suggestion                     |
| `k`       | Navigate to previous suggestion                 |
| `<Enter>` | Get detailed explanation of selected suggestion |
| `e`       | Get detailed explanation of selected suggestion |
| `q`       | Close explanation window                        |

## Getting Started

1. Install the plugin with your package manager
2. Add configuration to your Neovim config
3. Create a `.project-guide.lua` or `.project-guide.json` file in your project
4. Run `:ProjectGuide` to open the guide
5. Select a suggestion and press Enter for an explanation
