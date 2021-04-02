#!/bin/sh
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

case "$1" in
    subscribe)
        mkdir -p $SUB_DIR
        SUB_FILE=${2:-`date +%Y%m%d_%H%M%S`}
        touch -a "$SUB_DIR/$SUB_FILE"
        echo $SUB_FILE
        update_tool_state subscribed
        ;;
    unsubscribe)
        SUB_FILE="$SUB_DIR/$2"
        if [[ ! -a $SUB_FILE ]]; then
            echo "Invalid subscription name"
            exit 1
        fi
        rm "$SUB_FILE"
        update_tool_state unsubscribed
        ;;
    update)
        find $SUB_DIR -amin +$DELAY -type f -delete
        update_tool_state update
        ;;
    clean)
        if [[ -a $SUB_DIR ]]; then
            echo "Cleaning up subscriptions dir in $SUB_DIR, please verify"
            rm -rfvI $SUB_DIR
        fi
        stop_tool
        ;;
    *)
        print_usage
        ;;
esac