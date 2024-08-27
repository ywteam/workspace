#!/usr/bin/env bash
elastic:post:install(){
    echo "elastic:post:install"
    # wait service with name elastic-setup until it's stopped
    until docker service ls | grep -q "elastic-setup"; do
        echo "Waiting for elastic setup service to start..."
        local logs=$(docker service logs --tail 100 alexandria-opcyde-cloud_es-setup)
        [[ "$logs" == *"All done!"* ]] && break;
        echo "$logs"
        sleep 1;
    done
    echo "elastic setup service started"    
    # docker service logs -f --tail 100 alexandria-opcyde-cloud_es-setup
}
elastic:post:install "$@"