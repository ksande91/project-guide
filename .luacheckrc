-- .luacheckrc
std = {
  globals = {
    "vim",
  },
  read_globals = {
    -- Add any other Neovim APIs you use frequently
    "table",
    "string",
    "math",
    "os",
    "io",
    "coroutine",
    "debug",
    "assert",
    "error",
  },
}

-- Customize as needed
ignore = {
  "212", -- Unused argument
  "631", -- Line is too long
}

-- Exclude certain directories (optional)
exclude_files = {
  ".luarocks/*",
  "lua_modules/*",
}
