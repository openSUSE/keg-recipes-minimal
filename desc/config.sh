#!/bin/bash

# keg: included from common-config
# Copyright (c) 2021 SUSE LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

set -euxo pipefail

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]-[$kiwi_profiles]..."

#======================================
# Setup the build keys
#--------------------------------------
suseImportBuildKey


#======================================
# This is a workaround - someone,
# somewhere needs to load the xts crypto
# module, otherwise luksOpen will fail while
# creating the image.
#--------------------------------------
modprobe xts || true

#======================================
# add missing fonts
#--------------------------------------
# Systemd controls the console font now
echo FONT="eurlatgr.psfu" >> /etc/vconsole.conf

#======================================
# prepare for setting root pw, timezone
#--------------------------------------
echo "** reset machine settings"
rm -f /etc/machine-id \
      /var/lib/zypp/AnonymousUniqueId \
      /var/lib/systemd/random-seed

#======================================
# Specify default systemd target
#--------------------------------------
baseSetRunlevel multi-user.target

#======================================
# Enable cloud-init if installed
#--------------------------------------
echo '** Enabling cloud-init...'
if [ -e /etc/cloud/cloud.cfg ]; then
    systemctl mask systemd-firstboot.service
    
    systemctl enable cloud-init-local
    systemctl enable cloud-init
    systemctl enable cloud-config
    systemctl enable cloud-final
fi

#======================================
# Enable jeos-firstboot
#--------------------------------------
echo '** Enabling jeos-firstboot...'
mkdir -p /var/lib/YaST2
touch /var/lib/YaST2/reconfig_system

systemctl mask systemd-firstboot.service
systemctl enable jeos-firstboot.service

#=====================================
# Configure /etc overlay
#-------------------------------------

# The %post script can't edit /etc/fstab sys due to https://github.com/OSInside/kiwi/issues/945
# so use the kiwi custom hack
cat >/etc/fstab.script <<"EOF"
#!/bin/sh
set -eux

/usr/sbin/setup-fstab-for-overlayfs
# If /var is on a different partition than /...
if [ "$(findmnt -snT / -o SOURCE)" != "$(findmnt -snT /var -o SOURCE)" ]; then
    # ... set options for autoexpanding /var
    gawk -i inplace '$2 == "/var" { $4 = $4",x-growpart.grow,x-systemd.growfs" } { print $0 }' /etc/fstab
fi
EOF
chmod a+x /etc/fstab.script

# To make x-systemd.growfs work from inside the initrd
cat >/etc/dracut.conf.d/50-microos-growfs.conf <<"EOF"
install_items+=" /usr/lib/systemd/systemd-growfs "
EOF


#======================================
# Enable firewalld if installed
#--------------------------------------d
if [ -x /usr/sbin/firewalld ]; then
        systemctl enable firewalld.service
    # punch firewall to allow cockpit ws access
    firewall-offline-cmd --add-service cockpit
fi
~           

#======================================
# Configure SelfInstall specifics
#--------------------------------------
echo '** Configure SelfInstall specifics...'
if [[ "$kiwi_profiles" == *"SelfInstall"* ]]; then
    cat > /etc/systemd/system/selfinstallreboot.service <<-EOF
    [Unit]
    Description=SelfInstall Image Reboot after Firstboot (to ensure ignition and such runs)
    After=systemd-machine-id-commit.service
    Before=jeos-firstboot.service
    
    [Service]
    Type=oneshot
    ExecStart=rm /etc/systemd/system/selfinstallreboot.service
    ExecStart=rm /etc/systemd/system/default.target.wants/selfinstallreboot.service
    ExecStart=systemctl --no-block reboot

    [Install]
    WantedBy=default.target
    EOF
    ln -s /etc/systemd/system/selfinstallreboot.service /etc/systemd/system/default.target.wants/selfinstallreboot.service
else
    echo 'WARNING: Could not find profile named with SelfInstall'
