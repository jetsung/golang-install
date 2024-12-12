#!/usr/bin/env bash

# Golang Version Manager
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://framagit.org/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

# set -e
set -u
set -o pipefail

exec 3>&1

script_name=$(basename "$0")

if [ -t 1 ] && command -v tput >/dev/null; then
    ncolors=$(tput colors || echo 0)
    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        bold="$(tput bold || echo)"
        normal="$(tput sgr0 || echo)"
        black="$(tput setaf 0 || echo)"
        red="$(tput setaf 1 || echo)"
        green="$(tput setaf 2 || echo)"
        yellow="$(tput setaf 3 || echo)"
        blue="$(tput setaf 4 || echo)"
        magenta="$(tput setaf 5 || echo)"
        cyan="$(tput setaf 6 || echo)"
        white="$(tput setaf 7 || echo)"
    fi
fi

say_warning() {
    # shellcheck disable=SC2317
    printf "%b\n" "${yellow:-}${script_name}: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}${script_name}: Error: $1${normal:-}" >&2
    exit 1
}

say() {
    printf "%b\n" "${cyan:-}${script_name}:${normal:-} $1" >&3
}

# try profile
try_profile() {
    if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
        return 1
    fi
    sh_echo "${1}"
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

# fix macos
sedi() {
    if [ "${OS}" = "darwin" ]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

# check in china
check_in_china() {
    if ! curl -s -m 3 -IL https://google.com | grep -q "HTTP/2 200"; then
        IN_CHINA=1
    fi
}

# Get OS version
init_os() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    case "${OS}" in
    darwin) OS='darwin' ;;
    linux) OS='linux' ;;
    freebsd) OS='freebsd' ;;
        #        mingw*) OS='windows';;
        #        msys*) OS='windows';;
    *)
        say_err "OS $OS is not supported by this installation script\n"
        ;;
    esac
}

# install curl command
install_curl_command() {
    if ! test -x "$(command -v curl)"; then
        if test -x "$(command -v yum)"; then
            yum install -y curl
        elif test -x "$(command -v apt)"; then
            apt install -y curl
        else
            say_err "You must pre-install the curl tool\n"
        fi
    fi
}

# set gvm environment
set_environment() {
    tee "$GVM_ENV_PATH" >/dev/null 2>&1 <<-EOF
#!/usr/bin/env bash

export GVMPATH="\$HOME/.gvm"
export PATH="\$PATH:\$GVMPATH/bin"

__MY_PATHS=""
# Remove duplicate paths and remove go is not gvm version
# export PATH=\$(echo \$PATH | sed 's/:/\n/g' | sort | uniq | tr -s '\n' ':' | sed 's/:\$//g')
while IFS=\$'\n' read -r -d ' ' _V; do
  if command -v "\${_V}/go" >/dev/null 2>&1 && [[ -f "\${_V}/go" ]]; then
    [[ "\${_V}" == "\${GVMPATH}/go/bin" ]] || continue
  fi
  __MY_PATHS="\${__MY_PATHS}:\${_V}"
done < <(echo "\${PATH}" | sed 's/:/\n/g' | sort | uniq | tr -s '\n' ' ')

[[ -z "\${__MY_PATHS}" ]] || export PATH="\${__MY_PATHS#*:}"
EOF

    if ! grep -q "\$HOME/.gvm/env" "${PROFILE}"; then
        printf "\n## GVM\n" >>"${PROFILE}"
        echo ". \"\$HOME/.gvm/env\"" >>"$PROFILE"
    else
        sedi "s@^. \"\$HOME/.gvm/.*@. \"\$HOME/.gvm/env\"@" "$PROFILE"
    fi

    # Remove duplicate paths
    # export PATH=$(echo $PATH | sed 's/:/\n/g' | sort | uniq | tr -s '\n' ':' | sed 's/:$//g')
}

# Action
do_something() {
    REMOTE_GO_LIST=()
    GO_VERSION_LIST=()

    case "$COMMAND" in
    -h | --help | "")
        show_help_message
        ;;

    -i | --install)
        install_script
        ;;

    -u | --update)
        update_script
        ;;

    -v | --version)
        printf "gvm version: %s\n" "${GVM_VERSION}"
        exit
        ;;

    current)
        if ! command -v go >/dev/null 2>&1; then
            say_err "Go is not installed\n"
        else
            go version
            exit
        fi
        ;;

    install)
        if [ -z "$OPTIONS" ]; then
            say_err "Missing go version argument. \n      Example: $script_name install [VERSION]\n"
        fi

        if [ "${OPTIONS}" = "latest" ]; then
            OPTIONS=$(show_remote_list | sort -rV | head -n 1)
        fi

        GO_VERSION="${OPTIONS#go}"
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
        if [ -z "${OPTIONS}" ]; then
            say_err "Missing go version argument. \n      Example: $script_name uninstall [VERSION]\n"
        fi
        GO_VERSION="${OPTIONS#go}"
        uninstall_go
        exit
        ;;

    use)
        if [ -z "${OPTIONS}" ]; then
            say_err "Missing go version argument. \n      Example: $script_name use [VERSION]\n"
        fi

        if [ "${OPTIONS}" = "latest" ]; then
            OPTIONS=$(show_remote_list | sort -rV | head -n 1)
        fi

        GO_VERSION="${OPTIONS#go}"
        use_go
        exit
        ;;

    *)
        say_err "Unknown argument: $COMMAND\n"
        ;;

    esac
}

