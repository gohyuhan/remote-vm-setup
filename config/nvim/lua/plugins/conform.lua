return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local mason_bin = vim.fn.stdpath "data" .. "/mason/bin"
      vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
      require("conform").setup(require "configs.conform")
    end,
  },
}
