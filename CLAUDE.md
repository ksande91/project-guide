# ProjectGuide Plugin - Development Guidelines

## Build/Test Commands
- No specific build commands required
- Manual testing: Open Neovim and run `:ProjectGuide` command

## Code Style Guidelines
- **Indentation**: Use 2 spaces
- **Naming**: Use snake_case for variables, functions, and modules
- **Module Pattern**: Use `local M = {}` pattern with function exports
- **Error Handling**: Use pcall for protected calls with formatted error messages
- **Functions**: Add descriptive comments before function definitions
- **Comments**: Use `--` for single-line comments
- **Configuration**: Place defaults in config.lua, use vim.tbl_deep_extend for merging
- **Window/Buffer Management**: Clean up event listeners with augroups
- **Imports**: Place at top of file, assign to local variables
- **Consistency**: Follow existing patterns in neighboring files
- **API Usage**: Prefer nvim_* API methods over legacy vim.* equivalents
- **Strings**: Use double quotes for config keys, single quotes for strings
- **Line Length**: Keep lines reasonably short (< 100 characters)