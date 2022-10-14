function _MenuTmux
    if not set -q TMUX
            clear
        set PathSession ~/.config/fish/conf.d/sessions
        set PathChoose ~/.config/fish/conf.d/choose
        set sesson (tmux list-sessions | awk '{print $1}' | sed 's/.$//' > "$PathSession")
        set option (echo "Attach-Session New-Session Kill-Session Exit" | tr ' ' '\n)'> "$PathChoose")
        set selected (cat "$PathChoose" | fzf)
        if string match -q "New-Session" $selected
            read -P "Tmux session name: " query
                tmux new -s $query
        else if string match -q "Kill-Session" $selected
            set selectedKill (cat "$PathSession" | fzf)
            tmux kill-session -t "$selectedKill"
            _MenuTmux
        else if string match -q "Attach-Session" $selected
            set selectedSession (cat "$PathSession" | fzf)
            if set match -q $selected
                    tmux a -t "$selectedSession"
            else
                _MenuTmux
            end
        end
        rm $PathSession 2>/dev/null 
        rm $PathChoose 2>/dev/null 
    end
end

_MenuTmux
