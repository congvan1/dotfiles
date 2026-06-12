return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      yaml = {}, -- Keep YAML quotes/operators unchanged on save
      asm = {}, -- NASM has no reliable general-purpose formatter
    },
  },
}