fi


# Enable NetworkManager services if installed
if rpm -q --whatprovides NetworkManager >/dev/null; then
        systemctl enable NetworkManager
        systemctl enable ModemManager
fi

#======================================
# If SELinux is installed, configure it like transactional-update setup-selinux
#--------------------------------------
if [[ -e /etc/selinux/config ]]; then
    # Check if we don't have selinux already enabled.
    grep ^GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | grep -q security=selinux || \
        sed -i -e 's|\(^GRUB_CMDLINE_LINUX_DEFAULT=.*\)"|\1 security=selinux selinux=1"|g' "/etc/default/grub"

    # Adjust selinux config
# FIXME temporary set ALP on permissive mode
#   sed -i -e 's|^SELINUX=.*|SELINUX=enforcing|g' \
#       -e 's|^SELINUXTYPE=.*|SELINUXTYPE=targeted|g' \
#       "/etc/selinux/config"
    sed -i -e 's|^SELINUX=.*|SELINUX=permissive|g' \
        -e 's|^SELINUXTYPE=.*|SELINUXTYPE=targeted|g' \
        "/etc/selinux/config"

    # Move an /.autorelabel file from initial installation to writeable location
    test -f /.autorelabel && mv /.autorelabel /etc/selinux/.autorelabel
fi

#=====================================
# Configure snapper
#-------------------------------------
if [ "${kiwi_btrfs_root_is_snapshot-false}" = 'true' ]; then
    echo "creating initial snapper config ..."
    cp /usr/share/snapper/config-templates/default /etc/snapper/configs/root
    baseUpdateSysConfig /etc/sysconfig/snapper SNAPPER_CONFIGS root
	# Adjust parameters
    sed -i'' 's/^TIMELINE_CREATE=.*$/TIMELINE_CREATE="no"/g' /etc/snapper/configs/root
    sed -i'' 's/^NUMBER_LIMIT=.*$/NUMBER_LIMIT="2-10"/g' /etc/snapper/configs/root
    sed -i'' 's/^NUMBER_LIMIT_IMPORTANT=.*$/NUMBER_LIMIT_IMPORTANT="4-10"/g' /etc/snapper/configs/root
fi

#=====================================
# Enable chrony if installed
#-------------------------------------
echo '** Enabling chronyd...'
if [ -f /etc/chrony.conf ]; then
    systemctl enable chronyd
else
echo '** chrony not installed...'
fi

#======================================
# SSL Certificates Configuration
#--------------------------------------
echo '** Rehashing SSL Certificates...'
update-ca-certificate

#======================================
# Disable recommends on virtual images (keep hardware supplements, see bsc#1089498)
#--------------------------------------
sed -i 's/.*solver.onlyRequires.*/solver.onlyRequires = true/g' /etc/zypp/zypp.conf

#======================================
# Disable installing documentation
#--------------------------------------
sed -i 's/.*rpm.install.excludedocs.*/rpm.install.excludedocs = yes/g' /etc/zypp/zypp.conf

#======================================
# Disable any multiversion packages
#--------------------------------------
sed -i 's/^multiversion =.*/multiversion =/g' /etc/zypp/zypp.conf

# Add products repos before having registration process
# using $basearch; $arch refers to x86_64_v2
echo 'Adding $basearch repos to ALP Micro'
zypper addrepo --refresh --name 'ALP Micro 1.0 Repository' 'https://updates.suse.com/SUSE/Products/ALP-Micro/1.0/$basearch/product/' 'ALP-Micro-1.0'

# Temporary workaround for bsc#1212187
echo "techpreview.ZYPP_MEDIANETWORK=1" >> /etc/zypp/zypp.conf

# fix security level (boo#1171174)
sed -i -e '/^PERMISSION_SECURITY=s/easy/paranoid/' /etc/sysconfig/security
chkstat --set --system

# keg: included from common-services
baseInsertService sshd
