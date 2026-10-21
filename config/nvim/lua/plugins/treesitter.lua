return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- Your Core Languages
        "python",
        "javascript",
        "typescript",
        "tsx",
        "svelte",
        "html",
        "css",
        "rust",
        "go",

        -- NEW: Added common data & config languages
        "json",
        "yaml",
        "dockerfile",
        "bash",

        -- Always good to have
        "lua",
        "luadoc",
        "printf",
        "vim",
        "vimdoc",
        "markdown",
        "markdown_inline",
      },

      highlight = {
        enable = true,
        use_languagetree = true,
      },

      indent = {
        enable = true,
      },
    },
  },
}
