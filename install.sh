#!/usr/bin/env bash

# Golang-Install
# Project Home Page:
# https://github.com/jetsung/golang-install
# https://jihulab.com/jetsung/golang-install
#
# Author: Jetsung Chan <jetsungchan@gmail.com>

# load var
load_vars() {
    # Script file name
    SCRIPT_NAME=$0

    # Release link
    RELEASE_URL="https://go.dev/dl/"

    # Downlaod link
    DOWNLOAD_URL="https://dl.google.com/go/"

    # GOPROXY
    GOPROXY_TEXT="https://proxy.golang.org"

    # Set GOPATH PATH
    GO_PATH="\$HOME/go"

    # Is GWF
    IN_CHINA=0

    PROJECT_URL="https://github.com/jetsung/golang-install"

    PROFILE="$(detect_profile)"
}

# check in china
check_in_china() {
    urlstatus=$(curl -s -m 3 -IL https://google.com | grep 200)
    if [ "${urlstatus}" == "" ]; then
        IN_CHINA=1
        RELEASE_URL="https://golang.google.cn/dl/"
        PROJECT_URL="https://jihulab.com/jetsung/golang-install"
        GOPROXY_TEXT="https://goproxy.cn,https://goproxy.io"   
    fi
}

# custom version
custom_version() {
    if [ -n "${1}" ] ;then
        RELEASE_TAG="go${1}"
        echo "Custom Version = ${RELEASE_TAG}"
    fi
}

# create GOPATH folder
create_gopath() {
    if [ ! -d "${GO_PATH}" ]; then
        if [ "${GO_PATH}" = "~/go" ]; then
            mkdir -p ~/go
            GO_PATH="\$HOME/go"
        else
            mkdir -p "${GO_PATH}"
        fi
    fi
}

# Get OS bit
init_arch() {
    ARCH=$(uname -m)
    BIT=$ARCH
    case $ARCH in
        amd64) ARCH="amd64";;
        x86_64) ARCH="amd64";;
        i386) ARCH="386";;
        armv6l) ARCH="armv6l";; 
        armv7l) ARCH="armv6l";; 
        aarch64) ARCH="arm64";; 
        *) printf "\e[1;31mArchitecture %s is not supported by this installation script\e[0m\n" $ARCH; exit 1;;
    esac
#    echo "ARCH = ${ARCH}"
}

# Get OS version
init_os() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    case $OS in
        darwin) OS='darwin';;
        linux) OS='linux';;
        freebsd) OS='freebsd';;
#        mingw*) OS='windows';;
#        msys*) OS='windows';;
        *) printf "\e[1;31mOS %s is not supported by this installation script\e[0m\n" $OS; exit 1;;
    esac
#    echo "OS = ${OS}"
}

# init args
init_args() {
    key=""

    for arg in "$@" 
    do
        if test "-h" = $arg; then
            show_help_message
        fi

        if test -z $key; then 
            key=$arg
        else 
            if test "-v" = $key; then
                custom_version $arg
            elif test "-d" = $key; then
                GO_PATH=$arg
            fi

            key=""
        fi
    done
}

# if RELEASE_TAG was not provided, assume latest
latest_version() {
    if [ -z "${RELEASE_TAG}" ]; then
        RELEASE_TAG="$(curl -sL --retry 5 ${RELEASE_URL} | sed -n '/toggleVisible/p' | head -n 1 | cut -d '"' -f 4)"
#        echo "Latest Version = ${RELEASE_TAG}"
    fi
}

