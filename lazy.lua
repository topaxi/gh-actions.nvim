return {
  { 'nvim-lua/plenary.nvim', lazy = true },
  { 'MunifTanjim/nui.nvim',  lazy = true },
  {
    'topaxi/gh-actions.nvim',
    cmd = 'GhActions',
    lazy = true,
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
    opts = {},
  },
}
