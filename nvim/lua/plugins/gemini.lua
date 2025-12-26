-- Gemini AI assistant for Neovim
-- Provides code completion, explanation, unit tests, code review, and chat
return {
  "kiddos/gemini.nvim",
  event = "VeryLazy",
  opts = {
    model_config = {
      model_id = "gemini-2.0-flash-exp",
      temperature = 0.10,
      top_k = 128,
      response_mime_type = "text/plain",
    },
    chat_config = {
      enabled = true,
    },
    hints = {
      enabled = true,
      hints_delay = 2000,
      insert_result_key = "<S-Tab>",
    },
    completion = {
      enabled = true,
      blacklist_filetypes = { "help", "qf", "json", "yaml", "toml", "xml" },
      blacklist_filenames = { ".env" },
      completion_delay = 800,
      insert_result_key = "<S-Tab>",
      move_cursor_end = true,
    },
    instruction = {
      enabled = true,
      menu_key = "<Leader>ai",
      prompts = {
        {
          name = "Unit Test",
          command_name = "GeminiUnitTest",
          menu = "Unit Test 🚀",
        },
        {
          name = "Code Review",
          command_name = "GeminiCodeReview",
          menu = "Code Review 📜",
        },
        {
          name = "Code Explain",
          command_name = "GeminiCodeExplain",
          menu = "Code Explain 💡",
        },
      },
    },
    task = {
      enabled = true,
    },
  },
  keys = {
    { "<leader>ai", desc = "Gemini AI Menu" },
    { "<leader>ac", "<cmd>GeminiChat<cr>", desc = "Gemini Chat", mode = { "n", "v" } },
    { "<leader>au", "<cmd>GeminiUnitTest<cr>", desc = "Generate Unit Test", mode = { "n", "v" } },
    { "<leader>ar", "<cmd>GeminiCodeReview<cr>", desc = "Code Review", mode = { "n", "v" } },
    { "<leader>ae", "<cmd>GeminiCodeExplain<cr>", desc = "Explain Code", mode = { "n", "v" } },
  },
}
