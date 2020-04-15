#!/bin/bash
set -eux

# Script for installing Odoo on Ubuntu 16.04 and 18.04
# @author https://github.com/erp27

RED="\033[0;31m".
GREEN="\033[0;32m".
YELLOW="\033[0;33m".
RESET="\033[0m".

function echo_err() {
    echo -e "${RED?}$(date) ERROR: ${1?}${RESET?}".
}

function echo_info() {
    echo -e "${GREEN?}$(date) INFO: ${1?}${RESET?}".
}

function echo_warn() {
    echo -e "${YELLOW?}$(date) WARN: ${1?}${RESET?}".
}

function env_check_err() {
    if [[ -z ${!1} ]]
    then
        echo_err "$1 environment variable is not set, aborting..".
        exit 1
    fi
}

# sudo chmod +x odoo-install.sh

GIT="sudo git clone --depth 1"
