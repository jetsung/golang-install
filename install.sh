#!/usr/bin/env bash

# Golang-Install
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://framagit.org/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

set -euo pipefail

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

# custom version
custom_version() {
    if [ -n "$1" ]; then
        RELEASE_TAG="go$1"
    fi
}

# check in china
check_in_china() {
    if [ "$(curl -s -m 3 -o /dev/null -w "%{http_code}" https://www.google.com)" != "200" ]; then
        IN_CHINA=1
    fi
}

# Get OS bit
init_arch() {
    ARCH=$(uname -m)
    BIT="$ARCH"

    case "$ARCH" in
    amd64) ARCH="amd64" ;;
    x86_64) ARCH="amd64" ;;
    i386) ARCH="386" ;;
    armv6l) ARCH="armv6l" ;;
    armv7l) ARCH="armv6l" ;;
    aarch64) ARCH="arm64" ;;
    *)
        say_err "Architecture $ARCH is not supported by this installation script\n"
        ;;
    esac
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

# if RELEASE_TAG was not provided, assume latest
latest_version() {
    if [ -z "$RELEASE_TAG" ]; then
        RELEASE_TAG="$(curl -sL --retry 5 --max-time 30 "$RELEASE_URL" | sed -n '/toggleVisible/p' | head -n 1 | cut -d '"' -f 4)"
    fi
}

