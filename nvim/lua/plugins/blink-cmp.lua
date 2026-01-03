-- Use Lua implementation for blink.cmp (no Rust build needed)
return {
  {
    "saghen/blink.cmp",
    opts = {
      fuzzy = {
        -- Use Lua implementation instead of Rust
        implementation = "lua",
        use_proximity = true,
      },
    },
  },
}
