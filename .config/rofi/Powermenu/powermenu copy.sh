#!/usr/bin/env bash

# Rutas absolutas para evitar errores
dir="$HOME/.config/rofi/Powermenu"
theme='WLStyle'
icons="$HOME/.config/rofi/icons"
conf_rasi="$dir/confirm.rasi"

# Opciones
sdown="Shutdown\0icon\x1f${icons}/shutdown.svg"
reboot="Reboot\0icon\x1f${icons}/reboot.svg"
susp="Suspend\0icon\x1f${icons}/suspend.svg"
log="Logout\0icon\x1f${icons}/logout.svg"
hiber="Hibernate\0icon\x1f${icons}/hibernate.svg"

# Función de confirmación forzando el tema
confirm_exit() {
    echo -e "Yes\nNo" | rofi -dmenu \
        -p "Confirmation" \
        -mesg "Are you sure?" \
        -theme "${conf_rasi}"
}

# Menú principal
chosen=$(echo -e "$sdown\n$reboot\n$susp\n$log\n$hiber" | rofi -dmenu \
    -p "Goodbye ${USER}" \
    -mesg "󱑂 Uptime: $(uptime | grep -oP '(?<=up ).*?(?=,)')" \
    -theme "${dir}/${theme}.rasi" \
    -markup-rows)

case "$chosen" in
    "Shutdown")
        [[ $(confirm_exit) == "Yes" ]] && systemctl poweroff
        ;;
    "Reboot")
        [[ $(confirm_exit) == "Yes" ]] && systemctl reboot
        ;;
    "Suspend")
        systemctl suspend
        ;;
    "Logout")
        [[ $(confirm_exit) == "Yes" ]] &&  hyprctl dispatch 'hl.dsp.exit()'
        ;;
    "Hibernate")
        systemctl hibernate
        ;;
esac
