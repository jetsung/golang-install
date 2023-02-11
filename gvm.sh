#!/usr/bin/env bash

# Golang Version Manager
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://jihulab.com/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

load_vars() {
    GVM_VERSION="1.0.2"

    GVM_PATH="${HOME}/.gvm"
    GVM_BIN_PATH="${GVM_PATH}/bin"
    GVM_ENV_PATH="${GVM_PATH}/env"
    GVM_GO_ROOT="${GVM_PATH}/go"

    GO_INSTALL_SCRIPT="${GVM_PATH}/install.sh"
    GO_VERSIONS_PATH="${GVM_PATH}/verions"

    PRO_URL="https://raw.githubusercontent.com/jetsung/golang-install/main/"
    PRO_CN_URL="https://jihulab.com/jetsung/golang-install/-/raw/main/"

    PROFILE="$(detect_profile)"

    [[ -d "${GO_VERSIONS_PATH}" ]] || mkdir -p "${GO_VERSIONS_PATH}"
}

# sh echo
sh_echo() {
    command printf %s\\n "$*" 2>/dev/null
}

# Get PROFILE
detect_profile() {
    if [ "${PROFILE-}" = '/dev/null' ]; then
        # the user has specifically requested NOT to have nvm touch their profile
        return
    fi

    if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
        sh_echo "${PROFILE}"
        return
    fi

    local DETECTED_PROFILE
    DETECTED_PROFILE=''

    if [ "${SHELL#*bash}" != "$SHELL" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        fi
    elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
        if [ -f "$HOME/.zshrc" ]; then
            DETECTED_PROFILE="$HOME/.zshrc"
        fi
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
        for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"; do
            if DETECTED_PROFILE="$(try_profile "${HOME}/${EACH_PROFILE}")"; then
                break
            fi
        done
    fi

    if [ -n "$DETECTED_PROFILE" ]; then
        sh_echo "$DETECTED_PROFILE"
    fi
}

init_os() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    case "${OS}" in
    darwin) OS='darwin' ;;
    linux) OS='linux' ;;
    freebsd) OS='freebsd' ;;
    *)
        printf "\e[1;31mOS %s is not supported by this installation script\e[0m\n" "${OS}"
        exit 1
        ;;
    esac
}

sedi() {
    if [ "${OS}" = "darwin" ]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

check_in_china() {
    urlstatus=$(curl -s -m 3 -IL https://google.com | grep 200)
    if [[ -z "${urlstatus}" ]]; then
        IN_CHINA=1
    fi
}

init_vars() {
    local INDEX=0
    for ARG in "$@"; do
        ((INDEX++))
        case "${INDEX}" in
        1)
            COMMAND="${ARG}"
            ;;
        2)
            OPTIONS="${ARG}"
            ;;
        *)
            EXT_ARGS[${#EXT_ARGS[@]}]="${ARG}"
            ;;

        esac
    done
}

set_environment() {
    tee "${GVM_ENV_PATH}" >/dev/null 2>&1 <<-EOF
export GVMPATH="\$HOME/.gvm"
export PATH="\$PATH:\$GVMPATH/bin"
EOF

    if ! grep -q "\$HOME/.gvm/env" "${PROFILE}"; then
        printf "\n## GVM\n" >>"${PROFILE}"
        echo ". \"\$HOME/.gvm/env\"" >>"${PROFILE}"
    else
        sedi "s@^. \"\$HOME/.gvm/.*@. \"\$HOME/.gvm/env\"@" "${PROFILE}"
    fi
}

do_something() {
    case "${COMMAND}" in
    -h | --help)
        show_help_message
        ;;

    -i | --install)
        install_script
        ;;

    -u | --upgrade)
        upgrade_script
        ;;

    -v | --version)
        printf "gvm version: %s\n" "${GVM_VERSION}"
        exit
        ;;

    current)
        go version
        exit
        ;;

    install)
        if [[ -z "${OPTIONS}" ]]; then
            printf "miss go version\n"
            exit
        fi
        GO_VERSION="${OPTIONS}"
        install_go
        exit
        ;;

    list)
        show_list
        exit
        ;;

    list-remote)
        show_remote_list
        exit
        ;;

    uninstall)
        if [[ -z "${OPTIONS}" ]]; then
            printf "miss go version\n"
            exit
        fi
        GO_VERSION="${OPTIONS}"
        uninstall_go
        exit
        ;;

    use)
        if [[ -z "${OPTIONS}" ]]; then
            printf "miss go version\n"
            exit
        fi
        GO_VERSION="${OPTIONS}"
        use_go
        exit
        ;;
    esac
}

