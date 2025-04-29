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

      -- Helper function to find .golangci.yml configuration
      local function find_golangci_config(fname)
        -- First try to find go.mod directory
        local go_mod_root = util.root_pattern("go.mod")(fname)
        if go_mod_root then
          -- Check if .golangci.yml exists in the same directory as go.mod
          local config_path = util.path.join(go_mod_root, ".golangci.yml")
          if vim.fn.filereadable(config_path) == 1 then
            return go_mod_root
          end
        end
        -- If not found in go.mod directory, try .git directory level
        local git_root = util.root_pattern(".git")(fname)
        if git_root then
          local config_path = util.path.join(git_root, ".golangci.yml")
          if vim.fn.filereadable(config_path) == 1 then
            return git_root
          end
        end
        -- If no config found, return the directory of the file
        return util.path.dirname(fname)
      end

      -- Configure both servers with the same root_dir detection
      opts.servers = opts.servers or {}

      -- Configure golangci_lint_ls
      opts.servers.golangci_lint_ls = opts.servers.golangci_lint_ls or {}
      opts.servers.golangci_lint_ls.root_dir = find_go_mod

      local configPath = util.path.join(find_golangci_config(vim.fn.expand("%")), ".golangci.yml")

      -- Use golangci-lint 2.0 format with proper flags for LSP integration
      opts.servers.golangci_lint_ls.init_options = {
        command = {
          "golangci-lint",
          "run",
          "--output.json.path",
          "stdout",
          "--show-stats=false",
          "--issues-exit-code=1",
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
      -- Add improved debug command
      vim.api.nvim_create_user_command("GolangCIDebug", function()
        -- Create a timestamped temp file to capture the output
        local timestamp = os.date("%Y%m%d-%H%M%S")
        local temp_dir = vim.fn.expand("~/.cache/golangci-lint-debug")
        local temp_file = temp_dir .. "/golangci-lint-debug-" .. timestamp .. ".log"

        -- Create the directory if it doesn't exist
        vim.fn.mkdir(temp_dir, "p")

        -- Get current file and its directory
        local current_file = vim.fn.expand("%:p")
        local current_dir = vim.fn.expand("%:p:h")

        -- Create a new buffer for command output
        local buf = vim.api.nvim_create_buf(false, true)
        local width = vim.api.nvim_get_option("columns")
        local height = vim.api.nvim_get_option("lines")
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = math.floor(width * 0.8),
          height = math.floor(height * 0.8),
          row = math.floor(height * 0.1),
          col = math.floor(width * 0.1),
          style = "minimal",
          border = "rounded",
        })

        -- Set buffer options
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(buf, "swapfile", false)
        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

        -- Initial content
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "Running golangci-lint debug...",
          "Current file: " .. current_file,
          "Current directory: " .. current_dir,
          "Output will be saved to: " .. temp_file,
          "",
          "Please wait...",
        })

        -- Run the command asynchronously
        vim.fn.jobstart(
          "cd " .. vim.fn.getcwd() .. " && golangci-lint run --verbose --output.json.path " .. temp_file .. " 2>&1",
          {
            on_stdout = function(_, data)
              if data then
                vim.schedule(function()
                  vim.api.nvim_buf_set_option(buf, "modifiable", true)
                  vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
                  vim.api.nvim_buf_set_option(buf, "modifiable", false)
                end)
              end
            end,
            on_stderr = function(_, data)
              if data then
                vim.schedule(function()
                  vim.api.nvim_buf_set_option(buf, "modifiable", true)
                  vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
                  vim.api.nvim_buf_set_option(buf, "modifiable", false)
                end)
              end
            end,
            on_exit = function(_, exit_code)
              vim.schedule(function()
                vim.api.nvim_buf_set_option(buf, "modifiable", true)
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
                  "",
                  "golangci-lint completed with exit code: " .. exit_code,
                  "Output saved to: " .. temp_file,
                  "",
                  "Press 'o' to open the output file in a split",
                  "Press 'q' to close this window",
                })
                vim.api.nvim_buf_set_option(buf, "modifiable", false)
              end)
            end,
          }
        )

        -- Set up keymappings
        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf, noremap = true })

        vim.keymap.set("n", "o", function()
          vim.cmd("vsplit " .. temp_file)
        end, { buffer = buf, noremap = true })
      end, { desc = "Debug golangci-lint output with live feedback" })

      -- Add info command
      vim.api.nvim_create_user_command("GolangCIInfo", function()
        local current_file = vim.fn.expand("%")
        local go_mod_root = find_go_mod(current_file)
        local golangci_root = find_golangci_config(current_file)
        local config_path = util.path.join(golangci_root, ".golangci.yml")

        -- Create a buffer to show the information
        local buf = vim.api.nvim_create_buf(false, true)
        local width = vim.api.nvim_get_option("columns")
        local height = vim.api.nvim_get_option("lines")
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = math.floor(width * 0.8),
          height = math.floor(height * 0.8),
          row = math.floor(height * 0.1),
          col = math.floor(width * 0.1),
          style = "minimal",
          border = "rounded",
        })

        -- Set buffer options
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(buf, "swapfile", false)
        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

        -- Prepare the information
        local info = {
          "GolangCI-Lint Information",
          "========================",
          "",
          "Current File: " .. current_file,
          "Go Module Root: " .. go_mod_root,
          "GolangCI Root: " .. golangci_root,
          "Config File: " .. config_path,
          "",
          "Config File Exists: " .. (vim.fn.filereadable(config_path) == 1 and "Yes" or "No"),
          "",
          "Press 'q' to close this window",
        }

        -- Write the information to the buffer
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, info)

        -- Make the buffer read-only
        vim.api.nvim_buf_set_option(buf, "modifiable", false)

        -- Set up keymapping to close the window
        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf, noremap = true })
      end, { desc = "Show golangci-lint configuration information" })

      return opts
    end,
  },
}
