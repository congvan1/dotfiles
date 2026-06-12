-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local asm_indent_group = vim.api.nvim_create_augroup("asm_indent", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = asm_indent_group,
  pattern = "asm",
  callback = function()
    vim.opt_local.autoindent = true
    vim.opt_local.smartindent = false
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4

    vim.keymap.set("i", "<CR>", function()
      local line = vim.api.nvim_get_current_line()
      if line:match("^%s*[%w_.$@?]+:%s*(;.*)?$") then
        return "<CR><Tab>"
      end
      return "<CR>"
    end, { buffer = true, expr = true, desc = "Indent after assembly label" })
  end,
})
