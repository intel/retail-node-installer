#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic for managing profiles.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "fileutils.sh"
# source "bulkfileutils.sh"
# source "yamlparse.sh"

parseProfileFilesYml() {
    local configFile=$1
    eval $(yamlParse "${configFile}" "files_config_")
}

# Determine if the the files.yml config (for a profile) exists
canLoadProfileFiles() {
    local configFile=$1
    local profileName=$2
    if [[ -f ${configFile} ]]; then
        logOkMsg "Profile ${profileName} has a conf/files.yml"
        echo "0"
    else
        printMsg "${T_INFO_ICON} Did not find ${configFile} for profile ${profileName}"
        logMsg "${T_INFO_ICON} Did not find ${configFile} for profile ${profileName}"
        # we couldn't find the file so return error
        echo "1"
    fi
}

cloneProfile() {
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${name}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target="${git_remote_url}"

    if [[ "${git_token}" != "" && "${git_username}" != "" ]]; then
	    if [[ "${git_remote_url}" == "https://"* ]]; then
            printDatedInfoMsg "Git commands using HTTPS Protocol"
            git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")
        elif [[ "${git_remote_url}" == "http://"* ]]; then
            printDatedInfoMsg "Git commands using HTTP Protocol"
            git_clone_target=$(echo ${git_remote_url} | sed "s#http://#http://${git_username}:${git_token}@#g")
        fi
    fi

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        local git_current_remote_url=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles -w /tmp/profiles builder-git git remote get-url --all origin)
        local git_current_branch_name=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles -w /tmp/profiles builder-git git rev-parse --abbrev-ref HEAD)
        if [ "${git_clone_target}" != "${git_current_remote_url}" ] || [ "${git_branch_name}" != "${git_current_branch_name}" ]; then
            logMsg "Detected a configuration change in either the git remote or the git branch for the ${name} profile. Will re-create the repository from scratch in order to avoid git tree issues."
            rm -rf  ${WEB_PROFILE}/${name}
        fi
    fi

    if [ ! -d ${WEB_PROFILE}/${name}/.git ]; then
        if [ -n "${SSH_AUTH_SOCK-}" ]; then
            local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
            printAndLogDatedInfoMsg "Git authentication found SSH-Agent."
        fi

        if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
            if [[ ${git_remote_url} == "git@"* ]]; then
                printAndLogDatedErrMsg "Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                exit 1
            fi
            printAndLogDatedInfoMsg "Git authentication found Git user/token."
        fi

        if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
            printAndLogDatedInfoMsg "No Git authentication method found (git_username/git_token, or SSH-Agent)."
        fi

        run "  ${C_GREEN}${name}${T_RESET}: Cloning branch ${git_branch_name} on repo ${git_remote_url} with ssh-agent" \
            "docker run --rm ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}:/tmp/profiles -w /tmp/profiles builder-git git clone ${custom_git_arguments} -v --progress ${git_clone_target} --branch=${git_branch_name} ${name}" \
            ${LOG_FILE}
    else
        printDatedMsg "  ${C_GREEN}${name}${T_RESET} already exists."
        logOkMsg "${name} already exists."
    fi

    if [[ ${git_base_branch_name} == 'None' ]]; then
        printDatedMsg "  ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            local git_current_remote_url=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git remote get-url --all origin)
            local git_current_branch_name=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git rev-parse --abbrev-ref HEAD)
            if [ "${git_clone_target}" != "${git_current_remote_url}" ] || [ "${git_base_branch_name}" != "${git_current_branch_name}" ]; then
                logMsg "Detected a configuration change in either the git remote or the git branch for the ${base_name} profile. Will re-create the repository from scratch in order to avoid git tree issues."
                rm -rf  ${WEB_PROFILE}/${base_name}
            fi
        fi

        if [ ! -d ${WEB_PROFILE}/${base_name}/.git ]; then
            if [ -n "${SSH_AUTH_SOCK-}" ]; then
                local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
                printAndLogDatedInfoMsg "Git authentication found SSH-Agent."
            fi

            if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
                if [[ ${git_remote_url} == "git@"* ]]; then
                    printAndLogDatedErrMsg "Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                    exit 1
                fi
                printAndLogDatedInfoMsg "Git authentication found Git user/token."
            fi

            if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
                printAndLogDatedInfoMsg "No Git authentication method found (git_username/git_token, or SSH-Agent)."
            fi
            run "  ${C_GREEN}${base_name}${T_RESET}: Cloning branch ${git_base_branch_name} on repo ${git_remote_url}" \
                "docker run --rm ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}:/tmp/profiles -w /tmp/profiles builder-git git clone ${custom_git_arguments} -v --progress ${git_clone_target} --branch=${git_base_branch_name} ${base_name}" \
                ${LOG_FILE}
        else
            printDatedMsg "  ${C_GREEN}${base_name}${T_RESET} already exists."
            logOkMsg "${base_name} already exists."
        fi
    fi
}

resetProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        run "  ${C_GREEN}${name}${T_RESET}: Resetting branch ${git_branch_name}" \
            "docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles/${name} -w /tmp/profiles/${name} builder-git git reset --hard HEAD" \
            ${LOG_FILE}
    else
        printDatedMsg "Profile ${C_GREEN}${name}${T_RESET} either is improperly configured or does not exist."
        printDatedMsg "Unable to reset it."
        printDatedMsg "Please check ${WEB_PROFILE}/${name}."
    fi

    if [[ ${git_base_branch_name} == 'None' ]]; then
        printDatedMsg "  ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            run "  ${C_GREEN}${base_name}${T_RESET}: Resetting branch ${git_base_branch_name}" \
                "docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles/${base_name} -w /tmp/profiles/${base_name} builder-git git reset --hard HEAD" \
                ${LOG_FILE}
        else
            printDatedMsg "Profile ${C_GREEN}${base_name}${T_RESET} either is improperly configured or does not exist."
            printDatedMsg "Unable to reset it."
            printDatedMsg "Please check ${WEB_PROFILE}/${base_name}."
        fi
    fi
}

pullProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        if [ -n "${SSH_AUTH_SOCK-}" ]; then
            local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
            printAndLogDatedInfoMsg "Git authentication found SSH-Agent."
        fi

        if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
            if [[ ${git_remote_url} == "git@"* ]]; then
                printAndLogDatedErrMsg "Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                exit 1
            fi
            printAndLogDatedInfoMsg "Git authentication found Git user/token."
        fi

        if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
            printAndLogDatedInfoMsg "No Git authentication method found (git_username/git_token, or SSH-Agent)."
        fi
        run "  ${C_GREEN}${name}${T_RESET}: Pulling latest from ${git_branch_name} on repo ${git_remote_url}" \
            "docker run --rm ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${name}:/tmp/profiles/${name} -w /tmp/profiles/${name} builder-git git pull origin ${git_branch_name}" \
            ${LOG_FILE}
    else
        printDatedErrMsg "Profile ${name} either is improperly configured or does not exist."
        printDatedErrMsg "Unable to pull latest changes from upstream."
        printDatedErrMsg "Please check ${WEB_PROFILE}/${name}."
        logErrMsg "Profile ${name} either is improperly configured or does not exist."
        logErrMsg "Unable to pull latest changes from upstream."
        logErrMsg "Please check ${WEB_PROFILE}/${name}."
        exit 1
    fi

    if [[ ${git_base_branch_name} == 'None' ]]; then
        printDatedMsg "  ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            if [ -n "${SSH_AUTH_SOCK-}" ]; then
                local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
                printAndLogDatedInfoMsg "Git authentication found SSH-Agent."
            fi

            if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
                if [[ ${git_remote_url} == "git@"* ]]; then
                    printAndLogDatedErrMsg "Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                    exit 1
                fi
                printAndLogDatedInfoMsg "Git authentication found Git user/token."
            fi

            if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
                printAndLogDatedInfoMsg "No Git authentication method found (git_username/git_token, or SSH-Agent)."
            fi
            run "  ${C_GREEN}${base_name}${T_RESET}: Pulling latest from ${git_base_branch_name} on repo ${git_remote_url}" \
                "docker run --rm ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles/${base_name} -w /tmp/profiles/${base_name} builder-git git pull origin ${git_base_branch_name}" \
                ${LOG_FILE}
        else
            printDatedErrMsg "Profile ${base_name} either is improperly configured or does not exist."
            printDatedErrMsg "Unable to pull latest changes from upstream."
            printDatedErrMsg "Please check ${WEB_PROFILE}/${base_name}."
            logErrMsg "Profile ${base_name} either is improperly configured or does not exist."
            logErrMsg "Unable to pull latest changes from upstream."
            logErrMsg "Please check ${WEB_PROFILE}/${base_name}."
            exit 1
        fi
    fi
}

deleteProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ ! -d ${WEB_PROFILE}/${name}/.git ]; then
        printDatedOkMsg "Profile ${name} already does not exist."
        logOkMsg "Profile ${name} already does not exist."
    else
        run "Deleting profile ${name}" \
            "rm -rf ${WEB_PROFILE}/${name}" \
            ${LOG_FILE}
    fi

    if [[ ${git_base_branch_name} == 'None' ]]; then
        printDatedMsg "  ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ ! -d ${WEB_PROFILE}/${base_name}/.git ]; then
            printDatedOkMsg "Profile ${base_name} already does not exist."
            logOkMsg "Profile ${base_name} already does not exist."
        else
            run "Deleting profile ${base_name}" \
                "rm -rf ${WEB_PROFILE}/${base_name}" \
                ${LOG_FILE}
        fi
    fi
}

downloadProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    printBanner "Downloading files for profile: ${C_GREEN}${name}${T_RESET}"

    # Check if we can load the profile's files.yml first.
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"

        # Create the profile's files directory if it doesn't exist
        makeDirectory "${WEB_FILES}/${name}"
        logInfoMsg "Files (except base OS files) for this profile will be stored under ${WEB_FILES}/${name}, and will be accessible via HTTP at http://${builder_config_host_ip}/files/${name}/destination_file"
        logInfoMsg "Base OS files for this profile will be stored under ${TFTP_IMAGES}/${name}, and will be accessible via HTTP at http://${builder_config_host_ip}/tftp/${name}/filename"

        if [[ "${SKIP_FILES}" == "true" ]]; then
            printDatedInfoMsg "User decided to skip downloading files."
            logInfoMsg "User decided to skip downloading files."
        else
            # Download all files specified in ./conf/files.yml
            printDatedMsg "(1/6) Downloading ${name} ${C_MAGENTA}Base OS Files..."
            downloadBaseOSFiles ${name}
            printDatedMsg "(2/6) Downloading ${name} ${C_MAGENTA}General Files..."
            downloadGeneralFiles ${name}
            printDatedMsg "(3/6) Downloading ${name} ${C_MAGENTA}S3 Files..."
            downloadS3Files ${name}
            printDatedMsg "(4/6) Downloading ${name} ${C_MAGENTA}Public Docker Registry Files..."
            downloadPublicDockerImages ${name}
            printDatedMsg "(5/6) Downloading ${name} ${C_MAGENTA}Private Docker Registry Files..."
            downloadPrivateDockerRegistryImages ${name}
            printDatedMsg "(6/6) Downloading ${name} ${C_MAGENTA}Docker AWS Files..."
            downloadPrivateDockerAWSImages ${name}
        fi
    else
        printDatedInfoMsg "This profile contains no files to download."
        logInfoMsg "This profile contains no files to download."
    fi

    logInfoMsg "Finished downloading files for ${name} profile."
}

buildProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    printBanner "Running the build.sh from the profile: ${C_GREEN}${name}${T_RESET}"
    if [ -f "${WEB_PROFILE}/${name}/build.sh" ]; then
        logInfoMsg "Build file found for profile: ${C_GREEN}${name}${T_RESET}"
        logInfoMsg "Executing..."
        ${WEB_PROFILE}/${name}/build.sh
    else
	logInfoMsg "This profile contains no build.sh to execute."
    fi

    logInfoMsg "Finished running the build.sh from the ${name} profile."
}

resetGlobalProfileConfigVariables() {
    # Reset these variables.
    # If any variables are added to config.yml in profiles, add them here
    # if it's needed - it's only needed if the variable can be undefined
    # and we fill in a default value.
    #
    # Why? When iterating over multiple profiles and attempting to generate
    # multiple entries in the PXE menu, the yaml parsing script will read in
    # each of the below variables with a name like "profile_config_kernel_filename".
    # Due to limitations with the Bash scripting language, we can't dynamically
    # name and refer to arrays created by the yaml parsing script. In a perfect
    # world, the set of variables that get created from this yaml file would be
    # something like this:
    #   profile_rancher_config__kernel_filename
    #   profile_rancher_config__kernel_arguments
    # Then, we would refer to these variables later like this:
    #   ${profile_${name}_config__kernel_filename}
    #   ${profile_${name}_config__kernel_arguments}
    # When using for loops, this becomes impossible, for example:
    #   ${#profile_${name}_config_some_array{@}}
    # These examples just don't work in bash.
    #
    # So as a result, we have to reuse variable names when parsing configs for
    # multiple profiles. If a user wants to leave a variable undefined, and the
    # code supports that, we have to reset the variables each time.
    profile_config_kernel_arguments=
}

