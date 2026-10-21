require "nvchad.mappings"
local map = vim.keymap.set

-- General mappings
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })
map("i", "<C-e>", "<C-o>dw", { noremap = true, silent = true, desc = "Delete next word" })

map("n", "<leader>E", function()
  require("nvim-tree.api").tree.focus()
end, { noremap = true, silent = true })

-- Unmap NvChad defaults
map("n", "<leader>b", "<Nop>", { noremap = true, silent = true }) -- gitsigns takes this for blame_line (buffer-local)
map("n", "<leader>n", "<Nop>", { noremap = true, silent = true }) -- moved to <leader>nn
map("n", "<leader>rn", "<Nop>", { noremap = true, silent = true }) -- moved to <leader>nr

-- Line number toggles (nn/nr frees rn for grug-far buffer keymaps)
map("n", "<leader>nn", "<cmd>set nu!<CR>", { noremap = true, silent = true, desc = "Toggle line number" })
map("n", "<leader>nr", "<cmd>set rnu!<CR>", { noremap = true, silent = true, desc = "Toggle relative number" })

-- Unmap NvChad's default buffer navigation, close buffer, and LSP mappings
map("n", "<leader>l", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>x", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>d", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>D", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>z", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>Z", "<Nop>", { noremap = true, silent = true })
map("n", "<leader>p", "<Nop>", { noremap = true, silent = true })

-- Buffer navigation
map("n", "<leader>,", ":bprevious<CR>", { noremap = true, silent = true, desc = "Previous buffer" })
map("n", "<leader>.", ":bnext<CR>", { noremap = true, silent = true, desc = "Next buffer" })

-- Mac-style line/file navigation
map({ "n", "v" }, "<leader><Left>", "^", { noremap = true, silent = true, desc = "Start of line" })
map({ "n", "v" }, "<leader><Right>", "$", { noremap = true, silent = true, desc = "End of line" })

-- Mac-style line/file navigation (leader+arrow)
map({ "n", "v" }, "<leader><Up>", "gg", { noremap = true, silent = true, desc = "Top of file" })
map({ "n", "v" }, "<leader><Down>", "G", { noremap = true, silent = true, desc = "Bottom of file" })

-- Map <leader>x to close the current buffer ( a hack to call the command twice so that i can still remain on the workspace )
map("n", "<leader>x", ":bd<CR>|:bd<CR>", { noremap = true, silent = true })

-- Map <leader>z to undo
map("n", "<leader>z", "u", { noremap = true, silent = true })

-- Map <leader>Z to redo
map("n", "<leader>Z", "<C-r>", { noremap = true, silent = true })

-- Mappings for Command-C (Copy) and Command-V (Paste) for GUI clients
-- Copy (highlighted stuff in Visual mode)
-- `vmap` is for Visual mode mappings.
-- `"+y` yanks the selected text into the system clipboard.
map("v", "<D-c>", '"+y', { noremap = true, silent = true, desc = "Copy visual selection to system clipboard" })
map("v", "<C-c>", '"+y', { noremap = true, silent = true, desc = "Copy visual selection to system clipboard" })

-- Paste (Normal mode)
-- `nmap` is for Normal mode mappings.
-- `"+p` puts (pastes) content from the system clipboard after the cursor.
map("n", "<D-v>", '"+p', { noremap = true, silent = true, desc = "Paste from system clipboard" })
map("n", "<C-v>", '"+p', { noremap = true, silent = true, desc = "Paste from system clipboard" })

-- Paste (Visual mode - replaces selection)
-- `vmap` is for Visual mode mappings.
-- `"+p` replaces the current visual selection with content from the system clipboard.
map("v", "<D-v>", '"+p', { noremap = true, silent = true, desc = "Paste from system clipboard (replace selection)" })
map("v", "<C-v>", '"+p', { noremap = true, silent = true, desc = "Paste from system clipboard (replace selection)" })

-- Paste (Insert mode)
-- `imap` is for Insert mode mappings.
-- `<C-r>+` inserts the contents of the '+' (system clipboard) register without leaving Insert mode.
map("i", "<D-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from system clipboard (insert mode)" })
map("i", "<C-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from system clipboard (insert mode)" })

-- This overrides the default NvChad <leader>fm
map("n", "<leader>fm", function()
  require("conform").format {
    lsp_fallback = true,
    async = false,
    timeout_ms = 1000,
  }
end, { desc = "Format file" })

-- Replace 'gd' with Telescope definition
map("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { desc = "LSP Definition (Telescope)" })

-- Replace 'gD' with Telescope references/declarations
map("n", "gD", "<cmd>Telescope lsp_references<CR>", { desc = "LSP References (Telescope)" })

-- Optional: Replace 'gi' for implementations
map("n", "gi", "<cmd>Telescope lsp_implementations<CR>", { desc = "LSP Implementations (Telescope)" })

-- Floating terminal
map("n", "<leader>ii", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm0" }
end, { desc = "Toggle floating terminal - 0" })
map("n", "<leader>i1", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm1" }
end, { desc = "Toggle floating terminal - 1" })
map("n", "<leader>i2", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm2" }
end, { desc = "Toggle floating terminal - 2" })
map("n", "<leader>i3", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm3" }
end, { desc = "Toggle floating terminal - 3" })
map("n", "<leader>i4", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm4" }
end, { desc = "Toggle floating terminal - 4" })
map("n", "<leader>i5", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm5" }
end, { desc = "Toggle floating terminal - 5" })
map("n", "<leader>i6", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm6" }
end, { desc = "Toggle floating terminal - 6" })
map("n", "<leader>i7", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm7" }
end, { desc = "Toggle floating terminal - 7" })
map("n", "<leader>i8", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm8" }
end, { desc = "Toggle floating terminal - 8" })
map("n", "<leader>i9", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm9" }
end, { desc = "Toggle floating terminal - 9" })
map("t", "<C-Esc>", "<C-\\><C-n>", { noremap = true, silent = true, desc = "Terminal: back to Normal mode" })

-- Trouble: workspace diagnostics
map("n", "<leader>tt", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Workspace diagnostics (Trouble)" })
map("n", "<leader>tb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer diagnostics (Trouble)" })
