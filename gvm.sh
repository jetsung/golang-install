#!/usr/bin/env bash

# Golang Version Manager
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://framagit.org/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

exec 3>&1

script_name=$(basename "$0")
script_dir_name="${script_name##*/}"

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
    printf "%b\n" "${yellow:-}$script_name: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}$script_name: Error: $1${normal:-}" >&2
    exit 1
}

say() {
    printf "%b\n" "${cyan:-}$script_name:${normal:-} $1" >&3
}

# try profile
try_profile() {
    if [ -z "${1:-}" ] || [ ! -f "$1" ]; then
        return 1
    fi
    sh_echo "$1"
}

# sh echo
sh_echo() {
    command printf %s\\n "$*" 2>/dev/null
}

# Get PROFILE
detect_profile() {
    local DETECTED_PROFILE=""

    if [ -z "${SHELL:-}" ]; then
        SHELL="$(grep "^$(whoami):" /etc/passwd | cut -d: -f7)"
    fi

    BASENAME_SHELL=$(basename "$SHELL")
    case "$BASENAME_SHELL" in
        'sh')
            DETECTED_PROFILE="$HOME/.profile"
        ;;
        'zsh')
            DETECTED_PROFILE="$HOME/.zshrc"
        ;;
        'bash')
            DETECTED_PROFILE="$HOME/.bashrc"
        ;;
        'fish')
            DETECTED_PROFILE="$HOME/.config/fish/config.fish"
        ;;
        *)
            return
        ;;
    esac

    if [ ! -f "$DETECTED_PROFILE" ]; then
        touch "$DETECTED_PROFILE"
    fi   
    
    if [ -f "$DETECTED_PROFILE" ]; then
        sh_echo "$DETECTED_PROFILE"
    fi 
}

# fix macos
sedi() {
    if [ "$OS" = "darwin" ]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

# check in china
check_in_china() {
    if [[ -n "${CN:-}" ]]; then
        return 0 # 手动指定
    fi
    if [[ "$(curl -s -m 3 -o /dev/null -w "%{http_code}" https://www.google.com)" == "000" ]]; then
        return 0 # 中国网络
    fi
    return 1 # 非中国网络
}

# Get OS version
init_os() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    case "$OS" in
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
    # shellcheck disable=SC2016
    if ! grep -q '$HOME/.gvm/env' "$PROFILE"; then
        {
            printf '\n## GVM\n. "$HOME/.gvm/env"\n' 
        } >>"$PROFILE"
    else
        sedi 's@^. "$HOME/.gvm/.*@. "$HOME/.gvm/env"@' "$PROFILE"
    fi

    cat > "$GVM_ENV_PATH" <<-'EOF'
#!/usr/bin/env sh

export GVMPATH="$HOME/.gvm"

case ":${PATH}:" in
    *:"$GVMPATH/bin":*) ;;
    *) export PATH="$GVMPATH/bin:$PATH" ;;
esac

## GOLANG
export GOROOT="$HOME/.gvm/go"
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export GOPROXY="https://goproxy.cn,https://goproxy.io,direct"
export PATH="$PATH:$GOROOT/bin:$GOBIN"  
EOF

    if [ -z "$IN_CHINA" ]; then
        sedi '/GOPROXY/d' "$GVM_ENV_PATH"
    fi

    # shellcheck disable=SC2016
    sedi '/## GOLANG/,/export PATH="$PATH:$GOROOT"/d' "$PROFILE"
}

# update gvm.sh
gvm_script() {
    [ -d "$GVM_BIN_PATH" ] || mkdir -p "$GVM_BIN_PATH"

    CURRENT_GVM_PATH="$(pwd)/gvm"
    local GVM_SCRIPT_PATH="$GVM_BIN_PATH/gvm"

    # locally update
    if [ -f "$CURRENT_GVM_PATH.sh" ]; then
        cp "$CURRENT_GVM_PATH.sh" "$GVM_SCRIPT_PATH"
    else # git update
        if [ -n "$IN_CHINA" ]; then 
            PRO_URL="$PRO_CN_URL"
        fi
        curl -sSL -m 5 -o "$GVM_SCRIPT_PATH" "$PRO_URL/gvm.sh"
    fi

    if [ ! -f "$GVM_SCRIPT_PATH" ]; then
        say_err "GVM(gvm.sh) download failed\n"
    fi
    chmod +x "$GVM_SCRIPT_PATH"
}

