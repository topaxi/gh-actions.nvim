return {
  { 'nvim-lua/plenary.nvim', lazy = true },
  { 'MunifTanjim/nui.nvim', lazy = true },
  {
    'topaxi/pipeline.nvim',
    cmd = { 'Pipeline', 'GhActions' },
    lazy = true,
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
    opts = {},
    config = function(_, opts)
      require('pipeline').setup(opts)
    end,
  },
}
