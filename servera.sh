#!/bin/bash

current_hostname=$(hostname)
new_hostname="servera"

if [ "$current_hostname" != "$new_hostname" ]; then
    echo "Changing hostname from $current_hostname to $new_hostname"
    hostnamectl set-hostname "$new_hostname"
    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
    echo "Hostname changed to $new_hostname"
else
    echo "Hostname is already $new_hostname"
fi

# Root password
echo "Setting root password..."
echo "root:atenorth" | chpasswd

# Remove bzip2 if present
yum remove -y bzip2 || true

echo "Installing httpd..."
yum install -y httpd

echo "Starting and enabling httpd..."
systemctl start httpd
systemctl enable httpd


CONF_FILE="/etc/httpd/conf/httpd.conf"
BACKUP_FILE="/etc/httpd/conf/httpd.conf.bak"
cp "$CONF_FILE" "$BACKUP_FILE"
echo "Updating Listen directives from port 80 to 82 in all httpd configuration files..."
grep -rl "Listen 80" /etc/httpd | xargs sed -i 's/Listen 80/Listen 82/g'

echo "Restarting httpd service..."
systemctl restart httpd

if systemctl is-active --quiet httpd; then
    echo "Port successfully changed to 82 and httpd restarted."
else
    echo "Warning: httpd failed to restart. Reverting to backup..."
    cp "$BACKUP_FILE" "$CONF_FILE"
    systemctl restart httpd
fi


echo "Creating files in /var/www/html..."
mkdir -p /var/www/html
printf "Welcome to RHCSA Examination\n" > /var/www/html/file1
printf "Welcome to RHCSA Examination\n" > /var/www/html/file2
printf "Welcome to RHCSA Examination\n" > /var/www/html/file3
# set file1 to a non-httpd SELinux type (harmless if permissive)
chcon -t user_home_t /var/www/html/file1 || true

echo "Creating specified users..."
for username in remoteuser2 aslan simone alex; do
    id "$username" &>/dev/null || useradd "$username"
    echo "$username:atenorth" | chpasswd
done
echo "Users created."

yum install -y git

REPO_URL="https://github.com/codexchangee/rhel-manpages.git"
TMP_DIR="/tmp/rhel-manpages"

echo "Checking if manpage repo is public..."
if git ls-remote "$REPO_URL" &>/dev/null; then
    echo "Repo is public. Installing man pages..."
    rm -rf "$TMP_DIR"
    git clone --depth 1 "$REPO_URL" "$TMP_DIR"
    if [ -d "$TMP_DIR/man1" ]; then
        cp -f "$TMP_DIR"/man1/*.1 /usr/share/man/man1/
        mandb || true
    else
        echo "man1 directory not found in repo, skipping man page install."
    fi
    # Create /usr/sbin/ex200 script (as requested)
    cat >/usr/sbin/ex200 <<'EOF'
#!/bin/bash
if [ -f ~/.ex200/ex200.conf ]; then
        cat ~/.ex200/ex200.conf
else
        echo "There Is No Message For You Dude"
fi
EOF
    chmod +x /usr/sbin/ex200

fi


echo "Checking if GUI is installed..."
if ! rpm -qa | grep -q "gnome-session"; then
    echo "GUI not found. Installing Server with GUI..."
    dnf group install -y "Server with GUI" --nobest || yum group install -y "Server with GUI" --nobest || true
else
    echo "GUI is already installed."
fi

echo "Installing GUI packages..."

dnf groupinstall -y "Server with GUI" || true

dnf install -y gdm xorg-x11-xinit || true

systemctl enable gdm --now || true

echo "Configuring network to automatic (DHCP)..."
if command -v nmcli >/dev/null 2>&1; then
    nmcli -t -f NAME,TYPE connection show \
      | awk -F: '/:(ethernet|wifi|bridge|bond|vlan)$/{print $1}' \
      | while read -r conn; do
            [ -n "$conn" ] || continue
            nmcli connection modify "$conn" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns "" || true
            nmcli connection modify "$conn" ipv6.method auto || true
            nmcli connection modify "$conn" connection.autoconnect yes || true
            nmcli connection up "$conn" || true
        done
else
    for ifcfg in /etc/sysconfig/network-scripts/ifcfg-*; do
        [ -f "$ifcfg" ] || continue
        sed -i -e 's/^BOOTPROTO=.*/BOOTPROTO=dhcp/' \
               -e 's/^ONBOOT=.*/ONBOOT=yes/' \
               -e '/^IPADDR/d;/^PREFIX/d;/^NETMASK/d;/^GATEWAY/d;/^DNS.*/d' "$ifcfg"
    done
    systemctl try-restart NetworkManager.service || systemctl try-restart network.service || true
fi

echo "Script completed successfully."
history -c || true
rm -- "$0" || true
echo "Rebooting the system..."
reboot
