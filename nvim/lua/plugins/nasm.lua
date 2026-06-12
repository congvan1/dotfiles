return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "nasm" })
    end,
    init = function()
      vim.g.asmsyntax = "nasm"
      vim.treesitter.language.register("nasm", "asm")
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        asm_lsp = {},
      },
    },
  },
}
