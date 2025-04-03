local M = {}

-- ProjectGuide ASCII art
M.ascii_art = {
  "                                                          ",
  "______          _           _   _____       _     _       ",
  "| ___ \\        (_)         | | |  __ \\     (_)   | |      ",
  "| |_/ / __ ___  _  ___  ___| |_| |  \\/_   _ _  __| | ___ ",
  "|  __/ '__/ _ \\| |/ _ \\/ __| __| | __| | | | |/ _` |/ _ \\",
  "| |  | | | (_) | |  __/ (__| |_| |_\\ \\ |_| | | (_| |  __/",
  "\\_|  |_|  \\___/| |\\___|\\___|\\___|\\____/\\__,_|_|\\__,_|\\___|",
  "              _/ |                                        ",
  "             |__/                                         ",
  "                                                          "
}

-- Function to get the ASCII art
function M.get_logo()
	return M.ascii_art
end

-- Function to center ASCII art in the given window width
function M.center(ascii_art)
	local centered_art = {}
	local win_width = vim.api.nvim_win_get_width(0)

	for _, line in ipairs(ascii_art) do
		local padding = math.floor((win_width - #line) / 2)
		if padding > 0 then
			table.insert(centered_art, string.rep(" ", padding) .. line)
		else
			table.insert(centered_art, line)
		end
	end

	return centered_art
end

-- Add some vertical padding at the top
function M.padding(ascii_art)
	local win_height = vim.api.nvim_win_get_height(0)
	local vertical_padding = math.floor((win_height - #ascii_art) / 3)

	local ascii_with_padding = {}

	for _ = 1, vertical_padding do
		table.insert(ascii_with_padding, "")
	end

	for _, line in ipairs(ascii_art) do
		table.insert(ascii_with_padding, line)
	end
	return ascii_with_padding
end

-- Function that combines all operations: get logo art, center it, and add padding
function M.get_prepared_art()
	local logo_art = M.get_logo()
	local centered_art = M.center(logo_art)
	local padded_art = M.padding(centered_art)
	return padded_art
end

return M
