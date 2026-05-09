-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    event_handlers = {
      {
        event = 'neo_tree_buffer_enter',
        handler = function()
          vim.opt_local.number = true
          vim.opt_local.relativenumber = true
        end,
      },
    },
    filesystem = {
      commands = {
        copy_absolute_path = function(state)
          local node = state.tree:get_node()
          local path = node.path or node:get_id()
          vim.fn.setreg('+', path)
          vim.fn.setreg('"', path)
          vim.notify('Copied path: ' .. path)
        end,
        copy_relative_path = function(state)
          local node = state.tree:get_node()
          local path = vim.fn.fnamemodify(node.path or node:get_id(), ':.')
          vim.fn.setreg('+', path)
          vim.fn.setreg('"', path)
          vim.notify('Copied relative path: ' .. path)
        end,
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
          ['Y'] = 'copy_absolute_path',
          ['gy'] = 'copy_relative_path',
        },
      },
    },
  },
}
