#!/bin/bash
IAC_CLI_ENTRYPOINT="${0}" && readonly IAC_CLI_ENTRYPOINT
IAC_CLI_ENTRYPOINT_DIR=$(dirname "${IAC_CLI_ENTRYPOINT}") && IAC_CLI_ENTRYPOINT_DIR=$(realpath "${IAC_CLI_ENTRYPOINT_DIR}") && readonly IAC_CLI_ENTRYPOINT_DIR
export IAC_CLI_ARGS=("$@") && readonly IAC_CLI_ARGS


ls -lsa .

echo "IAC_CLI_ENTRYPOINT: ${IAC_CLI_ENTRYPOINT}"
echo "IAC_CLI_ENTRYPOINT_DIR: ${IAC_CLI_ENTRYPOINT_DIR}"
echo "IAC_CLI_ARGS: ${IAC_CLI_ARGS[@]}"

# docker stack deploy --detach=false --quiet -c workspace/infra/docker/services/compose.yaml yellow
