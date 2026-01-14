local M = { running = false, has_error = false }
local utils = require 'custom.utils'

M.run = function(files)
  local files_str = table.concat(files, ' ')
  local output_file = string.format('tmp/rspec_failures_%s.txt', os.date '%Y%m%d_%H%M%S')
  local output_buf = nil

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match 'RSpec$' then
      output_buf = b
      vim.api.nvim_set_option_value('modifiable', true, { buf = output_buf })
      vim.api.nvim_set_option_value('readonly', false, { buf = output_buf })
      break
    end
  end

  if not output_buf then
    output_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(output_buf, 'RSpec')
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = output_buf })
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = output_buf })
    vim.api.nvim_set_option_value('swapfile', false, { buf = output_buf })
  end
  local output_msg = { 'RSpec failures will be at: ' .. output_file }

  if vim.api.nvim_buf_line_count(output_buf) == 1 then
    vim.api.nvim_buf_set_lines(output_buf, 0, 0, false, output_msg)
  else
    utils.append_to_readonly_buf(output_buf, { '', '######## New Session ########' })
    utils.append_to_readonly_buf(output_buf, output_msg)
  end
  vim.api.nvim_set_option_value('modifiable', false, { buf = output_buf })
  vim.api.nvim_set_option_value('readonly', true, { buf = output_buf })

  utils.scroll_window(output_buf)

  local cmd = {
    'env',
    'bin/bundle',
    'exec',
    'rspec',
    '--format',
    'documentation',
    '--format',
    'failures',
    '--out',
    output_file,
  }

  if files_str and files_str ~= '' then
    table.insert(cmd, files_str)
  end

  print('RSpec is running with files: ' .. files_str)
  M.running = true
  vim.system(cmd, {
    text = true,
    stdout = function(_, data)
      if data then
        utils.append_to_readonly_buf(output_buf, { data })
        utils.scroll_window(output_buf)
      end
    end,
    stderr = function(_, data)
      if data then
        utils.append_to_readonly_buf(output_buf, { data })
        utils.scroll_window(output_buf)
      end
      M.has_error = true
    end,
  }, function(_)
    M.running = false
    if not M.has_error then
      vim.schedule(function()
        print 'RSpec is done!'
        local failures = vim.fn.readfile(output_file)
        if #failures > 0 then
          vim.fn.setqflist({}, 'r', {
            title = 'RSpec',
            lines = failures,
          })
          vim.cmd 'copen'
        end
      end)
    else
      M.has_error = false
    end
  end)
end

M.on_attach = function(bufnr)
  local function map(mode, l, r, opts)
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, l, r, opts)
  end
  map('n', '<leader>rt', '<cmd>RSpec<cr>', { desc = '[R]un Rspec' })
end

-- This is a basic plugin for running RSpec tests
-- :RSpec All will run all tests
-- :RSpec will run current test
-- :RSpec /path/to/a/file /path/to/another/file will run all tests on those file
-- :RSpec % will run all tests on current file
return {
  event = 'BufReadPre',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/plugins',
  name = 'rspec.nvim',
  opts = {},
  config = function()
    vim.api.nvim_create_autocmd('BufReadPost', {
      -- Only enable for files that match common RSpec test patterns
      pattern = { '*_spec.rb', '*_test.rb' },
      callback = function()
        vim.api.nvim_buf_create_user_command(0, 'RSpec', function(opts)
          if M.running then
            print 'RSpec already running'
            return
          end

          local files

          if opts.fargs[1] == nil then
            files = utils.get_current_file_with_line_number()
          elseif string.lower(opts.fargs[1]) == 'all' then
            files = {}
          else
            files = utils.get_files_or_default(opts.fargs[1])
          end

          M.run(files)
        end, {
          nargs = '?',
          desc = 'Runs RSpec',
        })
        M.on_attach(vim.api.nvim_get_current_buf())
      end,
    })
  end,
}
