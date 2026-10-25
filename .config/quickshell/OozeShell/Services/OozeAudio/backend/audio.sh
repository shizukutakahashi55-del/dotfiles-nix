# audio.sh — backend

set -u

SCRIPT_NAME="$(basename "$0")"

# ============================================================================


# ============================================================================


# ============================================================================

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

# ============================================================================

require_command "pw-cli"
require_command "pw-dump"
require_command "pw-link"
require_command "pw-loopback"
require_command "jq"
require_command "python3"
require_command "pgrep"
require_command "systemd-run"
require_command "systemctl"
require_command "wpctl"
require_command "flock"
require_command "pw-metadata"


# ============================================================================

# ============================================================================


STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/oozeshell"
STATE_FILE="$STATE_DIR/audio.toml"
LEGACY_FILE="$STATE_DIR/audio.json"
STATE_LOCK="$STATE_DIR/.audio.lock"
OPS_LOCK="$STATE_DIR/.audio.ops.lock"
STATE_DEFAULT='{"outputs":[],"apps":{}}'
TOML_TOOL="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../../Tools" 2>/dev/null && pwd)/ooze_toml.py"

state_json() {
    if [ -s "$STATE_FILE" ]; then
        python3 "$TOML_TOOL" to-json "$STATE_FILE" 2>/dev/null
    elif [ -s "$LEGACY_FILE" ]; then
        python3 "$TOML_TOOL" to-json "$LEGACY_FILE" 2>/dev/null
    else
        return 1
    fi
}

state_valid() {
    state_json | jq -e 'type == "object"' >/dev/null 2>&1
}

state_read() {
    local data
    if data="$(state_json)" && printf '%s' "$data" | jq -e 'type == "object"' >/dev/null 2>&1; then
        printf '%s' "$data"
    else
        printf '%s' "$STATE_DEFAULT"
    fi
}


state_update() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0

    (
        flock 9

        if [ -s "$STATE_FILE" ] && ! state_valid; then
            cp -f "$STATE_FILE" "$STATE_FILE.bak" 2>/dev/null || true
        fi

        tmp="$(mktemp "$STATE_DIR/.audio.toml.XXXXXX")" || exit 0
        tmp_json="$tmp.json"

        if state_read | jq "$@" >"$tmp_json" 2>/dev/null && [ -s "$tmp_json" ] \
            && python3 "$TOML_TOOL" from-json <"$tmp_json" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv -f "$tmp" "$STATE_FILE"
            [ -e "$LEGACY_FILE" ] && mv -f "$LEGACY_FILE" "$LEGACY_FILE.bak" 2>/dev/null
        else
            rm -f "$tmp"
        fi
        rm -f "$tmp_json"
    ) 9>"$STATE_LOCK"
}

acquire_ops_lock() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    exec 8>"$OPS_LOCK"
    flock -w 30 8 || die "Otra operación de OozeAudio sigue en curso"
}

