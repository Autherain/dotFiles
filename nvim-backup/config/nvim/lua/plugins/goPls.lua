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

      -- Use golangci-lint 2.0 format with proper flags for LSP integration
      opts.servers.golangci_lint_ls.init_options = {
        command = {
          "golangci-lint",
          "run",
          "--output.json.path",
          "stdout", -- Direct JSON output to stdout
          "--path-prefix",
          "", -- Empty path prefix helps with file path matching
          "--issues-exit-code=0", -- Don't fail on issues (prevents LSP errors)
          "--output.text.print-issued-lines=false", -- Cleaner output
          "--output.text.print-linter-name=true", -- Include linter names in output
          "--uniq-by-line=false", -- Show all issues on the same line
          "--show-stats=false", -- Don't show stats to keep output clean
        },
      }

      -- Custom on_attach function to improve LSP experience with golangci-lint
      local original_on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr)
        -- Call the original on_attach if it exists
        if original_on_attach then
          original_on_attach(client, bufnr)
        end

        -- If this is the golangci-lint client, set up specific config
        if client.name == "golangci_lint_ls" then
          -- Set lower update time for faster feedback
          vim.opt_local.updatetime = 1000

          -- Create buffer-local command to manually run linter
          vim.api.nvim_buf_create_user_command(bufnr, "GolangCILint", function()
            vim.lsp.buf.execute_command({
              command = "_golangci-lint-languageserver.showReferences",
              arguments = {},
            })
          end, { desc = "Run golangci-lint" })
        end
      end

      -- Add debug command
      vim.api.nvim_create_user_command("GolangCIDebug", function()
        -- Create a temp file to capture the output
        local temp_file = "/tmp/golangci-lint-debug.log"

        -- Run golangci-lint with verbose output
        local cmd = "cd "
          .. vim.fn.getcwd()
          .. " && golangci-lint run --verbose --output.json.path "
          .. temp_file
          .. " 2>&1"
        os.execute(cmd)

        -- Open the file in a split
        vim.cmd("vsplit " .. temp_file)
      end, { desc = "Debug golangci-lint output" })

      return opts
    end,
  },
}
