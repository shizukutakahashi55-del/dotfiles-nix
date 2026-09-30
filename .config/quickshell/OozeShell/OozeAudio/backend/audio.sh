#!/usr/bin/env bash

set -u

SCRIPT_NAME="$(basename "$0")"

# ============================================================================
# OozeAudio
# PipeWire virtual audio output manager
#
# Backend:
#   - pw-cli
#   - pw-dump
#   - jq
#   - pw-link
#
# No pactl / PulseAudio required.
# ============================================================================


# ============================================================================
# UTILITIES
# ============================================================================

die() {
    echo "ERROR: $*" >&2
    exit 1
}


require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        die "Required command not found: $1"
}


normalize_name() {
    echo "$1" |
        tr '[:upper:]' '[:lower:]' |
        tr ' ' '_' |
        tr -cd '[:alnum:]_-'
}


# ============================================================================
# PIPEWIRE CHECKS
# ============================================================================

require_command "pw-cli"
require_command "pw-dump"
require_command "pw-link"
require_command "pw-loopback"
require_command "jq"
require_command "pgrep"
require_command "systemd-run"
require_command "systemctl"
require_command "wpctl"


# ============================================================================
# FIND OBJECTS
# ============================================================================

find_node_id() {
    local node_name="$1"

    pw-dump |
        jq -r --arg name "$node_name" '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | select(.info.props["node.name"] == $name)
            | .id
        ' |
        head -n1
}


find_loopback_nodes() {
    local sink_name="$1"

    pw-dump |
        jq -r --arg name "$sink_name" '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | select(
                .info.props["node.name"] == $name
                or
                .info.props["node.name"] == ("playback." + $name)
            )
            | .id
        '
}


virtual_output_exists() {
    local sink_name="$1"

    pw-dump |
        jq -e --arg name "$sink_name" '
            any(
                .[];
                .type == "PipeWire:Interface:Node"
                and
                .info.props["node.name"] == $name
            )
        ' >/dev/null 2>&1
}


# ============================================================================
# VOLUME
# ============================================================================

node_volume_pct() {
    local node_id="$1"
    local line
    line="$(wpctl get-volume "$node_id" 2>/dev/null)"

    local vol
    vol="$(printf '%s' "$line" | awk '{ for (i = 1; i <= NF; i++) if ($i == "Volume:") print $(i+1) }')"
    [ -n "$vol" ] || vol="0"

    local muted="0"
    printf '%s' "$line" | grep -qi "MUTED" && muted="1"

    local pct
    pct="$(awk -v v="$vol" 'BEGIN { printf "%d", (v * 100) + 0.5 }' 2>/dev/null)"
    [ -n "$pct" ] || pct="0"

    printf '%s\t%s' "$pct" "$muted"
}


# ============================================================================
# LIST VIRTUAL OUTPUTS
# ============================================================================

