#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
SSH_DIR=/etc/ssh
RC_SCRIPT_FILE='/etc/rc.local'
RC_BACKUP_FILE='/etc/rc.local.bak'
RC_CONF='/etc/rc.conf'
BSDINIT_URL='https://github.com/pellaeon/bsd-cloudinit/archive/master.tar.gz'
VERIFY_PEER='--ca-cert=/usr/local/share/certs/ca-root-nss.crt'
FETCH="fetch ${VERIFY_PEER}"


INSTALL_PKGS='
	lang/python27
	devel/py-pip
	security/sudo
	security/ca_root_nss
	'


##############################################
#  utils
##############################################
	
echo_debug() {
	echo '[debug] '$1
}


##############################################
#  main block
##############################################

# Get freebsd version
if uname -K > /dev/null 2>&1
then
	BSD_VERSION=`uname -K`
else
	_BSD_VERSION=`uname -r | cut -d'-' -f 1`
	BSD_VERSION=$(printf "%d%02d%03d" `echo ${_BSD_VERSION} | cut -d'.' -f 1` `echo ${_BSD_VERSION} | cut -d'.' -f 2` 0)
fi

if [ $BSDINIT_DEBUG ]
then
	echo_debug "BSD_VERSION = $BSD_VERSION"
fi

if [ "$BSD_VERSION" -lt 903000 ]
then
	echo 'Oops! Your freebsd version is too old and not supported!'
	exit 1
fi

# Install our prerequisites
export ASSUME_ALWAYS_YES=yes
pkg install $INSTALL_PKGS

[ ! `which python2.7` ] && {
	echo 'python2.7 Not Found !'
	exit 1
}
PYTHON=`which python2.7`

$FETCH -o - $BSDINIT_URL | tar -xzvf - -C '/root'

pip install -r '/root/bsd-cloudinit-master/requirements.txt'

rm -vf $SSH_DIR/ssh_host*

touch $RC_SCRIPT_FILE
cp -pf $RC_SCRIPT_FILE $RC_BACKUP_FILE
echo "$PYTHON /root/bsd-cloudinit-master/run.py --log-file /tmp/cloudinit.log" >> $RC_SCRIPT_FILE
echo "cp -pf $RC_BACKUP_FILE $RC_SCRIPT_FILE " >> $RC_SCRIPT_FILE

# Output to OpenStack console log
echo 'console="comconsole,vidconsole"' >> /boot/loader.conf
# Bootloader menu delay
echo 'autoboot_delay="1"' >> /boot/loader.conf

# Get the active NIC and set it to use dhcp.
for i in `ifconfig -u -l`
do
	case $i in
		'lo0')
			;;
		'plip0')
			;;
		'pflog0')
			;;
		*)
			echo '# Generated by bsd-cloudinit-install '`date +'%Y/%m/%d %T'` >> $RC_CONF
			echo 'ifconfig_'${i}'="DHCP"' >> $RC_CONF
			break;
			;;
	esac
done

# Allow %wheel to become root with no password
sed -i '' 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /usr/local/etc/sudoers

# Readme - clean history
echo '==================================================='
echo 'If you want to clean the tcsh history, please issue'
echo '    # set history = 0'
echo '==================================================='
