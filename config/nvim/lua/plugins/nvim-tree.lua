return {
  {
    "nvim-tree/nvim-tree.lua",
    event = "VimEnter",
    opts = {
      filters = {
        git_ignored = false, -- ← this disables .gitignore filtering
        dotfiles = false, -- optional: show dotfiles like .env, .gitignore
      },

      diagnostics = {
        enable = true,
        show_on_dirs = true,
        show_on_open_dirs = true,
        debounce_delay = 50,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },

      actions = {
        open_file = {
          quit_on_open = false,
        },
      },

      on_attach = function(bufnr)
        local api = require "nvim-tree.api"
        -- Load default nvim-tree mappings
        api.config.mappings.default_on_attach(bufnr)
        -- Add custom mapping for creating a file/folder
        vim.keymap.set("n", "<leader>N", api.fs.create, { buffer = bufnr, noremap = true, silent = true })
        vim.keymap.set("n", "<leader>R", api.fs.rename, { buffer = bufnr, noremap = true, silent = true })
        vim.keymap.set("n", "<leader>D", api.fs.remove, { buffer = bufnr, noremap = true, silent = true })

        -- Remove default 'a' mapping for creating file/folder
        vim.keymap.set("n", "a", "<Nop>", { buffer = bufnr, noremap = true, silent = true })
        vim.keymap.set("n", "r", "<Nop>", { buffer = bufnr, noremap = true, silent = true })
        vim.keymap.set("n", "d", "<Nop>", { buffer = bufnr, noremap = true, silent = true })
        -- Add custom mapping for left arrow to navigate to parent directory and close the tree
        vim.keymap.set("n", "<Left>", function()
          api.node.navigate.parent_close()
        end, { buffer = bufnr, noremap = true, silent = true })
      end,
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)

      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          require("nvim-tree.api").tree.open()
        end,
      })
    end,
  },
}
