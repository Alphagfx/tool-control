#!/bin/bash
#
# Задача скрипта
#  осуществлять корректные запуск и завершение задач
#  отслеживать необходимость выполняемой задачи и своевременно её прекращать
#
# Технические требования
#  время выполнения <5 секунд
#  параллельное (в спец. ситуациях синхронное) выполнение
[ "$DEBUG" == 'true' ] && set -x

WORK_DIR=${WORK_DIR:-~/.local/share/tool_control}
SUB_DIR=$WORK_DIR/proc_subs/
TOOL_STATE=$WORK_DIR/status
DELAY=${DELAY:-$((30 * 60))}  # delay in seconds


function print_usage() {
    cat <<EOF
`basename "$0"` <subscribe|unsubscribe|update> [subs_id]
    info <start|timeout|update|end> <subs_id>
        Show info about subscription
    subscribe [subs_id]
        Create new or update existing subscription
    unsubscribe <subs_id>
        Unsubscribe from the tool
    update
        Check subscriptions. The tool may be stopped if needed
    clean
        Stop the process and remove all subscriptions
EOF
}

function start_tool() {
    echo "Start tool"
}

function update_tool() {
    echo "Update tool"
}

function stop_tool() {
    echo "Stop tool"
}

function is_running() {
    if [[ ! -f "$TOOL_STATE" ]]; then
        echo "0" >> $TOOL_STATE
    fi
    cat $TOOL_STATE
}

function set_running() {
    case "$1" in
        0|1)
            echo "$1" > $TOOL_STATE
            ;;
        *)
            echo "Unknows tool status to set: $1"
            exit 1
    esac
}

function update_tool_state() {
    case "$1" in
        subscribed)
            if [[ $(is_running) == 0 ]]; then
               start_tool
               set_running 1
            else
                update_tool
            fi
            ;;
        unsubscribed | update)
            if [[ is_running == 1 ]]; then
                update_tool
                has_active_subs=$(jq --slurp 'any(.end == null)' $SUB_DIR/*)
                if [[ $has_active_subs == "false" ]]; then
                    stop_tool
                    set_running 0
                fi
            fi
            ;;
        *)
            echo "Unknown event $1"
            exit 1
            ;;
    esac
}

function subscribe() {
    subs=$1 # subscription file
    update_time=`date -Iseconds`
    timeout=$DELAY
    if [[ -f "$subs" ]]; then
        if [[ $(jq '.end' "$subs") == "null" ]]; then
            cat <<< $(jq --arg time "$update_time" '.update = $time' "$subs") > "$subs"
        else
            echo "This subscription already ended"
            exit 1
        fi
    else
        cat > "$subs" << EOF
{
  "start": "$update_time",
  "timeout": "$timeout",
  "update": "$update_time",
  "end": null
}
EOF
    fi
}

function unsubscribe() {
    subs=$1 # subscription file
    if [[ -f "$subs" ]]; then
        end_time=`date -Iseconds`
        if [[ $(jq '.end' "$subs") == "null" ]]; then
            cat <<< $(jq --arg time "$end_time" '.end = $time' "$subs") > "$subs"
        else
            echo "This subscription already ended"
            exit 1
        fi
    else
        echo "Invalid subscription name"
        exit 1
    fi
}

function check_subscription() {
    subs=$1 # subscription file
    if [[ -f "$subs" ]]; then
        if [[ $(jq '.end' "$subs") == "null" ]]; then
            current_time=`date -u +%s`
            update_time=$(date -u -d $(jq -r '.update' $subs) +%s)
            timeout=$(jq -r '.timeout' $subs)
            if ((update_time + timeout <= current_time)); then
                cat <<< $(jq --arg time "$current_time" '.end = $time' "$subs") > "$subs"
            fi
        else
            echo "This subscription already ended"
        fi
    else
        echo "Invalid subscription name"
        exit 1
    fi
}

function get_info() {
    SUB_FILE="$SUB_DIR/$2"
    if [[ ! -f "$SUB_FILE" ]]; then
        echo "Invalid subscription name"
        exit 1
    fi
    case "$1" in
        start|timeout|update|end)
            command=$1
            info=$(jq -r ".$command" $SUB_FILE)
            date -u -d "$info" +%s
            ;;
        *)
            echo "No such info for this subscription"
            exit 1
    esac
}



case "$1" in
    info)
        get_info "$2" "$3"  || { exit 1; }
        ;;
    subscribe)
        mkdir -p "$SUB_DIR"
        SUB_FILE="$SUB_DIR/${2:-`date +%Y%m%d_%H%M%S`}"
        subscribe "$SUB_FILE"  || { echo "Subscription failed"; exit 1; }
        echo "$SUB_FILE"
        update_tool_state subscribed
        ;;
    unsubscribe)
        SUB_FILE="$SUB_DIR/$2"
        unsubscribe "$SUB_FILE" || { echo "Unsubscription failed"; exit 1; }
        update_tool_state unsubscribed
        ;;
    update)
        for f in $SUB_DIR/*; do
            check_subscription "$f"
        done
        update_tool_state update
        ;;
    clean)
        if [[ -a "$SUB_DIR" ]]; then
            echo "Cleaning up subscriptions dir in '$SUB_DIR', please verify"
            rm -rfvI "$SUB_DIR"
        fi
        stop_tool
        ;;
    *)
        print_usage
        ;;
esac
