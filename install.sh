#!/bin/bash

# Golang-Install
# Project Home Page:
# https://github.com/skiy/golang-install
# https://jihulab.com/skiy/golang-install
#
# Author: Jetsung Chan <skiy@jetsung.com>

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

    # Set environmental for golang
    PROFILE="${HOME}/.bashrc"

    # Set GOPATH PATH
    GO_PATH="~/.go/path"

    # Is GWF
    IN_CHINA=0

    PROJECT_URL="https://github.com/skiy/golang-install"
}

# check in china
check_in_china() {
    urlstatus=$(curl -s -m 3 -IL https://google.com | grep 200)
    if [ "$urlstatus" == "" ]; then
        IN_CHINA=1
        RELEASE_URL="https://golang.google.cn/dl/"
        GOPROXY_TEXT="https://goproxy.io,https://goproxy.cn"   
        PROJECT_URL="https://jihulab.com/skiy/golang-install"
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
        if [ "${GO_PATH}" = "~/.go/path" ]; then
            mkdir -p ~/.go/path
            GO_PATH="\$HOME/.go/path"
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
    echo "ARCH = ${ARCH}"
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
    echo "OS = ${OS}"
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
        echo "Latest Version = ${RELEASE_TAG}"
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
    [ ! -d ~/.go ] && mkdir ~/.go

    printf "Fetching ${1} \n\n"

    pushd "${HOME}/.go" > /dev/null
        curl -Lk --retry 3 "${1}" | gunzip | tar x 
    popd  > /dev/null
}

# set golang environment
set_environment() {
    #test ! -e "${PROFILE}" && PROFILE="${HOME}/.bash_profile"
    #test ! -e "${PROFILE}" && PROFILE="${HOME}/.bashrc"

    # check .zshrc on MacOS
    if [ -f "${HOME}"/.zshrc ] && [ -z "`grep \~\/\.bashrc ${HOME}/.zshrc`" ];then
            echo -e "\n. ~/.bashrc" >> "${HOME}/.zshrc"
	fi

    [ ! -f "~/.bashrc" ] && touch ~/.bashrc

    if [ -z "`grep 'export\sGOROOT' ${PROFILE}`" ];then
        echo -e "\n## GOLANG" >> "${PROFILE}"
        echo "export GOROOT=\"\$HOME/.go/go\"" >> "${PROFILE}"
    else
        sed -i "" -e "s@^export GOROOT.*@export GOROOT=\"\$HOME/.go/go\"@" "${PROFILE}"
    fi

    if [ -z "`grep 'export\sGOPATH' ${PROFILE}`" ];then
        echo "export GOPATH=\"${GO_PATH}\"" >> "${PROFILE}"
    else
        sed -i "" -e "s@^export GOPATH.*@export GOPATH=\"${GO_PATH}\"@" "${PROFILE}"
    fi
    
    if [ -z "`grep 'export\sGOBIN' ${PROFILE}`" ];then
        echo "export GOBIN=\"\$GOPATH/bin\"" >> ${PROFILE}
    else 
        sed -i "" -e "s@^export GOBIN.*@export GOBIN=\$GOPATH/bin@" "${PROFILE}"        
    fi   

    if [ -z "`grep 'export\sGO111MODULE' ${PROFILE}`" ];then
        if version_ge $RELEASE_TAG "go1.11.1"; then
            echo "export GO111MODULE=on" >> "${PROFILE}"
        fi
    fi       

    if [ "${IN_CHINA}" == "1" ]; then 
        if [ -z "`grep 'export\sGOSUMDB' ${PROFILE}`" ];then
            echo "export GOSUMDB=off" >> "${PROFILE}"
        fi      
    fi

    if [ -z "`grep 'export\sGOPROXY' ${PROFILE}`" ];then
        if version_ge $RELEASE_TAG "go1.13"; then
            GOPROXY_TEXT="${GOPROXY_TEXT},direct"
        fi
        echo "export GOPROXY=\"${GOPROXY_TEXT}\"" >> "${PROFILE}"
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
###  Author:  Jetsung Chan <skiy@jetsung.com>
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

Usage: %s [-h] [-v version] [-d gopath]

Options:
  -h            : this help
  -v            : set go version (default: latest version)
  -d            : set go path (default: %s/.go/path)
\n" "${SCRIPT_NAME}" "${HOME}"
exit 1
}

main() {
    load_vars "$@"

    # identify platform based on uname output
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
    # DOWNLOAD_FILE="$(mktemp).tar.gz"
    # download_file $BINARY_URL $DOWNLOAD_FILE

    # Remove go src
    rm -rf "${HOME}/.go/go"

    # Create GOPATH
    create_gopath

    # tar -C ${HOME}/.go -zxf $DOWNLOAD_FILE
    # rm -rf $DOWNLOAD_FILE

    # Download and unpack
    download_unpack "${BINARY_URL}"
    
    set_environment
    
    show_success_message
}

main "$@" || exit 1
