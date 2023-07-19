# fix security level (boo#1171174)
sed -i -e '/^PERMISSION_SECURITY=s/easy/paranoid/' /etc/sysconfig/security
chkstat --set --system
