local buffer = require("project-guide.buffer")
local config = require("project-guide.config")

-- Main function to create and display a project guide buffer
local function main()
	-- Check if a buffer with this name already exists
	local existing_buf = buffer.find_buf()

	-- Create or reuse buffer
	if existing_buf then
		vim.notify("Buffer exists", vim.log.levels.DEBUG)
		-- Just display the existing buffer
		buffer.display(existing_buf)
	else
		vim.notify("Buffer does not exists", vim.log.levels.DEBUG)
		-- Create a new buffer if one doesn't exist
		local buf = buffer.create()
		buffer.populate(buf)
		buffer.display(buf)
	end
end

-- Setup function to initialize the plugin
local function setup(opts)
	-- Initialize configuration
	config.setup(opts)

	-- Load filetype settings
	require("project-guide.filetype").setup()

	-- Set up auto-open functionality if enabled
	if config.options.auto_open then
		local augroup = vim.api.nvim_create_augroup("ProjectGuide", { clear = true })

		vim.api.nvim_create_autocmd("VimEnter", {
			group = augroup,
			desc = "Set a project guide buffer with ASCII art on load",
			once = true,
			callback = main,
		})
	end

	-- Add command to open the project guide buffer
	vim.api.nvim_create_user_command("ProjectGuide", main, { desc = "Open project guide with ASCII art" })
end

-- Function to manually open the project guide buffer
local function open()
	main()
end

return {
	setup = setup,
	open = open,
}
