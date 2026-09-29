return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local details = { file_size = true, type = true, last_modified = true }

      opts.event_handlers = opts.event_handlers or {}
      table.insert(opts.event_handlers, {
        event = "neo_tree_popup_input_ready",
        handler = function(args)
          for key, movement in pairs({
            ["<C-a>"] = "<Home>",
            ["<C-e>"] = "<End>",
            ["<C-b>"] = "<Left>",
            ["<C-f>"] = "<Right>",
            ["<M-b>"] = "<C-Left>",
            ["<M-f>"] = "<C-Right>",
          }) do
            vim.keymap.set("i", key, movement, { buffer = args.bufnr })
          end
        end,
      })

      opts.default_component_configs.file_size = { enabled = false }
      opts.default_component_configs.type = { enabled = false }
      opts.default_component_configs.last_modified = { enabled = false }

      local function show_details(state, visible)
        state.details_visible = visible
        for _, renderer in pairs(state.renderers) do
          for _, component in ipairs(renderer) do
            if component[1] == "container" then
              for _, item in ipairs(component.content) do
                if details[item[1]] then
                  item.enabled = visible
                  item.required_width = 0
                end
              end
            end
          end
        end
      end

      opts.window.mappings.e = function(state)
        if state.details_visible then
          show_details(state, false)
          vim.api.nvim_win_set_width(state.winid, state.window.width)
          require("neo-tree.ui.renderer").redraw(state)
          return
        end
        show_details(state, false)
        require("neo-tree.sources.common.commands").toggle_auto_expand_width(state)
        if not state.window.auto_expand_width then
          vim.api.nvim_win_set_width(state.winid, state.window.width)
        end
      end

      opts.window.mappings.E = function(state)
        state.window.auto_expand_width = false
        show_details(state, not state.details_visible)
        local width = state.details_visible and math.min(120, vim.o.columns - 1) or state.window.width
        vim.api.nvim_win_set_width(state.winid, width)
        require("neo-tree.ui.renderer").redraw(state)
      end
    end,
  },
}
