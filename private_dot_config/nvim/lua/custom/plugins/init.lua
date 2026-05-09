local rust_toolchain_rust_analyzer_cache = {}

local function read_rust_toolchain(root)
  if not root then
    return nil
  end

  local rust_toolchain_toml = root .. '/rust-toolchain.toml'
  if vim.fn.filereadable(rust_toolchain_toml) == 1 then
    for _, line in ipairs(vim.fn.readfile(rust_toolchain_toml)) do
      local channel = line:match '^%s*channel%s*=%s*"(.-)"'
      if channel then
        return channel
      end
    end
  end

  local rust_toolchain = root .. '/rust-toolchain'
  if vim.fn.filereadable(rust_toolchain) == 1 then
    local first_line = vim.fn.readfile(rust_toolchain)[1]
    if first_line and first_line ~= '' and not first_line:match '^%s*%[' then
      return vim.trim(first_line)
    end
  end

  return nil
end

local function resolve_rust_analyzer_cmd()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start = bufname ~= '' and vim.fs.dirname(bufname) or vim.uv.cwd()
  local root = start and vim.fs.root(start, { 'rust-toolchain.toml', 'rust-toolchain', 'Cargo.toml' }) or nil
  local toolchain = read_rust_toolchain(root)

  if toolchain then
    local cached = rust_toolchain_rust_analyzer_cache[toolchain]
    if cached ~= nil then
      return cached
    end

    local rustup_which = vim.fn.systemlist { 'rustup', 'which', '--toolchain', toolchain, 'rust-analyzer' }
    if vim.v.shell_error == 0 and #rustup_which > 0 and vim.fn.executable(rustup_which[1]) == 1 then
      rust_toolchain_rust_analyzer_cache[toolchain] = { rustup_which[1] }
      return rust_toolchain_rust_analyzer_cache[toolchain]
    end
  end

  return { 'rust-analyzer' }
end

local function run_current_jupytext_cell()
  local bufnr = 0
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local function get_line(lnum)
    return vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ''
  end

  local function is_cell_marker(line)
    return line:match '^%s*#%s*%%%%' ~= nil
  end

  local start_line = cursor_line
  while start_line > 1 and not is_cell_marker(get_line(start_line)) do
    start_line = start_line - 1
  end
  if is_cell_marker(get_line(start_line)) then
    start_line = start_line + 1
  else
    start_line = 1
  end

  local end_line = cursor_line + 1
  while end_line <= total_lines and not is_cell_marker(get_line(end_line)) do
    end_line = end_line + 1
  end
  end_line = end_line - 1

  while start_line <= end_line and get_line(start_line):match '^%s*$' do
    start_line = start_line + 1
  end
  while end_line >= start_line and get_line(end_line):match '^%s*$' do
    end_line = end_line - 1
  end

  if start_line > end_line then
    vim.notify('当前 Jupytext cell 没有可执行代码', vim.log.levels.WARN)
    return
  end

  vim.fn.MoltenEvaluateRange(start_line, end_line)
end

