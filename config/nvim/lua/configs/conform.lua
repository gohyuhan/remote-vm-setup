local options = {
  formatters_by_ft = {
    -- Lua
    lua = { "stylua" },

    -- Python: Runs 'ruff_fix' (linter fixes) first, then 'ruff_format'
    python = { "ruff_fix", "ruff_format" },

    -- Go
    go = { "gofumpt" },

    -- Rust
    rust = { "rustfmt" },

    -- Web Stack
    -- Prettier is robust enough to handle most "syntax-like" style errors in JS/HTML
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    svelte = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    less = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    ["markdown.inline"] = { "prettier" },
    graphql = { "prettier" },
    handlebars = { "prettier" },

    -- Shell
    sh = { "shfmt" },
    bash = { "shfmt" },

    -- C/C++
    c = { "clang-format" },
    cpp = { "clang-format" },
    objc = { "clang-format" },
    objcpp = { "clang-format" },
    cs = { "csharpier" },

    -- Java
    java = { "google-java-format" },

    -- PHP
    php = { "php-cs-fixer" },

    -- Ruby
    ruby = { "rubocop" },

    -- Kotlin
    kotlin = { "ktlint" },

    -- Swift
    swift = { "swiftlint" },

    -- SQL
    sql = { "sqlfluff" },

    -- XML
    xml = { "xmlformatter" },

    -- Terraform
    terraform = { "terraform_fmt" },
    tf = { "terraform_fmt" },

    -- TOML
    toml = { "taplo" },

    -- Protobuf
    proto = { "buf" },
  },

  format_on_save = {
    -- Increased to 2000ms because "Fixing" takes longer than just formatting
    timeout_ms = 2000,
    lsp_fallback = true,
  },
}

return options
