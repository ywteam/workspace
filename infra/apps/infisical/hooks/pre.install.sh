#!/usr/bin/env bash
echo "pre install hook"
prepare(){
    readonly STACK_NAME="infisical"
    secrects::read() {
        docker secret ls | grep "${STACK_NAME^^}" # | awk '{print $2}' # | xargs docker secret rm
    }
    clean() {
        docker service ls | grep "${TENANT_NAME}_${STACK_NAME}*" | awk '{print $2}' | while read -r SERVICE; do
            docker service rm "$SERVICE"
        done
    }
    clean
    # secrects::read
}
prepare "$@"
