#!/usr/bin/env bash
set -u
export PATH="$PATH:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:$HOME/.local/bin:$HOME/.npm-global/bin"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-}"

fail() { jq -cn --arg e "$1" '{ok:false,error:$e}'; exit 0; }
done_ok() { jq -cn --arg t "$1" '{ok:true,text:$t}'; exit 0; }

if [ "$MODE" = detect ]; then
  for c in claude gemini codex ollama; do
    command -v "$c" >/dev/null 2>&1 && echo "$c"
  done
  exit 0
fi

[ "$MODE" = ask ] || exit 2
command -v jq >/dev/null 2>&1 || fail "Falta jq"

AGENT="${2:-}"
MODEL="${3:-}"
PAYLOAD="${OOZE_AGENT_PAYLOAD:-}"
unset OOZE_AGENT_PAYLOAD
printf %s "$PAYLOAD" | jq -e '.messages | length > 0' >/dev/null 2>&1 || fail "Mensaje vacío"
printf %s "$MODEL" | grep -Eq '^[A-Za-z0-9._:/-]{1,100}$' || [ -z "$MODEL" ] || fail "Modelo inválido"

SYS=$(printf %s "$PAYLOAD" | jq -r '.system // ""')

PROMPT=$(printf %s "$PAYLOAD" | jq -r '
  if (.messages | length) == 1 then
    (if (.system // "") != "" then .system + "\n\n" else "" end) + .messages[0].content
  else
    [(if (.system // "") != "" then .system else empty end),
     (.messages[] | (if .role == "assistant" then "Asistente: " else "Usuario: " end) + .content)] | join("\n\n")
  end')

need_key() {
  command -v curl >/dev/null 2>&1 || fail "Falta curl"
  KEY=$(bash "$HERE/agent-secrets.sh" get "$1") || fail "No hay API key guardada para este agente"
}

post() {
  local url="$1" hdr="$2"
  shift 2
  printf %s "$BODY" | curl -sS -m 120 --config <(printf 'header = "%s: %s"\n' "$hdr" "$KEY") \
    -H 'content-type: application/json' "$@" --data-binary @- "$url" 2>&1
}

finish() {
  local resp="$1" textq="$2" errq="$3"
  printf %s "$resp" | jq -e . >/dev/null 2>&1 || fail "Respuesta inválida: ${resp:0:200}"
  local err text
  err=$(printf %s "$resp" | jq -r "$errq // empty")
  [ -n "$err" ] && fail "$err"
  text=$(printf %s "$resp" | jq -r "$textq // empty")
  [ -n "$text" ] || fail "Respuesta vacía"
  done_ok "$text"
}

run_cli() {
  local bin="$1"
  command -v "$bin" >/dev/null 2>&1 || fail "No está instalado: $bin"
  local out rc
  case "$bin" in
    claude) out=$(printf %s "$PROMPT" | timeout 180 claude -p 2>&1); rc=$? ;;
    gemini) out=$(timeout 180 gemini -p "$PROMPT" 2>/dev/null); rc=$? ;;
    codex)  out=$(timeout 180 codex exec --skip-git-repo-check "$PROMPT" 2>/dev/null); rc=$? ;;
  esac
  [ "$rc" -eq 124 ] && fail "Tiempo agotado"
  [ "$rc" -ne 0 ] && fail "${out:-El agente terminó con error. ¿Iniciaste sesión?}"
  [ -n "$out" ] || fail "Respuesta vacía"
  done_ok "$out"
}

case "$AGENT" in
  anthropic)
    need_key anthropic
    BODY=$(printf %s "$PAYLOAD" | jq -c --arg m "$MODEL" '{model:$m,max_tokens:2048,messages:.messages} + (if (.system // "") != "" then {system:.system} else {} end)')
    RESP=$(post https://api.anthropic.com/v1/messages x-api-key -H 'anthropic-version: 2023-06-01')
    finish "$RESP" '[.content[]? | select(.type == "text") | .text] | join("")' '.error.message'
    ;;
  openai|openrouter|groq)
    need_key "$AGENT"
    BODY=$(printf %s "$PAYLOAD" | jq -c --arg m "$MODEL" '{model:$m,messages:((if (.system // "") != "" then [{role:"system",content:.system}] else [] end) + .messages)}')
    case "$AGENT" in
      openrouter) URL=https://openrouter.ai/api/v1/chat/completions ;;
      groq)       URL=https://api.groq.com/openai/v1/chat/completions ;;
      *)          URL=https://api.openai.com/v1/chat/completions ;;
    esac
    KEYHDR="Bearer $KEY"
    KEY="$KEYHDR"
    RESP=$(post "$URL" Authorization)
    finish "$RESP" '.choices[0].message.content' '.error.message'
    ;;
  gemini)
    need_key gemini
    BODY=$(printf %s "$PAYLOAD" | jq -c '{contents:[.messages[] | {role:(if .role == "assistant" then "model" else "user" end),parts:[{text:.content}]}]} + (if (.system // "") != "" then {systemInstruction:{parts:[{text:.system}]}} else {} end)')
    RESP=$(post "https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent" x-goog-api-key)
    finish "$RESP" '[.candidates[0].content.parts[]?.text] | join("")' '.error.message'
    ;;
  ollama)
    command -v curl >/dev/null 2>&1 || fail "Falta curl"
    BODY=$(printf %s "$PAYLOAD" | jq -c --arg m "$MODEL" '{model:$m,stream:false,messages:((if (.system // "") != "" then [{role:"system",content:.system}] else [] end) + .messages)}')
    RESP=$(printf %s "$BODY" | curl -sS -m 300 -H 'content-type: application/json' --data-binary @- http://127.0.0.1:11434/api/chat 2>&1) || fail "Ollama no responde en 127.0.0.1:11434"
    finish "$RESP" '.message.content' '.error'
    ;;
  claude-cli) run_cli claude ;;
  gemini-cli) run_cli gemini ;;
  codex-cli)  run_cli codex ;;
  *) fail "Agente desconocido" ;;
esac
