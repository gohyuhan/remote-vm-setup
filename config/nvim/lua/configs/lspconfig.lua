-- Load NvChad's default LSP behavior
-- require("nvchad.configs.lspconfig").defaults()

-- List all installed servers here
local servers = {
  "lua_ls", -- Mason: lua-language-server
  "basedpyright", -- Mason: basedpyright
  "gopls", -- Mason: gopls
  "rust_analyzer", -- Mason: rust-analyzer (Must use underscore!)
  "ts_ls", -- Mason: typescript-language-server
  "html", -- Mason: html-lsp
  "cssls", -- Mason: css-lsp
  "jsonls", -- Mason: json-lsp
  "yamlls", -- Mason: yaml-language-server
  "bashls", -- Mason: bash-language-server
  "clangd", -- Mason: clangd
  "jdtls", -- Mason: jdtls
  "intelephense", -- Mason: intelephense
  "lemminx", -- Mason: lemminx
  "terraformls", -- Mason: terraform-ls
  "taplo", -- Mason: taplo
  "dockerls", -- Mason: dockerfile-language-server
  "kotlin_language_server", -- Mason: kotlin-language-server
  "solargraph", -- Mason: solargraph
  "omnisharp", -- Mason: omnisharp
  "sqlls", -- Mason: sqls (Note: 'sqlls' or 'sqls' depends on config, usually sqlls for lspconfig)
}

vim.lsp.enable(servers)
-- read :h vim.lsp.config for changing options of lsp servers

-- Override mappings after LSP attaches to a buffer
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local map = vim.keymap.set
    local opts = { buffer = args.buf }

    -- Force Telescope for definitions
    opts.desc = "LSP Definition (Telescope)"
    map("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)

    -- Force Telescope for references (usually mapped to gD or gr)
    opts.desc = "LSP References (Telescope)"
    map("n", "gD", "<cmd>Telescope lsp_references<CR>", opts)
  end,
})

-- Diagnostic float config
vim.diagnostic.config {
  virtual_text = false,
  float = { border = "rounded", source = true },
}

vim.o.updatetime = 550

-- Auto float: diagnostic if error present, else hover
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    local diagnostics = vim.diagnostic.get(0, {
      lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
    })

    if #diagnostics > 0 then
      vim.diagnostic.open_float(nil, { focusable = false })
    else
      local clients = vim.lsp.get_clients { bufnr = 0 }
      if #clients > 0 then
        vim.lsp.buf.hover {
          border = "rounded",
          focusable = false,
          silent = true,
        }
      end
    end
  end,
})