list_outputs() {

    pw-dump |
        jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | .info.props as $p
            | select(
                ($p["media.class"] // "") == "Audio/Sink"
                and
                (($p["node.name"] // "") | startswith("ooze_"))
            )
            | [
                .id,
                ($p["node.name"] // ""),
                ($p["node.description"] // $p["node.name"])
            ]
            | @tsv
        ' |
        while IFS=$'\t' read -r id name desc; do
            [ -n "$id" ] || continue
            printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$desc" "$(node_volume_pct "$id")"
        done
}


# ============================================================================
# LIST ALL AUDIO SINKS
# ============================================================================

list_sinks() {

    pw-dump |
        jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | .info.props as $p
            | select(
                ($p["media.class"] // "") == "Audio/Sink"
            )
            | [
                .id,
                ($p["node.name"] // ""),
                ($p["node.description"] // "")
            ]
            | @tsv
        ' |
        while IFS=$'\t' read -r id name desc; do
            [ -n "$id" ] || continue
            printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$desc" "$(node_volume_pct "$id")"
        done
}


# ============================================================================
# LIST AUDIO SOURCES
# ============================================================================

list_sources() {

    pw-dump |
        jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | .info.props as $p
            | select(
                ($p["media.class"] // "") == "Audio/Source"
            )
            | [
                .id,
                ($p["node.name"] // ""),
                ($p["node.description"] // "")
            ]
            | @tsv
        '
}


# ============================================================================
# LIST AUDIO STREAMS
# ============================================================================

list_streams() {

    pw-dump |
        jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | .info.props as $p
            | select(
                ($p["media.class"] // "") == "Stream/Output/Audio"
                or
                ($p["media.class"] // "") == "Stream/Input/Audio"
            )
            | [
                .id,
                ($p["media.class"] // ""),
                ($p["application.name"] // ""),
                ($p["node.name"] // ""),
                ($p["node.description"] // "")
            ]
            | @tsv
        '
}


# ============================================================================
# CREATE VIRTUAL OUTPUT
# ============================================================================

create_output() {

    local display_name="$1"

    [ -n "$display_name" ] ||
        die "Output name is required"


    local safe_name
    safe_name="$(normalize_name "$display_name")"


    [ -n "$safe_name" ] ||
        die "Invalid output name"


    local sink_name="ooze_${safe_name}"


    if virtual_output_exists "$sink_name"; then
        die "Virtual output already exists: $display_name"
    fi


    echo "Creating virtual output: $display_name"
    echo "Node: $sink_name"


    # pw-loopback needs to run as a long-lived process. Backgrounding it
    # with `nohup ... &` still leaves it inside the caller's process tree
    # (cgroup/systemd scope): if that caller is quickshell itself, killing
    # or restarting quickshell takes the loopback down with it, disowned or
    # not. Running it as its own transient systemd --user unit fully
    # detaches it -- it survives quickshell restarting, and can be stopped
    # reliably by unit name instead of a PID file that can go stale.
    local desc_escaped="${display_name//\"/\\\"}"

    local capture_props="node.name=$sink_name node.description=\"$desc_escaped\" media.class=Audio/Sink audio.position=[ FL FR ]"
    local playback_props="node.name=playback.$sink_name audio.position=[ FL FR ] node.passive=true stream.dont-remix=true"

    local unit_name="oozeaudio-${sink_name}"

    # Clear out any leftover unit of the same name sitting in a "failed"
    # state from a previous attempt, so systemd-run can reuse the name.
    systemctl --user stop "$unit_name" >/dev/null 2>&1 || true
    systemctl --user reset-failed "$unit_name" >/dev/null 2>&1 || true

    local run_err
    run_err="$(mktemp)"

    systemd-run --user \
        --unit "$unit_name" \
        --description "OozeAudio virtual output: $display_name" \
        --collect \
        pw-loopback \
            --capture-props "$capture_props" \
            --playback-props "$playback_props" \
        2>"$run_err"

    local run_status=$?

    if [ $run_status -ne 0 ]; then

        echo
        echo "systemd-run failed to start the unit (exit $run_status)."

        if [ -s "$run_err" ]; then
            echo "systemd-run said:"
            cat "$run_err"
        fi

        rm -f "$run_err"

        die "Virtual output creation failed"
    fi

    rm -f "$run_err"

    echo "systemd unit: $unit_name.service"


    # Give WirePlumber/PipeWire a moment to publish the nodes.
    sleep 0.6


    if virtual_output_exists "$sink_name"; then

        echo "Created virtual output: $display_name"
        echo "Internal sink: $sink_name"

    else

        echo
        echo "Unit started but the sink was not found. Recent logs:"
        journalctl --user -u "$unit_name" --no-pager -n 20 2>/dev/null

        systemctl --user stop "$unit_name" >/dev/null 2>&1 || true

        die "Virtual output creation failed"

    fi
}


# ============================================================================
# DELETE VIRTUAL OUTPUT
# ============================================================================

delete_output() {

    local display_name="$1"

    [ -n "$display_name" ] ||
        die "Output name is required"


    local safe_name
    safe_name="$(normalize_name "$display_name")"


    [ -n "$safe_name" ] ||
        die "Invalid output name"


    local sink_name="ooze_${safe_name}"
    local unit_name="oozeaudio-${sink_name}"

    local stopped=0
    local stop_err
    stop_err="$(mktemp)"

    if systemctl --user stop "$unit_name" 2>"$stop_err"; then
        echo "Stopped systemd unit: $unit_name.service"
        stopped=1
    fi

    rm -f "$stop_err"

    systemctl --user reset-failed "$unit_name" >/dev/null 2>&1 || true


    # Fallback for outputs created by an older version of this script that
    # used a bare background process instead of a systemd unit.
    if [ "$stopped" -eq 0 ]; then

        local pids
        pids="$(pgrep -f -- "pw-loopback.*node.name=$sink_name" || true)"

        if [ -n "$pids" ]; then
            echo "Stopping pw-loopback process(es) for: $display_name"
            kill $pids 2>/dev/null || true
            stopped=1
        fi
    fi


    [ "$stopped" -eq 1 ] ||
        die "Virtual output not found: $display_name"


   
    local tries=0
    while virtual_output_exists "$sink_name" && [ "$tries" -lt 20 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done

    if virtual_output_exists "$sink_name"; then
        die "El nodo $sink_name sigue en el grafo tras detener la unidad"
    fi

    echo "Deleted virtual output: $display_name"
}


# ============================================================================
# PORTS / LINKS (used to route virtual outputs to real destinations)
# ============================================================================

list_ports() {
    local node_id="$1"
    local direction="$2"   # "output" or "input"

    pw-dump |
        jq -r --arg id "$node_id" --arg dir "$direction" '
            .[]
            | select(.type == "PipeWire:Interface:Port")
            | select((.info.props["node.id"] | tostring) == $id)
            | select(.info.direction == $dir)
            | [
                .id,
                (.info.props["port.name"] // ""),
                (.info.props["audio.channel"] // "MONO")
              ]
            | @tsv
        '
}


# Un virtual output "ooze_X" (Audio/Sink) es el nodo que ven las apps para
# ESCRIBIR ahí; el que de verdad tiene puertos de SALIDA hacia otro
# dispositivo es su gemelo "playback.ooze_X" (el loopback que pw-loopback
# levanta). 
resolve_output_node_id() {
    local name="$1"
    local id

    id="$(find_node_id "playback.$name")"

    if [ -z "$id" ]; then
        id="$(find_node_id "$name")"
    fi

    echo "$id"
}

resolve_input_node_id() {
    find_node_id "$1"
}


connect_nodes() {
    local src_name="$1"
    local dst_name="$2"

    local src_id dst_id
    src_id="$(resolve_output_node_id "$src_name")"
    dst_id="$(resolve_input_node_id "$dst_name")"

    [ -n "$src_id" ] || die "Source node not found: $src_name"
    [ -n "$dst_id" ] || die "Destination node not found: $dst_name"

    local src_ports dst_ports
    src_ports="$(list_ports "$src_id" "output")"
    dst_ports="$(list_ports "$dst_id" "input")"

    [ -n "$src_ports" ] || die "Source node has no output ports: $src_name"
    [ -n "$dst_ports" ] || die "Destination node has no input ports: $dst_name"

    # Empareja por canal (FL-FL, FR-FR...) en vez de por orden de lista, que
    # se rompe apenas los dos nodos listan sus puertos en distinto orden.
    local linked=0

    while IFS=$'\t' read -r sport _sname schan; do

        [ -n "$sport" ] || continue

        local dport
        dport="$(printf '%s\n' "$dst_ports" | awk -F'\t' -v c="$schan" '$3==c{print $1; exit}')"

        if [ -z "$dport" ] && [ "$schan" = "MONO" ]; then
            # Origen mono -> a todos los canales del destino
            while IFS=$'\t' read -r dport2 _ _; do
                [ -n "$dport2" ] || continue
                pw-link "$sport" "$dport2" >/dev/null 2>&1
                linked=1
            done <<< "$dst_ports"
            continue
        fi

        if [ -z "$dport" ]; then
            # Sin match de canal: mejor esfuerzo, el primer puerto del destino
            dport="$(printf '%s\n' "$dst_ports" | head -n1 | cut -f1)"
        fi

        [ -n "$dport" ] || continue
        pw-link "$sport" "$dport" >/dev/null 2>&1
        linked=1

    done <<< "$src_ports"

    [ "$linked" = "1" ] ||
        die "No se pudo emparejar ningún canal entre $src_name y $dst_name"

    echo "Connected: $src_name -> $dst_name"
}


disconnect_nodes() {
    local src_name="$1"
    local dst_name="$2"

    local src_id dst_id
    src_id="$(resolve_output_node_id "$src_name")"
    dst_id="$(resolve_input_node_id "$dst_name")"

    [ -n "$src_id" ] || die "Source node not found: $src_name"
    [ -n "$dst_id" ] || die "Destination node not found: $dst_name"

    pw-dump |
        jq -r --arg sid "$src_id" --arg did "$dst_id" '
            .[]
            | select(.type == "PipeWire:Interface:Link")
            | select((.info["output-node-id"] | tostring) == $sid)
            | select((.info["input-node-id"] | tostring) == $did)
            | .id
        ' |
        while read -r lid; do
            [ -n "$lid" ] || continue
            pw-cli destroy "$lid" || true
        done

    echo "Disconnected: $src_name -> $dst_name"
}


# List every active link as "SRC_NODE_NAME<TAB>DST_NODE_NAME", with the
# "playback." prefix stripped from loopback sources so it matches the
# virtual output name shown in the UI.
list_links() {
    pw-dump |
        jq -r '
            . as $all
            | (map(select(.type == "PipeWire:Interface:Node"))) as $nodes
            | ($nodes | map({(.id | tostring): (.info.props["node.name"] // "")}) | add) as $names
            | $all[]
            | select(.type == "PipeWire:Interface:Link")
            | ($names[(.info["output-node-id"] | tostring)] // "") as $srcname
            | ($names[(.info["input-node-id"] | tostring)] // "") as $dstname
            | select($srcname != "" and $dstname != "")
            | [($srcname | sub("^playback\\."; "")), $dstname]
            | @tsv
        ' |
        sort -u
}


# ============================================================================
# SET VOLUME / MUTE
# ============================================================================

set_node_volume() {
    local node_id="$1"
    local percent="$2"

    [ -n "$node_id" ] || die "Node id is required"

    case "$percent" in
        ''|*[!0-9]*) die "Volume must be a whole number (0-150)" ;;
    esac

    wpctl set-volume "$node_id" "${percent}%" ||
        die "No se pudo cambiar el volumen del nodo $node_id"

    echo "Volume set: $node_id -> ${percent}%"
}

set_node_mute() {
    local node_id="$1"
    local muted="$2"   # "1" o "0"

    [ -n "$node_id" ] || die "Node id is required"

    case "$muted" in
        1)
            wpctl set-mute "$node_id" 1 ||
                die "No se pudo mutear el nodo $node_id"
            echo "Muted: $node_id"
            ;;
        0)
            wpctl set-mute "$node_id" 0 ||
                die "No se pudo desmutear el nodo $node_id"
            echo "Unmuted: $node_id"
            ;;
        *)
            die "Usage: $SCRIPT_NAME mute-set NODE_ID <0|1>"
            ;;
    esac
}


# ============================================================================
# STATUS
# ============================================================================

status() {

    echo
    echo "=== OozeAudio / PipeWire ==="
    echo

    echo "Virtual Outputs:"
    echo "----------------"

    local outputs
    outputs="$(list_outputs)"

    if [ -n "$outputs" ]; then
        echo "$outputs"
    else
        echo "No virtual outputs."
    fi


    echo
    echo "Physical / Other Sinks:"
    echo "-----------------------"

    list_sinks


    echo
    echo "Audio Sources:"
    echo "--------------"

    list_sources


    echo
    echo "Audio Streams:"
    echo "--------------"

    list_streams
}


# ============================================================================
# RAW PIPEWIRE GRAPH
# ============================================================================

dump() {

    pw-dump
}


# ============================================================================
# COMMANDS
# ============================================================================

case "${1:-}" in

    status)

        status

        ;;


    sinks)

        list_sinks

        ;;


    sources)

        list_sources

        ;;


    streams)

        list_streams

        ;;


    outputs)

        list_outputs

        ;;


    dump)

        dump

        ;;


    create)

        [ "$#" -ge 2 ] ||
            die "Usage: $SCRIPT_NAME create NAME"

        create_output "$2"

        ;;


    delete)

        [ "$#" -ge 2 ] ||
            die "Usage: $SCRIPT_NAME delete NAME"

        delete_output "$2"

        ;;


    links)

        list_links

        ;;


    connect)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME connect SOURCE DEST"

        connect_nodes "$2" "$3"

        ;;


    disconnect)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME disconnect SOURCE DEST"

        disconnect_nodes "$2" "$3"

        ;;


    volume-set)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME volume-set NODE_ID PERCENT"

        set_node_volume "$2" "$3"

        ;;


    mute-set)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME mute-set NODE_ID <0|1>"

        set_node_mute "$2" "$3"

        ;;


    *)

        echo
        echo "OozeAudio - PipeWire Audio Manager"
        echo
        echo "Usage:"
        echo
        echo "  $SCRIPT_NAME status"
        echo "      Show complete OozeAudio status"
        echo
        echo "  $SCRIPT_NAME sinks"
        echo "      List audio sinks"
        echo
        echo "  $SCRIPT_NAME sources"
        echo "      List audio sources"
        echo
        echo "  $SCRIPT_NAME streams"
        echo "      List audio streams"
        echo
        echo "  $SCRIPT_NAME outputs"
        echo "      List OozeAudio virtual outputs"
        echo
        echo "  $SCRIPT_NAME dump"
        echo "      Dump complete PipeWire graph as JSON"
        echo
        echo "  $SCRIPT_NAME create NAME"
        echo "      Create a virtual output"
        echo
        echo "  $SCRIPT_NAME delete NAME"
        echo "      Delete a virtual output"
        echo
        echo "  $SCRIPT_NAME links"
        echo "      List active connections as SRC<TAB>DST"
        echo
        echo "  $SCRIPT_NAME connect SOURCE DEST"
        echo "      Link SOURCE node ports to DEST node ports"
        echo
        echo "  $SCRIPT_NAME disconnect SOURCE DEST"
        echo "      Remove links between SOURCE and DEST"
        echo
        echo "  $SCRIPT_NAME volume-set NODE_ID PERCENT"
        echo "      Set a node's volume (0-150)"
        echo
        echo "  $SCRIPT_NAME mute-set NODE_ID <0|1>"
        echo "      Mute or unmute a node"
        echo

        exit 1

        ;;

esac