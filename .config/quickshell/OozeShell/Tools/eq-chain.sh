#!/usr/bin/env bash
set -u
export PATH="$PATH:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:$HOME/.local/bin"

RUN="${XDG_RUNTIME_DIR:-/tmp}/oozeshell"
CONF="$RUN/ooze-eq.conf"
PREV="$RUN/ooze-eq.prev"
NAME="ooze_eq"
FREQS=(60 120 250 500 1000 2000 4000 8000)

mkdir -p "$RUN"

node_id() {
  pw-dump 2>/dev/null | jq -r --arg n "effect_input.$NAME" \
    '[.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $n) | .id][0] // empty'
}

sink_name() {
  wpctl inspect "$1" 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)"/\1/p' | head -n1
}

mult() { awk -v d="$1" -v b="$2" -v s="$3" 'BEGIN {
  g = 10 ^ (d / 20)
  if (s == "L") g = g * (b > 0 ? 1 - b : 1)
  else g = g * (b < 0 ? 1 + b : 1)
  printf "%.4f", g
}'; }

write_conf() {
  local target="$1"; shift
  local g=("$@")
  local nodes="" links="" i ch prev
  for ch in L R; do
    prev=""
    for i in 0 1 2 3 4 5 6 7; do
      nodes+="        { type = builtin name = eq${ch}$i label = bq_peaking control = { Freq = ${FREQS[$i]} Q = ${g[12]:-1.4} Gain = ${g[$i]:-0} } }
"
      [ -n "$prev" ] && links+="        { output = \"$prev:Out\" input = \"eq${ch}$i:In\" }
"
      prev="eq${ch}$i"
    done
    nodes+="        { type = builtin name = bs$ch label = bq_lowshelf control = { Freq = 100 Q = 0.7 Gain = ${g[10]:-0} } }
        { type = builtin name = tr$ch label = bq_highshelf control = { Freq = 6000 Q = 0.7 Gain = ${g[11]:-0} } }
        { type = builtin name = g$ch label = linear control = { Mult = $(mult "${g[8]:-0}" "${g[9]:-0}" "$ch") Add = 0.0 } }
"
    links+="        { output = \"$prev:Out\" input = \"bs$ch:In\" }
        { output = \"bs$ch:Out\" input = \"tr$ch:In\" }
        { output = \"tr$ch:Out\" input = \"g$ch:In\" }
"
  done
  local tgt=""
  [ -n "$target" ] && tgt="target.object = \"$target\""
  cat > "$CONF" <<CFG
context.properties = { log.level = 0 }
context.spa-libs = {
  audio.convert.* = audioconvert/libspa-audioconvert
  support.*       = support/libspa-support
}
context.modules = [
  { name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }
  { name = libpipewire-module-protocol-native }
  { name = libpipewire-module-client-node }
  { name = libpipewire-module-adapter }
  { name = libpipewire-module-filter-chain
    args = {
      node.description = "Ooze Equalizer"
      media.name = "Ooze Equalizer"
      filter.graph = {
        nodes = [
${nodes}        ]
        links = [
${links}        ]
        inputs = [ "eqL0:In" "eqR0:In" ]
        outputs = [ "gL:Out" "gR:Out" ]
      }
      audio.channels = 2
      audio.position = [ FL FR ]
      capture.props = {
        node.name = "effect_input.$NAME"
        media.class = Audio/Sink
      }
      playback.props = {
        node.name = "effect_output.$NAME"
        node.passive = true
        $tgt
      }
    }
  }
]
CFG
}

apply_params() {
  local id; id="$(node_id)"
  [ -n "$id" ] || return 1
  local g=("$@") i ch p=""
  for ch in L R; do
    for i in 0 1 2 3 4 5 6 7; do
      p+="\"eq${ch}$i:Gain\" $(printf %.2f "${g[$i]:-0}") \"eq${ch}$i:Q\" $(printf %.2f "${g[12]:-1.4}") "
    done
    p+="\"bs$ch:Gain\" $(printf %.2f "${g[10]:-0}") \"tr$ch:Gain\" $(printf %.2f "${g[11]:-0}") "
    p+="\"g$ch:Mult\" $(mult "${g[8]:-0}" "${g[9]:-0}" "$ch") "
  done
  pw-cli s "$id" Props "{ params = [ $p] }" >/dev/null 2>&1
}

running() { [ -n "$(node_id)" ]; }

case "${1:-}" in
  status)
    running && echo on || echo off
    ;;
  start)
    shift
    for c in pipewire pw-cli pw-dump wpctl jq; do
      command -v "$c" >/dev/null 2>&1 || { echo "missing:$c"; exit 0; }
    done
    if running; then apply_params "$@"; echo ok; exit 0; fi
    cur="$(sink_name @DEFAULT_AUDIO_SINK@)"
    case "$cur" in effect_input.*) cur="" ;; esac
    [ -n "$cur" ] && printf %s "$cur" > "$PREV"
    write_conf "$cur" "$@"
    setsid -f pipewire -c "$CONF" >/dev/null 2>&1 < /dev/null
    for _ in $(seq 1 40); do running && break; sleep 0.1; done
    running || { echo "failed"; exit 0; }
    id="$(node_id)"
    wpctl set-default "$id" >/dev/null 2>&1
    echo ok
    ;;
  target)
    [ -f "$PREV" ] || exit 0
    pw-dump 2>/dev/null | jq -r --arg n "$(cat "$PREV")" \
      '[.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $n) | .info.props["node.description"]][0] // empty'
    ;;
  apply)
    shift
    apply_params "$@" && echo ok || echo off
    ;;
  stop)
    prev=""
    [ -f "$PREV" ] && prev="$(cat "$PREV")"
    pkill -f "pipewire -c $CONF" >/dev/null 2>&1
    for _ in $(seq 1 30); do running || break; sleep 0.1; done
    if [ -n "$prev" ]; then
      pid="$(pw-dump 2>/dev/null | jq -r --arg n "$prev" '[.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == $n) | .id][0] // empty')"
      [ -n "$pid" ] && wpctl set-default "$pid" >/dev/null 2>&1
    fi
    echo ok
    ;;
  *)
    exit 2
    ;;
esac
