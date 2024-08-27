#!/usr/bin/env bash
kibana:pre:install() {
    echo "kibana:pre:install"
    local ELASTIC_DEPLOYMENT_PATH=$(echo "${SERVICE_DEPLOYMENT_PATH}" | sed 's/kibana/elastic/g')
    local ELATIC_SECRET_FILE="${ELASTIC_DEPLOYMENT_PATH}/.secrets.env"
    [[ ! -f "${ELATIC_SECRET_FILE}" ]] && echo "File ${ELATIC_SECRET_FILE} does not exist" && exit 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == "PASSWORD="* ]] && ELASTIC_PASSWORD=$(echo "$line" | cut -d'=' -f2) && break
    done <"${ELATIC_SECRET_FILE}"
    [[ -z "${ELASTIC_PASSWORD}" ]] && echo "ELASTIC_PASSWORD is empty" && exit 1
    # replace fist and last "
    ELASTIC_PASSWORD="${ELASTIC_PASSWORD%\"}"
    ELASTIC_PASSWORD="${ELASTIC_PASSWORD#\"}"
    local ELASTICSEARCH_HOST="https://tsdb.alexandria.opcyde.cloud"
    local ELASTICSEARCH_USERNAME="elastic"
    local ELASTICSEARCH_PASSWORD="${ELASTIC_PASSWORD}"
    echo "Waiting for Elasticsearch to start up before bootstrapping Kibana."
    while true; do
        local RESPONSE=$(
            curl -s -k -w "%{http_code}" \
                -u "${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD}" \
                -H "Content-Type: application/json" \
                -X GET "${ELASTICSEARCH_HOST}/_cluster/health"
        )
        local STATUS_CODE=$(echo "$RESPONSE" | tail -n1)
        [[ "$STATUS_CODE" == *"200"* ]] && break
        echo "Retrying Elasticsearch connection... last status code was ${STATUS_CODE}"
        sleep 10
    done
    exit 200
    # echo "Setting kibana_system password";
    # until curl -i -X POST --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD?ELASTIC_PASSWORD not set}" -H "Content-Type: application/json" https://es01:9200/_security/user/kibana_system/_password -d "{\"password\":\"${KIBANA_ADMIN_PASSWORD}\"}" | grep -q "^{}"; do sleep 10; done;
}
kibana:pre:install "$@"
