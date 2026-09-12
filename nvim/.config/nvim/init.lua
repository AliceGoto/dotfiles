-- ==========================================
-- init.lua — Neovim 入口点
-- 部署路径: .config/nvim/init.lua
-- 所属包: nvim/
-- 功能: 引导 lazy.nvim 插件管理器，加载核心配置和插件
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 or not vim.uv.fs_stat(lazypath) then
    error("Failed to clone lazy.nvim: " .. vim.trim(result))
  end
end
vim.opt.rtp:prepend(lazypath)

-- 设置代理环境变量
vim.env.HTTP_PROXY = "http://127.0.0.1:7897"
vim.env.HTTPS_PROXY = "http://127.0.0.1:7897"

require("core.options")
require("core.keymaps")

require("lazy").setup("plugins", {
  defaults = {
    lazy = true,
  },
  change_detection = {
    notify = false,
  },
  performance = {
    cache = {
      enabled = true,
    },
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  ui = {
    border = "rounded",
  },
  timeout = 30000, -- 30秒超时
})
