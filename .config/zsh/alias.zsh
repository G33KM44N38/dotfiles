# Custom Aliases
alias vi="nvim"
alias ld="lazydocker"
alias lg="lazygit"
alias c="cursor ."
alias ocr="open_current_repo"
alias odn="daily_open.sh"
alias me="manage_env.sh"
alias ie="import_env.sh"
alias bch="babacoiffure_checkhealth.sh"
alias ca="coding-assistant"
alias bsetup="ie && pnpm i"

# Git command
alias gc="git commit"
alias gcn="git commit --no-verify"
alias gfa="git fetch --all --prune"
alias gcn="git commit -n"
alias gs="git status"
alias gp="git push && open raycast://extensions/raycast/raycast/confetti"
alias gpn="git push --no-verify && open raycast://extensions/raycast/raycast/confetti"
alias gl="git  pull"
# alias gpn="git push -n"
alias gaa="git add --all"
alias graph="git log --all --decorate --oneline --graph"
alias gcg="git config --edit --global"
alias glo="git log --graph --all --decorate --pretty=format:'%C(auto)%h %C(blue)%an%C(reset) %C(yellow)%d%C(reset) %s'"
alias gcl="git config --edit --local"
# git log oneline with the timestamp
alias glog="git log --decorate --date=iso --pretty=format:'%C(auto)%h%d %C(cyan)%ad%C(reset) %s' --color=always"
alias glcb="git log --oneline --graph --decorate $(git merge-base HEAD main)..HEAD"
#

# Tmux
alias tma="tmux a"
