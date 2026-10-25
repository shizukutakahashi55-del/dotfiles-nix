#!/usr/bin/env bash
set -u
export PATH="$PATH:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:$HOME/.local/bin"

CMD="${1:-}"
PROV="${2:-}"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/oozeshell/agents"
ITER=300000

valid_prov() {
  case "$1" in
    anthropic|openai|gemini|openrouter|groq) return 0 ;;
    *) return 1 ;;
  esac
}

has_keyring() {
  command -v secret-tool >/dev/null 2>&1 || return 1
  command -v busctl >/dev/null 2>&1 || return 1
  [ "$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.secrets 2>/dev/null)" = "b true" ]
}

has_file_backend() {
  command -v openssl >/dev/null 2>&1 && [ -r /etc/machine-id ]
}

derive_pass() {
  printf '%s:%s:oozeshell-agents-v1' "$(cat /etc/machine-id 2>/dev/null)" "$(id -u)"
}

keyring_get() {
  secret-tool lookup service oozeshell-agents provider "$PROV" 2>/dev/null
}

file_get() {
  local f="$DIR/$PROV.enc"
  [ -s "$f" ] || return 1
  openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" -pass fd:3 -in "$f" 3< <(derive_pass) 2>/dev/null
}

file_put() {
  mkdir -p "$DIR" && chmod 700 "$DIR" || return 1
  (
    umask 077
    openssl enc -aes-256-cbc -pbkdf2 -iter "$ITER" -salt -pass fd:3 -out "$DIR/$PROV.enc.tmp" 3< <(derive_pass)
  ) && chmod 600 "$DIR/$PROV.enc.tmp" && mv -f "$DIR/$PROV.enc.tmp" "$DIR/$PROV.enc"
}

backend() {
  if has_keyring; then echo keyring
  elif has_file_backend; then echo file
  else echo none
  fi
}

case "$CMD" in
  backend)
    backend
    ;;
  status)
    valid_prov "$PROV" || { echo none; exit 2; }
    if has_keyring && [ -n "$(keyring_get)" ]; then echo keyring
    elif [ -s "$DIR/$PROV.enc" ]; then echo file
    else echo none
    fi
    ;;
  set)
    valid_prov "$PROV" || exit 2
    KEY=$(printf %s "${OOZE_AGENT_KEY:-}" | tr -d '[:space:]')
    unset OOZE_AGENT_KEY
    printf %s "$KEY" | grep -Eq '^[A-Za-z0-9_.-]{8,300}$' || exit 2
    B=$(backend)
    case "$B" in
      keyring)
        printf %s "$KEY" | secret-tool store --label="OozeShell agent: $PROV" service oozeshell-agents provider "$PROV" || exit 1
        rm -f "$DIR/$PROV.enc"
        ;;
      file)
        printf %s "$KEY" | file_put || exit 1
        ;;
      *) exit 3 ;;
    esac
    echo "$B"
    ;;
  get)
    valid_prov "$PROV" || exit 2
    V=""
    has_keyring && V=$(keyring_get)
    [ -z "$V" ] && V=$(file_get)
    [ -n "$V" ] || exit 1
    printf %s "$V"
    ;;
  remove)
    valid_prov "$PROV" || exit 2
    has_keyring && secret-tool clear service oozeshell-agents provider "$PROV" >/dev/null 2>&1
    rm -f "$DIR/$PROV.enc" "$DIR/$PROV.enc.tmp"
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
