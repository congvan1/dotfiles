local markdownlint_config = vim.fn.expand("~/.markdownlint.json")

return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      local lint = require("lint")
      lint.linters["markdownlint-cli2"].args = { "--config", markdownlint_config, "-" }
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = { "markdownlint-cli2" }
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          args = { "--config", markdownlint_config, "--fix", "$FILENAME" },
        },
      },
    },
  },
}
