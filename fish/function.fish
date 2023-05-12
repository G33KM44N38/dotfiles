function dotfile
    gum style\
        --border normal\
        --margin "1"\
        --border-foreground "$GIT_COLOR"\
        " Dotfile Manager "
    set choose (gum choose --no-limit "Nvim" "Fish" "Config" "Plugin" "Lsp")
    switch $choose
        case "Nvim"
            cd ~/.dotfiles/.config/nvim
        case "Fish"
            cd ~/.dotfiles/.config/fish
        case "Config"
            cd ~/.dotfiles/.config/
        case "Plugin"
            vi ~/.dotfiles/.config/nvim/lua/plugin.lua
        case "Lsp"
            cd ~/.dotfiles/.config/nvim/lua/lsp/
    end
end
