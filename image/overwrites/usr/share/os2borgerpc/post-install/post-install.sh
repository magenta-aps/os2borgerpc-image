#! /usr/bin/env sh

set -x

# We don't want these files to affect the installation itself, so adding them after the installation has completed.
# Regarding late-commands: "The commands are run in the installer environment with the installed system mounted at ."
# https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html#user-data

DIR="$(dirname "$0")"

# Create our default post session config for gdm, which runs user-cleanup
cp "$DIR/files/Default" /etc/gdm3/PostSession/Default
chmod 700 /etc/gdm3/PostSession/Default

# Install dbus-x11 for dbus-launch and language support packages from .deb files
dpkg -i /etc/os2borgerpc/*.deb

# Secure GRUB as GRUB should now be fully installed, unlike at the time the image is being created
/usr/share/os2borgerpc/bin/grub_set_password.py "$(pwgen -N 1 -s 12)"

# Remove user access to settings. This also hides settings from user
PROGRAM_PATH="/usr/bin/gnome-control-center"
dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true

# Remove user access to terminal
PROGRAM_PATH="/usr/bin/gnome-terminal"
dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH" || true
dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH.real" || true

# Adding this group here as we need it when adding the user
groupadd nopasswdlogin

# Setup default user
useradd user --create-home --password 12345 --shell /bin/bash --user-group --groups nopasswdlogin --comment Borger

# Transfer relevant files to /home/superuser
# and delete the temporary directory
rsync -az /home/superuser_dir/ /home/superuser/
rm --force --recursive /home/superuser_dir/
chown --recursive superuser:superuser /home/superuser/
chmod 750 /home/superuser/

# For some reason, Ubuntu 24 does not keep the language packages installed during image building
# even though we mark them as manually installed. As a result, we install them from local .deb-files
# earlier in this script. The lack of installed language packages during the actual installation also
# results in the user and superuser directories initially being created with english names (the fallback).
# The incorrect superuser directories are removed here. The correct superuser directories are created by
# a .config/autostart script that also moves and activates the superuser shortcuts
# The user directories are fixed when user-cleanup.bash is run on first boot, provided that we ensure
# that the locale is correctly set at that time. Even if we do not ensure that locale is correctly set
# at the time of first boot, the system itself will set it correctly after first boot so the user directories
# will always be fixed when user-cleanup.bash is run for the first time after first boot.
rm -rf /home/superuser/Desktop /home/superuser/Documents /home/superuser/Downloads /home/superuser/Music \
  /home/superuser/Pictures /home/superuser/Public /home/superuser/Templates /home/superuser/Videos
# These lines are just meant to ensure that danish locale is set correctly at the time of first boot
# In the case of multilang images, the danish locale is overwritten by the swedish locale in a later
# late-command. If a language other than swedish is selected, the system itself will set the correct
# locale after first boot.
echo "LANG=da_DK.UTF-8" > /etc/locale.conf
ln --symbolic /etc/locale.conf /etc/default/locale

# Setup passwdless login of user
PAM_GDM=/etc/pam.d/gdm-password
sed -i "/include common-auth/i auth sufficient pam_succeed_if.so user ingroup nopasswdlogin" $PAM_GDM

# Setup service to run user-cleanup on system startup or shutdown
OS2BORGERPC_CLEANUP_SERVICE="/etc/systemd/system/os2borgerpc-cleanup.service"
cat << EOF > $OS2BORGERPC_CLEANUP_SERVICE
[Unit]
Description=OS2borgerPC user directory cleanup

[Service]
Type=oneshot
ExecStart=/usr/share/os2borgerpc/bin/user-cleanup.bash
RemainAfterExit=yes
ExecStop=/usr/share/os2borgerpc/bin/user-cleanup.bash

[Install]
WantedBy=multi-user.target
EOF

systemctl enable "$(basename $OS2BORGERPC_CLEANUP_SERVICE)"

# Setup service to run first-logout script on shutdown or reboot
FIRST_LOGOUT_SCRIPT="/etc/os2borgerpc/post-session-scripts/first-logout.sh"
FIRST_LOGOUT_SERVICE="/etc/systemd/system/first_logout.service"

cat << EOF > $FIRST_LOGOUT_SERVICE
[Unit]
Description=First logout service
DefaultDependencies=no

[Service]
Type=simple
ExecStart=$FIRST_LOGOUT_SCRIPT

[Install]
WantedBy=halt.target reboot.target shutdown.target multi-user.target
EOF

systemctl enable "$(basename $FIRST_LOGOUT_SERVICE)"

# Setup delayed start of unattended upgrades
TIME_TO_START=$(date -d 'now+4hours' +%FT%R)
mkdir --parents "/usr/local/lib/os2borgerpc"
UNATTENDED_UPGRADES_DELAY="/usr/local/lib/os2borgerpc/unattended_upgrades_delay.py"
UNATTENDED_UPGRADES_DELAY_SERVICE="/etc/systemd/system/os2borgerpc-unattended_upgrades_delay.service"
START_UNATTENDED_UPGRADES="/usr/local/lib/os2borgerpc/start_unattended_upgrades.sh"
cat <<EOF > $UNATTENDED_UPGRADES_DELAY
#!/usr/bin/env python3

import datetime
import time
import subprocess

TIME_TO_START = datetime.datetime.fromisoformat("$TIME_TO_START")

def main():
    while True:
        time.sleep(60)
        NOW = datetime.datetime.now()
        if NOW > TIME_TO_START:
            # Setup unattended upgrades
            subprocess.call("$START_UNATTENDED_UPGRADES")
            break

if __name__ == "__main__":
    main()
EOF

chmod 700 $UNATTENDED_UPGRADES_DELAY

cat <<EOF > $START_UNATTENDED_UPGRADES
#!/usr/bin/env bash

# setup unattended upgrades
"/etc/os2borgerpc/apt_periodic_control.sh" security

# disable the delay service
systemctl disable "$(basename $UNATTENDED_UPGRADES_DELAY_SERVICE)"

# delete the related files
rm --force $UNATTENDED_UPGRADES_DELAY $UNATTENDED_UPGRADES_DELAY_SERVICE $START_UNATTENDED_UPGRADES \
           /etc/os2borgerpc/apt_periodic_control.sh
EOF

chmod 700 $START_UNATTENDED_UPGRADES

cat <<EOF > $UNATTENDED_UPGRADES_DELAY_SERVICE
[Unit]
Description=OS2borgerPC delay unattended upgrades service

[Service]
Type=simple
ExecStart=$UNATTENDED_UPGRADES_DELAY

[Install]
WantedBy=multi-user.target
EOF

systemctl enable "$(basename $UNATTENDED_UPGRADES_DELAY_SERVICE)"

# Setup service to run automatic_registration.sh
AUTOMATIC_REGISTRATION_SERVICE="/etc/systemd/system/os2borgerpc-automatic_registration.service"
AUTOMATIC_REGISTRATION_SCRIPT="/usr/share/os2borgerpc/bin/automatic_registration.sh"
cat << EOF > $AUTOMATIC_REGISTRATION_SERVICE
[Unit]
Description=OS2borgerPC automatic registration service

[Service]
Type=simple
ExecStart=$AUTOMATIC_REGISTRATION_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

chmod 700 $AUTOMATIC_REGISTRATION_SCRIPT

systemctl enable "$(basename $AUTOMATIC_REGISTRATION_SERVICE)"

# We remove the following programs here, because they're either not installed during prepare.sh(?!)
# so we can't remove them there or removing them earlier causes apt to complain about "missing file list files"
# libfprint-2-2 because it fails during installation/updating because of an unmet interactive step, but we don't need finger print reading anyway so we can delete it
# apport and whoopsie because error reporting popping up is distracting on public pcs
# ...and the rest because they likely aren't needed by users
apt-get remove --assume-yes --purge deja-dup kdeconnect remmina thunderbird transmission-gtk apport evince libfprint-2-2 nautilus-extension-gnome-terminal nautilus-sendto openvpn whoopsie
apt-get autoremove
apt-get clean

# Create our default config for gdm
cat << EOF > /etc/gdm3/custom.conf
[daemon]
WaylandEnable=false

[security]
DisallowTCP=true

[xdmcp]

[chooser]

[debug]
EOF

# Run any added custom scripts
CUSTOM_SCRIPTS=$(find /usr/share/os2borgerpc/post-install/custom_scripts/ -maxdepth 1 -regex ".*\.sh\|.*\.py")
for FILE in $CUSTOM_SCRIPTS; do
  sed --in-place "s/\r//" "$FILE"
  "$FILE"
done

# Cleanup the files used for post-install
rm --recursive /etc/os2borgerpc/*.deb /usr/share/os2borgerpc/bin/grub_set_password.py $DIR/
