return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local util = require("lspconfig.util")

      -- Helper function to find the nearest go.mod file
      local function find_go_mod(fname)
        -- First try to find go.mod
        local go_mod_root = util.root_pattern("go.mod")(fname)
        if go_mod_root then
          return go_mod_root
        end

        -- Fallback to .git
        return util.root_pattern(".git")(fname) or vim.fs.dirname(fname)
      end

      -- Configure both servers with the same root_dir detection
      opts.servers = opts.servers or {}

      -- Configure gopls
      opts.servers.gopls = opts.servers.gopls or {}
      opts.servers.gopls.root_dir = find_go_mod

      -- Configure golangci_lint_ls to use the same root detection
      opts.servers.golangci_lint_ls = opts.servers.golangci_lint_ls or {}
      opts.servers.golangci_lint_ls.root_dir = find_go_mod

      -- This helps golangci-lint find the correct module
      opts.servers.golangci_lint_ls.init_options = {
        command = {
          "golangci-lint",
          "run",
          "--out-format",
          "json",
          "--issues-exit-code=1",
        },
      }
    end,
  },
}
