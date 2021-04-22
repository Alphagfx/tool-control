#!/bin/bash


[ "$DEBUG" == 'true' ] && set -x

WORK_DIR=${WORK_DIR:-~/.local/share/tool_control}
SUB_DIR=$WORK_DIR/proc_subs/
TOOL_STATE=$WORK_DIR/status
DELAY=${DELAY:-$((30 * 60))}  # delay in seconds


function print_usage() {
    cat <<EOF
`basename "$0"` <status|info|subscribe|unsubscribe|update|clean> [subs_id]
    status
        Show current status of the tool (running or not)
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
        unsubscribed|update)
            if [[ $(is_running) == 1 ]]; then
                update_tool
                for sub in $SUB_DIR/*; do
                    if [[ -z $(get_subs_value "$sub" end) ]]; then
                        return
                    fi
                done
                stop_tool
                set_running 0
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
        if [[ -z $(get_subs_value "$subs" end) ]]; then
            set_subs_value "$subs" update "$update_time"
        else
            echo "This subscription already ended"
            exit 1
        fi
    else
        cat > "$subs" << EOF
start=$update_time
timeout=$timeout
update=$update_time
end=
EOF
    fi
}

function unsubscribe() {
    subs=$1 # subscription file
    if [[ -f "$subs" ]]; then
        end_time=`date -Iseconds`
        if [[ -z $(get_subs_value "$subs" end) ]]; then
            set_subs_value "$subs" end "$end_time"
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
        if [[ -z $(get_subs_value "$subs" end) ]]; then
            current_time=`date -u +%s`
            update_time=$(date -u -d $(get_subs_value "$subs" update) +%s)
            timeout=$(get_subs_value "$subs" timeout)
            if ((update_time + timeout <= current_time)); then
                set_subs_value "$subs" end $current_time
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
            info=$(get_subs_value "$SUB_FILE" $command)
            if [[ -n "$info" ]]; then
                date -u -d "$info" +%s
            fi
            ;;
        *)
            echo "No such info for this subscription"
            exit 1
    esac
}


function get_subs_value() {
    file=$1
    key=$2
    sed -rn "s/^${key}=([^\n]+)$/\1/p" $file
}

function set_subs_value() {
    file=$1
    key=$2
    newvalue=$3

    ls $SUB_DIR

    if ! grep -R "^[#]*\s*${key}=.*" $file > /dev/null; then
        echo "Appening because '${key}' is not found"
        echo "$key=$newvalue" >> $file
    else
        echo "Updating because '${key}' is found"
        sed -i "s/^[#]*\s*${key}=.*/${key}=$newvalue/" $file
    fi

    ls $SUB_DIR
}



case "$1" in
    status)
        echo "Running: $(is_running)"
        ;;
    info)
        get_info "$2" "$3"  || { exit 1; }
        ;;
    subscribe)
        mkdir -p "$SUB_DIR"
        SUB_FILE=${2:-`date +%Y%m%d_%H%M%S`}
        subscribe "$SUB_DIR/$SUB_FILE"  || { echo "Subscription failed"; exit 1; }
        echo "Subscription name: $SUB_FILE"
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
        set_running 0
        stop_tool
        ;;
    *)
        print_usage
        ;;
esac
