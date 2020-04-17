#!/bin/bash
# Script for installing Odoo on Ubuntu 16.04 and 18.04
# @author https://github.com/erp27

# turn for debug
#set -eux

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
# Choose the Odoo version which you want to install.
# For example: 12, 11, 10, 9 ...
ODOO_VERSION="12"
ODOO_BRANCH="${ODOO_VERSION}.0"
ODOO_USER="odoo${ODOO_VERSION}"
ODOO_HOME="/home/${ODOO_USER}"
ODOO_CONFIG="${ODOO_USER}"
ODOO_CONFIG_FILE="/etc/${ODOO_CONFIG}.conf"
ODOO_HOME_EXT="/opt/${ODOO_CONFIG}-server"
# Set the default XML_RPC port
ODOO_XMLRPC_PORT="8069"
# set the Master random password
ODOO_SUPERADMIN=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 17`

# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"

###  WKHTMLTOPDF download links
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb

# Update Server
echo_info "\nUpdate Ubuntu server"
sudo apt-get update && sudo apt-get upgrade -y

echo_info "\nInstall tool packages"
sudo apt-get install wget wget curl git bzr ca-certificates gdebi-core -y

# Install PostgreSQL
sudo apt-get purge postgresql
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RELEASE=$(lsb_release -cs)
echo "deb http://apt.postgresql.org/pub/repos/apt/ ${RELEASE}"-pgdg main | sudo tee  /etc/apt/sources.list.d/pgdg.list
sudo apt-get update

echo_info "\nInstall PostgreSQL Server"
sudo apt-get install postgresql-11 -y
#sudo apt-get install postgresql -y
echo_info "\nCreating the Odoo PostgreSQL User"
sudo su - postgres -c "createuser -s $ODOO_USER" 2> /dev/null || true

# Install python3 + pip3
echo_info "\nInstall Python 3 + pip3"
sudo apt-install install python3 python3-pip -y

# clean old files
rm -f ./requirements.txt
wget -c https://raw.githubusercontent.com/erp27/odoo/${ODOO_BRANCH}/requirements.txt
sudo pip3 install -r requirements.txt

# Install Wkhtmltopdf if needed
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo_info"\nInstall wkhtml and place shortcuts on correct place"
    #pick up correct one from x64 & x32 versions:
    if [ "`getconf LONG_BIT`" == "64" ];then
        _url=$WKHTMLTOX_X64
    else
        _url=$WKHTMLTOX_X32
    fi
    sudo wget -c $_url
    sudo gdebi --n `basename $_url`
    sudo ln -sfn /usr/local/bin/wkhtmltopdf /usr/bin
    sudo ln -sfn /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

# Install Odoo
echo_info "\nInstalling Odoo ${ODOO_BRANCH} server"
if [ ! -d "${ODOO_HOME_EXT}" ]; then
    $GIT --branch ${ODOO_BRANCH} git@github.com:erp27/odoo.git ${ODOO_HOME_EXT}/
else
echo_err "\nOdoo home: ${ODOO_HOME_EXT} already exist!"
exit 1
fi

echo_info "\nCreate Odoo system user"
if getent passwd ${ODOO_USER} > /dev/null 2>&1; then
    sudo userdel -r ${ODOO_USER}
fi

sudo adduser --system --quiet --shell=/bin/bash --home=${ODOO_HOME} --gecos 'ODOO system user' --group $ODOO_USER
#The user should also be added to the sudo'ers group
sudo adduser $ODOO_USER sudo

echo_info "\nCreate Odoo log directory"
[ ! -d "/var/log/$ODOO_USER" ] && sudo mkdir /var/log/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_USER /var/log/$ODOO_USER

echo_info "\nCreate custom addons directory"
sudo su $ODOO_USER -c "mkdir -p $ODOO_HOME/custom/addons"

echo_info "\nSetting permissions on Odoo home"
sudo chown -R ${ODOO_USER}: ${ODOO_HOME}/*
