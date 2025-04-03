local M = {}

local BUFFER_NAME = "*project-guide*"

-- Function to create a new project guide buffer
function M.create()
	-- Create a buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer name and make sure it succeeds
	local success, error_msg = pcall(function()
		vim.api.nvim_buf_set_name(buf, BUFFER_NAME)
	end)

	if not success then
		vim.notify("Failed to set buffer name: " .. error_msg, vim.log.levels.WARN)
		-- Continue anyway, the buffer is still usable
	end
	-- Set filetype regardless
	vim.api.nvim_set_option_value("filetype", "project-guide", { buf = buf })

	return buf
end

function M.find_buf()
	-- Check if a buffer with this name already exists
	local buf_found = nil

	-- If not found, try to find by filetype
	if not buf_found then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) then
				local ft = vim.api.nvim_buf_get_option(buf, "filetype")
				if ft == "project-guide" then
					buf_found = buf
					break
				end
			end
		end
	end

	return buf_found
end

-- Function to set clean display options for the current window
function M.set_clean_window_options()
	vim.api.nvim_win_set_option(0, "signcolumn", "no")
	vim.api.nvim_win_set_option(0, "foldcolumn", "0")
	vim.api.nvim_win_set_option(0, "colorcolumn", "")
	vim.api.nvim_win_set_option(0, "number", false)
	vim.api.nvim_win_set_option(0, "relativenumber", false)
end

-- Function to populate a buffer with ASCII art and suggestions
function M.populate(buf)
	local config = require("project-guide.config")
	local ascii = require("project-guide.ascii")
	local suggestions = require("project-guide.suggestions")

	-- Make buffer modifiable temporarily to set content
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

	-- Get ASCII art
	local content = ascii.get_prepared_art()

	-- Add suggestions
	do
		local suggestion_content = suggestions.get_formatted_suggestions()

		-- Get window width to calculate centering
		local win_width = vim.api.nvim_win_get_width(0)

		-- Add extra line before suggestions
		table.insert(content, "")

		-- Store suggestion start line for cursor positioning
		local suggestion_start_line = #content + 1

		-- Store line numbers with actual suggestions for later reference
		local suggestion_lines = {}
		local suggestion_index = 0

		-- Center each suggestion line
		for _, line in ipairs(suggestion_content) do
			-- Ensure no newlines in suggestion lines that would break the buffer
			local safe_line = line:gsub("\n", " "):gsub("\r", " ")

			-- Keep track of actual suggestion lines (ones with numbers at start)
			if line:match("^%d+%.") then
				suggestion_index = suggestion_index + 1
				suggestion_lines[#content + 1] = {
					index = suggestion_index,
					text = line,
				}
			end

			-- Calculate padding for centering
			local padding = math.floor((win_width - vim.fn.strdisplaywidth(safe_line)) / 2)
			if padding > 0 then
				table.insert(content, string.rep(" ", padding) .. safe_line)
			else
				table.insert(content, safe_line)
			end
		end

		-- Save suggestion lines data to buffer
		vim.api.nvim_buf_set_var(buf, "suggestion_lines", suggestion_lines)
		vim.api.nvim_buf_set_var(buf, "suggestion_start_line", suggestion_start_line)
	end

	-- Set the buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)

	-- Make buffer non-modifiable after setting content
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	return buf
end

