#!/bin/bash
# Install OpenXPKI
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

#
# Configure OpenXPKI
#
#
set -e

# ENVIRONMENT

if ! $(grep -q OXI_CORE_DIR /etc/environment); then
    OXI_CORE_DIR=/run-env/openxpki
    mkdir -p $OXI_CORE_DIR
    echo "OXI_CORE_DIR=$OXI_CORE_DIR" >> /etc/environment
fi

# Read our configuration and the one written by previous (DB) provisioning scripts
while read def; do export $def; done < /etc/environment

# STARTUP SCRIPT
## Disabled because it expects mysql package and is not needed in dev env (?)
## cp /code-repo/package/debian/core/libopenxpki-perl.openxpkid.init /etc/init.d/openxpkid

# USERS AND GROUPS

apache_user=www-data
if $(grep -q apache /etc/passwd); then apache_user=apache; fi

# openxpki
if ! $(grep -q openxpki /etc/passwd); then
    echo "System user 'openxpki'"
    useradd  --system --no-create-home -U openxpki
    # add apache user to openxpki group (to allow connecting the socket)
    usermod -G openxpki $apache_user
else
    echo "System user 'openxpki' - already set up."
fi

# pkiadm
# if ! $(grep -q pkiadm /etc/passwd); then
#     echo "System user 'pkiadm'"
#     adduser --quiet --system --disabled-password --group pkiadm
#     usermod pkiadm -G openxpki
#     # In case somebody decided to change the home base
#     HOME=`grep pkiadm /etc/passwd | cut -d":" -f6`
#     chown pkiadm:openxpki $HOME
#     chmod 750 $HOME
# else
#     echo "System user 'pkiadm' - already set up."
# fi

# Create the sudo file to restart oxi from pkiadm
if [ -d /etc/sudoers.d ]; then
    echo "pkiadm ALL=(ALL) NOPASSWD:/etc/init.d/openxpki" > /etc/sudoers.d/pkiadm
fi

echo "Create directories and log files"

# DIRECTORIES
mkdir -p /etc/openxpki

mkdir -p /var/openxpki/session
chown -R openxpki:openxpki /var/openxpki

mkdir -p /var/log/openxpki
chown openxpki:openxpki /var/log/openxpki

mkdir -p /var/www/openxpki
chown $apache_user:$apache_user /var/www/openxpki

# LOG FILES
for f in webui acme certep cmc est rpc scep soap; do
    touch /var/log/openxpki/${f}.log
    chown $apache_user:openxpki /var/log/openxpki/${f}.log
    chmod 660 /var/log/openxpki/${f}.log
done

# logrotate
if [ -e /etc/logrotate.d/ ]; then
    echo "Configure logrotate"
    cp $OXI_TEST_SAMPLECONFIG_DIR/contrib/logrotate.conf /etc/logrotate.d/openxpki
fi

# Apache configuration
if command -v apache2 >/dev/null; then
    echo "Configure Apache"

    a2enmod cgid                                                      >$LOG 2>&1
    a2enmod fcgid                                                     >$LOG 2>&1
    # (Apache will be restarted by oxi-refresh)
fi

echo "Install OpenXPKI from host sources"
$OXI_SOURCE_DIR/tools/testenv/oxi-refresh --full 2>&1 | tee $LOG | sed -u 's/^/    /mg'

set +e

#
# Helper scripts
#
tools_dir="$OXI_SOURCE_DIR/tools/testenv"
if ! grep -q "$tools_dir" /root/.bashrc; then
    echo "Set \$PATH and run 'oxi-help' on login"
    echo "export PATH=\$PATH:$tools_dir" >> /root/.bashrc
    if [[ -d /home/vagrant ]]; then
        echo "export PATH=\$PATH:$tools_dir" >> /home/vagrant/.profile
        echo "$tools_dir/oxi-help"           >> /home/vagrant/.profile
    fi
fi
