#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

source "scripts/textutils.sh"

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Build Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-B${T_RESET}, --skip-builds     Skips the execution of profile-specific build.sh scripts"
    printMsg "  ${T_BOLD}-b${T_RESET}, --skip-backups    Skips the creation of backup files inside the data directory when re-running build.sh"
    printMsg "  ${T_BOLD}-s${T_RESET}, --skip-build-uos  will skip building the Utility Operating System (UOS)"
    printMsg "  ${T_BOLD}-c${T_RESET}, --clean-uos       will clean the intermediary docker images used during building of UOS"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help            Show this help dialog"
    printMsg ""
    printMsg " Usage: ./build.sh"
    printMsg ""
    exit 0
}

UOS_CLEAN="false"
BUILD_UOS="true"
SKIP_FILES="false"
SKIP_BACKUPS="false"
SKIP_PROFILE_BUILDS="false"
for var in "$@"; do
    case "${var}" in
        "-c" | "--clean-uos"       )    UOS_CLEAN="true";;
        "-s" | "--skip-build-uos"  )    BUILD_UOS="false";;
        "-F" | "--skip-files"      )    SKIP_FILES="true";;
        "-b" | "--skip-backups"    )    SKIP_BACKUPS="true";;
        "-B" | "--skip-builds"     )    SKIP_PROFILE_BUILDS="true";;
        "-h" | "--help"            )    printHelp;;
    esac
done

source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to the builder host build script"


# Parse the config before doing anything else
printBanner "Checking ${C_GREEN} Config..."
logMsg "Checking Config..."
parseConfig

source "scripts/templateutils.sh"
printBanner "Checking ${C_GREEN}Network Config..."
logMsg "Checking Network Config..."
# This function will ensure that the config options for
# network options that users can specify in conf/config.yml
# are set to _something_ non-empty.
verifyNetworkConfig

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='localhost,127.0.0.1'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='localhost,127.0.0.1';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

# Build Utility OS, if desired
if [[ "${BUILD_UOS}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Utility OS (UOS)..."
    logMsg "Building Utility OS (UOS)..."
    source "scripts/buildUOS.sh"
else
    logMsg "Skipping Build of UOS"
fi

printBanner "Building ${C_GREEN}Images..."

# Begin to build a few Docker images. A few of these images are utility
# images such as wget, git, and aws-cli. Using Docker for these utilities
# reduces the footprint of our application.

# Build the aws-cli image
run "Building builder-aws-cli" \
    "docker build -q -t builder-aws-cli dockerfiles/aws-cli" \
    ${LOG_FILE}

# Build the wget image
run "Building builder-wget" \
    "docker build -q -t builder-wget dockerfiles/wget" \
    ${LOG_FILE}

# Build the git image
run "Building builder-git" \
    "docker build -q -t builder-git dockerfiles/git" \
    ${LOG_FILE}

# Build the dnsmasq image
run "Building builder-dnsmasq" \
    "docker build -q -t builder-dnsmasq dockerfiles/dnsmasq" \
    ${LOG_FILE}

# Synchronize profiles. This step encapsulates a lot of profile-specific
# actions, such as cloning a profile repository, downloading the
# files for a profile, rendering templates for a profile, etc.
printBanner "Synchronizing ${C_GREEN}Profiles..."
source "scripts/profileutils.sh"
source "scripts/pxemenuutils.sh"
syncProfiles

# This next step will propagate the network configuration that was determined
# at the beginning of this script to dnsmasq.conf and the PXE menu
printBanner "Rendering ${C_GREEN}System Templates..."
renderSystemNetworkTemplates
updatePxeMenu

# Finishing message
printBanner "${C_GREEN}Build Complete!"
printMsg ""
printMsg "Note:"
printMsg "    Some systems may need to have local DNS listener services disabled."
printMsg "    Please disable them before running the next step, or"
printMsg "    the system will fail to start dnsmasq."
printMsg ""
printMsg "${T_BOLD}Next, please use this command as root to start the services:${T_RESET}"
printMsg ""
printMsg "${T_BOLD}${C_GREEN}./run.sh${T_RESET}"
printMsg ""
