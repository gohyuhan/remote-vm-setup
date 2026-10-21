-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@class ChadrcConfig
local M = {}

M.base46 = {
  theme = "solarized_osaka",
  transparency = false,
  -- Add this block to fix comment visibility under transparency
  hl_override = {
    Comment = { fg = "#9399b2", italic = true },
    ["@comment"] = { fg = "#9399b2", italic = true },
  },
}

-- M.ui = {
--   cmp = {
--     lspkind_text = true,
--     style = "default", -- default/flat_light/flat_dark/atom/atom_colored
--     format_colors = {
--       tailwind = false,
--     },
--   },
-- }

-- M.nvdash = { load_on_startup = true }
M.term = {
  sizes = {
    sp = 0.45, -- horizontal split height (0.45 = 45%)
    vsp = 0.45, -- vertical split width (0.45 = 45%)
  },
  float = {
    relative = "editor",
    row = 0.125,
    col = 0.125,
    width = 0.75,
    height = 0.75,
    border = "single",
  },

  -- winopts is for vim window settings, NOT sizing
  winopts = {
    number = false,
    relativenumber = false,
  },
}

-- Plugin configuration is now managed in lua/plugins/init.lua
-- M.plugins = {
--   user = {
--     -- ... other user plugins ...
--   },
-- }

return M
