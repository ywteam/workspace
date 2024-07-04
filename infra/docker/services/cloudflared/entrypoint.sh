#!/bin/bash
ydk:cloudflared(){
    whenDone(){
        local EXPECTED_MESSAGE="Registered tunnel connection"
        local MAX_RETRIES=10
        local RETRY_COUNT=0
        ydk:log info "Waiting for cloudflared to register tunnel connection"
        local SERVICE_ID=$(docker service ls --filter name=test_cloudflare --format "{{.ID}}")
        [[ -z "${SERVICE_ID}" ]] && return 1
        {
            # local LOG_PID=
            while read -r LOG; do
                ydk:log debug "[CLOUDFLARE] ${LOG}"
                if grep -q "${EXPECTED_MESSAGE}" <<< "${LOG}"; then
                    # [[ -n "${LOG_PID}" ]] && kill -9 $LOG_PID
                    break
                fi
            done < <(docker service logs "${SERVICE_ID}" --follow 2>&1) # & LOG_PID=$!)
        } & wait $!        
        ydk:log info "cloudflared has registered tunnel connection"
        return 0
    }
    ydk:try "$@" 4>&1
    return $?
}


# docker service ls --format "{{.Name}}" | while read -r SERVICE || [[ -n "${SERVICE}" ]]; do
#     docker service logs "${SERVICE}" --tail 10 --follow
# done            
# docker stack rm test