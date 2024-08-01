#!/usr/bin/env bash
preinstal(){
    readonly STACK_NAME="keycloak"
    _ logger "pre install hook ${STACK_NAME}"
    
    # local STACK_VOLUME_PATH="${SERVICE_VOLUME_PATH}/${STACK_NAME}" && export KEYCLOAK_STACK_VOLUME_PATH=$(realpath "${STACK_VOLUME_PATH}")
    # _ logger "Stack Volume ${STACK_NAME}:${STACK_VOLUME_PATH}"
    # mkdir -p "${STACK_VOLUME_PATH}"
    
    local STACK_CERTS_PATH="${SERVICE_VOLUME_PATH}/certs" && export KEYCLOAK_STACK_CERTS_PATH=$(realpath "${STACK_CERTS_PATH}")
    _ logger "Stack Certs ${STACK_NAME}:${STACK_CERTS_PATH}"
    mkdir -p "${STACK_CERTS_PATH}"


    # local CERTS_VOLUME_NAME="${TENANT_NAME}-${STACK_NAME}-certs"
    # docker service rm rapd_cloud_keycloak-frontend    
    # docker service rm rapd_cloud_keycloak-backend
    # docker service rm rapd_cloud_keycloak-console
    # docker volume rm "${CERTS_VOLUME_NAME}" > /dev/null || true
    # docker volume create "${CERTS_VOLUME_NAME}" > /dev/null || true
    # local CERTS_VOLUME_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' "${CERTS_VOLUME_NAME}")
    # _ logger "Certs Volume ${CERTS_VOLUME_NAME}:${CERTS_VOLUME_PATH}"
    # export KEYCLOAK_CERTS_VOLUME_PATH="${CERTS_VOLUME_PATH}"
    if [ -z "$(ls -A "${STACK_CERTS_PATH}")" ]; then
        _ logger "Generating self-signed certificate for Keycloak in ${STACK_CERTS_PATH}"
        
        openssl req -newkey rsa:2048 -nodes -x509 -days 3650 \
            -keyout "${STACK_CERTS_PATH}/keycloak-server.key.pem" \
            -out "${STACK_CERTS_PATH}/keycloak-server.crt.pem" \
            -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.keycloak.dl" \
            -addext "subjectAltName=DNS:www.keycloak.dl,DNS:keycloak.dl" | _ logger
    fi

    # set reable only for all users
    chmod 444 "${STACK_CERTS_PATH}/keycloak-server.crt.pem"
    chmod 444 "${STACK_CERTS_PATH}/keycloak-server.key.pem"
}
