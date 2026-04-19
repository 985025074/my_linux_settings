-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'
    local uv = vim.uv or vim.loop

    local function cargo_metadata()
      local current_file = vim.api.nvim_buf_get_name(0)
      local search_from = current_file ~= '' and vim.fs.dirname(current_file) or vim.fn.getcwd()
      local cargo_toml = vim.fs.find('Cargo.toml', { upward = true, path = search_from })[1]
      if not cargo_toml then
        return nil
      end

      local output = vim.fn.system {
        'cargo',
        'metadata',
        '--format-version',
        '1',
        '--no-deps',
        '--manifest-path',
        cargo_toml,
      }

      if vim.v.shell_error ~= 0 then
        return nil
      end

      local ok, decoded = pcall(vim.json.decode, output)
      if not ok then
        return nil
      end

      decoded.current_manifest = cargo_toml
      return decoded
    end

    local function rust_executable_path()
      local metadata = cargo_metadata()
      local default_dir = vim.fn.getcwd() .. '/target/debug/'
      if not metadata then
        return vim.fn.input('Path to executable: ', default_dir, 'file')
      end

      local package
      for _, item in ipairs(metadata.packages or {}) do
        if item.manifest_path == metadata.current_manifest then
          package = item
          break
        end
      end

      if not package then
        return vim.fn.input('Path to executable: ', default_dir, 'file')
      end

      local current_file = vim.api.nvim_buf_get_name(0)
      local current_stem = vim.fn.fnamemodify(current_file, ':t:r')
      local candidate
      local bin_targets = {}

      for _, target in ipairs(package.targets or {}) do
        if vim.tbl_contains(target.kind or {}, 'bin') then
          table.insert(bin_targets, target)
          if current_file ~= '' and target.src_path == current_file then
            candidate = target.name
            break
          end
        end
      end

      if not candidate then
        if package.default_run and package.default_run ~= '' then
          candidate = package.default_run
        elseif #bin_targets == 1 then
          candidate = bin_targets[1].name
        else
          for _, target in ipairs(bin_targets) do
            if target.name == current_stem then
              candidate = target.name
              break
            end
          end
        end
      end

      local target_dir = metadata.target_directory or (vim.fn.getcwd() .. '/target')
      local executable = target_dir .. '/debug/'
      if candidate and candidate ~= '' then
        executable = executable .. candidate
        if vim.fn.has 'win32' == 1 then
          executable = executable .. '.exe'
        end

        if uv.fs_stat(executable) then
          return executable
        end
      end

      return vim.fn.input('Path to executable: ', executable, 'file')
    end

    local function cpp_executable_path()
      local ok, cmake = pcall(require, 'cmake-tools')
      if ok then
        local launch_target = cmake.get_launch_target_path()
        if type(launch_target) == 'string' and launch_target ~= '' then
          return launch_target
        end

        local build_target = cmake.get_build_target_path()
        if type(build_target) == 'string' and build_target ~= '' then
          return build_target
        end
      end

      local current_file = vim.api.nvim_buf_get_name(0)
      local current_stem = current_file ~= '' and vim.fn.fnamemodify(current_file, ':t:r') or 'a.out'
      local cwd = vim.fn.getcwd()
      local candidates = {
        cwd .. '/build/' .. current_stem,
        cwd .. '/out/Debug/' .. current_stem,
        cwd .. '/out/Release/' .. current_stem,
        cwd .. '/' .. current_stem,
        cwd .. '/a.out',
      }

      for _, candidate in ipairs(candidates) do
        if uv.fs_stat(candidate) then
          return candidate
        end
      end

      return vim.fn.input('Path to executable: ', cwd .. '/build/' .. current_stem, 'file')
    end

    local function prompt_program_args()
      local input = vim.fn.input 'Arguments: '
      if input == nil or vim.trim(input) == '' then
        return {}
      end

      return vim.split(vim.trim(input), '%s+', { trimempty = true })
    end

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
        'codelldb',
        'python',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }

    local codelldb_cmd = vim.fn.stdpath 'data' .. '/mason/bin/codelldb'
    if not uv.fs_stat(codelldb_cmd) then
      codelldb_cmd = 'codelldb'
    end

    dap.adapters.codelldb = {
      type = 'executable',
      command = codelldb_cmd,
      detached = vim.fn.has 'win32' == 0,
    }

    dap.configurations.rust = {
      {
        name = 'Launch Rust binary (auto)',
        type = 'codelldb',
        request = 'launch',
        program = rust_executable_path,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
      },
    }

    local cpp_dap_configurations = {
      {
        name = 'Launch C/C++ binary (auto)',
        type = 'codelldb',
        request = 'launch',
        program = cpp_executable_path,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = prompt_program_args,
      },
    }

    dap.configurations.c = vim.deepcopy(cpp_dap_configurations)
    dap.configurations.cpp = vim.deepcopy(cpp_dap_configurations)

    local debugpy_python = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
    if not uv.fs_stat(debugpy_python) then
      debugpy_python = 'python3'
    end

    require('dap-python').setup(debugpy_python)
    require('dap-python').test_runner = 'pytest'

    -- .vscode/launch.json 会由 nvim-dap 的 provider 在 dap.continue() 时按需读取
  end,
}
