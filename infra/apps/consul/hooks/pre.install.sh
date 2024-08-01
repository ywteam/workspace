#!/usr/bin/env bash
echo "pre install hook"
prepare(){
    readonly STACK_NAME="consul"
    generate_ca_certificate() {
        local VOLUME_NAME="${TENANT_NAME}_${STACK_NAME}-certs"
        local VOLUME_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' "${VOLUME_NAME}")
        
        # generate consul-agent-ca.pem if don't exists using docker run and consul image
        local TMP_STACK_PATH="/tmp/${STACK_NAME}"
        mkdir -p "${TMP_STACK_PATH}"
        local CURRENT_DIR=$(pwd)
        # if volume path dir is empty, then generate certs
        if [ ! "$(ls -A ${VOLUME_PATH})" ]; then
            echo "Generating certs"
            cd "${TMP_STACK_PATH}"
            docker run --user root --rm -v "${TMP_STACK_PATH}:/certs" consul:1.6.2 consul tls ca create -domain "consul-agent-ca" -days 3650
            docker run --rm --user root -v "${TMP_STACK_PATH}:/certs" consul:1.6.2 consul tls cert create -server -dc dc1 -domain "${STACK_NAME}" -ca /certs/consul-agent-ca.pem -days 3650
            docker run --rm --user root -v "${TMP_STACK_PATH}:/certs" consul:1.6.2 consul tls cert create -client -dc dc1 -domain "${STACK_NAME}" -ca /certs/consul-agent-ca.pem -days 3650
            cd "${CURRENT_DIR}"
            cp "${TMP_STACK_PATH}/consul-agent-ca.pem" "${VOLUME_PATH}/consul-agent-ca.pem"
            cp "${TMP_STACK_PATH}/dc1-server-${STACK_NAME}-0.pem" "${VOLUME_PATH}/dc1-server-${STACK_NAME}-0.pem"
            cp "${TMP_STACK_PATH}/dc1-server-${STACK_NAME}-0-key.pem" "${VOLUME_PATH}/dc1-server-${STACK_NAME}-0-key.pem"
        fi


        rm -f "${TMP_STACK_PATH}/consul-agent-ca.pem"
        rm -f "${TMP_STACK_PATH}/dc1-server-${STACK_NAME}-0.pem"
        rm -f "${TMP_STACK_PATH}/dc1-server-${STACK_NAME}-0-key.pem"
        if [ ! -f "${TMP_STACK_PATH}/consul-agent-ca.pem" ]; then
            echo "Generating consul-agent-ca.pem"
            docker run --user root --rm -v "${TMP_STACK_PATH}:/certs" consul:1.6.2 consul tls ca create -domain "consul-agent-ca" -days 3650
            # docker run --rm -v "${VOLUME_NAME}:/certs" consul:1.6.2 consul tls ca create --out-dir /certs --out-file consul-agent-ca.pem -days 3650
            
            # local IMAGE_ID=$(docker run -d consul:1.6.2 consul tls ca create -domain "${STACK_NAME}" -days 3650)           
            # docker cp "${IMAGE_ID}:/certs/consul-agent-ca.pem" "${TMP_STACK_PATH}/consul-agent-ca.pem"
            # docker rm "${IMAGE_ID}"
        fi
        # generate dc1-server-consul-0.pem if don't exists using docker run and consul image
        # if [ ! -f "${TMP_STACK_PATH}/dc1-server-${STACK_NAME}-0.pem" ]; then
        #     echo "Generating dc1-server-${STACK_NAME}-0.pem"
        #     docker run --rm --user root -v "${TMP_STACK_PATH}:/certs" consul:1.6.2 consul tls cert create -server -dc dc1 -domain "${STACK_NAME}" -ca /certs/consul-agent-ca.pem -days 3650
        # fi
        # generate dc1-server-consul-0-key.pem if don't exists using docker run and consul image
        # if [ ! -f "${VOLUME_PATH}/dc1-server-${STACK_NAME}-0-key.pem" ]; then
        #     echo "Generating dc1-server-${STACK_NAME}-0-key.pem"
        #     docker run --rm -u root -v "${VOLUME_NAME}:/certs" consul:1.6.2 consul tls cert create -client -dc dc1 -domain "${STACK_NAME}" -days 3650
        # fi
        ls -lsa "$VOLUME_PATH"
        ls -lsa "$TMP_STACK_PATH"
    }
    # generate_ca_certificate
}
prepare "$@"