loadProfileConfig() {
    local name=${1}
    # If the profile has a conf/config.yml file,
    # then attempt tp parse the conf/config.yml file into bash variables.
    if [[ -f "${WEB_PROFILE}/${name}/conf/config.yml" ]]; then
        # If testing this script, uncomment this next line
        # source "scripts/yamlparse.sh"
        eval $(yamlParse "${WEB_PROFILE}/${name}/conf/config.yml" "profile_config_")
    else
        logInfoMsg "Profile ${name} did not have a conf/config.yml file. Will attempt to continue with generating the PXE menu using defaults."
    fi
}

getKernelFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "kernel" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

getInitrdFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "initrd" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

areKernelAndInitrdInProfileFilesYml() {
    local foundKernel="false"
    local foundInitrd="false"

    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "kernel" ]]; then
                foundKernel="true"
            elif [[ "${type}" == "initrd" ]]; then
                foundInitrd="true"
            fi

        done
        if [[ "${foundKernel}" == "true" && "${foundInitrd}" == "true" ]]; then
            echo "true"

            # Exit the function so that the final "echo false" statement
            # is not executed.
            return 0
        fi
    fi

    echo "false"
    return 0
}

getIsoFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "iso" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

isIsoInProfileFilesYml() {
    local foundIso="false"

    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "iso" ]]; then
                echo "true"
                return 0
            fi

        done
    fi

    echo "false"
    return 0
}

genProfilePxeMenu() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7



    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local autogen_str='# Auto-generated'

    resetGlobalProfileConfigVariables
    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi

    # Begin the header for this menu item
    addLineToPxeMenu ''
    addLineToPxeMenu "\"${autogen_str}\""

    # Determine the keyboard shortcut that corresponds for this menu item
    # based on the number of times the string appears in the file
    # i.e. 1, 2, 3
    local tmpPxeMenuFile=$(getTmpPxeMenuLocation)
    local autogenCount=$(cat ${tmpPxeMenuFile} | grep "${autogen_str}" | wc -l)

    # Continue to add lines to the menu, incorporating the above variable
    addLineToPxeMenu "\"LABEL ${autogenCount}\""

    # The keyboard shortcut is autogenCount + 0, so calculate it
    # It used to be n + 1, but we moved the local boot option to the bottom,
    # and so an offset is no longer necessary
    local autogenCountInc=$(( ${autogenCount} + 0 ))
    addLineToPxeMenu "\"    MENU LABEL ^${autogenCountInc}) ${name}\""

    local kernelArgs=""
    local proxyArgs=""
    local ttyArg="console=tty0"
    local httpserverArg="httpserver=@@HOST_IP@@"
    local bootstrapArg="bootstrap=http://@@HOST_IP@@/profile/${name}/bootstrap.sh"
    local uosInitrdKernelArg="initrd=http://@@HOST_IP@@/tftp/images/uos/initrd"
    local httpFilesPathArg="httppath=/files/${name}"

    if [[ ${git_base_branch_name} == 'None' ]]; then
        local baseBranchArg="basebranch=None"
    else
        local baseBranchArg="basebranch=http://@@HOST_IP@@/profile/${base_name}"
    fi

    kernelArgs="${ttyArg} ${httpserverArg} ${bootstrapArg} ${baseBranchArg} ${httpFilesPathArg} ${kernelArgs}"

    # If proxy args exist, add kernel parameters to pass along the proxy settings
    if [ ! -z "${HTTPS_PROXY+x}" ] || [ ! -z "${HTTP_PROXY+x}" ]; then
        if [ ! -z "${HTTPS_PROXY+x}" ]; then
            proxyArgs="proxy=${HTTPS_PROXY}"
        else
            proxyArgs="proxy=${HTTP_PROXY}"
        fi
    fi
    if [ ! -z "${FTP_PROXY+x}" ]; then
        proxyArgs="${proxyArgs} proxysocks=${FTP_PROXY}"
    fi
    if [ ! -z "${proxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${proxyArgs}"
    fi

    # If kernel & initrd are both specified in the profile's files.yml,
    # then use them. Otherwise, use UOS. In both cases, use the kernel args
    # that are passed by the user.
    profileContainsKernelAndInitrd=$(areKernelAndInitrdInProfileFilesYml)
    profileContainsIso=$(isIsoInProfileFilesYml)
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)
    isoFilename=$(getIsoFromProfileFilesYml)

    if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
        local kernelPath="http://@@HOST_IP@@/tftp/images/${name}/${kernelFilename}"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="initrd=http://@@HOST_IP@@/tftp/images/${name}/${initrdFilename} ${kernelArgs}"
    elif [[ "${profileContainsIso}" == "true" ]]; then
  	    addLineToPxeMenu "\"    LINUX http://@@HOST_IP@@/profile/${name}/memdisk vmalloc=16G \""
        addLineToPxeMenu "\"    INITRD http://@@HOST_IP@@/tftp/images/${name}/${isoFilename} \""
        addLineToPxeMenu "\"    APPEND iso raw \""
    else
        # Use utility os (UOS).
        local kernelPath="http://@@HOST_IP@@/tftp/images/uos/vmlinuz"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="${uosInitrdKernelArg} ${kernelArgs}"
    fi

    if [[ -n "${profile_config_kernel_arguments}" ]]; then
        kernelArgs="${kernelArgs} ${profile_config_kernel_arguments}"
    fi

    # Perform the @@PROFILE_NAME@@ template rendering for this profile's
    # kernel args here.
    profileNamePlaceholder="@@PROFILE_NAME@@"
    kernelArgs=$(echo "${kernelArgs}" | sed "s/${profileNamePlaceholder}/${name}/g")

    if [[ "${profileContainsIso}" == "false" ]]; then
	    addLineToPxeMenu "\"    APPEND ${kernelArgs}\""
    fi

    addLineToPxeMenu ''

    printDatedOkMsg "Added ${name} profile to PXE boot menu successfully."
    logMsg "Added ${name} profile to PXE boot menu successfully."
}