# update gvm.sh
gvm_script() {
    [ -d "$GVM_BIN_PATH" ] || mkdir -p "$GVM_BIN_PATH"

    CURRENT_GVM_PATH="$(pwd)/gvm"
    local GVM_SCRIPT_PATH="${GVM_BIN_PATH}/gvm"

    # locally update
    if [ -f "${CURRENT_GVM_PATH}.sh" ]; then
        cp "${CURRENT_GVM_PATH}.sh" "$GVM_SCRIPT_PATH"
    else # git update
        check_in_china
        [ -z "${IN_CHINA}" ] || PRO_URL="$PRO_CN_URL"
        curl -sSL -m 5 -o "$GVM_SCRIPT_PATH" "${PRO_URL}/gvm.sh"
    fi

    if [ ! -f "${GVM_SCRIPT_PATH}" ]; then
        say_err "GVM(gvm.sh) download failed\n"
    fi
    chmod +x "$GVM_SCRIPT_PATH"
}

# download go install.sh
dl_goinstall_script() {
    # force update
    [ -z "${1}" ] || rm -rf "$GO_INSTALL_SCRIPT"

    if [ ! -f "$GO_INSTALL_SCRIPT" ]; then
        # locally update
        if [ -f "./install.sh" ]; then
            cp -f "./install.sh" "$GO_INSTALL_SCRIPT"
        else # git update
            check_in_china
            [ -z "$IN_CHINA" ] || PRO_URL="$PRO_CN_URL"
            curl -sSL -m 5 -o "$GO_INSTALL_SCRIPT" "$PRO_URL/install.sh"
        fi
    fi

    if [ ! -f "${GO_INSTALL_SCRIPT}" ]; then
        say_err "GVM go-install.sh download failed\n"
    fi
    chmod +x "$GO_INSTALL_SCRIPT"
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
            
    \e[1;32m-u, --update\e[m
                Update Golang Version Manager

    \e[1;32m-v, --version\e[m
                Print Gvm version information

\e[1;33mSUBCOMMANDS:\e[m
  \e[1;32mcurrent\e[m                    Print the current go version
  \e[1;32minstall\e[m [VERSION|latest]   Install a new go version  
  \e[1;32mlist\e[m                       List all locally installed go versions
  \e[1;32mlist-remote\e[m <more>         List all remote go versions
  \e[1;32muninstall\e[m                  Uninstall a Go version                
  \e[1;32muse\e[m [VERSION|latest]       Change Go version
\n" "$GVM_VERSION" "${script_name##*/}"
    exit 1
}

# gvm script install
install_script() {
    gvm_script
    dl_goinstall_script ""

    say "GVM successfully installed\n"

    if ! command -v gvm >/dev/null; then
        printf "You need to execute: \n\e[1;33msource %s\e[m\n" "$PROFILE"
    fi
    exit
}

# gvm script upgrade
update_script() {
    gvm_script
    dl_goinstall_script "update"

    say "GVM successfully updated\n"
    exit
}

# Get a list of locally installed Go versions.
go_list_locale() {
    if ! find "$GO_VERSIONS_PATH"/go*/bin/go -maxdepth 3 -type f -print0 >/dev/null 2>&1; then
        if [ -z "${1}" ]; then
            say_err "No go version list found\n"
        fi
        return
    fi

    # GO_VERSION_LIST=$(find "${GO_VERSIONS_PATH}" -maxdepth 1 -name "go*" -type d | cut -d '/' -f 6 | sed 's/..//')
    while IFS= read -r -d '' _V; do
        GO_VERSION_LIST[${#GO_VERSION_LIST[@]}]=$(${_V} version | awk '{print $3}' | sed 's/..//')
    done < <(find "${GO_VERSIONS_PATH}"/go*/bin/go -maxdepth 3 -type f -print0)
}

# Obtain a list of versions from the Go official website.
go_list_remote() {
    check_in_china
    local GO_DL_URL="https://go.dev/dl/"
    [ -z "$IN_CHINA" ] || GO_DL_URL="https://golang.google.cn/dl/"

    RELEASE_TAGS="$(curl -sL --retry 5 --max-time 10 "$GO_DL_URL" | sed -n '/toggle/p' | cut -d '"' -f 4 | grep go)"

    while IFS=$'\n' read -r -d ' ' _V; do
        REMOTE_GO_LIST[${#REMOTE_GO_LIST[@]}]="$_V"
    done < <(echo "$RELEASE_TAGS" | tr -s '\n' ' ')
}

# Install Go
install_go() {
    go_list_locale "install"
    for _V in "${GO_VERSION_LIST[@]:-}"; do
        if [ "$_V" = "$GO_VERSION" ]; then
            say_err "Go $GO_VERSION already exists\n"
        fi
    done

    go_list_remote
    local REMOTE_HAS_VERSION=""
    for _V in "${REMOTE_GO_LIST[@]:-}"; do
        if [[ "$_V" = "go${GO_VERSION}" ]]; then
            REMOTE_HAS_VERSION=1
            break
        fi
    done

    if [ -z "$REMOTE_HAS_VERSION" ]; then
        say_err "There is no such version(go${GO_VERSION})\n"
    fi

    printf "\e[1;33mInstalling go %s\e[m\n" "${GO_VERSION}"

    PARAMS="--version ${GO_VERSION} --root ${GO_VERSIONS_PATH}/go${GO_VERSION}"
    # echo "${GO_INSTALL_SCRIPT} ${PARAMS}"

    # shellcheck disable=SC2086
    ${SHELL} ${GO_INSTALL_SCRIPT} ${PARAMS} >"$HOME/.gvm.log" 2>&1
    # shellcheck disable=SC1090,SC2086
    CURRENT_GO_BINARY="${GO_VERSIONS_PATH}/go${GO_VERSION}/bin/go"

    if [ -f "$CURRENT_GO_BINARY" ]; then
        ${CURRENT_GO_BINARY} version
    else
        say_err "Go $GO_VERSION installation failed\n"
    fi
}

# List all locally installed go versions
show_list() {
    go_list_locale ""

    for _V in "${GO_VERSION_LIST[@]:-}"; do
        printf "go%s\n" "$_V"
    done
}

# List all remote go versions
show_remote_list() {
    go_list_remote

    local SHOW_ALL=""
    if [[ "$OPTIONS" = "more" ]]; then
        SHOW_ALL="more"
    fi

    local __INDEX=1
    for _V in "${REMOTE_GO_LIST[@]:-}"; do
        if [ $__INDEX -ge 10 ] && [ -z "$SHOW_ALL" ]; then
            break
        fi

        printf "%s\n" "${_V}"
        ((__INDEX++))
    done
}

# Remove custom go version from locally
uninstall_go() {
    if [[ $(go version | awk '{print $3}') = "go${GO_VERSION}" ]]; then
        say_err "The current version(go${GO_VERSION}) is in use\n"
    fi

    if [ -d "${GO_VERSIONS_PATH}/go${GO_VERSION}" ]; then
        rm -rf "${GO_VERSIONS_PATH}/go${GO_VERSION}"
        say "go${GO_VERSION} uninstalled successfully\n"
    fi
}

# Use custom go version
use_go() {
    CURRENT_GO_BINARY="${GO_VERSIONS_PATH}/go${GO_VERSION}/bin/go"
    if [ ! -f "$CURRENT_GO_BINARY" ]; then
        install_go
    else
        $CURRENT_GO_BINARY version
    fi

    if [ -f "$CURRENT_GO_BINARY" ]; then
        rm -rf "$GVM_GO_ROOT"
        ln -s "${GO_VERSIONS_PATH}/go${GO_VERSION}" "$GVM_GO_ROOT"

        # use $HOME instead of /home/{USER}/
        __GVM_GO_ROOT=${GVM_GO_ROOT/"$HOME"/\$HOME}
        sedi "s@^export GOROOT.*@export GOROOT=\"$__GVM_GO_ROOT\"@" "$PROFILE"

        # sedi "s@^export GOROOT.*@export GOROOT=\"${GO_VERSIONS_PATH}/go${GO_VERSION}\"@" "${PROFILE}"
        if ! command -v go >/dev/null 2>&1 || [[ $(go version | awk '{print $3}') != "go${GO_VERSION}" ]]; then
            printf "\nYou need to execute: \n\e[1;33msource %s\e[m\n" "$PROFILE"
        fi
    fi
}

GVM_VERSION="1.0.8"

GVM_PATH="$HOME/.gvm"
GVM_BIN_PATH="$GVM_PATH/bin"
GVM_ENV_PATH="$GVM_PATH/env"
GVM_GO_ROOT="$GVM_PATH/go"

GO_INSTALL_SCRIPT="$GVM_PATH/install.sh"
GO_VERSIONS_PATH="$GVM_PATH/packages"

PRO_URL="https://raw.githubusercontent.com/jetsung/golang-install/main/"
PRO_CN_URL="https://framagit.org/jetsung/golang-install/-/raw/main/"

PROFILE=""
PROFILE="$(detect_profile)"

IN_CHINA=""

[ -d "$GO_VERSIONS_PATH}" ] || mkdir -p "$GO_VERSIONS_PATH"

COMMAND=""
OPTIONS=""
EXT_ARGS=()

__INDEX=1
for ARG in "$@"; do
    case $__INDEX in
    1)
        COMMAND="$ARG"
        ;;

    2)
        OPTIONS="$ARG"
        ;;

    *)
        EXT_ARGS[${#EXT_ARGS[@]}]="$ARG"
        ;;
    esac

    ((__INDEX++))
done

init_os

install_curl_command

set_environment

do_something
