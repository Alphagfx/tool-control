#!/bin/bash
#
# Задача скрипта
#  осуществлять корректные запуск и завершение задач
#  отслеживать необходимость выполняемой задачи и своевременно её прекращать
#
# Технические требования
#  время выполнения <5 секунд
#  параллельное (в спец. ситуациях синхронное) выполнение

SUB_DIR=/tmp/proc_subs/
DELAY=30
RUNNING=0

function print_usage() {
    echo "`basename "$0"` <subscribe|unsubscribe|update> [subs_id]"
    echo "  subscribe [subs_id]   : create new or update existing subscription"
    echo "  unsubscribe <subs_id> : unsubscribe"
    echo "  update                : check subscriptions and finish the process if needed"
    echo "  clean                 : stop the process and remove all subscriptions"
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

function update_tool_state() {
    case "$1" in
        subscribed)
            if [[ $RUNNING == 0 ]]; then
               start_tool
               RUNNING=1
            else
                update_tool
            fi
            ;;
        unsubscribed | update)
            update_tool
            if [[ -z $(ls -A $SUB_DIR) ]]; then
                stop_tool
                RUNNING=0
            fi
            ;;
        *)
            echo "Unknown event $1"
            exit 1
    esac
}

function subscribe() {
    subs=$1 # subscription file
    update_time=`date -Iseconds`
    timeout=$DELAY
    if [[ -f "$subs" ]]; then
        if [[ `jq '.ended' "$subs"` == "null" ]]; then
            cat <<< $(jq --arg time "$update_time" '.updated = $time' "$subs") > "$subs"
        else
            echo "This subscription already ended"
            exit 1
        fi
    else
        cat > "$subs" << EOF
{
  "started": "$update_time",
  "timeout": "$timeout",
  "updated": "$update_time",
  "ended": null
}
EOF
    fi
}

function unsubscribe() {
    subs=$1 # subscription file
    if [[ -f "$subs" ]]; then
        end_time=`date -Iseconds`
        if [[ `jq '.ended' "$subs"` == "null" ]]; then
            cat <<< $(jq --arg time "$end_time" '.ended = $time' "$subs") > "$subs"
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
        if [[ `jq '.ended' "$subs"` == "null" ]]; then
            current_time=`date -u +%s`
            expected_end_time=`date -u -d \`jq -r '.updated' sub.json\` +%s`
            if ((expected_end_time <= current_time)); then
                cat <<< $(jq --arg time "$current_time" '.ended = $time' "$subs") > "$subs"
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
        started|updated|ended)
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
        for f in "$SUB_DIR"; do
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