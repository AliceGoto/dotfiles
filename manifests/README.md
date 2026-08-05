# Manifests

清单是软件治理的声明层，不是安装命令脚本。

- `software.tsv`：软件、来源、状态、命令和配置路径。
- `ai-profiles.tsv`：Hermes Studio 调度关系、profile 生命周期和后台策略。
- `config-surface.tsv`：家目录配置、运行态和 legacy 路径的治理边界。
- `brew/.Brewfile`：Homebrew 安装声明，修改前必须和 `brew list` 差异审阅。
- `mise/.config/mise/config.toml`：Node/Python 运行时版本。
- `review` 项表示候选工具，当前不在 Homebrew 安装声明中，也不会被自动安装。
- Hermes profile 的常驻状态只由 Hermes Studio 管理并通过 `dotfiles hermes` 审计；不要手工复制或加载 profile LaunchAgent plist。

规则：

1. 不写 API key、token、cookie、auth、私钥或真实 `.env`。
2. 新工具先进入 `review`，完成用途、依赖、健康检查和回滚说明后再改为 `active`。
3. `autostart=review` 不代表会自动修改 launchd；需要单独审批和记录。
4. 清单与实际状态不一致时，先运行 `dotfiles inventory`，不要直接执行 `brew bundle install`。

## 新软件接入

从 `review` 开始，不直接写成 `active`：

1. 先将软件加入 `software.tsv`，写清来源、命令、配置路径和回滚方式。
2. 有持久配置时，为它创建 Stow 包，运行 `./configure link`，不要手工复制文件。
3. 运行 `dotfiles config`、`dotfiles doctor` 和 `dotfiles docs`，确认实际状态。
4. 只有验证完成后才把状态改为 `active`。

Python 项目依赖使用 `uv add` 并提交项目锁文件；全局 CLI 用 `uv tool install`，不把全局 `pip freeze` 当作系统配置。
