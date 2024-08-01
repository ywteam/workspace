#!/usr/bin/env bash
echo "pre install hook"
preinstall(){
    readonly STACK_NAME="wazuh"
    local CERTS_VOLUME_NAME="${TENANT_NAME}_${STACK_NAME}_certs"
    local CERTS_VOLUME_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' "${CERTS_VOLUME_NAME}")
    export WAZUH_CERTS_VOLUME_PATH="${CERTS_VOLUME_PATH}"
    echo "WAZUH_CERTS_VOLUME_PATH: $WAZUH_CERTS_VOLUME_PATH"
}

preinstall "$@"