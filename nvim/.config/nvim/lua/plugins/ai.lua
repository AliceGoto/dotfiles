-- ==========================================
-- plugins/ai.lua — 代码补全
-- 部署路径: .config/nvim/lua/plugins/ai.lua
-- 所属包: nvim/
-- 功能: blink.cmp 补全 + Supermaven AI 行内补全
-- ==========================================

return {
  {
    "saghen/blink.cmp",
    version = "*",
    event = "InsertEnter",
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        build = "make install_jsregexp",
      },
      "rafamadriz/friendly-snippets",
    },
    opts = function()
      local icons = require("configs.icons").get_kind()
      return {
        keymap = {
          ["<C-space>"] = { "show", "show_documentation" },
          ["<C-e>"] = { "hide", "fallback" },
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
          ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
          ["<C-b>"] = { "scroll_documentation_up", "fallback" },
          ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        },
        appearance = {
          nerd_font_variant = "normal",
          kind_icons = icons,
        },
        sources = {
          -- 注意：不要把 "supermaven" 加进来——它是幽灵文本内联补全，不走 blink 菜单
          default = { "lsp", "path", "snippets", "buffer" },
        },
        completion = {
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 500,
          },
          menu = { border = "rounded" },
        },
      }
    end,
  },
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    config = function()
      require("supermaven-nvim").setup({
        keymaps = {
          accept_suggestion = "<C-y>",
          accept_word = "<C-j>",
          clear_suggestion = "<C-]>",
        },
        ignore_filetypes = { "markdown", "text" },
      })
    end,
  },
}
