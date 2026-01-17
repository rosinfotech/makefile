#!/bin/bash

PORTS=(8081)

check_port_processes() {
    local port=$1
    if lsof -ti:$port >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

wait_for_ports_to_be_free() {

    local active_processes=false
    for port in "${PORTS[@]}"; do
        if check_port_processes $port; then
            active_processes=true
            break
        fi
    done

    if [ "$active_processes" = true ]; then

        echo "Waiting for processes to finish..."

        for port in "${PORTS[@]}"; do
            lsof -ti:$port | xargs -r kill 2>/dev/null
        done

        count=0
        max_checks=10
        while [ $count -lt $max_checks ]; do
            local still_running=false
            for port in "${PORTS[@]}"; do
                if check_port_processes $port; then
                    still_running=true
                    break
                fi
            done

            if [ "$still_running" = false ]; then
                break
            fi

            sleep 0.5
            count=$((count + 1))
        done

        for port in "${PORTS[@]}"; do
            if check_port_processes $port; then
                lsof -ti:$port | xargs -r kill -9 2>/dev/null
            fi
        done
    fi
}

wait_for_ports_to_be_free

sleep 1