# show help message
show_help_message() {
    printf "\e[1;32mgvm\e[m %s
Golang Version Manager

\e[1;33mUSAGE:\e[m
    %s [OPTIONS] <SUBCOMMANDS>

\e[1;33mOPTIONS:\e[m
    \e[1;32m-h, --help\e[m
                Print help information
            
    \e[1;32m-i, --install\e[m
                Install Golang Version Manager
            
    \e[1;32m-u, --upgrade\e[m
                Upgrade Golang Version Manager

    \e[1;32m-v, --version\e[m
                Print Gvm version information

\e[1;33mSUBCOMMANDS:\e[m
  \e[1;32mcurrent\e[m       Print the current go version
  \e[1;32minstall\e[m       Install a new go version  
  \e[1;32mlist\e[m          List all locally installed go versions
  \e[1;32mlist-remote\e[m   List all remote go versions <more>
  \e[1;32muninstall\e[m     Uninstall a Go version                
  \e[1;32muse\e[m           Change Go version
\n" "${GVM_VERSION}" "${SCRIPT_NAME##*/}"
    exit 1
}

dl_goinstall_script() {
    [[ -z "${1}" ]] || rm -rf "${GO_INSTALL_SCRIPT}"

    if [[ ! -f "${GO_INSTALL_SCRIPT}" ]]; then
        if [[ -f "./install.sh" ]]; then
            cp -f "./install.sh" "${GO_INSTALL_SCRIPT}"
        else
            check_in_china
            [[ -z "${IN_CHINA}" ]] || PRO_URL="${PRO_CN_URL}"
            wget -q -O "${GO_INSTALL_SCRIPT}" "${PRO_URL}/install.sh"
        fi
    fi
    if [[ ! -f "${GO_INSTALL_SCRIPT}" ]]; then
        printf "\e[1;31mGVM go-install.sh download failed\e[m\n"
        exit
    fi
    chmod +x "${GO_INSTALL_SCRIPT}"
}

gvm_script() {
    [[ -d "${GVM_BIN_PATH}" ]] || mkdir -p "${GVM_BIN_PATH}"

    CURRENT_GVM_PATH="$(pwd)/gvm.sh"
    local GVM_SCRIPT_PATH="${GVM_BIN_PATH}/gvm.sh"
    if [[ -f "${CURRENT_GVM_PATH}" ]]; then
        if [[ "${GVM_SCRIPT_PATH}" == "${SCRIPT_NAME}" ]] ||
            [[ "${GVM_SCRIPT_PATH}" == "$(pwd)/gvm.sh" ]]; then
            printf "\e[1;31mTarget gvm.sh(%s) is the same file\e[m\n" "${SCRIPT_NAME}"
            exit
        fi
        cp "${CURRENT_GVM_PATH}" "${GVM_BIN_PATH}"
    else
        check_in_china
        [[ -z "${IN_CHINA}" ]] || PRO_URL="${PRO_CN_URL}"
        wget -q -O "${GVM_SCRIPT_PATH}" "${PRO_URL}/gvm.sh"
    fi

    if [[ ! -f "${GVM_SCRIPT_PATH}" ]]; then
        printf "\e[1;31mGVM(gvm.sh) download failed\e[m\n"
    fi
    chmod +x "${GVM_SCRIPT_PATH}"
}

install_script() {
    gvm_script
    dl_goinstall_script ""

    printf "GVM successfully installed\n"
    exit
}

upgrade_script() {
    gvm_script
    dl_goinstall_script "upgrade"

    printf "GVM successfully updated\n"
    exit
}

go_list() {
    # GO_VERSION_LIST=$(find "${GO_VERSIONS_PATH}" -maxdepth 1 -name "go*" -type d | cut -d '/' -f 6 | sed 's/..//')
    while IFS= read -r -d '' _V; do
        GO_VERSION_LIST[${#GO_VERSION_LIST[@]}]=$(${_V} version | awk '{print $3}' | sed 's/..//')
    done < <(find "${GO_VERSIONS_PATH}"/go*/bin/go -maxdepth 3 -type f -print0)
}

go_list_remote() {
    check_in_china
    local GO_DL_URL="https://go.dev/dl/"
    [[ -z "${IN_CHINA}" ]] || GO_DL_URL="https://golang.google.cn/dl/"

    RELEASE_TAGS="$(curl -sL --retry 5 "${GO_DL_URL}" | sed -n '/toggle/p' | cut -d '"' -f 4 | grep go)"

    while IFS=$'\n' read -r -d ' ' _V; do
        REMOTE_GO_LIST[${#REMOTE_GO_LIST[@]}]="${_V}"
    done < <(echo "${RELEASE_TAGS}" | tr -s '\n' ' ')
}

show_list() {
    go_list

    for _V in "${GO_VERSION_LIST[@]}"; do
        printf "go%s\n" "${_V}"
    done
}

show_remote_list() {
    go_list_remote

    if [[ "${OPTIONS}" == "more" ]]; then
        SHOW_ALL="more"
    fi

    local INDEX=0
    for _V in "${REMOTE_GO_LIST[@]}"; do
        ((INDEX++))

        if [[ ${INDEX} -gt 10 ]] && [[ -z "${SHOW_ALL}" ]]; then
            break
        fi

        printf "%s\n" "${_V}"
    done
}

use_go() {
    CURRENT_GO_BINARY="${GO_VERSIONS_PATH}/go${GO_VERSION}/bin/go"
    if [[ ! -f "${CURRENT_GO_BINARY}" ]]; then
        install_go
    else
        ${CURRENT_GO_BINARY} version
    fi

    if [[ -f "${CURRENT_GO_BINARY}" ]]; then
        rm -rf "${GVM_GO_ROOT}"
        ln -s "${GO_VERSIONS_PATH}/go${GO_VERSION}" "${GVM_GO_ROOT}"
        sedi "s@^export GOROOT.*@export GOROOT=\"${GVM_GO_ROOT}\"@" "${PROFILE}"

        # sedi "s@^export GOROOT.*@export GOROOT=\"${GO_VERSIONS_PATH}/go${GO_VERSION}\"@" "${PROFILE}"
        if [[ $(go version | awk '{print $3}') != "go${GO_VERSION}" ]]; then
            printf "\nYou need to execute: \n\e[1;33msource %s\e[m\n" "${PROFILE}"
        fi
    fi
}

uninstall_go() {
    if [[ $(go version | awk '{print $3}') == "go${GO_VERSION}" ]]; then
        printf "\e[1;31mThe current version(go%s) is in use\e[m\n" "${GO_VERSION}"
        exit
    fi

    if [[ -d "${GO_VERSIONS_PATH}/go${GO_VERSION}" ]]; then
        rm -rf "${GO_VERSIONS_PATH}/go${GO_VERSION}"
        printf "go%s uninstalled successfully\n" "${GO_VERSION}"
    fi
}

install_go() {
    go_list
    for _V in "${GO_VERSION_LIST[@]}"; do
        if [[ "${_V}" == "${GO_VERSION}" ]]; then
            printf "\e[1;31mGo %s already exists\e[m\n" "${GO_VERSION}"
            exit
        fi
    done

    go_list_remote
    for _V in "${REMOTE_GO_LIST[@]}"; do
        if [[ "${_V}" == "go${GO_VERSION}" ]]; then
            REMOTE_HAS_VERSION=1
            break
        fi
    done

    if [[ -z "${REMOTE_HAS_VERSION}" ]]; then
        printf "\e[1;31mThere is no such version(go%s)\e[m\n" "${GO_VERSION}"
        exit
    fi

    printf "\e[1;33mInstalling go %s\e[m\n" "${GO_VERSION}"

    PARAMS="-v ${GO_VERSION} -c ${GO_VERSIONS_PATH}/go${GO_VERSION}"
    # echo "${GO_INSTALL_SCRIPT} ${PARAMS}"

    # shellcheck disable=SC2086
    ${SHELL} ${GO_INSTALL_SCRIPT} ${PARAMS} >"${HOME}/.gvm.log" 2>&1
    # shellcheck disable=SC1090,SC2086
    CURRENT_GO_BINARY="${GO_VERSIONS_PATH}/go${GO_VERSION}/bin/go"
    OLD_GOROOT="${GOROOT}"
    if [[ -f "${CURRENT_GO_BINARY}" ]]; then
        ${CURRENT_GO_BINARY} version
    else
        printf "\e[1;31mGo %s installation failed\e[m\n" "${GO_VERSION}"
    fi
    sedi "s@^export GOROOT.*@export GOROOT=\"${OLD_GOROOT}\"@" "${PROFILE}"
}

main() {
    SCRIPT_NAME="$0"
    init_os
    load_vars
    init_vars "$@"

    set_environment

    do_something
}

main "$@" || exit 1
