-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = false })
vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = false })

-- Comment out visually selected lines with <leader>/
vim.keymap.set("v", "<leader>/", "gc", { desc = "Comment toggle linewise (visual)", remap = true })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what anyone expects.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Fix 'E' in terminal buffers to go to the end of the actual text
-- instead of jumping across padded spaces to the next line.
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("TerminalFixE", { clear = true }),
  callback = function()
    vim.keymap.set("n", "E", "g_", { buffer = true, desc = "End of text (ignore terminal padding)" })
  end,
})
