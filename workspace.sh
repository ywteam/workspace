#!/bin/bash
WKSPC_CLI_ENTRYPOINT="${0}" && readonly WKSPC_CLI_ENTRYPOINT
WKSPC_CLI_ENTRYPOINT_DIR=$(dirname "${WKSPC_CLI_ENTRYPOINT}") && WKSPC_CLI_ENTRYPOINT_DIR=$(realpath "${WKSPC_CLI_ENTRYPOINT_DIR}") && readonly WKSPC_CLI_ENTRYPOINT_DIR
export WKSPC_CLI_ARGS=("$@") && readonly WKSPC_CLI_ARGS

export YDK_PATH="./sdk/shell/packages/ydk/ydk.cli.sh" && readonly YDK_PATH
WKSPC_CLI__LOGGER_CONTEXT="WKSPC" && readonly WKSPC_CLI__LOGGER_CONTEXT

ydk:workspace:setup(){
    declare -A YDK_WKSPC_SETUP_CONFIG=(
        ["repo/url"]="https://github.com/raphaelcarlosr/workspace"
    )
    [[ -f "${YDK_PATH}" ]] && return 0
    __workspace:onexit(){
        local STATUS="$?"
        echo "Exiting with status ${STATUS}"
        exit "${STATUS}"
    }
    __workspace:configure(){
        echo "Configuring"
        return 0
    }
    local RETURN_STATUS=0
    trap '__workspace:onexit' EXIT
    if declare -f "__workspace:$1" > /dev/null; then
        # call arguments verbatim
        __workspace:"$1" "$@"
        return $?
    else
        # Show a helpful error
        echo "'$1' is not a known function name" >&2
        return 1
    fi
    [[ ! -f "${YDK_PATH}" ]] && return 1
    return "${RETURN_STATUS}"
}
if ! ydk:workspace:setup "$@"; then
    echo "Failed to setup workspace"
    exit 1