local function jump_jupytext_cell(direction)
  local flags = direction == 'prev' and 'bW' or 'W'
  local target = vim.fn.search([[^\s*#\s*%%]], flags)
  if target == 0 then
    vim.notify(direction == 'prev' and '前面没有 Jupyter cell' or '后面没有 Jupyter cell', vim.log.levels.INFO)
  end
end

return {
  {
    'OXY2DEV/markview.nvim',
    lazy = false,
    keys = {
      { '<leader>mm', '<cmd>Markview toggle<CR>', desc = '[M]arkview toggle' },
      { '<leader>ms', '<cmd>Markview splitToggle<CR>', desc = '[M]arkview [S]plit toggle' },
      { '<leader>mh', '<cmd>Markview hybridToggle<CR>', desc = '[M]arkview [H]ybrid toggle' },
    },
    opts = {
      preview = {
        icon_provider = 'devicons',
      },
    },
  },
  -- 纠正低效移动习惯并给出更高效的 motion 提示
  {
    'm4xshen/hardtime.nvim',
    lazy = false,
    dependencies = {
      'MunifTanjim/nui.nvim',
      {
        'rcarriga/nvim-notify',
        opts = {
          minimum_width = 20,
          render = 'minimal',
          stages = 'static',
          timeout = 1800,
          top_down = true,
        },
      },
    },
    keys = {
      { '<leader>tm', '<cmd>Hardtime toggle<CR>', desc = '[T]oggle Hardti[m]e' },
      { '<leader>tM', '<cmd>Hardtime report<CR>', desc = 'Hardtime Report' },
    },
    opts = {
      callback = function(text)
        local ok, notify = pcall(require, 'notify')
        if ok then
          notify(text, vim.log.levels.INFO, {
            hide_from_history = true,
            render = 'minimal',
            timeout = 1800,
          })
          return
        end

        vim.notify(text, vim.log.levels.INFO, { timeout = 1800 })
      end,
      max_time = 1500,
      max_count = 4,
      disable_mouse = false,
      hints = {
        ['jjjj'] = {
          message = function()
            return '试试 5j / <C-d>；代码结构跳转可用 ]]，同屏跳转可用 s / S (Flash).'
          end,
          length = 4,
        },
        ['kkkk'] = {
          message = function()
            return '试试 5k / <C-u>；代码结构跳转可用 [[，同屏跳转可用 s / S (Flash).'
          end,
          length = 4,
        },
        ['wwww'] = {
          message = function()
            return '别一直按 w：当前行用 f / t，同屏用 s (Flash)，更远用 / 搜索.'
          end,
          length = 4,
        },
        ['bbbb'] = {
          message = function()
            return '别一直按 b：当前行用 F / T，同屏用 s (Flash)，更远用 ? 搜索.'
          end,
          length = 4,
        },
        [';;;'] = {
          message = function()
            return '别一直追 ;：直接用 s (Flash) 或 S (Treesitter Flash).'
          end,
          length = 3,
        },
        [',,,'] = {
          message = function()
            return '别一直追 ,：直接用 s (Flash) 或 S (Treesitter Flash).'
          end,
          length = 3,
        },
      },
    },
  },
  -- 终端里的平滑光标拖影，做成偏克制的一版
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>ts', '<cmd>SmearCursorToggle<CR>', desc = '[T]oggle [S]mear cursor' },
    },
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      scroll_buffer_space = true,
      smear_insert_mode = false,
      smear_replace_mode = false,
      smear_terminal_mode = false,
      time_interval = 10,
      stiffness = 0.68,
      trailing_stiffness = 0.58,
      damping = 0.93,
      trailing_exponent = 1.8,
      distance_stop_animating = 0.2,
      max_length = 16,
      transparent_bg_fallback_color = '#1a1b26',
      filetypes_disabled = {
        'aerial',
        'checkhealth',
        'help',
        'lazy',
        'mason',
        'neo-tree',
        'notify',
        'qf',
        'TelescopePrompt',
        'trouble',
      },
    },
  },
  {
    'keaising/im-select.nvim',
    config = function()
      require('im_select').setup {
        default_im_select = 'keyboard-us',
        default_command = 'fcitx5-remote',
        set_default_events = { 'InsertLeave', 'CmdlineLeave', 'FocusGained' },
        set_previous_events = { 'InsertEnter' },
      }
    end,
  },
  {
    'theHamsta/nvim-dap-virtual-text',
    opts = {
      commented = true,
      virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',
    },
  },
  {
    'stevearc/overseer.nvim',
    cmd = { 'OverseerOpen', 'OverseerToggle', 'OverseerRun', 'OverseerShell', 'OverseerTaskAction' },
    keys = {
      { '<leader>or', '<cmd>OverseerRun<CR>', desc = 'Overseer run task' },
      { '<leader>oo', '<cmd>OverseerToggle right<CR>', desc = 'Overseer toggle list' },
      { '<leader>os', '<cmd>OverseerShell<CR>', desc = 'Overseer shell task' },
      { '<leader>oa', '<cmd>OverseerTaskAction<CR>', desc = 'Overseer task action' },
    },
    opts = {
      dap = true,
      component_aliases = {
        default = {
          'on_exit_set_status',
          'on_complete_notify',
          { 'on_complete_dispose', require_view = { 'SUCCESS', 'FAILURE' } },
          { 'on_output_quickfix', tail = true },
          { 'open_output', on_complete = 'always', direction = 'vertical' },
        },
        default_vscode = {
          'default',
          'on_result_diagnostics',
        },
        default_builtin = {
          'on_exit_set_status',
          'on_complete_dispose',
          { 'unique', soft = true },
          { 'on_output_quickfix', tail = true },
          { 'open_output', on_complete = 'always', direction = 'vertical' },
        },
      },
      output = {
        use_terminal = true,
      },
      task_list = {
        direction = 'right',
        min_width = 40,
        max_width = { 80, 0.35 },
        default_detail = 1,
      },
    },
  },
  {
    'folke/persistence.nvim',
    event = 'VimEnter',
    config = function(_, opts)
      require('persistence').setup(opts)
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

        -- 隐藏行号
        hide_numbers = true,

        -- 终端高亮设置
        highlights = {
          Normal = { guibg = 'NONE' }, -- 跟随终端透明背景
          NormalFloat = { link = 'Normal' }, -- 浮动窗口继承Normal的样式
          FloatBorder = { guifg = '#81A1C1', guibg = 'NONE' }, -- 边框保留颜色，但不填背景
        },

        -- 终端背景阴影设置
        shade_terminals = false, -- 允许透出 kitty 背景
        shading_factor = 0,
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

  -- Cargo.toml 依赖版本提示（Rust）
  {
    'saecki/crates.nvim',
    event = 'BufRead Cargo.toml',
    opts = {
      completion = {
        crates = { enabled = true },
      },
    },
  },
  {
    'mrcjkb/rustaceanvim',
    version = '^8',
    lazy = false,
    dependencies = { 'mason-org/mason.nvim' },
    init = function()
      vim.g.rustaceanvim = {
        server = {
          cmd = resolve_rust_analyzer_cmd,
          default_settings = {
            ['rust-analyzer'] = {
              cargo = {
                allFeatures = true,
                targetDir = true,
              },
              check = {
                command = 'clippy',
                features = 'all',
                extraArgs = { '--no-deps' },
              },
              inlayHints = {
                bindingModeHints = {
                  enable = true,
                },
                closureReturnTypeHints = {
                  enable = 'always',
                },
                lifetimeElisionHints = {
                  enable = 'skip_trivial',
                },
                parameterHints = {
                  enable = true,
                },
                typeHints = {
                  enable = true,
                },
              },
            },
          },
        },
      }
    end,
  },

  -- Python 虚拟环境切换
  {
    'linux-cultist/venv-selector.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    cmd = 'VenvSelect',
    keys = {
      { '<leader>tv', '<cmd>VenvSelect<CR>', desc = '[T]oggle [V]env selector' },
    },
    opts = {},
  },

  -- Jupyter notebook 支持：Jupytext 负责 .ipynb <-> 文本，Molten 负责连接 kernel 执行代码。
  {
    'GCBallesteros/jupytext.nvim',
    lazy = false,
    config = function()
      require('jupytext').setup()

      local jupyter_cell_group = vim.api.nvim_create_augroup('custom-jupyter-cell-keymaps', { clear = true })
      vim.api.nvim_create_autocmd('FileType', {
        group = jupyter_cell_group,
        pattern = '*',
        callback = function(ev)
          local name = vim.api.nvim_buf_get_name(ev.buf)
          if not name:match '%.ipynb$' then
            return
          end

          vim.keymap.set('n', ']]', function()
            jump_jupytext_cell 'next'
          end, { buffer = ev.buf, desc = 'Next Jupyter cell', silent = true })
          vim.keymap.set('n', '[[', function()
            jump_jupytext_cell 'prev'
          end, { buffer = ev.buf, desc = 'Previous Jupyter cell', silent = true })
        end,
      })

      vim.api.nvim_create_autocmd('BufWritePost', {
        group = jupyter_cell_group,
        pattern = '*.ipynb',
        callback = function()
          local ok, status = pcall(require, 'molten.status')
          if ok and status.initialized() == 'Molten' then
            vim.cmd 'MoltenExportOutput!'
          end
        end,
      })

      vim.api.nvim_create_user_command('NewNotebook', function(opts)
        local path = opts.args
        if not path:match '%.ipynb$' then
          path = path .. '.ipynb'
        end

        if vim.fn.filereadable(path) == 1 then
          vim.cmd.edit(vim.fn.fnameescape(path))
          return
        end

        local notebook = {
          cells = {},
          metadata = {
            kernelspec = {
              display_name = 'Python 3',
              language = 'python',
              name = 'python3',
            },
            language_info = {
              codemirror_mode = {
                name = 'ipython',
              },
              file_extension = '.py',
              mimetype = 'text/x-python',
              name = 'python',
              nbconvert_exporter = 'python',
              pygments_lexer = 'ipython3',
            },
          },
          nbformat = 4,
          nbformat_minor = 5,
        }

        local parent = vim.fn.fnamemodify(path, ':h')
        if parent ~= '' and vim.fn.isdirectory(parent) == 0 then
          vim.fn.mkdir(parent, 'p')
        end

        local file = assert(io.open(path, 'w'))
        file:write(vim.json.encode(notebook))
        file:close()
        vim.cmd.edit(vim.fn.fnameescape(path))
      end, {
        nargs = 1,
        complete = 'file',
      })
    end,
  },
  {
    '3rd/image.nvim',
    event = 'VeryLazy',
    build = false,
    opts = {
      backend = 'kitty',
      processor = 'magick_cli',
      integrations = {
        markdown = { enabled = false },
        neorg = { enabled = false },
        asciidoc = { enabled = false },
      },
    },
  },
  {
    'benlubas/molten-nvim',
    version = '^1.0.0',
    lazy = false,
    build = ':UpdateRemotePlugins',
    dependencies = { '3rd/image.nvim' },
    keys = {
      { '<leader>ji', '<cmd>MoltenInit<CR>', desc = '[J]upyter [I]nit kernel' },
      { '<leader>jI', '<cmd>MoltenInfo<CR>', desc = '[J]upyter [I]nfo' },
      { '<leader>je', '<cmd>MoltenEvaluateOperator<CR>', desc = '[J]upyter [E]valuate operator' },
      { '<leader>jc', run_current_jupytext_cell, desc = '[J]upyter run current [C]ell' },
      { '<leader>jl', '<cmd>MoltenEvaluateLine<CR>', desc = '[J]upyter run [L]ine' },
      { '<leader>jv', ':<C-u>MoltenEvaluateVisual<CR>gv', mode = 'v', desc = '[J]upyter run [V]isual' },
      { '<leader>jr', '<cmd>MoltenReevaluateCell<CR>', desc = '[J]upyter [R]e-evaluate cell' },
      { '<leader>ja', '<cmd>MoltenReevaluateAll<CR>', desc = '[J]upyter re-evaluate [A]ll' },
      { '<leader>jo', '<cmd>noautocmd MoltenEnterOutput<CR>', desc = '[J]upyter open [O]utput' },
      { '<leader>jO', '<cmd>MoltenShowOutput<CR>', desc = '[J]upyter show [O]utput' },
      { '<leader>jh', '<cmd>MoltenHideOutput<CR>', desc = '[J]upyter [H]ide output' },
      { '<leader>j]', '<cmd>MoltenNext<CR>', desc = '[J]upyter next output cell' },
      { '<leader>j[', '<cmd>MoltenPrev<CR>', desc = '[J]upyter previous output cell' },
      { '<leader>jd', '<cmd>MoltenDelete<CR>', desc = '[J]upyter [D]elete cell output' },
      { '<leader>jD', '<cmd>MoltenDelete!<CR>', desc = '[J]upyter [D]elete all outputs' },
      { '<leader>jx', '<cmd>MoltenInterrupt<CR>', desc = '[J]upyter interrupt e[X]ecution' },
      { '<leader>jR', '<cmd>MoltenRestart!<CR>', desc = '[J]upyter [R]estart kernel' },
      { '<leader>jE', '<cmd>MoltenExportOutput!<CR>', desc = '[J]upyter [E]xport outputs' },
      { '<leader>jM', '<cmd>MoltenImportOutput<CR>', desc = '[J]upyter i[M]port outputs' },
      { '<leader>jP', '<cmd>MoltenImagePopup<CR>', desc = '[J]upyter image [P]opup' },
      { '<leader>jb', '<cmd>MoltenOpenInBrowser<CR>', desc = '[J]upyter open HTML in [B]rowser' },
    },
    init = function()
      vim.g.molten_image_provider = 'image.nvim'
      vim.g.molten_output_win_max_height = 18
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_text_max_lines = 16
      vim.g.molten_wrap_output = true
    end,
  },

  -- CMake 项目支持（C/C++）
  {
    'Civitasv/cmake-tools.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'stevearc/overseer.nvim',
      'akinsho/toggleterm.nvim',
    },
    cmd = {
      'CMakeGenerate',
      'CMakeClean',
      'CMakeBuild',
      'CMakeQuickBuild',
      'CMakeBuildCurrentFile',
      'CMakeInstall',
      'CMakeRun',
      'CMakeQuickRun',
      'CMakeRunCurrentFile',
      'CMakeDebug',
      'CMakeDebugCurrentFile',
      'CMakeRunTest',
      'CMakeOpenCache',
      'CMakeSettings',
      'CMakeLaunchArgs',
      'CMakeSelectBuildType',
      'CMakeSelectBuildTarget',
      'CMakeSelectConfigurePreset',
      'CMakeSelectBuildPreset',
      'CMakeSelectTestPreset',
      'CMakeSelectLaunchTarget',
      'CMakeSelectKit',
      'CMakeSelectCwd',
      'CMakeSelectBuildDir',
    },
    keys = {
      { '<leader>cg', '<cmd>CMakeGenerate<CR>', desc = '[C]Make [G]enerate' },
      { '<leader>cb', '<cmd>CMakeBuild<CR>', desc = '[C]Make [B]uild' },
      { '<leader>cB', '<cmd>CMakeBuildCurrentFile<CR>', desc = '[C]Make [B]uild current file' },
      { '<leader>cr', '<cmd>CMakeRun<CR>', desc = '[C]Make [R]un' },
      { '<leader>cf', '<cmd>CMakeRunCurrentFile<CR>', desc = '[C]Make run current [F]ile' },
      { '<leader>cd', '<cmd>CMakeDebug<CR>', desc = '[C]Make [D]ebug' },
      { '<leader>cD', '<cmd>CMakeDebugCurrentFile<CR>', desc = '[C]Make [D]ebug current file' },
      { '<leader>cx', '<cmd>CMakeClean<CR>', desc = '[C]Make clean' },
      { '<leader>ci', '<cmd>CMakeInstall<CR>', desc = '[C]Make [I]nstall' },
      { '<leader>cc', '<cmd>CMakeOpenCache<CR>', desc = '[C]Make open [C]ache' },
      { '<leader>ca', '<cmd>CMakeLaunchArgs<CR>', desc = '[C]Make launch [A]rgs' },
      { '<leader>ct', '<cmd>CMakeSelectBuildType<CR>', desc = '[C]Make select build [T]ype' },
      { '<leader>cT', '<cmd>CMakeSelectBuildTarget<CR>', desc = '[C]Make select build [T]arget' },
      { '<leader>cL', '<cmd>CMakeSelectLaunchTarget<CR>', desc = '[C]Make select [L]aunch target' },
      { '<leader>ck', '<cmd>CMakeSelectKit<CR>', desc = '[C]Make select [K]it' },
      { '<leader>cp', '<cmd>CMakeSelectConfigurePreset<CR>', desc = '[C]Make select configure [P]reset' },
      { '<leader>cP', '<cmd>CMakeSelectBuildPreset<CR>', desc = '[C]Make select build [P]reset' },
      { '<leader>cU', '<cmd>CMakeSelectTestPreset<CR>', desc = '[C]Make select test preset' },
      { '<leader>cR', '<cmd>CMakeRunTest<CR>', desc = '[C]Make run tests' },
      { '<leader>cw', '<cmd>CMakeSelectCwd<CR>', desc = '[C]Make select [W]orkdir' },
      { '<leader>cO', '<cmd>CMakeSelectBuildDir<CR>', desc = '[C]Make select build dir' },
      { '<leader>cS', '<cmd>CMakeSettings<CR>', desc = '[C]Make [S]ettings' },
    },
    opts = {
      cmake_regenerate_on_save = false,
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
      cmake_compile_commands_options = {
        action = 'soft_link',
        target = function()
          return vim.uv.cwd()
        end,
      },
      cmake_executor = {
        name = 'overseer',
        opts = {},
      },
      cmake_runner = {
        name = 'toggleterm',
        opts = {
          direction = 'horizontal',
          close_on_exit = false,
          auto_scroll = true,
          singleton = true,
        },
      },
      cmake_dap_configuration = {
        name = 'CMake target',
        type = 'codelldb',
        request = 'launch',
        stopOnEntry = false,
        runInTerminal = true,
        cwd = '${workspaceFolder}',
      },
      cmake_virtual_text_support = true,
    },
  },

  -- 测试框架（支持 pytest + cargo test）
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
      'rouge8/neotest-rust',
    },
    keys = {
      {
        '<leader>Tr',
        function()
          require('neotest').run.run()
        end,
        desc = '[T]est [R]un nearest',
      },
      {
        '<leader>Tf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = '[T]est run [F]ile',
      },
      {
        '<leader>Td',
        function()
          require('neotest').run.run { strategy = 'dap' }
        end,
        desc = '[T]est [D]ebug nearest',
      },
      {
        '<leader>Ts',
        function()
          require('neotest').summary.toggle()
        end,
        desc = '[T]est [S]ummary toggle',
      },
      {
        '<leader>To',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = '[T]est [O]utput toggle',
      },
      {
        '<leader>Tx',
        function()
          require('neotest').run.stop()
        end,
        desc = '[T]est stop [X]',
      },
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-python' { dap = { justMyCode = false } },
          require 'neotest-rust' {},
        },
      }
    end,
  },

  -- 顶部固定显示当前函数/类上下文
  {
    'nvim-treesitter/nvim-treesitter-context',
    opts = { max_lines = 3 },
  },
}