-- Function to explain a suggestion in detail
function M.explain_suggestion(buffer, line_nr)
	-- Get the suggestion lines data
	local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buffer, "suggestion_lines")
	if not ok or not suggestion_lines then
		return
	end

	-- Check if this is a suggestion line
	local suggestion = suggestion_lines[line_nr]
	if not suggestion then
		return
	end

	-- Prepare to generate explanation
	local suggestion_text = suggestion.text

	-- Create a floating window for the explanation
	local width = math.min(120, vim.o.columns - 10)
	local height = math.min(30, vim.o.lines - 10)

	-- Create a buffer for the floating window
	local explain_buf = vim.api.nvim_create_buf(false, true)

	-- Set initial content
	vim.api.nvim_buf_set_lines(explain_buf, 0, -1, false, {
		"Getting detailed explanation for:",
		suggestion_text,
		"",
		"Loading...",
	})

	-- Calculate position (centered)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Set up floating window options
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Suggestion Explanation ",
		title_pos = "center",
	}

	-- Create the window
	local win_id = vim.api.nvim_open_win(explain_buf, true, win_opts)

	-- Add close keybinding
	vim.api.nvim_buf_set_keymap(explain_buf, "n", "q", "", {
		callback = function()
			vim.api.nvim_win_close(win_id, true)
		end,
		noremap = true,
		silent = true,
		desc = "Close explanation window",
	})

	-- Set buffer options
	vim.api.nvim_buf_set_option(explain_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(explain_buf, "bufhidden", "wipe")

	-- Generate explanation in the background
	vim.defer_fn(function()
		-- Use the same source as for suggestions
		local config = require("project-guide.config")
		local anthropic = require("project-guide.anthropic")

		-- Request explanation
		local explanation = anthropic.explain_suggestion(suggestion_text)

		-- Update the buffer with the explanation
		vim.api.nvim_buf_set_option(explain_buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(explain_buf, 0, -1, false, {
			"# Explanation: " .. suggestion_text,
			"",
		})

		-- Add the explanation lines
		for _, line in ipairs(explanation) do
			vim.api.nvim_buf_set_lines(explain_buf, -1, -1, false, { line })
		end

		-- Add help text at the bottom
		vim.api.nvim_buf_set_lines(explain_buf, -1, -1, false, {
			"",
			"_Press 'q' to close this window_",
		})

		-- Apply markdown formatting if enabled
		if config.options.explanations and config.options.explanations.markdown then
			-- Set the buffer filetype to markdown for syntax highlighting
			vim.api.nvim_buf_set_option(explain_buf, "filetype", "markdown")

			-- Set additional options for better markdown display
			if config.options.explanations.syntax_highlighting then
				-- Enable concealing for markdown syntax (e.g., hide * in bold text)
				vim.api.nvim_win_set_option(win_id, "conceallevel", 2)
				vim.api.nvim_win_set_option(win_id, "concealcursor", "nc")

				-- Enable syntax highlighting
				vim.api.nvim_win_set_option(win_id, "spell", false)

				-- Set colorcolumn to improve readability
				vim.api.nvim_win_set_option(win_id, "colorcolumn", "")

				-- Check if we have treesitter markdown parser available
				local has_treesitter = pcall(require, "nvim-treesitter")
				if has_treesitter then
					pcall(function()
						vim.treesitter.start(explain_buf, "markdown")
					end)
				end
			end
		end

		vim.api.nvim_buf_set_option(explain_buf, "modifiable", false)
	end, 0)

	return win_id
end

-- Helper function to find the position of the first digit in a line
local function find_first_digit_pos(buf, line_nr)
	-- Get the content of the line
	local line_content = vim.api.nvim_buf_get_lines(buf, line_nr - 1, line_nr, false)[1]

	-- Find position of first digit in the line (0-indexed for nvim_win_set_cursor)
	local digit_pos = line_content:find("%d")

	-- Default to 0 if not found
	return digit_pos and digit_pos - 1 or 0
end

-- Function to display a buffer in the current window and set up options
function M.display(buf)
	-- Get the current window ID
	local win_id = vim.api.nvim_get_current_win()

	-- Store original line number settings for this specific window
	local original_settings = {
		win_id = win_id,
		number = vim.api.nvim_win_get_option(win_id, "number"),
		relativenumber = vim.api.nvim_win_get_option(win_id, "relativenumber"),
	}

	-- Store these settings in a global table indexed by window ID
	if not _G.project_guide_original_settings then
		_G.project_guide_original_settings = {}
	end
	_G.project_guide_original_settings[win_id] = original_settings

	-- Set the buffer to the current window
	vim.api.nvim_win_set_buf(win_id, buf)

	-- Position cursor at the first suggestion line
	local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buf, "suggestion_lines")
	if ok and suggestion_lines then
		-- Find the first suggestion line with a number
		local first_numbered_line = nil
		for line_nr, suggestion in pairs(suggestion_lines) do
			if not first_numbered_line or line_nr < first_numbered_line then
				first_numbered_line = line_nr
			end
		end

		if first_numbered_line then
			-- Position cursor at the first digit (the line number)
			local digit_pos = find_first_digit_pos(buf, first_numbered_line)
			vim.api.nvim_win_set_cursor(0, { first_numbered_line, digit_pos })
		end
	end

	-- Apply clean window options only to the project guide buffer
	M.set_clean_window_options()

	-- Helper function to find next/previous numbered line
	local function find_next_numbered_line(buf_id, current_line, direction)
		local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buf_id, "suggestion_lines")
		if not ok or not suggestion_lines then
			return nil
		end

		local target_line = nil
		if direction == "next" then
			-- Find next suggestion line after current line
			for line_nr, _ in pairs(suggestion_lines) do
				if line_nr > current_line and (not target_line or line_nr < target_line) then
					target_line = line_nr
				end
			end
		else -- direction == "prev"
			-- Find previous suggestion line before current line
			for line_nr, _ in pairs(suggestion_lines) do
				if line_nr < current_line and (not target_line or line_nr > target_line) then
					target_line = line_nr
				end
			end
		end

		return target_line
	end

	-- Add keybindings for suggestion interaction
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		callback = function()
			local current_line = vim.api.nvim_win_get_cursor(0)[1]
			-- Verify this is a suggestion line before explaining
			local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buf, "suggestion_lines")
			if ok and suggestion_lines and suggestion_lines[current_line] then
				M.explain_suggestion(buf, current_line)
			end
		end,
		noremap = true,
		silent = true,
		desc = "Get detailed explanation of the selected suggestion",
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "e", "", {
		callback = function()
			local current_line = vim.api.nvim_win_get_cursor(0)[1]
			-- Verify this is a suggestion line before explaining
			local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buf, "suggestion_lines")
			if ok and suggestion_lines and suggestion_lines[current_line] then
				M.explain_suggestion(buf, current_line)
			end
		end,
		noremap = true,
		silent = true,
		desc = "Get detailed explanation of the selected suggestion",
	})

	-- Add j/k navigation between numbered suggestions
	vim.api.nvim_buf_set_keymap(buf, "n", "j", "", {
		callback = function()
			local current_line = vim.api.nvim_win_get_cursor(0)[1]
			local next_line = find_next_numbered_line(buf, current_line, "next")
			if next_line then
				-- Position at the digit (line number)
				local digit_pos = find_first_digit_pos(buf, next_line)
				vim.api.nvim_win_set_cursor(0, { next_line, digit_pos })
			end
		end,
		noremap = true,
		silent = true,
		desc = "Move to next numbered suggestion",
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
		callback = function()
			local current_line = vim.api.nvim_win_get_cursor(0)[1]
			local prev_line = find_next_numbered_line(buf, current_line, "prev")
			if prev_line then
				-- Position at the digit (line number)
				local digit_pos = find_first_digit_pos(buf, prev_line)
				vim.api.nvim_win_set_cursor(0, { prev_line, digit_pos })
			end
		end,
		noremap = true,
		silent = true,
		desc = "Move to previous numbered suggestion",
	})

	-- Create autocmd group for project guide buffer settings
	local augroup = vim.api.nvim_create_augroup("ProjectGuideSettings", { clear = true })

	-- When leaving the project guide buffer, restore settings for the specific window
	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup,
		buffer = buf,
		callback = function()
			vim.api.nvim_win_set_option(0, "number", true)
			vim.api.nvim_win_set_option(0, "relativenumber", true)
		end,
	})

	-- Ensure project guide buffer always has line numbers disabled when entered
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		buffer = buf,
		callback = function()
			local current_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_option(current_win, "number", false)
			vim.api.nvim_win_set_option(current_win, "relativenumber", false)
		end,
	})

	-- Add autocmd to prevent horizontal cursor movement
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		buffer = buf,
		callback = function()
			-- Get current cursor position
			local cursor = vim.api.nvim_win_get_cursor(0)
			local line = cursor[1]
			local col = cursor[2]

			-- Check if this is a numbered suggestion line
			local ok, suggestion_lines = pcall(vim.api.nvim_buf_get_var, buf, "suggestion_lines")
			if ok and suggestion_lines and suggestion_lines[line] then
				-- Get the position of the first digit
				local digit_pos = find_first_digit_pos(buf, line)

				-- If the cursor moved horizontally, put it back on the digit
				if col ~= digit_pos then
					vim.api.nvim_win_set_cursor(0, { line, digit_pos })
				end
			end
		end,
	})

	-- Re-center content when window is resized - commented out to avoid refetching suggestions
	vim.api.nvim_create_autocmd("VimResized", {
		group = augroup,
		buffer = buf,
		callback = function()
			-- Do nothing to avoid refetching suggestions
			-- This means the display might be slightly off-center after resize
		end,
	})

	return buf
end

return M
