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
        return util.root_pattern(".git")(fname) or util.path.dirname(fname)
      end

      -- Configure both servers with the same root_dir detection
      opts.servers = opts.servers or {}

      -- Configure gopls
      opts.servers.gopls = opts.servers.gopls or {}
      opts.servers.gopls.root_dir = find_go_mod

      -- Configure golangci_lint_ls
      opts.servers.golangci_lint_ls = opts.servers.golangci_lint_ls or {}
      opts.servers.golangci_lint_ls.root_dir = find_go_mod

      -- This approach ensures golangci-lint output is processed by the LSP
      -- and shown directly in the editor, while handling possible errors
      opts.servers.golangci_lint_ls.init_options = {
        command = {
          "bash",
          "-c",
          "set -o pipefail; TERM=dumb COLORTERM='' golangci-lint run --out-format json --show-stats=false --print-resources-usage=false 2>/dev/null",
        },
      }

      -- Add a Neovim command to examine the debug output
      vim.api.nvim_create_user_command("GolangCIDebug", function()
        vim.cmd("vsplit /tmp/golangci-lint-errors.log")
      end, {})
    end,
  },
}
