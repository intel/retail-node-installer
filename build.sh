#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u
source "scripts/textutils.sh"

if [[ $(id -u) -ne 0 ]]; then
    printMsg "${T_ERR} Please run this script as root ${T_RESET}"
    logMsg "Please run this script as root"
    exit 1
fi

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Retail Node Installer ${T_RESET}Build Script"
    printMsg " You can specify one the following options:"
    # printMsg "  ${T_BOLD}-b${T_RESET}, --build-uos    will build the Utility Operating System (UOS)"
    # printMsg "  ${T_BOLD}-c${T_RESET}, --clean-uos    will clean the intermediary docker images used during building of UOS"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help         Show this help dialog"
    printMsg ""
    printMsg " Usage: ./build.sh"
    printMsg ""
    exit 0
}

UOS_CLEAN="false"
BUILD_UOS="false"
SKIP_FILES="false"
for var in "$@"; do
    case "${var}" in
        "-b" | "--build-uos"  ) BUILD_UOS="true";;
        "-c" | "--clean-uos"  ) UOS_CLEAN="true";;
        "-F" | "--skip-files" ) SKIP_FILES="true";;
        "-h" | "--help"      ) printHelp;;
    esac
done

source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"

printMsg "\n-------------------------"
printMsg " Welcome to ${T_BOLD}${C_BLUE}Retail Node Installer${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome To Retail Node Installer"


# Parse the Retail Node Installer config before doing anything else
printBanner "Checking ${C_GREEN}Retail Node Installer Config..."
logMsg "Checking Retail Node Installer Config..."
parseRNIConfig

source "scripts/templateutils.sh"
printBanner "Checking ${C_GREEN}Network Config..."
logMsg "Checking Network Config..."
# This function will ensure that the config options for
# network options that users can specify in conf/config.yml
# are set to _something_ non-empty.
verifyRNINetworkConfig

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
# reduces the footprint of Retail Node Installer.

# Build the aws-cli image
run "Building rni-aws-cli" \
    "docker build -q -t rni-aws-cli dockerfiles/aws-cli" \
    ${LOG_FILE}

# Build the wget image
run "Building rni-wget" \
    "docker build -q -t rni-wget dockerfiles/wget" \
    ${LOG_FILE}

# Build the git image
run "Building rni-git" \
    "docker build -q -t rni-git dockerfiles/git" \
    ${LOG_FILE}

# Build the dnsmasq image
run "Building rni-dnsmasq" \
    "docker build -q -t rni-dnsmasq dockerfiles/dnsmasq" \
    ${LOG_FILE}

# Pull the required images for running RNI
# Ignore pull failures because "docker-compose pull" does not gracefully
# handle images that are built and tagged locally. This step is more of a
# nice-to-have, since running "run.sh" will attempt to pull the images anyways.
run "Pulling Retail Node Installer images" \
    "docker-compose pull --ignore-pull-failures --parallel" \
    ${LOG_FILE}

# Synchronize profiles. This step encapsulates a lot of profile-specific
# actions, such as cloning a profile repository, downloading the
# files for a profile, rendering rnitemplates for a profile, etc.
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
printBanner "${C_GREEN}Retail Node Installer Build Complete!"
printMsg ""
printMsg "Note:"
printMsg "    Some systems may need to have local DNS listener services disabled."
printMsg "    Please disable them before running the next step, or Retail Node"
printMsg "    Installer will fail to start dnsmasq."
printMsg ""
printMsg "${T_BOLD}Next, please use this command as root to start the Retail Node Installer:${T_RESET}"
printMsg ""
printMsg "${T_BOLD}${C_GREEN}./run.sh${T_RESET}"
printMsg ""
