# gh-actions.nvim

The gh-actions plugin for Neovim allows developers to easily manage and dispatch their GitHub Actions workflow runs directly from within the editor.

## Features

- List workflows and their runs for the current repository
- Run/dispatch workflows with `workflow_dispatch`

## ToDo

- Rerun a failed workflow
- Configurable keybindings

## Installation

### Dependencies

- [GNU Make](https://www.gnu.org/software/make/)
- [Cargo](https://doc.rust-lang.org/cargo/)

### lazy.nvim

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'topaxi/gh-actions.nvim',
  cmd = 'GhActions',
  keys = {
    { '<leader>gh', '<cmd>GhActions<cr>', desc = 'Open Github Actions' },
  },
  build = 'make',
  dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
  opts = {},
  config = function(_, opts)
    require('gh-actions').setup(opts)
  end,
},
```

## Authentication

The plugin requires authentication with your GitHub account to access your workflows and runs. You can authenticate by running the `gh auth login command` in your terminal and following the prompts.

Alternatively, define a `GITHUB_TOKEN` variable in your environment.

## Usage

### Commands

- `:GhActions` opens the `gh-actions` split

### Keybindings

The following keybindings are provided by the plugin:

- `q` - closes the `gh-actions` the split
- `gw` - open the workflow file below the cursor on GitHub
- `gr` - open the workflow run below the cursor on GitHub
- `gj` - open the job of the workflow run below the cursor on GitHub
- `d` - dispatch a new run for the workflow below the cursor on GitHub

### Options

The default options (as defined in [lua/config.lua](./blob/main/lua/gh-actions/config.lua)

```lua
{
  --- The browser executable path to open workflow runs/jobs in
  ---@type string|nil
  browser = nil,
  --- Interval to refresh in seconds
  refresh_interval = 10,
  --- How much workflow runs and jobs should be indented
  indent = 2,
  icons = {
    workflow_dispatch = '⚡️',
    conclusion = {
      success = '✓',
      failure = 'X',
      startup_failure = 'X',
      cancelled = '⊘',
      skipped = '◌',
    },
    status = {
      unknown = '?',
      pending = '○',
      queued = '○',
      requested = '○',
      waiting = '○',
      in_progress = '●',
    },
  },
  highlights = {
    GhActionsRunIconSuccess = { link = 'LspDiagnosticsVirtualTextHint' },
    GhActionsRunIconFailure = { link = 'LspDiagnosticsVirtualTextError' },
    GhActionsRunIconStartup_failure = { link = 'LspDiagnosticsVirtualTextError' },
    GhActionsRunIconPending = { link = 'LspDiagnosticsVirtualTextWarning' },
    GhActionsRunIconRequested = { link = 'LspDiagnosticsVirtualTextWarning' },
    GhActionsRunIconWaiting = { link = 'LspDiagnosticsVirtualTextWarning' },
    GhActionsRunIconIn_progress = { link = 'LspDiagnosticsVirtualTextWarning' },
    GhActionsRunIconCancelled = { link = 'Comment' },
    GhActionsRunIconSkipped = { link = 'Comment' },
    GhActionsRunCancelled = { link = 'Comment' },
    GhActionsRunSkipped = { link = 'Comment' },
    GhActionsJobCancelled = { link = 'Comment' },
    GhActionsJobSkipped = { link = 'Comment' },
    GhActionsStepCancelled = { link = 'Comment' },
    GhActionsStepSkipped = { link = 'Comment' },
  },
  split = {
    relative = 'editor',
    position = 'right',
    size = 60,
    win_options = {
      wrap = false,
      number = false,
      foldlevel = nil,
      foldcolumn = '0',
      cursorcolumn = false,
      signcolumn = 'no',
    },
  },
}

```

## Credits

- [folke/lazy.nvim](https://github.com/folke/lazy.nvim) for the rendering approach
