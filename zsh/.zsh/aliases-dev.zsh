# Development Environment Aliases
# Add to ~/.zshrc

# 开发环境管理（`dev` 保留为兼容入口；统一审计入口是 `dotfiles`）
alias dev='~/.local/bin/dev'
alias devstart='dev start'
alias devstop='dev stop'
alias devstatus='dev status'
alias devreset='dev reset'

# Docker 快捷命令
alias d='docker'
alias dps='docker ps'
alias dai='docker images'
alias dl='docker logs -f'
alias de='docker exec -it'
alias dpc='docker compose'

# UV 快捷命令
alias uvpy='uv python'
alias uvr='uv run'
alias uvadd='uv add'
alias uvrm='uv remove'

# Ollama 快捷命令
alias ol='ollama'
alias oll='ollama list'
alias ollrun='ollama run'
alias ollpull='ollama pull'
alias ollrm='ollama rm'

# 服务管理
alias services='dev status'
alias startall='dev start'
alias stopall='dev stop'

# 清理：统一走 dry-run 控制面，不直接删除容器、卷或模型
alias dprune='dotfiles cleanup'
alias clean='dotfiles cleanup'

# 项目快速启动
alias hermes='dotfiles hermes'
alias workspace='cd ~/.hermes/workspace'
