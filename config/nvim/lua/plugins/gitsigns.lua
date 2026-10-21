return {
  {
    "lewis6991/gitsigns.nvim",
    config = function(_, opts)
      local function set_blame_hl()
        local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
        local is_dark = true
        if bg then
          local r = bit.rshift(bit.band(bg, 0xFF0000), 16)
          local g = bit.rshift(bit.band(bg, 0x00FF00), 8)
          local b = bit.band(bg, 0x0000FF)
          -- perceived luminance
          local lum = 0.299 * r + 0.587 * g + 0.114 * b
          is_dark = lum < 128
        end
        local color = is_dark and "#c084a0" or "#5a3d50"
        vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = color, italic = true })
      end
      set_blame_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_blame_hl })
      require("gitsigns").setup(opts)
    end,
    opts = function()
      dofile(vim.g.base46_cache .. "git")
      return {
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "󰍵" },
          topdelete = { text = "‾" },
          changedelete = { text = "󱕖" },
        },
        -- Only refresh signs after you stop typing (2s) or on save
        update_debounce = 2000,
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 850,
          ignore_whitespace = false,
        },
        current_line_blame_formatter = "<abbrev_sha> • <author>, <author_time:%Y-%m-%d> • <summary>",
        on_attach = function(bufnr)
          local gs = require "gitsigns"
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          -- Hunk navigation
          map("n", "]h", function()
            if vim.wo.diff then
              vim.cmd.normal { "]c", bang = true }
            else
              gs.next_hunk()
            end
          end, "Next hunk")

          map("n", "[h", function()
            if vim.wo.diff then
              vim.cmd.normal { "[c", bang = true }
            else
              gs.prev_hunk()
            end
          end, "Prev hunk")

          -- Blame popup for current line
          map("n", "<leader>b", function()
            gs.blame_line { full = true }
          end, "Blame line (popup)")

          -- Hunk preview
          map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        end,
      }
    end,
  },
}
