#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic to build the Utility OS.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "fleutils.sh"

set -u

cd dockerfiles/uos
printDatedMsg "This can take a few minutes..."
run "(1/10) Downloading and preparing the kernel" \
    "docker build --rm ${DOCKER_BUILD_ARGS} -t alpine/kernel:v3.9 --build-arg ALPINELINUX_RELEASE=v3.9 -f ./Dockerfile.alpine ." \
    ../../${LOG_FILE}
run "(2/10) Downloading and preparing the initrd" \
    "docker build --rm ${DOCKER_BUILD_ARGS} -t builder/dyninit:v1.0 -f ./Dockerfile.dyninit ." \
    ../../${LOG_FILE}
run "(3/10) Compiling tools" \
    "docker build --rm ${DOCKER_BUILD_ARGS} -t uosbuilder -f ./Dockerfile ." \
    ../../${LOG_FILE}
run "(4/10) Building UOS" \
    "docker run -t --rm ${DOCKER_RUN_ARGS} -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/uos uosbuilder -c \"cd /linuxkit && make && cd /uos && /linuxkit/bin/linuxkit build -format kernel+initrd uos.yml\"" \
    ../../${LOG_FILE}
run "(5/10) Prepping initrd" \
    "./prepInitrd.sh 2>&1" \
    ../../${LOG_FILE}
run "(6/10) Creating public directory to serve UOS images" \
    "mkdir -p ${TFTP_IMAGES}/uos" \
    ../../${LOG_FILE}
run "(7/10) Moving UOS initrd to public UOS directory" \
    "mv uos-initrd.img ${TFTP_IMAGES}/uos/initrd" \
    ../../${LOG_FILE}
run "(8/10) Moving UOS kernel to public UOS directory" \
    "mv uos-kernel ${TFTP_IMAGES}/uos/vmlinuz" \
    ../../${LOG_FILE}

if [[ "${UOS_CLEAN}" == true ]]; then
    run "(9/10) Cleaning up linuxkit images" \
        "docker rmi $(docker images | grep linuxkit | awk '{ print $3 }') " \
        ../../${LOG_FILE}

    run "(10/10) Cleaning up builder image" \
        "docker rmi uosbuilder:latest builder/dyninit:v1.0" \
        ../../${LOG_FILE}
else
    printMsg "Skipping (9/10) Cleaning up linuxkit images"
    logMsg "Skipping (9/10) Cleaning up linuxkit images"
    printMsg "Skipping (10/10) Cleaning up builder images"
    logMsg "Skipping (10/10) Cleaning up builder images"
fi

cd - >/dev/null
