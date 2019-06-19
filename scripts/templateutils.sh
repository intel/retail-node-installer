#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions and logic to handle templating in Retail Node Installer..
# See documentation on rnitemplates and the supported @@VARIABLES@@.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"
# source "fileutils.sh"
# It's probably a good idea to run this as well:
# parseRNIConfig

getMyIp() {
    echo $(ip route get 9.9.9.9 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
}

getMySubnet() {
    echo $(echo $(getMyIp) | awk -F'.' '{print $1,$2,$3}' OFS='.' )
}

# Checks for empty network-related configuration items in
# the conf/config.yml file and sets defaults if any
# are not set.
verifyRNINetworkConfig() {
    local ipAddr=$(getMyIp)
    local subnet=$(getMySubnet)

    # Ensure the DHCP range min is set
    if [[ -z "${rni_config_dhcp_range_minimum+x}" ]]; then
        rni_config_dhcp_range_minimum="${subnet}.100"
        printDatedInfoMsg "Auto-determined dhcp_range_minimum=${rni_config_dhcp_range_minimum}"
        logInfoMsg "Using default dhcp_range_minimum=${rni_config_dhcp_range_minimum} - Set dhcp_range_minimum in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the DHCP range max is set
    if [[ -z "${rni_config_dhcp_range_maximum+x}" ]]; then
        rni_config_dhcp_range_maximum="${subnet}.250"
        printDatedInfoMsg "Auto-determined dhcp_range_maximum=${rni_config_dhcp_range_maximum}"
        logInfoMsg "Using default dhcp_range_maximum=${rni_config_dhcp_range_maximum} - Set dhcp_range_maximum in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's broadcast is set
    if [[ -z "${rni_config_network_broadcast_ip+x}" ]]; then
        rni_config_network_broadcast_ip="${subnet}.255"
        printDatedInfoMsg "Auto-determined network_broadcast_ip=${rni_config_network_broadcast_ip}"
        logInfoMsg "Using default network_broadcast_ip=${rni_config_network_broadcast_ip} - Set network_broadcast_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's gateway IP is set
    if [[ -z "${rni_config_network_gateway_ip+x}" ]]; then
        rni_config_network_gateway_ip="${subnet}.1"
        printDatedInfoMsg "Auto-determined network_gateway_ip=${rni_config_network_gateway_ip}"
        logInfoMsg "Using default network_gateway_ip=${rni_config_network_gateway_ip} - Set network_gateway_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the Retail Node Installer host IP address is set
    if [[ -z "${rni_config_rni_ip+x}" ]]; then
        rni_config_rni_ip="${ipAddr}"
        printDatedInfoMsg "Auto-determined rni_ip=${rni_config_rni_ip}"
        logInfoMsg "Using default rni_ip=${rni_config_rni_ip} - Set rni_ip in conf/config.yml and re-run this script if this value is not desired."
    else
        if [[ "${ipAddr}" != "${rni_config_rni_ip}" ]]; then
            printDatedInfoMsg "${C_L_YELLOW}Warning:${T_RESET} Using a user-specified value for rni_ip=${C_L_YELLOW}${rni_config_rni_ip}${T_RESET} which is different from this device's default outbound route IP of ${C_L_YELLOW}${ipAddr}${T_RESET}"
            logInfoMsg "Warning: Using a user-specified value for rni_ip=${rni_config_rni_ip} which is different from this device's default outbound route IP of ${ipAddr}"
        fi
    fi

    # Ensure the Retail Node Installer dnsmasq secondary DNS is set
    if [[ -z "${rni_config_network_dns_secondary+x}" ]]; then
        rni_config_network_dns_secondary="8.8.8.8"
        printDatedInfoMsg "Auto-determined network_dns_secondary=${rni_config_network_dns_secondary}"
        logInfoMsg "Using default network_dns_secondary=${rni_config_network_dns_secondary} - Set network_dns_secondary in conf/config.yml and re-run this script if this value is not desired."
    fi

    printDatedOkMsg "Network configuration determined."
    logOkMsg "Network configuration determined."
}

renderSystemNetworkTemplates() {
    # Get the IP and subnet of the current system
    local ipAddr=$(getMyIp)
    local subnet=$(getMySubnet)

    # make directories if they don't exist
    local dnsMasqConfDir="data/etc"
    local pxeMenuFileDir="data/srv/tftp/pxelinux.cfg"
    makeDirectory ${dnsMasqConfDir}
    makeDirectory ${pxeMenuFileDir}

    # Set file locations
    local dnsMasqConf="${dnsMasqConfDir}/dnsmasq.conf"
    local pxeMenuFile="${pxeMenuFileDir}/default"
    # Set template file locations
    local tmpDnsMasqConf="template/dnsmasq/dnsmasq.conf"
    local tmpPxeMenuFile=$(getTmpPxeMenuLocation)

    # Copy template files
    copySampleFile ${tmpDnsMasqConf} ${tmpDnsMasqConf}.modified
    copySampleFile ${tmpPxeMenuFile} ${tmpPxeMenuFile}.modified

    # Replace the template variables with their appropriate values
    local dhcpRangeMinimumPlaceholder="@@RNI_DHCP_MIN@@"
    local dhcpRangeMaximumPlaceholder="@@RNI_DHCP_MAX@@"
    local networkBroadcastIpPlaceholder="@@RNI_NETWORK_BROADCAST_IP@@"
    local networkGatewayIpPlaceholder="@@RNI_NETWORK_GATEWAY_IP@@"
    local rniIpPlaceholder="@@RNI_IP@@"
    local networkDnsSecondaryPlaceholder="@@RNI_NETWORK_DNS_SECONDARY@@"

    # Replace all the potential variables in the staged files.
    # Note that profile-scoped variables are not accessible here.
    # In order to gain access to that scope use the renderRniTemplate
    # functionality
    local stgFiles=("${tmpDnsMasqConf}.modified" "${tmpPxeMenuFile}.modified")
    for stgFile in ${stgFiles[@]}; do
        sed -i -e "s/${dhcpRangeMinimumPlaceholder}/${rni_config_dhcp_range_minimum}/g" ${stgFile}
        sed -i -e "s/${dhcpRangeMaximumPlaceholder}/${rni_config_dhcp_range_maximum}/g" ${stgFile}
        sed -i -e "s/${networkBroadcastIpPlaceholder}/${rni_config_network_broadcast_ip}/g" ${stgFile}
        sed -i -e "s/${networkGatewayIpPlaceholder}/${rni_config_network_gateway_ip}/g" ${stgFile}
        sed -i -e "s/${rniIpPlaceholder}/${rni_config_rni_ip}/g" ${stgFile}
        sed -i -e "s/${networkDnsSecondaryPlaceholder}/${rni_config_network_dns_secondary}/g" ${stgFile}
        logInfoMsg "Applied network config to ${stgFile}"
    done

    # Copy the modified config files to the real locations
    copySampleFile ${tmpDnsMasqConf}.modified ${dnsMasqConf}
    copySampleFile ${tmpPxeMenuFile}.modified ${pxeMenuFile}

    # Clean up the modified templates
    rm ${tmpDnsMasqConf}.modified
    rm ${tmpPxeMenuFile}.modified

    # Because the PXE menu generation process is a bit more involved,
    # there is another PXE menu artifact that needs to be cleaned up.
    # This function will clean it up.
    cleanupTmpPxeMenu

    printDatedOkMsg "Successfully applied this system's network configuration to Retail Node Installer configs."
}

renderRniTemplate() {
    local fileName=$1
    local profileName=$2

    # Check if the filename is an rnitemplate or not.
    if [[ "${fileName}" != *".rnitemplate" ]]; then
        printDatedErrMsg "renderRniTemplate: ${fileName} was not an .rnitemplate file. This function should not be called on files that are not rnitemplates. Exiting"
        logErrMsg "renderRniTemplate: ${fileName} was not an .rnitemplate file. This function should not be called on files that are not rnitemplates. Exiting"
        exit 1
    fi

    # Copy the .rnitemplate file to .rnitemplate.modified,
    # and stage the changes in that file.
    copySampleFile ${fileName} ${fileName}.modified

    # Replace the template variables with their appropriate values
    local dhcpRangeMinimumPlaceholder="@@RNI_DHCP_MIN@@"
    local dhcpRangeMaximumPlaceholder="@@RNI_DHCP_MAX@@"
    local networkBroadcastIpPlaceholder="@@RNI_NETWORK_BROADCAST_IP@@"
    local networkGatewayIpPlaceholder="@@RNI_NETWORK_GATEWAY_IP@@"
    local rniIpPlaceholder="@@RNI_IP@@"
    local networkDnsSecondaryPlaceholder="@@RNI_NETWORK_DNS_SECONDARY@@"
    local profileNamePlaceholder="@@PROFILE_NAME@@"

    # Replace all the potential variables in the staged file.
    sed -i -e "s/${dhcpRangeMinimumPlaceholder}/${rni_config_dhcp_range_minimum}/g" ${fileName}.modified
    sed -i -e "s/${dhcpRangeMaximumPlaceholder}/${rni_config_dhcp_range_maximum}/g" ${fileName}.modified
    sed -i -e "s/${networkBroadcastIpPlaceholder}/${rni_config_network_broadcast_ip}/g" ${fileName}.modified
    sed -i -e "s/${networkGatewayIpPlaceholder}/${rni_config_network_gateway_ip}/g" ${fileName}.modified
    sed -i -e "s/${rniIpPlaceholder}/${rni_config_rni_ip}/g" ${fileName}.modified
    sed -i -e "s/${networkDnsSecondaryPlaceholder}/${rni_config_network_dns_secondary}/g" ${fileName}.modified
    sed -i -e "s/${profileNamePlaceholder}/${profileName}/g" ${fileName}.modified

    # Get the name of the actual file by using awk to split the file name.
    # Example:
    # if fileName is dyn-ks.yml.rnitemplate, renderedFilename will be dyn-ks.yml
    local renderedFilename=$(docker run --rm -t alpine:3.9 echo "${fileName}.modified" | awk '{split($0, a, ".rnitemplate.modified"); print a[1]}')

    # Copy the .rnitemplate.modified file to the original fileName.
    copySampleFile ${fileName}.modified ${renderedFilename}

    # Cleanup the staging file
    rm ${fileName}.modified
    logInfoMsg "Rendered ${renderedFilename}"
}
