---@type Base46Table
local M = {}

M.base_30 = {
  white = "#0abdc6", -- REPLACED: Using Cyan as the 'light' color to match your Ghostty FG
  darker_black = "#00050e", -- Slightly deeper than the ghostty bg
  black = "#000b1e", -- core bg (from your Ghostty config)
  black2 = "#05152d", -- subtle panels
  one_bg = "#123e7c", -- selection/hover (from your Ghostty palette 0/4)
  one_bg2 = "#162a4d",
  one_bg3 = "#1d355f",
  grey = "#3a4a5f",
  grey_fg = "#5a6a7f",
  grey_fg2 = "#6a7a8f",
  light_grey = "#7a8a9f",

  red = "#ff0000", -- bright neon red/pink accents (from your Ghostty palette 1/9)
  baby_pink = "#d300c4",
  pink = "#d300c4", -- signature neon magenta/pink (from your Ghostty palette 2/10)
  line = "#123e7c", -- splits/borders
  green = "#00ff00", -- neon green (from your Ghostty palette 12)
  vibrant_green = "#00ff00",
  blue = "#123e7c", -- Darker blue (from your Ghostty palette 0/4)
  nord_blue = "#123e7c",
  seablue = "#0abdc6",
  yellow = "#f57800", -- neon yellow/orange (from your Ghostty palette 3/11)
  sun = "#f57800",
  purple = "#9d4dfa", -- purple
  dark_purple = "#711c91", -- dark purple
  teal = "#0abdc6",
  orange = "#f57800",
  cyan = "#0abdc6",

  statusline_bg = "#05152d",
  lightbg = "#123e7c",
  pmenu_bg = "#123e7c",
  folder_bg = "#0abdc6",
}

M.base_16 = {
  base00 = "#000b1e", -- default bg
  base01 = "#05152d", -- gutter / lighter bg
  base02 = "#123e7c", -- selection
  base03 = "#5a6a7f", -- comments / line nr (muted grey)
  base04 = "#7a8a9f", -- line nr active, borders
  base05 = "#0abdc6", -- foreground text (STRICT CYAN - NO WHITE)
  base06 = "#0abdc6", -- lighter text
  base07 = "#d300c4", -- replacement for white
  base08 = "#ff0000", -- variables (RED - prevents Cyan overlap)
  base09 = "#f57800", -- numbers, constants (ORANGE)
  base0A = "#f57800", -- types/classes (ORANGE)
  base0B = "#00ff00", -- strings (GREEN)
  base0C = "#0abdc6", -- regex/support (CYAN)
  base0D = "#0abdc6", -- functions (CYAN)
  base0E = "#d300c4", -- keywords/operators (MAGENTA)
  base0F = "#9d4dfa", -- punctuation/tags (PURPLE)
}

M.type = "dark"

-- Optional: theme-specific polish (e.g. make comments more visible with transparency)
M.polish_hl = {
  defaults = {
    Comment = { fg = "#5a6a7f", italic = true },

    -- Telescope Overrides
    TelescopeSelection = { bg = "#123e7c", fg = "#f57800", bold = true },
    TelescopeSelectionCaret = { fg = "#ff0000", bg = "#123e7c" },
    TelescopeMatching = { fg = "#00ff00", bold = true },
    TelescopeNormal = { bg = "#00050e" },

    -- FORCE DISTINCTNESS:
    -- Even if things default to Cyan, we force the Ghostty palette here.
    ["@variable"] = { fg = "#ff0000" }, -- Variables MUST be RED to stand out from Cyan text
    ["@keyword"] = { fg = "#d300c4", bold = true }, -- Keywords MAGENTA
    ["@function"] = { fg = "#0abdc6", bold = true }, -- Functions CYAN
    ["@operator"] = { fg = "#711c91", bold = true }, -- Operators PURPLE
    ["@punctuation.bracket"] = { fg = "#711c91" }, -- Brackets PURPLE

    Operator = { fg = "#711c91" }, -- Purple
    Delimiter = { fg = "#711c91" }, -- Purple
  },
}

-- Allow chadrc overrides (string MUST match filename without .lua)
M = require("base46").override_theme(M, "cyber-punk-neon")

return M
