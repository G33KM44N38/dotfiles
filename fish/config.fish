alias vi "nvim"
alias pj "cd ~/myproject/"
alias conf "cd ~/.config/ ; vi ."
alias stack "cd ~/myproject/freelance/site/minata/stackdev/"
alias mapi "cd ~/myproject/freelance/site/minata/stackdev/src/api/"
alias mfr "cd ~/myproject/freelance/site/minata/stackdev/src/front/"
alias kl "cd ~/myproject/freelance/application/KaelGame/"

# git command
alias gs "git status"
alias gp "git push"
alias gaa "git add --all"
alias fla "cd ~/myproject/freelance/application/"
alias train "cd ~/myproject/formation/"
alias graph "git log --all --decorate --oneline --graph"
alias G "go run ."

set -g fish_greeting "Welcome lord Kylian Let's code 💻"

if type -q exa
	alias ls "exa -g --icons"
	alias ll "exa -l -g --icons"
	alias lla "ll -a"
	alias llt "ll --tree"
end

if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -U FZF_COMPLETE 2
#set the default shell
export SHELL=/usr/local/bin/fish
