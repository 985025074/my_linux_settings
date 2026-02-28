return {
  {
    'preservim/vim-markdown',
  },
  {
    'folke/persistence.nvim',
    event = 'VimEnter',
    config = function(_, opts)
      require('persistence').setup(opts)
      -- 添加会话选项，避免 Neotree 错误
      vim.opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }
      vim.keymap.set('n', '<leader>ls', function()
        require('persistence').load()
      end, { desc = '加载当前目录的会话 load setion' })
      vim.keymap.set('n', '<leader>lS', function()
        require('persistence').select()
      end, { desc = '选择要加载的会话 load Select' })
      vim.keymap.set('n', '<leader>lr', function()
        require('persistence').load { last = true }
      end, { desc = '加载最近一次的会话 load recent' })
      vim.keymap.set('n', '<leader>nl', function()
        require('persistence').stop()
      end, { desc = '停止会话持久化（退出时不保存） not load' })
    end,
  },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup {
        options = {

          numbers = 'ordinal',
        },
      }
      -- 统一设置快捷键选项
      local opts = { noremap = true, silent = true }

      -- 关闭当前 buffer
      vim.keymap.set('n', '<leader>gbc', '<cmd>bdelete<CR>', vim.tbl_extend('force', opts, { desc = '关闭当前buffer' }))

      -- 关闭其余 buffer（保留当前）
      vim.keymap.set('n', '<leader>gbo', '<cmd>BufferLineCloseOthers<CR>', vim.tbl_extend('force', opts, { desc = '关闭其余buffer' }))
      -- 关闭右侧buffer
      vim.keymap.set('n', '<leader>gbr', '<cmd>BufferLineCloseRight<CR>', vim.tbl_extend('force', opts, { desc = '关闭右侧buffer' }))
      -- 跳转到指定序号的 buffer（1-6）
      for i = 1, 6 do
        vim.keymap.set(
          'n',
          '<leader>gb' .. i,
          '<cmd>BufferLineGoToBuffer ' .. i .. '<CR>',
          vim.tbl_extend('force', opts, { desc = '跳转到' .. i .. '号buffer' })
        )
      end
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        -- 设置终端大小，支持根据终端方向动态调整
        size = function(term)
          if term.direction == 'horizontal' then
            return 15 -- 水平方向时终端占用15行
          elseif term.direction == 'vertical' then
            return vim.o.columns * 0.4 -- 垂直方向时占用屏幕40%的宽度
          end
        end,

        -- 设置打开终端的快捷键
        open_mapping = [[<c-t>]], -- 使用Ctrl+t打开终端

        -- 回调函数：终端创建、打开、关闭时触发
        on_create = function(t)
          print 'Terminal created!'
        end,
        on_open = function(t)
          print 'Terminal opened!'
        end,
        on_close = function(t)
          print 'Terminal closed!'
        end,

        -- 终端输出回调（处理标准输出、标准错误）
        on_stdout = function(t, job, data, name)
          print('stdout:', data)
        end,
        on_stderr = function(t, job, data, name)
          print('stderr:', data)
        end,

        -- 进程退出时的回调
        on_exit = function(t, job, exit_code, name)
          print('Process exited with code', exit_code)
        end,

        -- 隐藏行号
        hide_numbers = true,

        -- 终端高亮设置
        highlights = {
          Normal = { guibg = '#2E3440' }, -- 设置终端背景颜色为暗色
          NormalFloat = { link = 'Normal' }, -- 浮动窗口继承Normal的样式
          FloatBorder = { guifg = '#81A1C1', guibg = '#2E3440' }, -- 设置浮动窗口边框颜色
        },

        -- 终端背景阴影设置
        shade_terminals = true, -- 启用背景阴影
        shading_factor = -30, -- 阴影强度
        start_in_insert = true, -- 启动时进入插入模式
        insert_mappings = true, -- 插入模式下启用映射
        terminal_mappings = true, -- 终端模式下启用映射

        -- 窗口大小和模式保持
        persist_size = true,
        persist_mode = true, -- 记住终端的模式

        -- 设置终端打开方向
        direction = 'vertical', -- 默认水平打开

        -- 关闭终端时自动退出
        close_on_exit = true,

        -- 自定义shell，使用系统默认shell
        shell = vim.o.shell,

        -- 启用自动滚动
        auto_scroll = true,

        -- 浮动窗口配置（仅在方向设置为'float'时有效）
        float_opts = {
          border = 'single', -- 单边框
          width = 80, -- 宽度
          height = 20, -- 高度
          row = 2, -- 距离屏幕顶部2行
          col = 10, -- 距离屏幕左侧10列
          winblend = 3, -- 窗口透明度
          zindex = 10, -- 设置浮动窗口的堆叠顺序
          title_pos = 'center', -- 设置标题居中显示
        },

        -- 设置窗口栏
        winbar = {
          enabled = true,
          name_formatter = function(term) -- 格式化终端名称
            return 'Terminal: ' .. (term.name or 'Unnamed')
          end,
        },

        -- 响应式布局：当屏幕宽度小于一定值时终端堆叠显示
        responsiveness = {
          horizontal_breakpoint = 100, -- 当屏幕宽度小于100列时终端堆叠
        },
      }
    end,
  },
}
