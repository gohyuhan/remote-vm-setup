return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" },
    opts = {
      file_types = { "markdown", "codecompanion" },
      anti_conceal = {
        enabled = false,
      },
      on_cursor = "hidden",

      heading = {
        enabled = true,
        sign = true,
        position = "overlay",
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)

      vim.opt.conceallevel = 2
      vim.opt.concealcursor = "nvic" -- Hide markup in Normal, Visual, Insert, and Command modes
      --
      -- -- FOR NVCHAD: Force it again whenever you enter a CodeCompanion buffer
      -- -- because NvChad/CodeCompanion might reset buffer-local options
      -- vim.api.nvim_create_autocmd("FileType", {
      --   pattern = "codecompanion",
      --   callback = function()
      --     vim.opt_local.conceallevel = 2
      --     vim.opt_local.concealcursor = "nvic"
      --   end,
      -- })
    end,
  },
}