# download go install.sh
dl_goinstall_script() {
    # force update
    if [ -n "${1:-}" ]; then
        rm -rf "$GO_INSTALL_SCRIPT"
    fi

    if [ ! -f "$GO_INSTALL_SCRIPT" ]; then
        # locally update
        if [ -f "./install.sh" ]; then
            cp -f "./install.sh" "$GO_INSTALL_SCRIPT"
        else # git update
            if [ -n "$IN_CHINA" ]; then
                PRO_URL="$PRO_CN_URL"
            fi
            curl -fsSL -m 5 -o "$GO_INSTALL_SCRIPT" "$PRO_URL/install.sh"
        fi
    fi

    if [ ! -f "$GO_INSTALL_SCRIPT" ]; then
        say_err "GVM go-install.sh download failed\n"
    fi
    chmod +x "$GO_INSTALL_SCRIPT"
}

# gvm script install
install_script() {
    gvm_script
    dl_goinstall_script

    say "GVM successfully installed\n"

    if ! command -v gvm >/dev/null; then
        printf "You need to execute: \n\e[1;33msource %s\e[m\n" "$PROFILE"
    fi
}

# gvm script upgrade
update_script() {
    gvm_script
    dl_goinstall_script "force"

    say "GVM successfully updated\n"
}

# Get a list of locally installed Go versions.
go_list_locale() {
    if ! find "$GO_VERSIONS_PATH"/go*/bin/go -maxdepth 1 -type f >/dev/null 2>&1; then
        if [ -z "${1:-}" ]; then
            say_err "No go version list found\n"
        fi
        return
    fi

    # GO_VERSION_LIST=$(find "${GO_VERSIONS_PATH}" -maxdepth 1 -name "go*" -type d | cut -d '/' -f 6 | sed 's/..//')
    while IFS= read -r _V; do
        GO_VERSION_LIST[${#GO_VERSION_LIST[@]}]=$(${_V} version | awk '{print $3}' | sed 's/..//')
    done < <(find "$GO_VERSIONS_PATH"/go*/bin/go -maxdepth 1 -type f)
}

# Obtain a list of versions from the Go official website.
go_list_remote() {
    IN_CHINA=""
    if check_in_china; then
        IN_CHINA=1
    fi
    local GO_DL_URL="https://go.dev/dl/"
    if [ -n "$IN_CHINA" ]; then
        GO_DL_URL="https://golang.google.cn/dl/"
    fi

    RELEASE_TAGS=$(curl -sL --retry 5 --max-time 10 "$GO_DL_URL" | sed -n '/toggle/p' | cut -d '"' -f 4 | grep go | grep -Ev 'rc|beta')

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
        if [ "$_V" = "go$GO_VERSION" ]; then
            REMOTE_HAS_VERSION=1
            break
        fi
    done

    if [ -z "$REMOTE_HAS_VERSION" ]; then
        say_err "There is no such version(go$GO_VERSION)\n"
    fi

    printf "\e[1;33mInstalling go %s\e[m\n" "$GO_VERSION"

    PARAMS="--version $GO_VERSION --root $GO_VERSIONS_PATH/go$GO_VERSION"
    # echo "${GO_INSTALL_SCRIPT} ${PARAMS}"

    # shellcheck disable=SC2086
    $SHELL $GO_INSTALL_SCRIPT $PARAMS >"$HOME/.gvm.log" 2>&1
    # shellcheck disable=SC1090,SC2086
    CURRENT_GO_BINARY="$GO_VERSIONS_PATH/go$GO_VERSION/bin/go"

    if [ ! -d "$GVM_GO_ROOT" ]; then
        ln -s "$GO_VERSIONS_PATH/go$GO_VERSION" "$GVM_GO_ROOT"    
    fi

    if [ -f "$CURRENT_GO_BINARY" ]; then
        $CURRENT_GO_BINARY version
    else
        say_err "Go $GO_VERSION installation failed\n"
    fi
}

# List all locally installed go versions
show_list() {
    go_list_locale

    for _V in "${GO_VERSION_LIST[@]:-}"; do
        if [ -z "$_V" ]; then
            continue
        fi
        printf "go%s\n" "$_V"
    done
}

# List all remote go versions
show_remote_list() {
    go_list_remote

    local SHOW_ALL=""
    SHOW_ALL="${1:-}"

    local __INDEX=1
    for _V in "${REMOTE_GO_LIST[@]:-}"; do
        if [ $__INDEX -ge 10 ] && [ -z "$SHOW_ALL" ]; then
            break
        fi

        printf "%s\n" "$_V"
        ((__INDEX++))
    done
}

# Remove custom go version from locally
uninstall_go() {
    if command -v go > /dev/null; then
        if [ "$(go version | awk '{print $3}')" = "go$GO_VERSION" ]; then
            say_err "The current version(go${GO_VERSION}) is in use\n"
        fi    
    fi


    if [ -d "$GO_VERSIONS_PATH/go$GO_VERSION" ]; then
        rm -rf "$GO_VERSIONS_PATH/go$GO_VERSION"
        say "go$GO_VERSION uninstalled successfully\n"
    else
        say "go$GO_VERSION does not exist\n"
    fi
}

# Use custom go version
use_go() {
    CURRENT_GO_BINARY="$GO_VERSIONS_PATH/go$GO_VERSION/bin/go"
    if [ ! -f "$CURRENT_GO_BINARY" ]; then
        install_go
    else
        $CURRENT_GO_BINARY version
    fi

    if [ -f "$CURRENT_GO_BINARY" ]; then
        rm -rf "$GVM_GO_ROOT"
        ln -s "$GO_VERSIONS_PATH/go$GO_VERSION" "$GVM_GO_ROOT"

        if ! command -v go >/dev/null 2>&1 || [ "$(go version | awk '{print $3}')" != "go$GO_VERSION" ]; then
            printf "\nYou need to execute: \n\e[1;33msource %s\e[m\n" "$PROFILE"
        fi
    fi
}

# Get go latest version
get_latest_version() {
    _VERSION="${1:-}"
    if [ "$_VERSION" = "latest" ]; then
        _VERSION=$(show_remote_list | sort -rV | head -n 1)
    fi
}    

# show help message
show_help_message() {
    printf "\e[1;32mgvm\e[m %s

Golang Version Manager

\e[1;33mUsage:\e[m %s [OPTIONS] [COMMAND]

\e[1;33mCommands:\e[m
  \e[1;32muse\e[m [VERSION|latest]       Change Go version
  \e[1;32minstall\e[m [VERSION|latest]   Install a new go version  
  \e[1;32muninstall\e[m                  Uninstall a Go version                
  \e[1;32mlist\e[m                       List all locally installed go versions
  \e[1;32mremote\e[m <more>              List all remote go versions
  \e[1;32mversion\e[m                    Print the current go version

\e[1;33mOptions:\e[m          
    \e[1;32m-i, --install\e[m
                Install Golang Version Manager

    \e[1;32m-u, --update\e[m
                Update Golang Version Manager

    \e[1;32m-h, --help\e[m
                Print help information

    \e[1;32m-v, --version\e[m
                Print Gvm version information
\n" "$GVM_VERSION" "$script_dir_name"
    exit 0
}

# 处理参数信息
judgment_parameters() {
    # 参数带帮助
    if [ $# -eq 0 ]; then
        if [ "$0" == "bash" ] || [ "$0" == "-bash" ]; then # 无参数，远程，安装
            DO_ACTION="--install"
        else # 无参数，本地
            DO_ACTION="--help"
        fi
        return
    fi

    while [ $# -gt 0 ]; do
        case "$1" in

        # 切换 Go
        'use')
            if [ -z "${2:-}" ]; then
                say_err "Missing go version argument. \n      Example: $script_name use [VERSION]\n"
            fi

            DO_ACTION="use"
            DO_PARAMETER="${2:-}"
            shift
            ;;

        # 安装 Go
        'install')
            if [ -z "${2:-}" ]; then
                say_err "Missing go version argument. \n      Example: $script_name install [VERSION]\n"
            fi

            DO_ACTION="install"
            DO_PARAMETER="${2:-}"
            shift
            ;;

        'uninstall')
            if [ -z "${2:-}" ]; then
                say_err "Missing go version argument. \n      Example: $script_name uninstall [VERSION]\n"
            fi

            DO_ACTION="uninstall"
            DO_PARAMETER="${2:-}"
            shift
            ;;

        # 显示本地已安装的 Go 版本
        'list')
            DO_ACTION="list"
            ;;

        # 显示远程已安装的 Go 版本
        'remote')
            DO_ACTION="remote"
            DO_PARAMETER="${2:-}"
            if [ -n "$DO_PARAMETER" ]; then
                shift
            fi
            ;;

        # 显示 Go 版本
        'version')
            DO_ACTION="version"
            ;;        

        # 安装此项目
        '-i' | '--install')
            DO_ACTION="--install"
            ;;

        # 更新此项目
        '-u' | '--update')
            DO_ACTION="--update"
            ;;

        # 显示脚本版本
        '-v' | '--version')
            DO_ACTION="--version"
            ;;


        # 帮助
        '-h' | '--help')
            DO_ACTION="--help"
            ;;

        # 未知参数
        *)
            echo "$script_dir_name: unknown option -- $1"
            exit 1
            ;;

        esac
        shift
    done
}

do_action() {
    case "${DO_ACTION:-}" in

    # 切换 Go
    'use')
        get_latest_version "${DO_PARAMETER:-}"
        GO_VERSION="${_VERSION#go}"
        use_go
        ;;

    # 安装 Go
    'install')
        get_latest_version "${DO_PARAMETER:-}"
        GO_VERSION="${_VERSION#go}"
        install_go
        ;;

    'uninstall')
        _VERSION="${DO_PARAMETER:-}"
        GO_VERSION="${_VERSION#go}"
        uninstall_go
        ;;

    # 显示本地已安装的 Go 版本
    'list')
        show_list
        ;;

    # 显示远程已安装的 Go 版本
    'remote')
        _MODE="${DO_PARAMETER:-}"
        show_remote_list "$_MODE"
        ;;

    # 显示 Go 版本
    'version')
        if ! command -v go >/dev/null 2>&1; then
            _msg=$(printf "Go is not installed\nPlease execute: \e[1;33m%s install latest\e[0m\n" "$script_dir_name")
            say_err "$_msg"
        else
            go version
        fi
        ;;        

    # 安装此项目
    '-i' | '--install')
        install_script
        ;;


    # 更新此项目
    '-u' | '--update')
        update_script
        ;;

    # 显示脚本版本
    '-v' | '--version')
        printf "gvm version: %s\n" "$GVM_VERSION"
        ;;

    # 帮助
    '-h' | '--help')
        show_help_message
        ;;

    # 未知参数
    *)
        ;;
    esac    
} 

set_project_url() {
    PRO_URL="https://raw.githubusercontent.com/jetsung/golang-install/main/"
    PRO_CN_URL="https://framagit.org/jetsung/golang-install/-/raw/main/"

    # DEBUG
    if [ -n "$DEBUG" ]; then
        PRO_CN_URL="https://git.envs.net/jetsung/learn/raw/branch/dev/"
    fi
}

main() {
    GVM_VERSION="1.1.1"

    GVM_PATH="$HOME/.gvm"
    GVM_BIN_PATH="$GVM_PATH/bin"
    GVM_ENV_PATH="$GVM_PATH/env"
    GVM_GO_ROOT="$GVM_PATH/go"

    GO_INSTALL_SCRIPT="$GVM_PATH/install.sh"
    GO_VERSIONS_PATH="$GVM_PATH/packages"

    DEBUG=""

    BASENAME_SHELL=""
    PROFILE="$(detect_profile)"

    if [ -z "$PROFILE" ]; then
        say_err "Error: can not find profile"
    fi

    IN_CHINA=""
    if check_in_china; then
        IN_CHINA=1
    fi

    REMOTE_GO_LIST=()
    GO_VERSION_LIST=()

    # 动作
    DO_ACTION=""
    # 参数
    DO_PARAMETER=""

    if [ ! -d "$GO_VERSIONS_PATH" ]; then
        mkdir -p "$GO_VERSIONS_PATH"
    fi

    # 检测系统
    init_os

    # 安装必要的依赖
    install_curl_command

    # 设置环境变量
    set_environment

    # 设置项目地址
    set_project_url

    # 提取参数和值
    judgment_parameters "$@"

    # 执行命令
    do_action
}

main "$@" || exit 1