renderProfileTemplates() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    # Set globstar option in bash.
    # This enables us to use ** to recursively list
    # all files under a directory, space-separated
    # so that we can iterate over them in a loop.
    shopt -s globstar

    # Iterate over all files and check if they are buildertemplates.
    # If any are found, render them.
    for file in ${WEB_PROFILE}/${name}/**; do
        if [[ "${file}" == *".buildertemplate" || \
                "${file}" == *".ebtemplate" || \
                "${file}" == *".rnitemplate" ]]; then
            logInfoMsg "Found ${file}, will proceed to render it"
            renderTemplate ${file} ${name}
        fi
    done

    # Unset the variable so it doesn't interfere with anything else.
    shopt -u globstar
}


# Usage: Pass in an arbitrary function as an argument to profilesActions
# This makes it easier to do tasks against every profile.
profilesActions() {
    local passedFunction=$1

    if [ -z "${builder_config_profiles__name+x}" ]; then
        printDatedInfoMsg "No Profiles to download"
        logFataErrMsg "No Profiles to download"
        exit 1
    else
        for ((j = 0; j < "${#builder_config_profiles__name[@]}"; j += 1)); do

            # if [ -z "${builder_config_profiles__git_base_branch_name+x}" ]; then
            #     logInfoMsg "Profile did not have a base profile"
            #     local git_base_branch_name=""
            # else
            #     local git_base_branch_name=${builder_config_profiles__git_base_branch_name[j]}
            # fi

            local git_remote_url=${builder_config_profiles__git_remote_url[j]}
            local git_branch_name=${builder_config_profiles__profile_branch[j]}
            local git_base_branch_name=${builder_config_profiles__profile_base_branch[j]}
            local git_username=${builder_config_profiles__git_username[j]:-"None"}
            local git_token=${builder_config_profiles__git_token[j]:-"None"}
            local name=${builder_config_profiles__name[j]}
            local custom_git_arguments=${builder_config_profiles__custom_git_arguments[j]}

            (
                ${passedFunction} \
                    ${git_remote_url} \
                    ${git_branch_name} \
                    ${git_base_branch_name} \
                    ${git_username} \
                    ${git_token} \
                    ${name} \
                    ${custom_git_arguments}

            )

            if [[ $? -ne 0 ]]; then
                # Note that no log output is needed here,
                # because the function that gets passed to this
                # function should contain a sequence to log and "exit 1"
                # if a failure occurs.
                # Since ${passedFunction} is being run inside its own shell,
                # running "exit 1" in that shell does not quit this script.
                # So it has to be quit here.
                exit 1
            fi
        done
    fi
}

syncProfiles() {
    printDatedMsg "${T_BOLD}Clone${T_RESET} profiles"
    profilesActions cloneProfile
    printDatedMsg "${T_BOLD}Reset${T_RESET} profiles"
    profilesActions resetProfile
    printDatedMsg "${T_BOLD}Pull${T_RESET} latest from profiles"
    profilesActions pullProfile

    profilesActions renderProfileTemplates

    if [[ "${SKIP_PROFILE_BUILDS}" == "false" ]]; then
        profilesActions buildProfile
    else
        logMsg "User decided to skip the execution of profile-specific build scripts."
    fi

    # Now we need to download files associated with the profile
    profilesActions downloadProfile
}
