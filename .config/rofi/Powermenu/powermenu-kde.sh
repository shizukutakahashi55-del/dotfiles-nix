
#!/usr/bin/env bash

# ── Rutas ──────────────────────────────────────────────────────

dir="$HOME/.config/rofi/Powermenu"
theme="WLStyle"
icons="$HOME/.config/rofi/icons"
conf_rasi="$dir/confirm.rasi"

# ── Opciones ───────────────────────────────────────────────────

sdown="Shutdown\0icon\x1f${icons}/shutdown.svg"
reboot="Reboot\0icon\x1f${icons}/reboot.svg"
susp="Suspend\0icon\x1f${icons}/suspend.svg"
log="Logout\0icon\x1f${icons}/logout.svg"
hiber="Hibernate\0icon\x1f${icons}/hibernate.svg"

# ── Confirmación ───────────────────────────────────────────────

confirm_exit() {
    printf "Yes\nNo\n" | rofi -dmenu \
        -p "Confirmation" \
        -mesg "Are you sure?" \
        -theme "${conf_rasi}"
}

# ── Menú principal ─────────────────────────────────────────────

chosen=$(printf "%b\n" \
    "$sdown" \
    "$reboot" \
    "$susp" \
    "$log" \
    "$hiber" |
    rofi -dmenu \
        -p "Goodbye ${USER}" \
        -mesg "󱑂 Uptime: $(uptime | grep -oP '(?<=up ).*?(?=,)' | head -1)" \
        -theme "${dir}/${theme}.rasi" \
        -markup-rows)

# ── Acciones ───────────────────────────────────────────────────

case "$chosen" in

    "Shutdown")
        [[ "$(confirm_exit)" == "Yes" ]] && systemctl poweroff
        ;;

    "Reboot")
        [[ "$(confirm_exit)" == "Yes" ]] && systemctl reboot
        ;;

    "Suspend")
        systemctl suspend
        ;;

    "Logout")
        if [[ "$(confirm_exit)" == "Yes" ]]; then
            loginctl terminate-session "$XDG_SESSION_ID"
        fi
        ;;

    "Hibernate")
        systemctl hibernate
        ;;

esac