# compare version
compare_version() {
    OLD_VERSION="none"
    NEW_VERSION="$RELEASE_TAG"

    _gobin="${GOROOT:-}/bin/go"
    if [ -f "$_gobin" ]; then
        OLD_VERSION=$("$_gobin" version | awk '{print $3}')
    fi

    if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
        say_err "You have installed this version: $OLD_VERSION"
    fi

    printf "
Current version: \e[1;33m %s \e[0m 
Target  version: \e[1;33m %s \e[0m
" "$OLD_VERSION" "$NEW_VERSION"
}

check_gvm() {
    # shellcheck disable=SC2016
    if grep -q '$HOME/.gvm/env' "$PROFILE"; then
        IS_GVM=1
    fi
}    

# Download file and unpack
download_unpack() {
    local downurl="$1"
    local savepath="$2"

    if [ -z "$downurl" ] || [ -z "$savepath" ]; then
        say_err "not found downurl or savepath"
    fi

    printf "Fetching %s \n\n" "$downurl"

    _tempdir=$(mktemp -d -t goroot.XXXXXX)
    curl -Lk --connect-timeout 30 --retry 5 --retry-max-time 360 --max-time 300 "$downurl" | gunzip | tar xf - --strip-components=1 -C "$_tempdir" || {
        say_err "download and unpack failed"
    }
    if [ -d "$savepath" ]; then
        rm -rf "$savepath"
    fi
    mv "$_tempdir" "$savepath"
}

# compare version size
version_ge() { [ "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1" ]; }

# set golang environment
set_environment() {
    if [ -n "$IS_GVM" ]; then
        return
    fi

    # shellcheck disable=SC2016
    sedi '/## GOLANG/,/export PATH="$PATH:$GOROOT"/d' "$PROFILE"

    # shellcheck disable=SC2001
    _goroot=$(echo "$GO_ROOT" | sed "s|$HOME|\\\$HOME|g")
    # shellcheck disable=SC2001
    _gopath=$(echo "$GO_PATH" | sed "s|$HOME|\\\$HOME|g")
    {
        echo
        echo '## GOLANG'
        echo "export GOROOT=\"$_goroot\""
        echo "export GOPATH=\"$_gopath\""
        # shellcheck disable=SC2016
        echo 'export GOBIN="$GOPATH/bin"'
        echo 'GOPROXY="https://goproxy.cn,https://goproxy.io,direct"'
        # shellcheck disable=SC2016
        echo 'export PATH="$PATH:$GOROOT/bin:$GOBIN"'
    } >>"$PROFILE"

    if [ -z "$IN_CHINA" ]; then
        sedi '/GOPROXY/d' "$PROFILE"
    fi
}

# show copyright
show_copyright() {
    clear

    printf "
###############################################################
###  Golang Install
###
###  Author:  Jetsung Chan <i@jetsung.com>
###  Link:    https://jetsung.com
###  Project: %s
###############################################################
\n" "$PROJECT_URL"
}

# show system information
show_system_information() {
    printf "
###############################################################
###  System:  %s 
###  Bit:     %s 
###  Version: %s 
###############################################################
\n" "$OS" "$BIT" "$RELEASE_TAG"
}

# Show success message
show_success_message() {
    printf "
###############################################################
# Installation successful, please execute again \e[1;33msource %s\e[0m
###############################################################
\n" "$PROFILE"
}

# show help message
show_help_message() {
    printf "Go install

\e[1;33mUSAGE:\e[m
    \e[1;32m%s\e[m [OPTIONS]

\e[1;33mOPTIONS:\e[m
    \e[1;32m-p, --path\e[m <GOPATH>
                Set GOPATH. (default: \$HOME/go)  

    \e[1;32m-r, --root\e[m <GOROOT>
                Set GOROOT. (default: \$HOME/.go)                 

    \e[1;32m-v, --version\e[m <VERSION>
                Set golang version.                  

    \e[1;32m-h, --help\e[m
                Print help information.
\n" "$script_dir_name"
    exit
}

# 处理参数信息
judgment_parameters() {
    while [ $# -gt 0 ]; do
        case "$1" in

        '-p' | '--path')
            if [ -z "${2:-}" ]; then
                say_err "Missing go path argument. \n      Example: $script_name --path [GOPATH]\n"
            fi
            if [[ "$2" == -* ]]; then
                shift
                continue
            fi
            GO_PATH="${2:-}"
            shift
            ;;

        '-r' | '--root')
            if [ -z "${2:-}" ]; then
                say_err "Missing go root argument. \n      Example: $script_name --root [GOROOT]\n"
            fi
            if [[ "$2" == -* ]]; then
                shift
                continue
            fi
            GO_ROOT="${2:-}"
            shift
            ;;

        '-v' | '--version')
            if [ -z "${2:-}" ]; then
                say_err "Missing go version argument. \n      Example: $script_name --version [VERSION]\n"
            fi
            if [[ "$2" == -* ]]; then
                shift
                continue
            fi
            custom_version "${2:-}"
            shift
            ;;

        # 帮助
        '-h' | '--help')
            show_help_message
            ;;

        # 未知参数
        *)
            say_err "$script_dir_name: unknown option - $1"
            ;;

        esac
        shift
    done
}

do_action() {
    echo
}

set_project_url() {
    # Release URL
    RELEASE_URL="https://go.dev/dl/"
    RELEASE_CN_URL="https://golang.google.cn/dl/"

    # Project URL
    PROJECT_URL="https://github.com/jetsung/golang-install"
    PROJECT_CN_URL="https://framagit.org/jetsung/golang-install"

    if [ -n "$IN_CHINA" ]; then
        RELEASE_URL="$RELEASE_CN_URL"
        PROJECT_URL="$PROJECT_CN_URL"
    fi
}

main() {
    # GVM
    IS_GVM=""
    GVMPATH=${GVMPATH:-$HOME/.gvm}

    # Downlaod URL
    DOWNLOAD_URL="https://dl.google.com/go/"

    # GOPATH
    # shellcheck disable=SC2016
    GO_PATH="$HOME/go"

    # GOROOT
    GO_ROOT="$HOME/.go"

    # Release tag / go version 
    RELEASE_TAG=""

    BASENAME_SHELL=""
    PROFILE="$(detect_profile)"

    if [ -z "$PROFILE" ]; then
        say_err "Error: can not find profile"
    fi

    # 提取参数和值
    judgment_parameters "$@"    

    check_gvm
    if [ -n "$IS_GVM" ]; then
        if [ ! -d "$GVMPATH/packages" ]; then
            mkdir -p "$GVMPATH/packages"
        fi
        GO_ROOT="$GVMPATH/packages/$RELEASE_TAG"
    fi

    IN_CHINA=""
    check_in_china
    set_project_url

    show_copyright

    init_arch

    init_os

    install_curl_command

    latest_version

    compare_version

    show_system_information

    # Download File
    BINARY_URL="$DOWNLOAD_URL$RELEASE_TAG.$OS-$ARCH.tar.gz"

    # Download and unpack
    download_unpack "$BINARY_URL" "$GO_ROOT"

    # Set ENV
    set_environment || say_err "set environment error"

    show_success_message
}

main "$@" || exit 1