#!/usr/bin/env bash

# Golang-Install
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://jihulab.com/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

set -e
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

# show help message
show_help_message() {
    printf "Go install

\e[1;33mUSAGE:\e[m
    \e[1;32m%s\e[m [OPTIONS] <SUBCOMMANDS>

\e[1;33mOPTIONS:\e[m
    \e[1;32m-h, --help\e[m
                Print help information.

    \e[1;32m-p, --path\e[m
                Set GOPATH. (default: \$HOME/go)  

    \e[1;32m-r, --root\e[m
                Set GOROOT. (default: \$HOME/.go)                 

    \e[1;32m-v, --version\e[m
                Set golang version.                  
\n" "${script_name##*/}"
    exit
}

# custom version
custom_version() {
    if [ -n "${1}" ]; then
        RELEASE_TAG="go${1}"
    fi
}

# check in china
check_in_china() {
    if ! curl -s -m 3 -IL https://google.com | grep -q "200 OK"; then
        IN_CHINA=1
    fi
}

# Get OS bit
init_arch() {
    ARCH=$(uname -m)
    BIT="${ARCH}"
    case "${ARCH}" in
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

# if RELEASE_TAG was not provided, assume latest
latest_version() {
    if [ -z "$RELEASE_TAG" ]; then
        RELEASE_TAG="$(curl -sL --retry 5 --max-time 10 "${RELEASE_URL}" | sed -n '/toggleVisible/p' | head -n 1 | cut -d '"' -f 4)"
    fi
}

# compare version
compare_version() {
    OLD_VERSION="none"
    NEW_VERSION="$RELEASE_TAG"

    if [ -f "$GOROOT_PATH/bin/go" ]; then
        OLD_VERSION=$("$GOROOT_PATH"/bin/go version | awk '{print $3}')
    fi

    # DELETE current go
    # if [[ "$OLD_VERSION"="none" ]]; then
    #     __CURRENT_GO=$(which go)
    # fi

    if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
        say_err "You have installed this version: $OLD_VERSION"
    fi

    printf "
Current version: \e[1;33m %s \e[0m 
Target  version: \e[1;33m %s \e[0m
" "$OLD_VERSION" "$NEW_VERSION"
}

# create folder
create_folder() {
    if [ -n "${1}" ]; then
        local MYPATH="${1}"
        local REAL_PATH=${MYPATH/\$HOME/$HOME}
        [ -d "$REAL_PATH" ] || mkdir "$REAL_PATH"
        __TMP_PATH="$REAL_PATH"
    fi
}

# Download file and unpack
download_unpack() {
    local downurl="$1"
    local savepath="$2"

    printf "Fetching %s \n\n" "$downurl"

    curl -Lk --retry 3 --max-time 180 "$downurl" | gunzip | tar xf - --strip-components=1 -C "$savepath"
}

# compare version size
version_ge() { [[ "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1" ]]; }

# set golang environment
set_environment() {
    if ! grep -q 'export\sGOROOT' "$PROFILE"; then
        printf "\n## GOLANG\n" >>"$PROFILE"
        echo "export GOROOT=\"$__GOROOT\"" >>"$PROFILE"
    else
        sedi "s@^export GOROOT.*@export GOROOT=\"$__GOROOT\"@" "$PROFILE"
    fi

    if ! grep -q 'export\sGOPATH' "$PROFILE"; then
        echo "export GOPATH=\"$__GOPATH\"" >>"${PROFILE}"
    else
        sedi "s@^export GOPATH.*@export GOPATH=\"$__GOPATH\"@" "$PROFILE"
    fi

    if ! grep -q 'export\sGOBIN' "$PROFILE"; then
        echo "export GOBIN=\"\$GOPATH/bin\"" >>"$PROFILE"
    else
        sedi "s@^export GOBIN.*@export GOBIN=\$GOPATH/bin@" "$PROFILE"
    fi

    if ! grep -q 'export\sGO111MODULE' "$PROFILE"; then
        echo "export GO111MODULE=on" >>"$PROFILE"
    fi

    if ! grep -q 'export\sASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH' "$PROFILE"; then
        if version_ge "$RELEASE_TAG" "go1.17"; then
            echo "export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.18" >>"$PROFILE"
        fi
    fi

    if ! grep -q 'export\sGOPROXY' "$PROFILE"; then
        echo "export GOPROXY=\"$__GOPROXY_URL,direct\"" >>"$PROFILE"
    else
        sedi "s@^export GOPROXY.*@export GOPROXY=\"$__GOPROXY_URL,direct\"@" "$PROFILE"
    fi

    if ! grep -q "\$GOROOT/bin:\$GOBIN" "$PROFILE"; then
        echo "export PATH=\"\$PATH:\$GOROOT/bin:\$GOBIN\"" >>"$PROFILE"
    fi
}

# show copyright
show_copyright() {
    clear

    printf "
###############################################################
###  Golang Install
###
###  Author:  Jetsung Chan <jetsungchan@gmail.com>
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
# Install success, please execute again \e[1;33msource %s\e[0m
###############################################################
\n" "$PROFILE"
}

# Downlaod URL
DOWNLOAD_URL="https://dl.google.com/go/"

# Release URL
RELEASE_URL="https://go.dev/dl/"
RELEASE_CN_URL="https://golang.google.cn/dl/"

# GOPROXY
__GOPROXY_URL="https://proxy.golang.org"
__GOPROXY_CN_URL="https://goproxy.cn,https://goproxy.io"

# GOPATH
__GOPATH="\$HOME/go"

# GOROOT
__GOROOT="\$HOME/.go"

# Project URL
PROJECT_URL="https://github.com/jetsung/golang-install"
PROJECT_CN_URL="https://jihulab.com/jetsung/golang-install"

# Profile
PROFILE=""
PROFILE="$(detect_profile)"

# Release tag
RELEASE_TAG=""

for ARG in "$@"; do
    case "${ARG}" in
    --help | -h)
        show_help_message
        ;;

    --path | -p)
        shift
        if [ $# -ge 1 ] && [[ "${1}" != -* ]]; then
            __GOPATH=${1/"$HOME"/\$HOME}
        fi
        ;;

    --root | -r)
        shift
        if [ $# -ge 1 ] && [[ "${1}" != -* ]]; then
            __GOROOT=${1/"$HOME"/\$HOME}
        fi
        ;;

    --version | -v)
        shift
        if [ $# -ge 1 ] && [[ "${1}" != -* ]]; then
            custom_version "${1}"
        fi
        ;;
    *)
        shift
        ;;
    esac
done

create_folder "$__GOPATH"

__TMP_PATH=""
create_folder "$__GOROOT"
GOROOT_PATH="$__TMP_PATH"

IN_CHINA=""
check_in_china
if [ -n "$IN_CHINA" ]; then
    RELEASE_URL="${RELEASE_CN_URL}"
    PROJECT_URL="${PROJECT_CN_URL}"
    __GOPROXY_URL="${__GOPROXY_CN_URL}"
fi

show_copyright

init_arch

init_os

install_curl_command

latest_version

compare_version

show_system_information

# Download File
BINARY_URL="${DOWNLOAD_URL}${RELEASE_TAG}.${OS}-${ARCH}.tar.gz"

# Download and unpack
download_unpack "$BINARY_URL" "$GOROOT_PATH"

# Set ENV
set_environment

show_success_message
