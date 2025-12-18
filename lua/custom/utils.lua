local M = {}

local collect_lines = function(lines)
  local processed_lines = {}
  for _, line in ipairs(lines) do
    if type(line) == 'string' and line:find '\n' then
      for split_line in line:gmatch '[^\n]+' do
        table.insert(processed_lines, split_line)
      end
    else
      table.insert(processed_lines, line)
    end
  end
  return processed_lines
end

M.get_files_or_default = function(file_pattern)
  local get_current_file = function()
    local file = vim.fn.expand '%:p'
    return { file }
  end
  if file_pattern then
    local files = vim.fn.glob(file_pattern, false, true)
    if #files == 0 then
      return get_current_file()
    end
    return files
  else
    return get_current_file()
  end
end

M.append_to_readonly_buf = function(buf, lines)
  vim.schedule(function()
    local ok, _ = pcall(function()
      vim.api.nvim_set_option_value('readonly', false, { buf = buf })
      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

      lines = collect_lines(lines)

      vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

      vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
      vim.api.nvim_set_option_value('readonly', true, { buf = buf })
    end)
    if not ok then
      vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
      vim.api.nvim_set_option_value('readonly', true, { buf = buf })
    end
  end)
end

M.scroll_window = function(bufnr)
  vim.schedule(function()
    local current_win = vim.api.nvim_get_current_win()

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == bufnr and win ~= current_win then
        local last_line = vim.api.nvim_buf_line_count(bufnr)
        vim.api.nvim_win_set_cursor(win, { last_line, 0 })
      end
    end
  end)
end

return M
