#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u
source "scripts/textutils.sh"

if [[ $(id -u) -ne 0 ]]; then
    printMsg "${T_ERR} Please run Retail Node Installer as root ${T_RESET}"
    logMsg "Please run Retail Node Installer as root"
    exit 1
fi

printHelp() {
    printMsg "\n ${T_BOLD}${C_BLUE}Retail Node Installer ${T_RESET}Run Script"
    printMsg " This script simply starts (or restarts) the Retail Node Installer containers."
    printMsg " If this is your first time deploying, please use ${T_BOLD}${C_YELLOW}build.sh${T_RESET} first."
    printMsg " Running this script without any arguments will safely attempt "
    printMsg " to bring up all containers without any downtime."
    printMsg ""
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-f${T_RESET}, --force         Will forceably stop & re-create the Retail Node Installer components"
    printMsg "  ${T_BOLD}-r${T_RESET}, --restart       Will only restart the Retail Node Installer containers"
    printMsg "  ${T_BOLD}-n${T_RESET}, --no-tail-logs  Do not tail the RNI containers' logs after completion (default is to tail)"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help          Show this help dialog"
    printMsg ""
    printMsg " Usage: ./run.sh"
    printMsg ""
    exit 0
}

FORCE_RECREATE="false"
FORCE_RESTART="false"
NO_TAIL_LOGS="false"
for var in "$@"; do
    case "${var}" in
        "-f" | "--force"        ) FORCE_RECREATE="true";;
        "-r" | "--restart"      ) FORCE_RESTART="true";;
        "-n" | "--no-tail-logs" ) NO_TAIL_LOGS="true";;
        "-h" | "--help"         ) printHelp;;
    esac
done

printMsg "\n-------------------------"
printMsg " Welcome to ${T_BOLD}${C_BLUE}Retail Node Installer${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome To Retail Node Installer run script"

if [[ "${FORCE_RESTART}" == "true" ]]; then
    printDatedInfoMsg "Restarting Retail Node Installer containers..."
    logMsg "run.sh restarting RNI containers"
    docker-compose restart
else
    if [[ "${FORCE_RECREATE}" == "true" ]]; then
        printDatedInfoMsg "Stopping Retail Node Installer containers..."
        logMsg "run.sh force-recreating RNI containers"
        sleep 1
        docker-compose down
    fi

    printDatedInfoMsg "Starting Retail Node Installer dnsmasq container..."
    logMsg "run.sh bringing up RNI containers"
    docker-compose up -d dnsmasq
    printDatedInfoMsg "Waiting a moment before starting the remaining RNI containers..."
    sleep 3
    docker-compose up -d
fi

if [[ "${NO_TAIL_LOGS}" == "true" ]]; then
    printBanner "${C_GREEN}Run script completed!"
else
    printBanner "${C_GREEN}Following Logs..."
    printMsg ""
    printMsg "${T_BOLD}It is safe to press CTRL+C at any time to stop following logs.${T_RESET}"
    printMsg ""

    # Give the user a moment to read the above message before tailing logs.
    printMsgNoNewline "."
    sleep 1
    printMsgNoNewline "."
    sleep 1
    printMsgNoNewline "."
    sleep 1
    printMsg ""

    docker-compose logs -f
fi
