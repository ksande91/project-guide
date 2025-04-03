local M = {}

function M.setup()
	-- Create an augroup for project guide buffer settings
	local augroup = vim.api.nvim_create_augroup("ProjectGuideFiletype", { clear = true })

	-- Set up autocmd for project-guide filetype
	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = "project-guide",
		callback = function()
			-- Configure buffer settings
			vim.opt_local.number = false
			vim.opt_local.relativenumber = false
			vim.opt_local.list = false
			vim.opt_local.wrap = false

			vim.opt_local.cursorcolumn = false
			vim.opt_local.spell = false
			vim.opt_local.foldenable = false

			-- Enable cursorline for better navigation in the file list
			vim.opt_local.cursorline = true

			-- Disable statusline for a cleaner look (optional)
			vim.opt_local.laststatus = 0

			-- Set buffer-local keymaps
			local opts = { buffer = true, silent = true }
			vim.keymap.set("n", "q", "<cmd>q<CR>", opts)
			vim.keymap.set("n", "<Esc>", "<cmd>q<CR>", opts)

			-- We don't disable editing keys here anymore since we need to allow
			-- editing in the search line and navigation in the file list
		end,
	})
end

return M