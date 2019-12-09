#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions that are intended to trigger the downloading
# or management of potentially large numbers of files. Functions in this file
# typically run functions from fileutils.sh in looped constructs.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"
# source "fileutils.sh"
# It's probably a good idea to run this as well:
# parseProfileFilesYml "${WEB_PROFILE}/${profileName}/conf/files.yml"

downloadBaseOSFiles() {
    local profileName=$1
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Base OS Files to download"
        logMsg "No Base OS Files to download"
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local url=${files_config_base_os_files__url[j]}
            local filename=${files_config_base_os_files__filename[j]}

            downloadBaseOSFile \
                "  Downloading: ${filename}" \
                "${url}" \
                "${profileName}" \
                "${filename}"
        done
    fi
}

downloadGeneralFiles() {
    local profileName=$1
    if [ -z "${files_config_general_files__url+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No General Files to download"
        logMsg "No General Files to download"
    else
        for ((j = 0; j < "${#files_config_general_files__url[@]}"; j += 1)); do
            local url=${files_config_general_files__url[j]}
            local destination_file=${files_config_general_files__destination_file[j]}
            local token=${files_config_general_files__token[j]}

            downloadPublicFile "  Downloading file ${url} to ${destination_file}" \
                ${url} \
                "${WEB_FILES}/${profileName}" \
                ${destination_file} \
                ${token}
        done
    fi
}

downloadS3Files() {
    local profileName=$1
    if [ -z "${files_config_s3_files__object+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No S3 Files to download"
        logMsg "No S3 Files to download"
    else
        for ((j = 0; j < "${#files_config_s3_files__object[@]}"; j += 1)); do
            local aws_access_key=${files_config_s3_files__aws_access_key[j]}
            local aws_secret_key=${files_config_s3_files__aws_secret_key[j]}
            local aws_region=${files_config_s3_files__aws_region[j]}
            local bucket=${files_config_s3_files__bucket[j]}
            local object=${files_config_s3_files__object[j]}
            local destination_file=${files_config_s3_files__destination_file[j]}

            downloadS3File "  Downloading AWS S3 object ${object} to ${WEB_FILES}/${profileName}/${destination_file}" \
                "${aws_region}" \
                "${aws_access_key}" \
                "${aws_secret_key}" \
                "${bucket}" \
                "${object}" \
                "${WEB_FILES}/${profileName}" \
                "${destination_file}"
        done
    fi
}

downloadPublicDockerImages() {
    local profileName=$1
    if [ -z "${files_config_public_docker_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Public Docker Images to download"
        logMsg "No Public Docker Images to download"
    else
        for ((j = 0; j < "${#files_config_public_docker_images__image[@]}"; j += 1)); do
            local image=${files_config_public_docker_images__image[j]}
            local tag=${files_config_public_docker_images__tag[j]}
            local destination_file=${files_config_public_docker_images__destination_file[j]}

            downloadPublicDockerImage \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}"
        done
    fi
}

downloadPrivateDockerAWSImages() {
    local profileName=$1
    if [ -z "${files_config_private_docker_aws_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Private Docker AWS Images to download"
        logMsg "No Private Docker AWS Images to download"
    else
        for ((j = 0; j < "${#files_config_private_docker_aws_images__image[@]}"; j += 1)); do
            local image=${files_config_private_docker_aws_images__image[j]}
            local docker_registry=${files_config_private_docker_aws_images__docker_registry[j]}
            local aws_access_key=${files_config_private_docker_aws_images__aws_access_key[j]}
            local aws_secret_key=${files_config_private_docker_aws_images__aws_secret_key[j]}
            local aws_region=${files_config_private_docker_aws_images__aws_region[j]}
            local aws_registry=${files_config_private_docker_aws_images__aws_registry[j]}
            local tag=${files_config_private_docker_aws_images__tag[j]}
            local destination_file=${files_config_private_docker_aws_images__destination_file[j]}

            # Log in to the AWS ECR
            $(
                docker run --rm \
                    --env AWS_ACCESS_KEY_ID=${aws_access_key} \
                    --env AWS_SECRET_ACCESS_KEY=${aws_secret_key} \
                    --env AWS_DEFAULT_REGION=${aws_region} \
                    builder-aws-cli \
                    sh -c "${AWS_CLI_PROXY} aws ecr get-login --registry-id ${aws_registry}" | sed "s/\-e\ none//g"
            )

            # Not all parameters are required to be passed in to
            # this function since we are already logged in
            downloadPrivateDockerImage \
                "${docker_registry}" \
                "None" \
                "None" \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}" \
                "Y"
        done
    fi
}

downloadPrivateDockerRegistryImages() {
    local profileName=$1
    if [ -z "${files_config_private_docker_registry_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Private Docker Images to download"
        logMsg "No Private Docker Images to download"
    else
        for ((j = 0; j < "${#files_config_private_docker_registry_images__image[@]}"; j += 1)); do
            local image=${files_config_private_docker_registry_images__image[j]}
            local tag=${files_config_private_docker_registry_images__tag[j]}
            local destination_file=${files_config_private_docker_registry_images__destination_file[j]}
            local docker_registry=${files_config_private_docker_registry_images__docker_registry[j]}
            local docker_username=${files_config_private_docker_registry_images__docker_username[j]}
            local docker_password=${files_config_private_docker_registry_images__docker_password[j]}

            downloadPrivateDockerImage \
                "${docker_registry}" \
                "${docker_username}" \
                "${docker_password}" \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}" \
                ''
        done
    fi
}
