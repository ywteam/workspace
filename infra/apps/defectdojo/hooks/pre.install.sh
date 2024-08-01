#!/usr/bin/env bash
echo "pre install hook"
prepare(){
    readonly STACK_NAME="defectdojo"
    clean() {
        docker service ls | grep "${TENANT_NAME}_${STACK_NAME}" | awk '{print $2}' | while read -r SERVICE; do
            docker service rm "$SERVICE"
        done
    }
    # clean
}
prepare "$@"

# docker service rm "rapd_cloud_defectdojo-db" &&
# docker service rm "rapd_cloud_defectdojo-redis" &&
# docker service rm "rapd_cloud_defectdojo-initializer" &&
# docker service rm "rapd_cloud_defectdojo-celerybeat" &&
# docker service rm "rapd_cloud_defectdojo-celeryworker" &&
# docker service rm "rapd_cloud_defectdojo-uwsgi" &&
# docker service rm "rapd_cloud_defectdojo-nginx"