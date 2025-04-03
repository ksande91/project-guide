-- Scratch Buffer Configuration
return {
	-- A detailed description of your project
	description = "A detailed description of your project goes here",

	-- File patterns to include in the context
	include_patterns = {
		"%.js$",
		"%.ts$",
		"%.py$",
		"%.go$",
		"%.rs$",
	},

	-- Directories to exclude from scanning
	exclude_dirs = {
		"node_modules",
		"dist",
		"build",
		"target",
		"venv",
		".git",
	},

	-- Maximum directory scan depth
	max_depth = 3,

	-- Maximum number of files to include in context
	max_files = 50,

	-- Maximum number of README lines to include
	-- Set to 0, "unlimited", or "inf" for unlimited lines
	max_readme_lines = 15,
}
