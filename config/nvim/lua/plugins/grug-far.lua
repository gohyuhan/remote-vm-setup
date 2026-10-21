return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    config = function(_, opts)
      vim.api.nvim_create_user_command("GrugFarOpenFloat", function()
        local w = math.floor(vim.o.columns * 0.9)
        local h = math.floor(vim.o.lines * 0.9)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].bufhidden = "wipe"
        vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = w,
          height = h,
          row = math.floor((vim.o.lines - h) / 2),
          col = math.floor((vim.o.columns - w) / 2),
          style = "minimal",
          border = "rounded",
        })
      end, {})
      require("grug-far").setup(opts)
    end,
    keys = {
      {
        "<leader>sr",
        function()
          require("grug-far").open { windowCreationCommand = "GrugFarOpenFloat", transient = true }
        end,
        desc = "Search & Replace (grug-far)",
      },
      {
        "<leader>sw",
        function()
          require("grug-far").open {
            windowCreationCommand = "GrugFarOpenFloat",
            transient = true,
            prefills = { search = vim.fn.expand "<cword>" },
          }
        end,
        desc = "Search & Replace word under cursor",
      },
      {
        "<leader>sr",
        function()
          require("grug-far").with_visual_selection { windowCreationCommand = "GrugFarOpenFloat", transient = true }
        end,
        mode = "v",
        desc = "Search & Replace selection",
      },
    },
    opts = {
      headerMaxWidth = 80,
      keymaps = {
        replace = { n = "rr" },
        qflist = { n = "rq" },
        syncLocations = { n = "rs" },
        syncLine = { n = "rl" },
        close = { n = "rc" },
        historyOpen = { n = "rt" },
        historyAdd = { n = "ra" },
        refresh = { n = "rf" },
        openLocation = { n = "ro" },
        openNextLocation = { n = "<down>" },
        openPrevLocation = { n = "<up>" },
        gotoLocation = { n = "<enter>" },
        pickHistoryEntry = { n = "<enter>" },
        abort = { n = "rb" },
        help = { n = "g?" },
        toggleShowCommand = { n = "rw" },
        swapEngine = { n = "re" },
        previewLocation = { n = "ri" },
        swapReplacementInterpreter = { n = "rx" },
        applyNext = { n = "rj" },
        applyPrev = { n = "rk" },
        syncNext = { n = "rn" },
        syncPrev = { n = "rp" },
        syncFile = { n = "rv" },
        nextInput = { n = "<tab>" },
        prevInput = { n = "<s-tab>" },
      },
    },
  },
}
