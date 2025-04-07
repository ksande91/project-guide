return {
  "ksande91/project-guide",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  cmd = { "ProjectGuide" },
  config = function()
    require("project-guide").setup()
  end,
}