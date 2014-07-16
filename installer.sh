#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
SSH_DIR=/etc/ssh
RC_SCRIPT_FILE='/etc/rc.local'
RC_BACKUP_FILE='/etc/rc.local.bak'
RC_CONF='/etc/rc.conf'
BSDINIT_URL="https://github.com/pellaeon/bsd-cloudinit/archive/master.tar.gz"

BSD_VERSION=`uname -r | cut -d. -f 1`
INSTALL_PKGS='
	lang/python27
	devel/py-setuptools
	security/sudo
	'
VERIFY_PEER=''

# For FreeBSD10 get root certs and use them
if [ "$BSD_VERSION" -ge 10 ];then
	INSTALL_PKGS="$INSTALL_PKGS ca_root_nss"
	VERIFY_PEER="--ca-cert=/usr/local/share/certs/ca-root-nss.crt"
fi


# Install our prerequisites
export ASSUME_ALWAYS_YES=yes
pkg install $INSTALL_PKGS
easy_install eventlet
easy_install iso8601

[ ! `which python2.7` ] && {
	echo 'python2.7 Not Found !' 
	exit 1
	}
PYTHON=`which python2.7`

fetch $VERIFY_PEER -o - $BSDINIT_URL | tar -xzvf - -C '/root'

rm -vf $SSH_DIR/ssh_host*

touch $RC_SCRIPT_FILE
cp -pf $RC_SCRIPT_FILE $RC_BACKUP_FILE
echo "$PYTHON /root/bsd-cloudinit-master/cloudinit --log-file /tmp/cloudinit.log" >> $RC_SCRIPT_FILE
echo "cp -pf $RC_BACKUP_FILE $RC_SCRIPT_FILE " >> $RC_SCRIPT_FILE

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
sed -i 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL' /usr/local/etc/sudoers

# Readme - clean history
echo "==================================================="
echo "If you want to clean the tcsh history, please issue"
echo "    # set history = 0"
echo "==================================================="
