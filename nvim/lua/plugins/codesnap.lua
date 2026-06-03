return {
  "mistricky/codesnap.nvim",
  enabled = false,
  build = "make",
  config = function()
    require("codesnap").setup({
      watermark = "",
    })
  end,
}
