# ============================================================
#  .zshrc — Soft & Cozy (Starship Edition) 🌸✨
# ============================================================

# ── Fastfetch ────────────────────────────────────────────────
if command -v fastfetch &>/dev/null; then
    fastfetch
fi

# ── Historial ─────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# ── Opciones generales ────────────────────────────────────────
setopt AUTO_CD
setopt CORRECT
setopt EXTENDED_GLOB
setopt NO_BEEP

# ── Autocompletado ────────────────────────────────────────────
autoload -Uz compinit
compinit

setopt MENU_COMPLETE
setopt AUTO_LIST
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' verbose yes

zstyle ':completion:*:descriptions' format '%F{#f5c2e7}🎀 %d 🎀%f'
zstyle ':completion:*:messages' format '%F{#a6e3a1}✨ %d ✨%f'
zstyle ':completion:*:warnings' format '%F{#f38ba8}🌸 sin resultados 🌸%f'
zstyle ':completion:*:corrections' format '%F{#f9e2af}💭 %d (errores: %e) 💭%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' special-dirs true

# ── Plugins (Rutas compatibles con NixOS y FHS) ─────────────
if [[ -f /run/current-system/sw/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /run/current-system/sw/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [[ -f /run/current-system/sw/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /run/current-system/sw/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -f /run/current-system/sw/share/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /run/current-system/sw/share/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
elif [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

# ── Autosuggestions & Highlighting ────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#7f6e85"

typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#f5c2e7,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#cba6f7'
ZSH_HIGHLIGHT_STYLES[function]='fg=#f4b8e4'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#94e2d5'
ZSH_HIGHLIGHT_STYLES[path]='fg=#f9e2af'
ZSH_HIGHLIGHT_STYLES[string]='fg=#a6e3a1'
ZSH_HIGHLIGHT_STYLES[error]='fg=#f38ba8,bold'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#7f6e85,italic'

# ── Keybindings ───────────────────────────────────────────────
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^R' history-incremental-search-backward

# ── Aliases ───────────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons=auto'
    alias ll='eza -la --icons=auto--git'
    alias la='eza -a --icons=auto'
    alias tree='eza --tree --icons=auto'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias la='ls -A --color=auto'
fi

alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias reload='source ~/.zshrc'
alias zshconfig='nvim ~/.zshrc'

alias vi='nvim'
alias vim='nvim'

if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
fi

alias hyprconf='nvim ~/.config/hypr/hyprland.conf'
alias nyx='~/Nyx-Python/start.sh'

# ── Variables de entorno ──────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'
export TERM='xterm-256color'
export PATH="$HOME/.local/bin:$PATH"
export LS_COLORS="di=38;5;218:ln=38;5;183:so=38;5;183:pi=38;5;223:ex=38;5;157"

# # ── NixOS Helpers ─────────────────────────────────────────────
# export NIXOS_FLAKE="/etc/nixos"
# export NIXOS_HOST="nixos"

# flake() {
#     if [[ "$1" == "update" ]]; then
#         shift
#         echo "🌸 Actualizando flake en $NIXOS_FLAKE..."
#         command nix flake update --flake "$NIXOS_FLAKE" "$@"
#     else
#         command nix flake "$@"
#     fi
# }

# sys() {
#     case "$1" in
#         test)
#             shift
#             echo "✨ Probando NixOS ($NIXOS_HOST)..."
#             sudo nixos-rebuild build --flake "$NIXOS_FLAKE#$NIXOS_HOST" "$@"
#             ;;
#         rebuild|switch)
#             shift
#             echo "🎀 Aplicando NixOS ($NIXOS_HOST)..."
#             sudo nixos-rebuild switch --flake "$NIXOS_FLAKE#$NIXOS_HOST" "$@"
#             ;;kon
#         boot)
#             shift
#             echo "🚀 Configurando para el próximo arranque..."
#             sudo nixos-rebuild boot --flake "$NIXOS_FLAKE#$NIXOS_HOST" "$@"
#             ;;
#         *)
#             echo "Uso: sys {test|rebuild|boot}"
#             return 1
#             ;;
#     esac
# }

# ── NixOS Helpers ─────────────────────────────────────────────
# Si estás en un repo local usa '.', si no, usa ~/nixos-config
export NIXOS_FLAKE="$HOME/nixos-config"
export NIXOS_HOST="nixos"

flake() {
    local target="${1:-update}"
    if [[ "$target" == "update" ]]; then
        shift 2>/dev/null
        echo "🌸 Actualizando flake en $NIXOS_FLAKE..."
        command nix flake update --flake "$NIXOS_FLAKE" "$@"
    else
        command nix flake "$@"
    fi
}

sys() {
    # Detecta si estás dentro de la carpeta del repo para usar '.' o la ruta guardada
    local flake_dir="$NIXOS_FLAKE"
    if [[ -f "./flake.nix" ]]; then
        flake_dir="."
    fi

    case "$1" in
        test)
            shift
            echo "✨ Probando NixOS ($NIXOS_HOST) desde $flake_dir..."
            sudo nixos-rebuild build --flake "$flake_dir#$NIXOS_HOST" "$@"
            ;;
        rebuild|switch)
            shift
            echo "🎀 Aplicando NixOS ($NIXOS_HOST) desde $flake_dir..."
            sudo nixos-rebuild switch --flake "$flake_dir#$NIXOS_HOST" "$@"
            ;;
        boot)
            shift
            echo "🚀 Configurando para el próximo arranque desde $flake_dir..."
            sudo nixos-rebuild boot --flake "$flake_dir#$NIXOS_HOST" "$@"
            ;;
        *)
            echo "Uso: sys {test|rebuild|boot}"
            return 1
            ;;
    esac
}

# ── Inicializar Starship ──────────────────────────────────────
eval "$(starship init zsh)"