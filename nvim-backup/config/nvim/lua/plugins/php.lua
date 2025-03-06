return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- PHP Prettier integration
      _G.PrettierPhpCursor = function()
        -- Save the current cursor position
        local save_pos = vim.fn.getpos(".")
        -- Get the current file path
        local file_path = vim.fn.expand("%:p")
        -- Get the current buffer content
        local current_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        -- Create a temporary file
        local temp_file = vim.fn.tempname()
        -- Write current content to the temporary file
        vim.fn.writefile(current_content, temp_file)
        -- Run Prettier on the temporary file
        local prettier_cmd = string.format("prettier --stdin-filepath %s --parser php < %s", file_path, temp_file)
        local formatted_content = vim.fn.system(prettier_cmd)
        -- Check if Prettier succeeded
        if vim.v.shell_error == 0 then
          -- If successful, update the buffer with the formatted content
          vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.split(formatted_content, "\n"))
          -- Restore the cursor position
          vim.fn.setpos(".", save_pos)
          print("Prettier formatting applied successfully.")
        else
          -- If there was an error, print it without modifying the buffer
          print("Prettier error: " .. formatted_content)
        end
        -- Remove the temporary file
        vim.fn.delete(temp_file)
      end

      -- Define custom command :PrettierPhp
      vim.api.nvim_create_user_command("PrettierPhp", _G.PrettierPhpCursor, {})

      -- Autoformat PHP files on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.php",
        callback = function()
          _G.PrettierPhpCursor()
        end,
      })

      -- Configure PHP LSP if needed
      opts.servers = opts.servers or {}
      opts.servers.intelephense = opts.servers.intelephense or {}

      return opts
    end,
  },
}