# compare version
compare_version() {
    OLD_VERSION="none"
    NEW_VERSION="${RELEASE_TAG}"
    if test -x "$(command -v go)"; then
        OLD_VERSION="$(go version | awk '{print $3}')"
    fi
    if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
       printf "\n\e[1;31mYou have installed this version: %s\e[0m\n" $OLD_VERSION; exit 1;
    fi

printf "
Current version: \e[1;33m %s \e[0m 
Target version: \e[1;33m %s \e[0m
" $OLD_VERSION $NEW_VERSION
}

# compare version size 
version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

# install curl command
install_curl_command() {
    if !(test -x "$(command -v curl)"); then
        if test -x "$(command -v yum)"; then
            yum install -y curl
        elif test -x "$(command -v apt)"; then
            apt install -y curl
        else 
            printf "\e[1;31mYou must pre-install the curl tool\e[0m\n"
            exit 1
        fi
    fi  
}

# Download go file
## unused
download_file() {
    url="${1}"
    destination="${2}"

    printf "Fetching ${url} \n\n"

    if test -x "$(command -v curl)"; then
        code=$(curl --connect-timeout 15 -w '%{http_code}' -L "${url}" -o "${destination}")
    elif test -x "$(command -v wget)"; then
        code=$(wget -t2 -T15 -O "${destination}" --server-response "${url}" 2>&1 | awk '/^  HTTP/{print $2}' | tail -1)
    else
        printf "\e[1;31mNeither curl nor wget was available to perform http requests.\e[0m\n"
        exit 1
    fi

    if [ "${code}" != 200 ]; then
        printf "\e[1;31mRequest failed with code %s\e[0m\n" $code
        exit 1
    else 
	    printf "\n\e[1;33mDownload succeeded\e[0m\n"
    fi
}

# Download file and unpack
download_unpack() {
    printf "Fetching ${1} \n\n"

    rm -rf ${HOME}/.go

    curl -Lk --retry 3 "${1}" | gunzip | tar xf - -C /tmp

    mv /tmp/go ${HOME}/.go
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
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"
    do
      if DETECTED_PROFILE="$(try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    sh_echo "$DETECTED_PROFILE"
  fi
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

# set golang environment
set_environment() {
    if [ -z "`grep 'export\sGOROOT' ${PROFILE}`" ];then
        printf "\n## GOLANG\n" >> "${PROFILE}"
        echo "export GOROOT=\"\$HOME/.go\"" >> "${PROFILE}"
    else
        sedi "s@^export GOROOT.*@export GOROOT=\"\$HOME/.go\"@" "${PROFILE}"
    fi

    if [ -z "`grep 'export\sGOPATH' ${PROFILE}`" ];then
        echo "export GOPATH=\"${GO_PATH}\"" >> "${PROFILE}"
    else
        sedi "s@^export GOPATH.*@export GOPATH=\"${GO_PATH}\"@" "${PROFILE}"
    fi
    
    if [ -z "`grep 'export\sGOBIN' ${PROFILE}`" ];then
        echo "export GOBIN=\"\$GOPATH/bin\"" >> ${PROFILE}
    else 
        sedi "s@^export GOBIN.*@export GOBIN=\$GOPATH/bin@" "${PROFILE}"     
    fi   

    if [ -z "`grep 'export\sGO111MODULE' ${PROFILE}`" ];then
        echo "export GO111MODULE=on" >> "${PROFILE}"
    fi       

    if [ -z "`grep 'export\sASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH' ${PROFILE}`" ];then
        if version_ge "${RELEASE_TAG}" "go1.17"; then
            echo "export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.18" >> "${PROFILE}"
        fi
    fi

    if [ "${IN_CHINA}" == "1" ]; then 
        if [ -z "`grep 'export\sGOSUMDB' ${PROFILE}`" ];then
            echo "export GOSUMDB=off" >> "${PROFILE}"
        fi      
    fi

    if [ -z "`grep 'export\sGOPROXY' ${PROFILE}`" ];then
        echo "export GOPROXY=\"${GOPROXY_TEXT},direct\"" >> "${PROFILE}"
    else 
        sedi "s@^export GOPROXY.*@export GOPROXY=\"${GOPROXY_TEXT},direct\"@" "${PROFILE}"     
    fi 
    
    if [ -z "`grep '\$GOROOT/bin:\$GOBIN' ${PROFILE}`" ];then
        echo "export PATH=\"\$PATH:\$GOROOT/bin:\$GOBIN\"" >> "${PROFILE}"
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
\n" "${PROJECT_URL}"
}

# show system information
show_system_information() {
printf "
###############################################################
###  System: %s 
###  Bit: %s 
###  Version: %s 
###############################################################
\n" "${OS}" "${BIT}" "${RELEASE_TAG}"
}

# Show success message
show_success_message() {
printf "
###############################################################
# Install success, please execute again \e[1;33msource %s\e[0m
###############################################################
\n" "${PROFILE}"
}

# show help message
show_help_message() {
printf "
Go install

Usage: %s [-h] [-v version] [-d GOPATH]

Options:
  -h            : this help
  -v            : set go version (default: latest version)
  -d            : set GOPATH (default: \$HOME/go)
\n" "${SCRIPT_NAME}"
exit 1
}

main() {
    load_vars "$@"

    init_args "$@"

    check_in_china

    show_copyright

    set -e

    init_arch

    init_os

    install_curl_command

    latest_version

    compare_version

    show_system_information

    # Download File
    BINARY_URL="${DOWNLOAD_URL}${RELEASE_TAG}.${OS}-${ARCH}.tar.gz"

    # Create GOPATH
    create_gopath

    # Download and unpack
    download_unpack "${BINARY_URL}"
    
    # Set ENV
    set_environment
    
    show_success_message
}

main "$@" || exit 1
