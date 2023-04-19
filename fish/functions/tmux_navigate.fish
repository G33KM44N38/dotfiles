function tmux_navigate
    set selected
    if test (count $argv) -eq 1
        set selected $argv[1]
    else
        set selected (find \
        ~/myproject/freelance/site/minata/ \
        ~/myproject/freelance/site/minata/stackdev/src/ \
        ~/goinfre/ \
        ~/.config/ \
        -mindepth 1 -maxdepth 2 -type d | fzf)
    end

    if test -z $selected
        exit 0
    end

    set selected_name (basename $selected | tr . _)
    set tmux_running (pgrep tmux)

    if test -z $TMUX -a -z $tmux_running
        tmux new-session -s $selected_name -c $selected
        exit 0
    end

    if not tmux has-session -t=$selected_name ^/dev/null
        tmux new-session -ds $selected_name -c $selected
    end

    tmux switch-client -t $selected_name
end
