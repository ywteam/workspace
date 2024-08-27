#!/bin/bash
# shellcheck disable=SC2044,SC2155,SC2317
{

    declare -A CONFIG=(
        ["entrypoint"]="${0}"
        ["pwd"]=$(realpath "$(dirname "${0}")")
        ["submodules"]="dotnet go node python shell"
    )
    CONFIG["submodules.path"]="${CONFIG["pwd"]}/projects/ydk/src"
}
debug:config() {
    for CONFIG_KEY in "${!CONFIG[@]}"; do
        echo "WKSPC_CLI_CONFIG_${CONFIG_KEY}=${CONFIG[${CONFIG_KEY}]}"
        # export "WKSPC_CLI_CONFIG_${CONFIG_KEY}"="${CONFIG[${CONFIG_KEY}]}"
    done
}
git:submodules:remove() {
    local SUBMODULE_PATH="${1}"
    ! test -d "${SUBMODULE_PATH}" && echo "Submodule ${SUBMODULE_PATH} does not exist" && return 1
    echo "Removing submodule ${SUBMODULE_PATH} ${SUBMODULE_REPO}"
    ! git submodule deinit "${SUBMODULE_PATH}" && echo "Failed to deinit submodule ${SUBMODULE_PATH}" && return 1
    ! git rm -rf --cached "${SUBMODULE_PATH}" && echo "Failed to remove submodule ${SUBMODULE_PATH}" && return 1
    ! rm -rf .git/modules/"${SUBMODULE_PATH}" && echo "Failed to remove submodule ${SUBMODULE_PATH} from .git/modules" && return 1
    ! rm -rf "${SUBMODULE_PATH}" && echo "Failed to remove submodule ${SUBMODULE_PATH}" && return 1
    SUBMODULE_PATH="projects/ydk/src/${SUBMODULE_PATH#"${CONFIG["submodules.path"]}/"}"
    ! git config -f .gitmodules --remove-section "submodule.${SUBMODULE_PATH}" && echo "Failed to remove submodule ${SUBMODULE_PATH} from .gitmodules" && return 1
    ! git config --local --remove-section "submodule.${SUBMODULE_PATH}" 2>/dev/null && echo "Failed to remove submodule ${SUBMODULE_PATH} from .git/config" && return 1
}

git:submodules:remove-all() {
    read -r -a SUBMODULES <<<"${CONFIG["submodules"]}"
    for SUBMODULE in "${SUBMODULES[@]}"; do
        ! git:submodules:remove "${CONFIG["submodules.path"]}/${SUBMODULE}" && echo -e "\tFailed to remove submodule ${SUBMODULE}" && continue
    done
}

# debug:config
# git:submodules:remove-all
if [ -d "./.git/modules/projects/ydk" ]; then
    rm -rf ./.git/modules/projects/ydk
fi
if [ -d "./projects/ydk" ]; then
    rm -rf ./projects/ydk
fi

# Reinitialize the submodule
git submodule update --init --recursive --force
git submodule add https://github.com/ywteam/ydk ./projects/ydk