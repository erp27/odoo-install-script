#!/bin/bash
# Script for installing Odoo on Ubuntu 16.04 and 18.04
# @author https://github.com/erp27

# turn for debug
set -eux

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

GIT="sudo git clone --single-branch --depth 1"
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
ODOO_XMLRPC_PORT="8012"
# set the Master random password
ODOO_SUPERADMIN=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 17`

# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"

###  WKHTMLTOPDF download links
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.xenial_i386.deb
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb

# Update Server
echo_info "\nUpdate Ubuntu server"
echo "deb http://mirrors.kernel.org/ubuntu/ xenial main" | sudo tee /etc/apt/sources.list.d/libpng12.list
sudo apt-get update && sudo apt-get upgrade -y

echo_info "\nInstall tool packages"
sudo apt-get install wget wget curl git bzr ca-certificates -y
sudo apt-get install sudo libxml2-dev libxslt1-dev gdebi-core -y
sudo apt-get install libsasl2-dev python3-dev libldap2-dev libssl-dev -y

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
sudo apt-get install libxml2-dev libxslt1-dev -y
sudo apt-get install libsasl2-dev libldap2-dev libssl-dev
sudo apt-get install python3 python3-dev python3-pip -y

#sudo ssh-keyscan -H github.com >> ~/.ssh/known_hosts
mkdir -p ~/.ssh/
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
# clean old files
rm -f ./requirements.txt
wget -c https://raw.githubusercontent.com/erp27/odoo/${ODOO_BRANCH}/requirements.txt
sudo pip3 install -r requirements.txt

# Install Wkhtmltopdf if needed
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo_info "\nInstall wkhtml and place shortcuts on correct place"
    sudo apt-get install libpng12-0
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

# add user
echo_info "\nCreate Odoo system user"
if getent passwd ${ODOO_USER} > /dev/null 2>&1; then
    sudo userdel -r ${ODOO_USER}
fi

sudo adduser --system --quiet --shell=/bin/bash --home=${ODOO_HOME} --gecos 'ODOO system user' --group $ODOO_USER
#The user should also be added to the sudo'ers group
sudo adduser $ODOO_USER sudo

# Install Odoo
echo_info "\nInstalling Odoo ${ODOO_BRANCH} server"
if [ ! -d "${ODOO_HOME_EXT}" ]; then
    sudo mkdir -p ${ODOO_HOME_EXT}
    sudo chown ${ODOO_USER}: ${ODOO_HOME_EXT}
    $GIT --branch ${ODOO_BRANCH} https://github.com/erp27/odoo.git ${ODOO_HOME_EXT}/
else
echo_err "\nOdoo home: ${ODOO_HOME_EXT} already exist!"
fi


echo_info "\nCreate Odoo log directory"
[ ! -d "/var/log/$ODOO_USER" ] && sudo mkdir /var/log/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_USER /var/log/$ODOO_USER

echo_info "\nCreate custom addons directory"
sudo su $ODOO_USER -c "mkdir -p ${ODOO_HOME}/custom/addons"

echo_info "\nSetting permissions on Odoo home"
sudo chown -R ${ODOO_USER}: ${ODOO_HOME}/*

echo_info "\nCreate server config file"
sudo touch ${ODOO_CONFIG_FILE}
sudo su root -c "printf '[options] \n; password that allows database operations:\n' > ${ODOO_CONFIG_FILE}"
sudo su root -c "printf 'admin_passwd = ${ODOO_SUPERADMIN}\n' >> ${ODOO_CONFIG_FILE}"
sudo su root -c "printf 'xmlrpc_port = ${ODOO_XMLRPC_PORT}\n' >> ${ODOO_CONFIG_FILE}"
sudo su root -c "printf 'logfile = /var/log/${ODOO_USER}/${ODOO_CONFIG}.log\n' >> ${ODOO_CONFIG_FILE}"
sudo su root -c "printf 'log_handler = werkzeug:CRITICAL,odoo.api:DEBUG,odoo:INFO\n' >> ${ODOO_CONFIG_FILE}"
sudo su root -c "printf 'addons_path=${ODOO_HOME_EXT}/addons,${ODOO_HOME}/custom/addons\n' >> ${ODOO_CONFIG_FILE}"
sudo chown ${ODOO_USER}: ${ODOO_CONFIG_FILE}
sudo chmod 640 ${ODOO_CONFIG_FILE}

# Adding ODOO as a deamon systemd)
echo_info "Create systemd service file"
sudo rm -f /etc/systemd/system/odoo${ODOO_VERSION}.service
cat << EOF | sudo tee -a /etc/systemd/system/odoo${ODOO_VERSION}.service
[Unit]
Description=Odoo ${ODOO_VERSION} ERP system
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo${ODOO_VERSION}
PermissionsStartOnly=true
User=${ODOO_USER}
Group=${ODOO_USER}
ExecStart=$ODOO_HOME_EXT/odoo-bin -c ${ODOO_CONFIG_FILE}
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target

# pidfile
#PIDFILE=/var/run/\${NAME}.pid
EOF

echo_info "Reload systemd manager configuration"
sudo systemctl daemon-reload
echo_info "Start Odoo service"
sudo systemctl start odoo${ODOO_VERSION}
sudo systemctl enable odoo${ODOO_VERSION}

#echo -e "* Starting Odoo Service"
#sudo su root -c "/etc/init.d/$ODOO_CONFIG start"
echo_warn "-----------------------------------------------------------"
echo_info "\nDone! The Odoo server is up and running. Specifications:"
echo "TCP port: $ODOO_XMLRPC_PORT"
echo "User service: $ODOO_USER"
echo "User PostgreSQL: $ODOO_USER"
echo "Source code location: $ODOO_USER"
echo "Addons directory: /home/$ODOO_USER/$ODOO_CONFIG/addons/"
echo "Start Odoo service: sudo systemctl start odoo${ODOO_VERSION}"
echo "Stop Odoo service: sudo systemctl stop odoo${ODOO_VERSION}"
echo "Restart Odoo service: sudo systemctl restart odoo${ODOO_VERSION}"
echo "Show log: sudo tail -f /var/log/${ODOO_USER}/${ODOO_CONFIG}.log"