state_add_output() {
    state_update --arg d "$1" --arg n "$2" '
        .outputs = ((.outputs // []) | map(select(.node != $n)))
                   + [{display: $d, node: $n, volume: 100, muted: false, links: []}]'
}

state_remove_output() {
    state_update --arg n "$1" '
        .outputs = ((.outputs // []) | map(select(.node != $n)))
        | .apps = ((.apps // {}) | with_entries(select(.value != $n)))'
}

state_set_links() {
    local node="$1"; shift
    local arr
    arr="$(printf '%s\n' "$@" | jq -R 'select(length > 0)' | jq -s '.')"
    state_update --arg n "$node" --argjson l "$arr" \
        '.outputs |= map(if .node == $n then .links = $l else . end)'
}

state_link_add() {
    state_update --arg n "$1" --arg d "$2" '
        .outputs |= map(if .node == $n
                        then .links = (((.links // []) + [$d]) | unique)
                        else . end)'
}

state_link_remove() {
    state_update --arg n "$1" --arg d "$2" '
        .outputs |= map(if .node == $n
                        then .links = ((.links // []) | map(select(. != $d)))
                        else . end)'
}

state_set_volume() {
    state_update --arg n "$1" --argjson v "$2" \
        '.outputs |= map(if .node == $n then .volume = $v else . end)'
}

state_set_muted() {
    local m="false"; [ "$2" = "1" ] && m="true"
    state_update --arg n "$1" --argjson m "$m" \
        '.outputs |= map(if .node == $n then .muted = $m else . end)'
}

state_app_set() {
    state_update --arg k "$1" --arg s "$2" '.apps = ((.apps // {}) + {($k): $s})'
}

state_app_clear() {
    state_update --arg k "$1" '.apps = ((.apps // {}) | del(.[$k]))'
}


# ============================================================================

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


sink_names() {
    pw-dump |
        jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | select((.info.props["media.class"] // "") == "Audio/Sink")
            | (.info.props["node.name"] // empty)
        '
}


current_links_of() {
    local name="$1"
    list_links | awk -F'\t' -v n="$name" '$1 == n { print $2 }'
}


sink_only() {
    local names n
    names="$(sink_names)"

    while IFS= read -r n; do
        [ -n "$n" ] || continue
        printf '%s\n' "$names" | grep -Fxq -- "$n" && printf '%s\n' "$n"
    done
}


# ============================================================================

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

# ============================================================================


spawn_loopback() {

    local display_name="$1"
    local sink_name="$2"


    local desc_escaped="${display_name//\"/\\\"}"

    local capture_props="node.name=$sink_name node.description=\"$desc_escaped\" media.class=Audio/Sink audio.position=[ FL FR ]"
    local playback_props="node.name=playback.$sink_name audio.position=[ FL FR ] node.passive=true stream.dont-remix=true"

    local unit_name="oozeaudio-${sink_name}"


    systemctl --user stop "$unit_name" >/dev/null 2>&1 || true
    systemctl --user reset-failed "$unit_name" >/dev/null 2>&1 || true

    local run_err
    run_err="$(mktemp)"

    systemd-run --user \
        --unit "$unit_name" \
        --description "OozeAudio virtual output: $display_name" \
        --collect \
        -p Restart=always \
        -p RestartSec=1 \
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


    local tries=0
    while ! virtual_output_exists "$sink_name" && [ "$tries" -lt 20 ]; do
        sleep 0.15
        tries=$((tries + 1))
    done

    if ! virtual_output_exists "$sink_name"; then

        echo
        echo "Unit started but the sink was not found. Recent logs:"
        journalctl --user -u "$unit_name" --no-pager -n 20 2>/dev/null

        systemctl --user stop "$unit_name" >/dev/null 2>&1 || true

        die "Virtual output creation failed"

    fi
}


wait_playback_linked() {
    local sink_name="$1"
    local tries=0

    while [ "$tries" -lt 20 ]; do
        if [ -n "$(current_links_of "$sink_name")" ]; then
            return 0
        fi
        sleep 0.1
        tries=$((tries + 1))
    done

    return 0
}


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

    spawn_loopback "$display_name" "$sink_name"


    state_add_output "$display_name" "$sink_name"


    wait_playback_linked "$sink_name"

    state_set_links "$sink_name" $(current_links_of "$sink_name" | sink_only)

    echo "Created virtual output: $display_name"
    echo "Internal sink: $sink_name"
}


# ============================================================================

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


    if [ "$stopped" -eq 0 ]; then

        local pids
        pids="$(pgrep -f -- "pw-loopback.*node.name=$sink_name" || true)"

        if [ -n "$pids" ]; then
            echo "Stopping pw-loopback process(es) for: $display_name"
            kill $pids 2>/dev/null || true
            stopped=1
        fi
    fi


    if [ "$stopped" -eq 0 ]; then


        if state_read | jq -e --arg n "$sink_name" 'any(.outputs[]?; .node == $n)' >/dev/null 2>&1; then
            state_remove_output "$sink_name"
            echo "Removed saved output (was not running): $display_name"
            return 0
        fi

        die "Virtual output not found: $display_name"
    fi


    local tries=0
    while virtual_output_exists "$sink_name" && [ "$tries" -lt 20 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done

    if virtual_output_exists "$sink_name"; then
        die "El nodo $sink_name sigue en el grafo tras detener la unidad"
    fi


    state_remove_output "$sink_name"

    echo "Deleted virtual output: $display_name"
}


# ============================================================================

# ============================================================================

list_ports() {
    local node_id="$1"
    local direction="$2"

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


link_nodes() {
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


    local linked=0

    while IFS=$'\t' read -r sport _sname schan; do

        [ -n "$sport" ] || continue

        local dport
        dport="$(printf '%s\n' "$dst_ports" | awk -F'\t' -v c="$schan" '$3==c{print $1; exit}')"

        if [ -z "$dport" ] && [ "$schan" = "MONO" ]; then

            while IFS=$'\t' read -r dport2 _ _; do
                [ -n "$dport2" ] || continue
                pw-link "$sport" "$dport2" >/dev/null 2>&1
                linked=1
            done <<< "$dst_ports"
            continue
        fi

        if [ -z "$dport" ]; then

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


connect_nodes() {
    link_nodes "$1" "$2"

    case "$1" in
        ooze_*) state_link_add "$1" "$2" ;;
    esac
}


unlink_nodes() {
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


disconnect_nodes() {
    unlink_nodes "$1" "$2"

    case "$1" in
        ooze_*) state_link_remove "$1" "$2" ;;
    esac
}


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

# ============================================================================


find_sink_id() {
    local sink_name="$1"

    pw-dump |
        jq -r --arg name "$sink_name" '
            .[]
            | select(.type == "PipeWire:Interface:Node")
            | select((.info.props["media.class"] // "") == "Audio/Sink")
            | select(.info.props["node.name"] == $name)
            | .id
        ' |
        head -n1
}


stream_move() {
    local sid="$1"
    local sink="${2:-default}"

    case "$sid" in
        ''|*[!0-9]*) die "Stream id must be a number" ;;
    esac

    if [ "$sink" = "default" ]; then
        pw-metadata -n default -d "$sid" target.node   >/dev/null 2>&1 || true
        pw-metadata -n default -d "$sid" target.object >/dev/null 2>&1 || true
        echo "Stream $sid -> default output"
        return 0
    fi

    local did
    did="$(find_sink_id "$sink")"
    [ -n "$did" ] || die "Sink not found: $sink"

    pw-metadata -n default "$sid" target.node "$did" >/dev/null 2>&1 ||
        die "pw-metadata no pudo mover el stream $sid"


    pw-metadata -n default "$sid" target.object "$sink" >/dev/null 2>&1 || true

    echo "Stream $sid -> $sink"
}


valid_app_key() {
    case "$1" in
        ''|*[!a-z0-9_.-]*) return 1 ;;
    esac
    return 0
}


stream_route() {
    valid_app_key "$2" || die "Invalid app key: $2"
    [ -n "$3" ] && [ "$3" != "default" ] || die "Usage: $SCRIPT_NAME stream-route ID KEY SINK"


    state_app_set "$2" "$3"
    stream_move "$1" "$3"
}


stream_unroute() {
    valid_app_key "$2" || die "Invalid app key: $2"
    state_app_clear "$2"
    stream_move "$1" default
}


list_app_rules() {
    state_read |
        jq -r '(.apps // {}) | to_entries[] | [.key, .value] | @tsv'
}


# ============================================================================

# ============================================================================


wait_for_pipewire() {
    local i=0
    while [ "$i" -lt 60 ]; do
        if pw-dump >/dev/null 2>&1 && wpctl status >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
        i=$((i + 1))
    done
    return 1
}


wait_for_hardware_sink() {
    local i=0
    while [ "$i" -lt 20 ]; do
        if sink_names | grep -qv '^ooze_'; then
            return 0
        fi
        sleep 0.4
        i=$((i + 1))
    done
    return 0
}


adopt_live_outputs() {
    local id name desc pct muted
    local known
    known="$(state_read | jq -r '.outputs[]?.node')"

    while IFS=$'\t' read -r id name desc pct muted; do
        [ -n "$name" ] || continue
        printf '%s\n' "$known" | grep -Fxq -- "$name" && continue

        state_add_output "$desc" "$name"
        state_set_volume "$name" "${pct:-100}"
        state_set_muted "$name" "${muted:-0}"

        state_set_links "$name" $(current_links_of "$name" | sink_only)
    done < <(list_outputs)
}


restore_outputs() {
    wait_for_pipewire || die "PipeWire no responde"
    wait_for_hardware_sink

    adopt_live_outputs

    local state count i
    state="$(state_read)"
    count="$(printf '%s' "$state" | jq '.outputs | length')"

    for ((i = 0; i < count; i++)); do

        local display node volume muted links created=0

        IFS=$'\t' read -r display node volume muted < <(
            printf '%s' "$state" |
                jq -r ".outputs[$i] | [.display, .node, (.volume // 100), (.muted // false)] | @tsv"
        )
        links="$(printf '%s' "$state" | jq -r ".outputs[$i].links // [] | .[]")"

        [ -n "$node" ] || continue

        if ! virtual_output_exists "$node"; then
            if ( spawn_loopback "${display:-$node}" "$node" ) >/dev/null 2>&1; then
                created=1
                echo "Restored output: $display ($node)"
            else
                echo "restore: no se pudo recrear $node" >&2
                continue
            fi
        fi

        if [ "$created" -eq 1 ]; then
            local nid
            nid="$(find_node_id "$node")"

            if [ -n "$nid" ]; then
                wpctl set-volume "$nid" "${volume:-100}%" >/dev/null 2>&1 || true
                if [ "$muted" = "true" ]; then
                    wpctl set-mute "$nid" 1 >/dev/null 2>&1 || true
                else
                    wpctl set-mute "$nid" 0 >/dev/null 2>&1 || true
                fi
            fi


            wait_playback_linked "$node"


            local dst
            while IFS= read -r dst; do
                [ -n "$dst" ] || continue
                printf '%s\n' "$links" | grep -Fxq -- "$dst" && continue
                ( unlink_nodes "$node" "$dst" ) </dev/null >/dev/null 2>&1 || true
            done < <(current_links_of "$node" | sink_only)
        fi


        local want present
        present="$(sink_names)"

        while IFS= read -r want; do
            [ -n "$want" ] || continue
            printf '%s\n' "$present" | grep -Fxq -- "$want" || continue
            current_links_of "$node" | grep -Fxq -- "$want" && continue
            ( link_nodes "$node" "$want" ) </dev/null >/dev/null 2>&1 || true
        done <<< "$links"

    done
}


# ============================================================================

# ============================================================================


node_name_of() {
    wpctl inspect "$1" 2>/dev/null |
        awk -F'"' '/^[ *]*node\.name = / { print $2; exit }'
}


persist_node_volume() {
    local name
    name="$(node_name_of "$1")"
    case "$name" in
        ooze_*) state_set_volume "$name" "$2" ;;
    esac
}

persist_node_mute() {
    local name
    name="$(node_name_of "$1")"
    case "$name" in
        ooze_*) state_set_muted "$name" "$2" ;;
    esac
}


set_node_volume() {
    local node_id="$1"
    local percent="$2"

    [ -n "$node_id" ] || die "Node id is required"

    case "$percent" in
        ''|*[!0-9]*) die "Volume must be a whole number (0-150)" ;;
    esac

    wpctl set-volume "$node_id" "${percent}%" ||
        die "No se pudo cambiar el volumen del nodo $node_id"

    persist_node_volume "$node_id" "$percent"

    echo "Volume set: $node_id -> ${percent}%"
}

set_node_mute() {
    local node_id="$1"
    local muted="$2"

    [ -n "$node_id" ] || die "Node id is required"

    case "$muted" in
        1)
            wpctl set-mute "$node_id" 1 ||
                die "No se pudo mutear el nodo $node_id"
            persist_node_mute "$node_id" 1
            echo "Muted: $node_id"
            ;;
        0)
            wpctl set-mute "$node_id" 0 ||
                die "No se pudo desmutear el nodo $node_id"
            persist_node_mute "$node_id" 0
            echo "Unmuted: $node_id"
            ;;
        *)
            die "Usage: $SCRIPT_NAME mute-set NODE_ID <0|1>"
            ;;
    esac
}


# ============================================================================

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

# ============================================================================

dump() {

    pw-dump
}


# ============================================================================

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

        acquire_ops_lock

        create_output "$2"

        ;;


    delete)

        [ "$#" -ge 2 ] ||
            die "Usage: $SCRIPT_NAME delete NAME"

        acquire_ops_lock

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


    restore)

        acquire_ops_lock

        restore_outputs

        ;;


    app-rules)

        list_app_rules

        ;;


    app-forget)

        [ "$#" -ge 2 ] ||
            die "Usage: $SCRIPT_NAME app-forget APP_KEY"

        valid_app_key "$2" || die "Invalid app key: $2"
        state_app_clear "$2"
        echo "Forgot rule: $2"

        ;;


    stream-move)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME stream-move STREAM_ID SINK|default"

        stream_move "$2" "$3"

        ;;


    stream-route)

        [ "$#" -ge 4 ] ||
            die "Usage: $SCRIPT_NAME stream-route STREAM_ID APP_KEY SINK"

        stream_route "$2" "$3" "$4"

        ;;


    stream-unroute)

        [ "$#" -ge 3 ] ||
            die "Usage: $SCRIPT_NAME stream-unroute STREAM_ID APP_KEY"

        stream_unroute "$2" "$3"

        ;;


    state)

        echo "$STATE_FILE"
        state_read | jq .

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
        echo "  $SCRIPT_NAME restore"
        echo "      Recreate saved virtual outputs, links and volumes (idempotent)"
        echo
        echo "  $SCRIPT_NAME state"
        echo "      Show the saved configuration ($STATE_FILE)"
        echo
        echo "  $SCRIPT_NAME app-rules"
        echo "      List saved per-app output rules as APP<TAB>SINK"
        echo
        echo "  $SCRIPT_NAME stream-route STREAM_ID APP_KEY SINK"
        echo "      Move an app's stream to SINK and remember it"
        echo
        echo "  $SCRIPT_NAME stream-unroute STREAM_ID APP_KEY"
        echo "      Back to the default output and forget the rule"
        echo
        echo "  $SCRIPT_NAME app-forget APP_KEY"
        echo "      Forget a saved per-app output rule"
        echo
        echo "  $SCRIPT_NAME stream-move STREAM_ID SINK|default"
        echo "      Move a stream without saving anything"
        echo

        exit 1

        ;;

esac