fi
exit 100
ydk:workspace(){
    ydk:log info "Yellow Team Workspace CLI"
    ydk:undo add "Workspace rollback" echo "Rollback"
    local DOCKER_SWARM_ENABLED=true
    local DOCKER_SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}')
    [[ "${DOCKER_SWARM_ENABLED}" == "inactive" ]] && DOCKER_SWARM_ENABLED=false
    declare -a YDK_WKSPC_CLEANUP=()
    declare -A YDK_WKSPC_OPTS=(
        ["project/name"]="yellow-team"
        ["images/directory"]="${WKSPC_CLI_ENTRYPOINT_DIR}/docker"
        ["images/base/path"]="${WKSPC_CLI_ENTRYPOINT_DIR}/docker/ydk-base.dockerfile"
        ["deployments/directory"]="${WKSPC_CLI_ENTRYPOINT_DIR}/deployments"
        ["deployments/profiles"]="ywt-default ywt-backstage"
        ["vault/paths"]="${YDK_CONFIG_VAULT_PATHS}"
        ["vault/clientId"]="${YDK_CONFIG_VAULT_CLIENT_ID}"
        ["vault/clientSecret"]="${YDK_CONFIG_VAULT_CLIENT_SECRET}"
        ["vault/workspaceId"]="${YDK_CONFIG_VAULT_PROJECT_ID}"
        ["vault/env"]="${YDK_CONFIG_VAULT_ENV:-dev}"
        ["dotenv/default"]="${WKSPC_CLI_ENTRYPOINT_DIR}/.env"
        ["dotenv/example"]="${WKSPC_CLI_ENTRYPOINT_DIR}/.env.example"
        ["agent/remote-path"]="/workspace/yellow-team"
        ["agent/dependencies"]="ydk:is ydk:nnf ydk:throw ydk:try ydk:colors compose dotenv vault"
        ["host/uname"]="$(uname -n | cut -d'.' -f1)"       
        ["capabilities/docker-swarm"]="${DOCKER_SWARM_ENABLED}"
    )
    ! [[ -f "${YDK_WKSPC_OPTS["dotenv/example"]}" ]] && touch "${YDK_WKSPC_OPTS["dotenv/example"]}"
    IFS=' ' read -r -a YDK_WKSPC_AGENT_DEPENDENCIES <<< "${YDK_WKSPC_OPTS["agent/dependencies"]}"
    build(){
        images(){
            base(){
                local BASE_IMAGE="yellowteam/ywt-base:latest"
                local BASE_IMAGE_ID=$(docker images --format "{{.ID}}" "${BASE_IMAGE}")
                if [[ -z "${BASE_IMAGE_ID}" ]]; then
                    ydk:log info "Building base image ${BASE_IMAGE}"
                    docker build -t "${BASE_IMAGE}" \
                        -f "${YDK_WKSPC_OPTS["images/base/path"]}" \
                        "${WKSPC_CLI_ENTRYPOINT_DIR}"

                    if [[ "$?" -ne 0 ]]; then
                        ydk:log error "Failed to build base image ${BASE_IMAGE}"
                        return 1
                    fi
                    ydk:log success "Base image ${BASE_IMAGE} built successfully"
                else
                    ydk:log success "Base image ${BASE_IMAGE} already exists"
                fi
                return 0
            
            }
            ydk:try "$@" 4>&1
            return $?
        }
        ydk:try "$@" 4>&1
        return $?        
    }
    compose(){
        local COMPOSE_ARGS=(
            "--project-name" "${YDK_WKSPC_OPTS["project/name"]}"
            "--project-directory" "${YDK_WKSPC_OPTS["deployments/directory"]}"
        )
        declare -A YDK_WKSPC_COMPOSE_OPTS=(
            ["args.profile.present"]=false
        )         
        files(){
            local COMPOSE_FILES=()
            while read -r FILE || [[ -n "${FILE}" ]]; do
                COMPOSE_FILES+=("${FILE}")
                COMPOSE_ARGS+=("--file" "${FILE}")
            done < <(
                find "${YDK_WKSPC_OPTS["deployments/directory"]}" \
                    -type f -name "compose.yaml" \
                    -not -path "${YDK_WKSPC_OPTS["deployments/directory"]}/compose.yaml"
            )
            COMPOSE_FILES+=("${YDK_WKSPC_OPTS["deployments/directory"]}/compose.yaml")
            echo "${COMPOSE_FILES[@]}" >&4
            return 0
        }
        cli(){
            local ARGS=()
            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --profile)
                        COMPOSE_ARGS+=("--profile" "$2")
                        YDK_WKSPC_COMPOSE_OPTS["args.profile.present"]=true
                        shift 2
                        ;;
                    --file)
                        COMPOSE_ARGS+=("--file" "$2")
                        shift 2
                        ;;
                    *)
                        ARGS+=("$1")
                        shift
                        ;;
                esac
            done
            if [[ "${YDK_WKSPC_COMPOSE_OPTS["args.profile.present"]}" == "false" ]]; then
                IFS=' ' read -r -a YDK_WKSPC_COMPOSE_PROFILES <<< "${YDK_WKSPC_OPTS["deployments/profiles"]}"
                for COMPOSE_PROFILE in "${YDK_WKSPC_COMPOSE_PROFILES[@]}"; do
                    COMPOSE_ARGS+=("--profile" "${COMPOSE_PROFILE}")
                done
            fi  
        }
        
        ydk:log info "Running docker compose ${YDK_WKSPC_COMPOSE_PROFILES[*]// /,}"
        local ARGS=()
        while [[ "$#" -gt 0 ]]; do
            case "$1" in
                --profile)
                    COMPOSE_ARGS+=("--profile" "$2")
                    YDK_WKSPC_COMPOSE_OPTS["args.profile.present"]=true
                    shift 2
                    ;;
                --file)
                    COMPOSE_ARGS+=("--file" "$2")
                    shift 2
                    ;;
                *)
                    ARGS+=("$1")
                    shift
                    ;;
            esac
        done
        if [[ "${YDK_WKSPC_COMPOSE_OPTS["args.profile.present"]}" == "false" ]]; then
            # readarray -t YDK_WKSPC_COMPOSE_PROFILES <<< "${YDK_WKSPC_OPTS["deployments/profiles"]}"
            IFS=' ' read -r -a YDK_WKSPC_COMPOSE_PROFILES <<< "${YDK_WKSPC_OPTS["deployments/profiles"]}"
            for COMPOSE_PROFILE in "${YDK_WKSPC_COMPOSE_PROFILES[@]}"; do
                COMPOSE_ARGS+=("--profile" "${COMPOSE_PROFILE}")
            done
        fi 
        while read -r FILE || [[ -n "${FILE}" ]]; do
            COMPOSE_ARGS+=("--file" "${FILE}")
        done < <(
            find "${YDK_WKSPC_OPTS["deployments/directory"]}" \
                -type f -name "compose.yaml" \
                -not -path "${YDK_WKSPC_OPTS["deployments/directory"]}/compose.yaml"
        )
        COMPOSE_ARGS+=("--file" "${YDK_WKSPC_OPTS["deployments/directory"]}/compose.yaml")
        ydk:log debug "docker compose ${COMPOSE_ARGS[*]} ${ARGS[*]}"
        docker compose "${COMPOSE_ARGS[@]}" "${ARGS[@]}" >&4
        return $?
        # ydk:try "$@" 4>&1
        # return $? 
    }
    dotenv(){
        files(){
            readarray -t YDK_WKSPC_DOTENV_FILES < <(
                find "${YDK_WKSPC_OPTS["deployments/directory"]}" \
                    -type f -name ".env" \
                    -not -path "${YDK_WKSPC_OPTS["deployments/directory"]}/.env"
            )
            YDK_WKSPC_DOTENV_FILES+=("${WKSPC_CLI_ENTRYPOINT_DIR}/.env")
            ydk:log debug "Dotenv files ${YDK_WKSPC_DOTENV_FILES[*]// /,}"
            echo "${YDK_WKSPC_DOTENV_FILES[@]}" >&4
            return 0
        }
        kv(){
            local LINE="${1}"
            [[ "${LINE}" =~ ^[[:space:]]*# ]] && return 1
            [[ ! "${LINE}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]] && return 1
            local KEY="${BASH_REMATCH[1]}"
            local VALUE="${BASH_REMATCH[2]//\"/}" && VALUE="${VALUE//\`/}" VALUE="${VALUE#\'}" && VALUE="${VALUE%\'}"
            # base64 value
            # VALUE=$(base64 <<< "${VALUE}" | tr -d '\n')
            # echo "${KEY}]]][[${VALUE}" >&4
            echo "${KEY}" "${VALUE}" >&4
            return 0
        }
        exports(){
            local KEY="${1}"
            local VALUE="${2}"
            local KEY_PATH="${3}"
            local VAR_PREFX="${4:-"CONFIG"}" && VAR_PREFX="${VAR_PREFX^^}"
            local VAR_NAME="${KEY//[^a-zA-Z0-9_]/}"
            declare -gx "${KEY}"="${VALUE}"
            declare -gx "YDK_${VAR_PREFX}_${VAR_NAME}"="${VALUE}"
            YDK_WKSPC_OPTS["${KEY_PATH}"]="${VALUE}"
            VALUE=$(base64 <<< "${VALUE}" | tr -d '\n')
            local VALUE_LENGTH=${#VALUE}            
            [[ "${VALUE_LENGTH}" -gt 10 ]] && VALUE_LENGTH=10
            ydk:log debug "Exported dotenv ${YELLOW}${KEY_PATH}${NC}=${VALUE:0:${VALUE_LENGTH}}..."
            if [[ "${YDK_WKSPC_OPTS["capabilities/docker-swarm"]}" == true ]]; then
                local SECRET_NAME="${KEY,,}"
                local SECRET_NAME="${SECRET_NAME//_/-}"
                local SECRET_NAME="${SECRET_NAME//[^a-zA-Z0-9-]/}"
                local SECRET_NAME="${SECRET_NAME:0:63}"
                local SECRET_ID=$(docker secret ls --filter "name=${SECRET_NAME}" --format "{{.ID}}")
                ydk:log debug "Exporting secret ${YELLOW}${SECRET_NAME}${NC}=${SECRET_VALUE:0:10}..."
                if [[ -n "${SECRET_ID}" ]]; then
                    docker secret rm "${SECRET_ID}" >/dev/null
                    ydk:log warn "Secret ${YELLOW}${SECRET_NAME}${NC} already exists, updating..."
                fi
                echo -n "${YDK_WKSPC_OPTS["${KEY_PATH}"]}" | docker secret create "${SECRET_NAME}" - >/dev/null
                if [[ "$?" -ne 0 ]]; then
                    ydk:log error "Failed to create secret ${YELLOW}${SECRET_NAME}${NC}"
                    continue
                fi
                ydk:log success "Secret ${YELLOW}${SECRET_NAME}${NC} created successfully"
            fi
            return 0
        }
        load(){
            IFS=',' read -r -a YDK_WKSPC_DOTENV_FILES < <(dotenv files 4>&1)
            YDK_WKSPC_DOTENV_FILES+=("$@")
            ydk:log debug "Loading Dotenv files ${#YDK_WKSPC_DOTENV_FILES[@]}"
            for YDK_WKSPC_DOTENV_FILE in "${YDK_WKSPC_DOTENV_FILES[@]}"; do
                if [[ ! -f "${YDK_WKSPC_DOTENV_FILE}" ]]; then
                    ydk:log warn "Invalid dotenv file ${YDK_WKSPC_DOTENV_FILE}"
                    continue
                fi
                local YDK_WKSPC_DOTENV_DIRNAME=$(basename "$(dirname "${YDK_WKSPC_DOTENV_FILE}")")
                local YDK_WKSPC_DOTENV_CONFIG_PATH="dotenv/${YDK_WKSPC_DOTENV_DIRNAME,,}"
                ydk:log info "Loading dotenv ${YDK_WKSPC_DOTENV_CONFIG_PATH}"
                while read -r LINE || [[ -n "${LINE}" ]]; do
                    # readarray -t KEYVALUE < <(dotenv kv "${LINE}" 4>&1)                    
                    KEYVALUE=($(kv "${LINE}" 4>&1))
                    [[ -z "${KEYVALUE[*]}" ]] && continue
                    [[ "${#KEYVALUE[@]}" -ne 2 ]] && continue
                    local KEY="${KEYVALUE[0]}"
                    local VALUE="${KEYVALUE[1]}"
                    exports "${KEY}" "${VALUE}" "${YDK_WKSPC_DOTENV_CONFIG_PATH}/${KEY^^}" "DOTENV"
                done < "${YDK_WKSPC_DOTENV_FILE}" 
                ydk:log success "Dotenv ${YDK_WKSPC_DOTENV_CONFIG_PATH} loaded successfully"
            done            
            return 0
        }
        save(){
            local DOTENV_KEY="${1}"
            local DOTENV_VALUE="${2}"
            local DOTENV_FILE="${3:-"${YDK_WKSPC_OPTS["dotenv/default"]}"}"
            if [[ ! -f "${DOTENV_FILE}" || -z "${DOTENV_KEY}" || -z "${DOTENV_VALUE}" ]]; then
                ydk:log warn "Invalid dotenv file ${DOTENV_FILE} or key ${DOTENV_KEY} or value ${DOTENV_VALUE}"
                return 1
            fi
            if ! grep -q "^${DOTENV_KEY}=" "${DOTENV_FILE}"; then
                ydk:log debug "Appending dotenv ${DOTENV_KEY}"
                echo "${DOTENV_KEY}=${DOTENV_VALUE}" >> "${DOTENV_FILE}"
            else
                ydk:log debug "Updating dotenv ${DOTENV_KEY}"
                sed -i "s/^${DOTENV_KEY}=.*/${DOTENV_KEY}=${DOTENV_VALUE}/" "${DOTENV_FILE}"
            fi
            return 0
        }
        help(){
            {
                echo -e "Declared as local and exported variable ${YELLOW}\$<DOTENV-KEY>${NC}"
                echo -e "Declared as exported variable ${YELLOW}\$YDK_DOTENV_<DOTENV-KEY>${NC}"
                echo -e "Declared as config ${YELLOW}\$YDK_WKSPC_OPTS['dotenv/<DOTENV-KEY-WITHTOUT-PATH-NAME>']${NC}"
                echo -e "Use 'printenv | grep YDK_' to list dotenv"
            } >&4
            return 0
        }
        ydk:try "$@" 4>&1
        return $?
    }
    vault(){
        [[ -n "$YDK_WKSPC_OPTS["vault/clientId"]" ]] && readonly INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="${YDK_WKSPC_OPTS["vault/clientId"]}"
        [[ -n "$YDK_WKSPC_OPTS["vault/clientSecret"]" ]] && readonly INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="${YDK_WKSPC_OPTS["vault/clientSecret"]}"
        [[ -n "$YDK_WKSPC_OPTS["vault/workspaceId"]" ]] && readonly INFISICAL_PROJECT_ID="${YDK_WKSPC_OPTS["vault/workspaceId"]}"
        [[ -n "$YDK_WKSPC_OPTS["vault/env"]" ]] && readonly INFISICAL_DEFAULT_ENV="${YDK_WKSPC_OPTS["vault/env"]}"
        [[ -n "$YDK_WKSPC_OPTS["vault/paths"]" ]] && readonly INFISICAL_DEFAULT_PATH="${YDK_WKSPC_OPTS["vault/paths"]}"
        install(){
            {
                if command -v infisical &>/dev/null; then
                    ydk:log success "Infisical CLI already installed $(infisical --version)"
                    return 0
                fi
                curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh'  | sudo -E bash
                sudo apt-get update && sudo apt-get install -y infisical
                ydk:log success "Infisical CLI installed successfully $(infisical --version)"
            } >&4
            return 0 
        }
        upgrade(){
            apt update && apt upgrade -y infisical
            return $?
        }
        auth() {
            token(){
                local YDK_VAULT_TOKEN="${YDK_WKSPC_OPTS["dotenv/workspace/INFISICAL_TOKEN"]:-$INFISICAL_TOKEN}"
                [[ -n "${YDK_VAULT_TOKEN}" ]] && {
                    ydk:log success "Token already exists"
                    return 0
                }
                YDK_VAULT_TOKEN=$(infisical login --plain --method=universal-auth) 
                if [[ -z "${YDK_VAULT_TOKEN}" ]]; then
                    ydk:log error  "Failed to authenticate"
                    return 1
                fi
                ydk:log success "Authenticated successfully"
                export INFISICAL_TOKEN="${YDK_VAULT_TOKEN}" && readonly INFISICAL_TOKEN
                dotenv save "INFISICAL_TOKEN" "${YDK_VAULT_TOKEN}"
                return 0
            }
            refresh(){
                INFISICAL_TOKEN=$(infisical service-token renew "${INFISICAL_TOKEN}")
                if [[ -z "${INFISICAL_TOKEN}" ]]; then
                    ydk:log error "Failed to refresh token"
                    return 1
                fi
                ydk:log success "Token refreshed successfully"
                export INFISICAL_TOKEN
                return 0
            }
            ydk:try "$@" 4>&1
            return $? 
        }
        get(){
            ! auth token >&4 && return 1
            local SECRETS_PROCESS_IDS=()
            local SECRETS_TMP_FILE=$(mktemp)
            echo -n "" > ${SECRETS_TMP_FILE}
            local YDK_VAULT_PATHS="${YDK_WKSPC_OPTS["dotenv/workspace/INFISICAL_DEFAULT_PATH"]:-$INFISICAL_DEFAULT_PATH}"
            local YDK_VAULT_ENV="${YDK_WKSPC_OPTS["dotenv/workspace/INFISICAL_DEFAULT_ENV"]:-${INFISICAL_DEFAULT_ENV:-"dev"}}"
            local YDK_VAULT_WORKSPACE_ID="${YDK_WKSPC_OPTS["dotenv/workspace/INFISICAL_PROJECT_ID"]:-$INFISICAL_PROJECT_ID}"
            local YDK_VAULT_ARGS=(
                "--projectId=${YDK_VAULT_WORKSPACE_ID}"
                "--env=${YDK_VAULT_ENV}" 
                # "--format=dotenv-export"
            )
            ydk:log debug "Getting secrets from (${#YDK_VAULT_ARGS[@]}) ${YDK_VAULT_ARGS[*]}"
            IFS=';' read -r -a INFISICAL_PATHS <<< "${YDK_VAULT_PATHS}"
            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --path)
                        INFISICAL_PATHS+=("$2")
                        shift 2
                        ;;
                    *)
                        YDK_VAULT_ARGS+=("$1")
                        shift
                        ;;
                esac
            done
            ydk:log debug "Getting secrets from ${#INFISICAL_PATHS[@]} paths"
            for INFISICAL_PATH in "${INFISICAL_PATHS[@]}"; do
                ydk:log info "Getting secrets from /${YDK_VAULT_ENV}${INFISICAL_PATH} path"
                {
                    if ! infisical export --path="${INFISICAL_PATH}" "${YDK_VAULT_ARGS[@]}" >> ${SECRETS_TMP_FILE} 2>&1; then
                        ydk:log error "Failed to get secrets from /${INFISICAL_DEFAULT_ENV}${INFISICAL_PATH}"
                        return 1
                    fi
                } &
                SECRET_PROCESS_ID+=($!)                
            done
            ydk:log debug "Waiting vault (${#SECRET_PROCESS_ID[@]}) ${SECRET_PROCESS_ID[*]}"
            wait "${SECRET_PROCESS_ID[@]}"
            cat "${SECRETS_TMP_FILE}" >&4
            rm -f "${SECRETS_TMP_FILE}"
            ydk:log success "Secrets exported successfully"
        }
        exports(){
            local TMP_FILE=$(mktemp)
            local YDK_VAULT_SECRETS=$(get "$@" 4>&1)
            echo "${YDK_VAULT_SECRETS}" > ${TMP_FILE}
            while read -r LINE || [[ -n "${LINE}" ]]; do
                local KEYVALUE=($(dotenv kv "${LINE}" 4>&1))
                [[ -z "${KEYVALUE[*]}" ]] && continue
                [[ "${#KEYVALUE[@]}" -ne 2 ]] && continue
                local KEY="${KEYVALUE[0]}"
                local VALUE="${KEYVALUE[1]}"
                dotenv exports "${KEY}" "${VALUE}" "vault/${KEY^^}" "VAULT"                
            done < ${TMP_FILE}
            rm -f "${TMP_FILE}"
        }
        ydk:try "$@" 4>&1
        return $? 
    }
    agent(){        
        if [[ -z "${YELLOW_AGENT_HOST}" || -z "${YELLOW_AGENT_SECRET}" ]]; then
            ydk:throw 22 "Invalid arguments"
            return 1
        fi
        cli(){
            ydk:log debug "Running agent on ${YELLOW_AGENT_HOST}"
            {
                if ! sshpass -p "${YELLOW_AGENT_SECRET}" ssh -t "${YELLOW_AGENT_HOST}" "$@"; then
                    ydk:throw $? "Failed to execute command ($?)"
                    return 1
                fi
            } >&4
            ydk:log success "Executed successfully"
            return 0
        }
        copy(){
            local ORIGINS=(
                "${YDK_WKSPC_OPTS["deployments/directory"]}/.env:"
                "${WKSPC_CLI_ENTRYPOINT_DIR}/.env:"
                "${YDK_WKSPC_OPTS["deployments/directory"]}/:${YDK_WKSPC_OPTS["agent/remote-path"]}/"
            )
            ORIGINS=( "${ORIGINS[@]}" "$@" )
            ydk:log info "Copying ${#ORIGINS[@]} items to ${YELLOW_AGENT_HOST}"
            for ITEM in "${ORIGINS[@]}"; do
                local ORIGIN="${ITEM%%:*}"
                ! [[ -d "${ORIGIN}" || -f "${ORIGIN}" ]] && ydk:log warn "Invalid origin ${ORIGIN}" && continue
                local DESTINATION="${ITEM#*:}"
                [[ -z "${DESTINATION}" ]] && DESTINATION="${YDK_WKSPC_OPTS["agent/remote-path"]}/$(basename "${ORIGIN}")"
                ydk:log debug "Copying ${ORIGIN} to ${YELLOW_AGENT_HOST}:${DESTINATION}"
                if ! sshpass -p "${YELLOW_AGENT_SECRET}" scp -r "${ORIGIN}" "${YELLOW_AGENT_HOST}:${DESTINATION}"; then
                    ydk:throw 22 "Failed to copy ${ORIGIN} to ${YELLOW_AGENT_HOST}:${DESTINATION}"
                    return 1
                fi
            done
            ydk:log success "Copied successfully"
            return 0            
        }
        entrypoint(){
            {
                echo "#!/bin/bash"
                echo "set -e -o pipefail"
                echo "YDK_AGENT_ENTRYPOINT="\${0}" && readonly YDK_AGENT_ENTRYPOINT"
                echo "YDK_AGENT_ENTRYPOINT_DIR=\$(dirname \"\${YDK_AGENT_ENTRYPOINT}\") && YDK_AGENT_ENTRYPOINT_DIR=\$(realpath \"\${YDK_AGENT_ENTRYPOINT_DIR}\") && readonly YDK_AGENT_ENTRYPOINT_DIR"
                declare -p "YDK_WKSPC_OPTS" | sed 's/YDK_WKSPC_OPTS=(/-g YDK_AGENT_CONFIG=(/'
                declare -p "YDK_COLORS"
                declare -p "YDK_COLORS_NAMES"
                echo "YDK_AGENT_CONFIG[\"agent/fifo\"]=\"/tmp/ydk.fifo\""
                echo "YDK_AGENT_CONFIG[\"agent/uname\"]=\"\$(uname -n | cut -d'.' -f1)\""
                echo "ydk:log() {"
                echo "    {"
                echo "      echo -en \"[${YELLOW}${YDK_BRAND}${NC}] 🩳 | ${YELLOW}\${YDK_AGENT_CONFIG[\"agent/uname\"]}${NC} \$ \""
                echo "      case \"\${1}\" in"
                echo "        debug) echo -ne \"\${PURPLE}\${1}\${NC}\" ;;"
                echo "        info) echo -ne \"\${GRAY}\${1}\${NC}\" ;;"
                echo "        warn) echo -ne \"\${YELLOW}\${1}\${NC}\" ;;"
                echo "        error) echo -ne \"\${RED}\${1}\${NC}\" ;;"
                echo "        success) echo -ne \"\${GREEN}\${1}\${NC}\" ;;"
                echo "        *) echo -ne \"\${1}\" ;;"
                echo "      esac"
                echo "      echo -ne \$'\\t'"
                echo "      echo -ne \"\${2}\""
                echo "      echo -ne \$'\\t'"
                echo "      echo -ne \"\${3}\""
                echo "      echo"
                echo "    } 1>&2"
                echo "    return 0"
                echo "}" 
                echo "ydk:teardown() {"
                echo "    local STATUS=\"\$?\""
                echo "    ydk:log info \"Cleaning up\""
                echo "    rm -f \"\${YDK_AGENT_ENTRYPOINT}\""
                echo "    rm -f \"\${YDK_AGENT_ENTRYPOINT}.log\""
                echo "    [[ -p \"\${YDK_AGENT_CONFIG["agent/fifo"]}\" ]] && exec 4>&- && rm -f \"\${YDK_AGENT_CONFIG["agent/fifo"]}\""
                echo "    if [[ \"\$STATUS\" -ne 0 ]]; then"
                echo "      ydk:log error \"(\$STATUS) Failed to execute command\""
                echo "    else"
                echo "      ydk:log success \"Executed successfully\""
                echo "    fi"
                echo "    exit \$STATUS"
                echo "}"
                # echo "mkdir -p \"${YDK_WKSPC_OPTS["agent/remote-path"]}\""
                for DEPENDENCY in "${YDK_WKSPC_AGENT_DEPENDENCIES[@]}"; do
                    declare -f "${DEPENDENCY}"
                done
                declare -f "__workspace:agent" 
                # echo "declare -f \"__workspace:agent\""
                # echo "declare -p \"YDK_AGENT_CONFIG\""
                echo "if ! declare -f \"__workspace:agent\" &>/dev/null; then"
                echo "    ydk:throw 22 \"Invalid agent\""
                echo "fi"
                echo "ydk:log info \"Running agent\""  
                echo "ydk:colors exports"
                echo "if ! __workspace:agent \"\$@\"; then"
                echo "    ydk:throw \$? \"Failed to execute command\""
                echo "else"
                echo "    ydk:log success \"Executed successfully \$?\""
                echo "fi"
                echo "exit 0"
            } | sed 's/YDK_WKSPC_OPTS/YDK_AGENT_CONFIG/g' \
              | sed "s@${WKSPC_CLI_ENTRYPOINT_DIR}@${YDK_WKSPC_OPTS["agent/remote-path"]}@g" >&4
            return 0
            {
                echo "#!/bin/bash"
                echo "set -e -o pipefail"
                echo "YDK_AGENT_ENTRYPOINT="\${0}" && readonly YDK_AGENT_ENTRYPOINT"
                echo "YDK_AGENT_ENTRYPOINT_DIR=\$(dirname \"\${YDK_AGENT_ENTRYPOINT}\") && YDK_AGENT_ENTRYPOINT_DIR=\$(realpath \"\${YDK_AGENT_ENTRYPOINT_DIR}\") && readonly YDK_AGENT_ENTRYPOINT_DIR"
                echo "mkdir -p \"${YDK_WKSPC_OPTS["agent/remote-path"]}\""
                echo "cd '${YDK_WKSPC_OPTS["agent/remote-path"]}'"
                echo "declare -A YDK_AGENT_CONFIG=("
                echo "  [\"vault/client-id\"]=\"${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}\""
                echo "  [\"vault/client-secret\"]=\"${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}\""
                echo "  [\"vault/project-id\"]=\"${INFISICAL_PROJECT_ID}\""
                echo "  [\"vault/env\"]=\"prod\""
                echo "  [\"vault/paths\"]=\"${INFISICAL_DEFAULT_PATH}\""
                echo "  [\"agent/fifo\"]=\"/tmp/ydk.fifo\""
                echo "  [\"agent/uname\"]=\"\$(uname -n | cut -d'.' -f1)\""
                echo "  [\"agent/origin\"]=\"${YDK_WKSPC_OPTS["host/uname"]}\""
                echo ")"
                echo "[[ ! -p \"\${YDK_AGENT_CONFIG["agent/fifo"]}\" ]] && mkfifo \"\${YDK_AGENT_CONFIG["agent/fifo"]}\""
                echo "exec 4<>\"\${YDK_AGENT_CONFIG["agent/fifo"]}\""
                for DEPENDENCY in "${YDK_WKSPC_AGENT_DEPENDENCIES[@]}"; do
                    declare -f "${DEPENDENCY}"
                done
                echo "ydk:log() {"
                echo "    {"
                echo "      echo -en \"[${YELLOW}${YDK_BRAND}${NC}] 🩳 | ${YELLOW}\${YDK_AGENT_CONFIG[\"agent/uname\"]}${NC} \$ \""
                # echo "      echo -ne \$'\\t'"
                echo "      echo -n \"\${1}\""
                echo "      echo -ne \$'\\t'"
                echo "      echo -n \"\${2}\""
                echo "      echo -ne \$'\\t'"
                echo "      echo -n \"\${3}\""
                echo "      echo"
                echo "    } 1>&2"
                echo "    return 0"
                echo "}" 
                echo "ydk:teardown() {"
                echo "    local STATUS=\"\$?\""
                echo "    ydk:log info \"Cleaning up\""
                echo "    rm -f \"\${YDK_AGENT_ENTRYPOINT}\""
                echo "    rm -f \"\${YDK_AGENT_ENTRYPOINT}.log\""
                echo "    [[ -p \"\${YDK_AGENT_CONFIG["agent/fifo"]}\" ]] && exec 4>&- && rm -f \"\${YDK_AGENT_CONFIG["agent/fifo"]}\""
                echo "    if [[ \"\$STATUS\" -ne 0 ]]; then"
                echo "      ydk:log error \"(\$STATUS) Failed to execute command\""
                echo "    else"
                echo "      ydk:log success \"Executed successfully\""
                echo "    fi"
                echo "    exit \$STATUS"
                echo "}"
                echo "trap 'ydk:teardown \$?' EXIT"
                echo "ydk:log info \"Running agent on \${YDK_AGENT_CONFIG[\"agent/uname\"]}\""
                echo "[[ -f .env ]] && source .env # && printenv | sort"
                echo "[[ -z "\${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}" ]] && export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=\"\${YDK_AGENT_CONFIG["vault/client-id"]}\" && readonly INFISICAL_UNIVERSAL_AUTH_CLIENT_ID"
                echo "[[ -z "\${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}" ]] && export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=\"\${YDK_AGENT_CONFIG["vault/client-secret"]}\" && readonly INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET"
                echo "[[ -z "\${INFISICAL_PROJECT_ID}" ]] && export INFISICAL_PROJECT_ID=\"\${YDK_AGENT_CONFIG["vault/project-id"]}\" && readonly INFISICAL_PROJECT_ID"
                echo "export INFISICAL_DEFAULT_ENV=\"\${YDK_AGENT_CONFIG["vault/env"]}\" && readonly INFISICAL_DEFAULT_ENV"
                echo "export INFISICAL_DEFAULT_PATH=\"\${YDK_AGENT_CONFIG["vault/paths"]};/yellowteam/infra/\${YDK_AGENT_CONFIG["agent/uname"]}\" && readonly INFISICAL_DEFAULT_PATH"
                echo "ydk:log info \"\$(infisical --version)\""
                #
                echo "[[ -z \"\${YELLOW_AGENT_EXPECTED_HOSTS}\" ]] && ydk:log error \"Invalid expected hosts\" && exit 403"
                echo "IFS=' ' read -r -a YDK_AGENT_CONFIG_EXPECTED_ORIGINS <<< \"\${YELLOW_AGENT_EXPECTED_HOSTS}\""
                echo "if [[ ! \"\${YDK_AGENT_CONFIG_EXPECTED_ORIGINS[@]}\" =~ \"\${YDK_AGENT_CONFIG["agent/origin"]}\" ]]; then"
                echo "    ydk:log error \"Invalid origin \${YDK_AGENT_CONFIG[\"agent/origin\"]}\""
                echo "    exit 1"
                echo "fi"
                # echo "ls -lsa"
                # echo "cat .env"
                # echo "echo ''"
                # echo "source ./.env"
                # echo "echo \"INFISICAL_TOKEN= \$INFISICAL_TOKEN\""
                echo "ydk:log success \"Done. Showing secrets list\""
                echo "docker secret ls | while read -r LINE || [[ -n \"\${LINE}\" ]]; do"
                echo "    ydk:log debug \"\${LINE}\""
                echo "done"
                echo "docker config ls | while read -r LINE || [[ -n \"\${LINE}\" ]]; do"
                echo "    ydk:log debug \"\${LINE}\""
                echo "done"
                # echo "IFS=' ' read -r -a YDK_AGENT_DEPENDENCIES <<< \"${YDK_WKSPC_OPTS["agent/dependencies"]}\""
                # echo "for DEPENDENCY in \"\${YDK_AGENT_DEPENDENCIES[@]}\"; do"
                # echo "    declare -f \"\${DEPENDENCY}\""
                # echo "done"
                echo "exit 0"
                echo 
            } >&4
            return 0
        }
        ydk:try "$@" 4>&1
        return $? 
    }
    submodules(){
        local SUBMODULE_FILE="${WKSPC_CLI_ENTRYPOINT_DIR}/.gitmodules"
        if [[ ! -f "${SUBMODULE_FILE}" ]]; then
            ydk:log warn "Invalid submodules file ${SUBMODULE_FILE}. Try git submodule init."
            return 1
        fi
        list(){
            cat "${SUBMODULE_FILE}" >&4
            return 0        
        }
        unlink(){
            declare -A YDK_WKSPC_SUBMODULES=()
            while read -r LINE || [[ -n "${LINE}" ]]; do
                if [[ "${LINE}" =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
                    local SUBMODULE_PATH="${BASH_REMATCH[1]}"
                    local SUBMODULE_DIR="${WKSPC_CLI_ENTRYPOINT_DIR}/${SUBMODULE_PATH}"
                    if [[ -d "${SUBMODULE_DIR}" ]]; then
                        local SUBMODULE_CHANGES=$(git -C "${SUBMODULE_DIR}" status --porcelain)
                        if [[ -n "${SUBMODULE_CHANGES}" ]]; then
                            ydk:log warn "Uncommitted changes in submodule ${SUBMODULE_PATH}. ${YELLOW}${SUBMODULE_CHANGES//$'\n'/ }${NC}"
                            continue
                        fi
                        YDK_WKSPC_SUBMODULES["${SUBMODULE_DIR}"]=""
                    fi
                fi
                if [[ "${LINE}" =~ ^[[:space:]]*url[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
                    local SUBMODULE_URL="${BASH_REMATCH[1]}"
                    [[ -n "${SUBMODULE_DIR}" ]] &&  YDK_WKSPC_SUBMODULES["${SUBMODULE_DIR}"]="${SUBMODULE_URL}" && continue                    
                fi
            done < "${SUBMODULE_FILE}"
            for SUBMODULE_DIR in "${!YDK_WKSPC_SUBMODULES[@]}"; do
                local SUBMODULE_URL="${YDK_WKSPC_SUBMODULES["${SUBMODULE_DIR}"]}"
                [[ -z "${SUBMODULE_URL}" ]] && ydk:log warn "Invalid submodule url for path ${SUBMODULE_DIR}. Secure path is defined before url." && continue
                ydk:log info "Unlinking submodule ${SUBMODULE_DIR} => ${SUBMODULE_URL}"
                git submodule deinit -f "${SUBMODULE_DIR}"
                git rm -f "${SUBMODULE_DIR}"
                git commit -m "chore: Unlinking submodule ${SUBMODULE_DIR} from ${SUBMODULE_URL}"
                rm -rf "${SUBMODULE_DIR}"
            done
            return 0
        }
        ydk:try "$@" 4>&1
        return $? 
    }
    __workspace:agent(){
        ydk:log info "from remote server" # >&4
        [[ -z "$YDK_AGENT_CONFIG[*]" ]] && {
            ydk:log error "Invalid agent configuration"
            return 1
        }
        mkdir -p "${YDK_AGENT_CONFIG["agent/remote-path"]}" "${YDK_AGENT_CONFIG["deployments/directory"]}" 
        cd "${YDK_AGENT_CONFIG["agent/remote-path"]}"
        init(){           
            for CONFIG_KEY in "${!YDK_AGENT_CONFIG[@]}"; do
                local CONFIG_VALUE="${YDK_AGENT_CONFIG["${CONFIG_KEY}"]}"
                ydk:log debug "[${YELLOW}CONFIG${NC}] ${CONFIG_KEY}=${CONFIG_VALUE}"
            done 
            while read -r LINE || [[ -n "${LINE}" ]]; do
                KEYVALUE=($(dotenv kv "${LINE}" 4>&1))
                [[ -z "${KEYVALUE[*]}" ]] && continue
                [[ "${#KEYVALUE[@]}" -ne 2 ]] && continue
                local KEY="${KEYVALUE[0]}"
                local VALUE="${KEYVALUE[1]}"
                dotenv exports "${KEY}" "${VALUE}" "dotenv/workspace/${KEY^^}" "VAULT"
                # local VAR_NAME="${KEY//[^a-zA-Z0-9_]/}"
                # declare -gx "${VAR_NAME}"="${VALUE}"
                # declare -gx "YDK_CONFIG_${VAR_NAME}"="${VALUE}"
                # YDK_AGENT_CONFIG["dotenv/workspace/${KEY^^}"]="${VALUE}"
                # VALUE=$(base64 <<< "${VALUE}" | tr -d '\n')
                # local VALUE_LENGTH=${#VALUE}            
                # [[ "${VALUE_LENGTH}" -gt 10 ]] && VALUE_LENGTH=10
                # ydk:log debug "[${YELLOW}DOTENV${NC}] ${KEY} = ${VALUE:0:${VALUE_LENGTH}}..."
                # dotenv  exports "${KEY}" "${VALUE}" "${YDK_WKSPC_DOTENV_CONFIG_PATH}/${KEY^^}" "DOTENV"
            done < ".env"
            INFISICAL_DEFAULT_PATH="${INFISICAL_DEFAULT_PATH};/yellowteam/infra/${YDK_AGENT_CONFIG["agent/uname"]}"
            YDK_AGENT_CONFIG["dotenv/workspace/INFISICAL_DEFAULT_PATH"]="${INFISICAL_DEFAULT_PATH}"
            export INFISICAL_DEFAULT_ENV=prod
            YDK_AGENT_CONFIG["dotenv/workspace/INFISICAL_DEFAULT_ENV"]="${INFISICAL_DEFAULT_ENV}"
            ydk:log info "$(infisical --version)"            
            vault exports
            [[ -z "${YELLOW_AGENT_EXPECTED_HOSTS}" ]] && ydk:log error "Invalid expected hosts" && exit 403
            IFS=' ' read -r -a YDK_AGENT_CONFIG_EXPECTED_ORIGINS <<< "${YELLOW_AGENT_EXPECTED_HOSTS}"
            if [[ ! "${YDK_AGENT_CONFIG_EXPECTED_ORIGINS[@]}" =~ "${YDK_AGENT_CONFIG["host/uname"]}" ]]; then
                ydk:log error "Invalid origin ${YDK_AGENT_CONFIG["host/uname"]}"
                exit 1
            fi
            ydk:log success "Orgin ${YDK_AGENT_CONFIG["host/uname"]} is valid"

            printenv | grep "YDK" | sort | while read -r LINE || [[ -n "${LINE}" ]]; do
                KEYVALUE=($(dotenv kv "${LINE}" 4>&1))
                [[ -z "${KEYVALUE[*]}" ]] && continue
                [[ "${#KEYVALUE[@]}" -ne 2 ]] && continue
                local KEY="${KEYVALUE[0]}"
                local VALUE="${KEYVALUE[1]}"        
                VALUE=$(base64 <<< "${VALUE}" | tr -d '\n')
                local VALUE_LENGTH=${#VALUE}            
                [[ "${VALUE_LENGTH}" -gt 10 ]] && VALUE_LENGTH=10        
                ydk:log debug "[${YELLOW}ENV${NC}] ${KEY}=${VALUE:0:${VALUE_LENGTH}}..."
            done
            local DOCKER_WORKLOADS=(
                "secret" "config" "service" "stack" "network" "volume" "node" "service" "image" "container"
            )                       
            for WORKLOAD in "${DOCKER_WORKLOADS[@]}"; do
                local DOCKER_WORKLOADS_PRUNE=false
                local DOCKER_ARGS=()
                case "${WORKLOAD}" in
                network|volume|container)
                    DOCKER_WORKLOADS_PRUNE=true
                    ;;
                image)
                        DOCKER_WORKLOADS_PRUNE=true
                        DOCKER_ARGS+=("--all")
                        ;;
                *);;
                esac
                # [[ "${DOCKER_WORKLOADS_PRUNE}" == "true" ]] && docker prune -f "${WORKLOAD}"
                if [[ "${DOCKER_WORKLOADS_PRUNE}" == "true" ]]; then
                     docker "${WORKLOAD}" prune -f 2>&1 | while read -r LINE || [[ -n "${LINE}" ]]; do
                        ydk:log debug "[${GREEN}${WORKLOAD^^}${NC}] ${LINE}"
                    done
                fi
                docker "${WORKLOAD}" ls "${DOCKER_ARGS[@]}" | while read -r LINE || [[ -n "${LINE}" ]]; do
                    ydk:log debug "[${YELLOW}${WORKLOAD^^}${NC}] ${LINE}"
                done
            done            
            return 0
        }
        init 
        local STACK_ARGS=(
            "--detach=false" "--quiet"
            # "--compose-file" "${YDK_AGENT_CONFIG["deployments/directory"]}/stack/backstage/compose.yaml"
        )
        # while read -r FILE || [[ -n "${FILE}" ]]; do
        #     STACK_ARGS+=("--compose-file" "${FILE}")
        # done < <(
        #     find "${YDK_AGENT_CONFIG["deployments/directory"]}" \
        #         -type f -name "compose.yaml" \
        #         -not -path "${YDK_AGENT_CONFIG["deployments/directory"]}/compose.yaml"
        # )
        # STACK_ARGS+=("--compose-file" "${YDK_AGENT_CONFIG["deployments/directory"]}/compose.yaml")
        local TMP_COMPOSE=$(mktemp) && TMP_COMPOSE="$(basename "${TMP_COMPOSE}").yaml"
        TMP_COMPOSE="${YDK_AGENT_CONFIG["deployments/directory"]}/${TMP_COMPOSE}"
        STACK_ARGS+=("--compose-file" "${TMP_COMPOSE}")
        docker compose \
            -f "${YDK_AGENT_CONFIG["deployments/directory"]}/stack/backstage/compose.yaml" \
            config --no-normalize 4>&1 | tail -n +2 > "${TMP_COMPOSE}"

        cat "${TMP_COMPOSE}" | while read -r LINE || [[ -n "${LINE}" ]]; do
            ydk:log debug "[${YELLOW}COMPOSE${NC}] ${LINE}"
        done
        ydk:log debug "docker stack deploy ${STACK_ARGS[*]} test"
        docker stack deploy "${STACK_ARGS[@]}" test 2>&1 | while read -r LINE || [[ -n "${LINE}" ]]; do
            ydk:log debug "[${YELLOW}DOCKER${NC}] ${LINE}"
        done
        rm -f "${TMP_COMPOSE}"
        # source /develop/yellowteam/workspace/deployments/registry/cloudflared/entrypoint.sh
        # ydk:cloudflared whenDone
        # docker stack rm test
        return $?

        ydk:try "$@" 4>&1
        return $?
    }
    submodules unlink 4>&1
    return $?
    # agent entrypoint 4>&1
    # if ! agent copy; then
    #     ydk:throw $? "Failed to copy files"
    #     return 1
    # fi    
    # agent cli "$(agent entrypoint 4>&1)"
    # return $?

    # build images base
    # return $?

    ydk:try "$@" 4>&1
    return $? 
}

source ./sdk/shell/packages/ydk/ydk.cli.sh "$@" 4>&1