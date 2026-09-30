
#!/usr/bin/env bash

# ============================================================================
# POWERMENU
# ============================================================================

# Rutas absolutas para evitar errores
dir="$HOME/.config/rofi/Powermenu"

theme="WLStyle"

icons="$HOME/.config/rofi/icons"

conf_rasi="$dir/confirm.rasi"


# ============================================================================
# OPTIONS
# ============================================================================

sdown="Shutdown\0icon\x1f${icons}/shutdown.svg"
reboot="Reboot\0icon\x1f${icons}/reboot.svg"
susp="Suspend\0icon\x1f${icons}/suspend.svg"
log="Logout\0icon\x1f${icons}/logout.svg"
hiber="Hibernate\0icon\x1f${icons}/hibernate.svg"


# ============================================================================
# CONFIRMATION
# ============================================================================

confirm_exit() {
    echo -e "Yes\nNo" | rofi -dmenu \
        -p "Confirmation" \
        -mesg "Are you sure?" \
        -theme "${conf_rasi}"
}


# ============================================================================
# MAIN MENU
# ============================================================================

chosen=$(echo -e "$sdown\n$reboot\n$susp\n$log\n$hiber" | rofi -dmenu \
    -p "Goodbye ✧ ${USER} !!" \
    -mesg "󱑂 Uptime: $(uptime | grep -oP '(?<=up ).*?(?=,)' | head -1)" \
    -theme "${dir}/${theme}.rasi" \
    -markup-rows)


# ============================================================================
# ACTIONS
# ============================================================================

case "$chosen" in

    "Shutdown")
        if [[ $(confirm_exit) == "Yes" ]]; then
            hyprshutdown --vt 2 -t "Shutting down..." --post-cmd "systemctl poweroff"

        fi
        ;;

    "Reboot")
        if [[ $(confirm_exit) == "Yes" ]]; then
            hyprshutdown --vt 2 -t "Rebooting..." --post-cmd "reboot"
        fi
        ;;

    "Suspend")
        if [[ $(confirm_exit) == "Yes" ]]; then
            systemctl suspend
        fi
        ;;

    "Logout")
        if [[ $(confirm_exit) == "Yes" ]]; then
            hyprshutdown --vt 2 -t "See you soon~"   ##Nvidia Fix
        fi
        ;;

    "Hibernate")
        if [[ $(confirm_exit) == "Yes" ]]; then
            systemctl hibernate
        fi
        ;;

esac
