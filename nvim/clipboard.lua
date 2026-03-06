-- OSC52 Clipboard integration for Neovim
-- This configuration automatically uses OSC52 for clipboard operations in SSH sessions

-- Check if we're in an SSH session or if osc52 command is available
local in_ssh = os.getenv("SSH_CONNECTION") ~= nil or 
               os.getenv("SSH_CLIENT") ~= nil or 
               os.getenv("SSH_TTY") ~= nil

local has_osc52 = vim.fn.executable("osc52") == 1

if in_ssh or has_osc52 then
  -- Use OSC52 clipboard for SSH sessions or when osc52 is available
  vim.g.clipboard = {
    name = "osc52",
    copy = {
      ["+"] = "osc52",
      ["*"] = "osc52",
    },
    paste = {
      ["+"] = function()
        -- For SSH sessions, paste is handled by the terminal
        -- Return empty to avoid errors
        return {}
      end,
      ["*"] = function()
        return {}
      end,
    },
  }
  
  -- Direct OSC52 implementation in Lua as fallback
  local function osc52_copy(text)
    if not text or text == "" then
      return
    end
    
    -- Use external osc52 command if available, otherwise use Lua implementation
    if has_osc52 then
      vim.fn.system("echo -n " .. vim.fn.shellescape(text) .. " | osc52")
    else
      local base64_text = vim.fn.system("echo -n " .. vim.fn.shellescape(text) .. " | base64 | tr -d '\n'")
      local osc52_sequence = "\027]52;c;" .. base64_text .. "\007"
      io.write(osc52_sequence)
      io.flush()
    end
  end
  
  -- Enhanced key mappings for OSC52 copy
  vim.keymap.set("v", "<leader>y", function()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    if #lines > 0 then
      -- Handle partial line selection
      if start_pos[2] == end_pos[2] then
        -- Single line selection
        local line = lines[1]
        local text = string.sub(line, start_pos[3], end_pos[3])
        osc52_copy(text)
      else
        -- Multi-line selection
        local text = table.concat(lines, "\n")
        osc52_copy(text)
      end
      vim.notify("Copied to clipboard via OSC52", vim.log.levels.INFO)
    end
  end, { desc = "Copy selection to system clipboard via OSC52" })
  
  -- Copy current line
  vim.keymap.set("n", "<leader>yy", function()
    local line = vim.api.nvim_get_current_line()
    osc52_copy(line)
    vim.notify("Copied line to clipboard via OSC52", vim.log.levels.INFO)
  end, { desc = "Copy current line to system clipboard via OSC52" })
  
else
  -- Use system clipboard for local sessions
  vim.opt.clipboard = "unnamedplus"
end