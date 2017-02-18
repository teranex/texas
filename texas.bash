# -*- sh -*-

if ! command -v ranger &> /dev/null || ! command -v tmux &> /dev/null; then
    return 1
fi

texas()
{
    # Start a new tmux session with texas inside.
    if [ -z "$TMUX" ]; then
        tmux -L texas new-session 'LAUNCH_TEXAS=1 bash'
        return
    fi

    if [ "$TEXAS_CONFIG_NOSWAP" = 1 ]; then
        TEXAS_RANGER_PID=$(tmux split-window -p 70 -P -F '#{pane_pid}' "TEXAS_BASH=1 LAUNCH_TEXAS=$LAUNCH_TEXAS TEXAS_SHELL_PID=$$ ranger")
    else
        TEXAS_RANGER_PID=$(tmux split-window -p 30 -P -F '#{pane_pid}' "TEXAS_BASH=1 LAUNCH_TEXAS=$LAUNCH_TEXAS TEXAS_SHELL_PID=$$ ranger")
        tmux swap-pane -D -d
    fi

    # Do not bind a key in a non-dedicated tmux daemon. Tmux binds are
    # global per daemon so that would contaminate the user environment.
    if [ "$LAUNCH_TEXAS" = 1 ]; then
        local TEXAS_SWITCH_COMMAND
        TEXAS_SWITCH_COMMAND=$(cat <<'EOF'
if [ "$(tmux display-message -p '#{window_panes}')" -gt 1 ]; then
    tmux select-pane -t :.+
else
    tmux next-window
fi
EOF
)
        tmux bind -n C-o run -b "$TEXAS_SWITCH_COMMAND"
    fi

    # Unset the variable only here because the ranger plugin reacts to it.
    unset LAUNCH_TEXAS

    cd()
    {
        builtin cd "$@"
        if ! kill -USR1 $TEXAS_RANGER_PID 2> /dev/null; then
            # ranger is no longer running, let's clean up the bash state.

            # The ranger's PID is no longer needed.
            unset TEXAS_RANGER_PID

            # Remove the hook because there is no ranger to communicate with.
            unset -f cd
        fi
    }

    texas--exit-cleanup() {
        kill -HUP $TEXAS_RANGER_PID
    }
    trap texas--exit-cleanup EXIT

    texas--ranger-to-sh-sync() {
        # Needs to be immediately followed by SIGINT to update the
        # prompt. It's handled in the ranger plugin, controlled by the
        # TEXAS_BASH env variable.
        builtin cd -P /proc/$TEXAS_RANGER_PID/cwd
    }
    trap texas--ranger-to-sh-sync USR1


    texas--switch-to-ranger() {
        if [ "$(tmux display-message -p '#{window_panes}')" -gt 1 ]; then
            tmux select-pane -t :.+
        else
            tmux next-window
        fi
    }
}

if [ -n "$LAUNCH_TEXAS" ]; then
    texas
fi
