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
