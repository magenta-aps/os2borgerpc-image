#!/usr/bin/env bash

# Setup the configuration we know to be necessary for this
# computer to be "OS2borgerPC ready".

# Will execute the following steps:
# * Overwrite file structure
# * Install packages
# * Create and setup user "user"
#
# The machine will now be a fully functional and standardized
# OS2borgerPC computer which is not, however, registered with the admin
# system nor endowed with local settings such as printers, etc.
#
# After running this script on a fresh Ubuntu install, you can
# customize it to your heart's content - change the wallpaper of the default
# user, add scripts, whatever. Once you're done customizing, please call the
# *finalize* script to launch the setup script on first boot.

printf "\n%s\n" "===== RUNNING: $0 (INSIDE SQUASHFS) ====="

DIR=$(dirname "${BASH_SOURCE[0]}")

# Load VERSION_CODENAME variable below, so it's dynamically set
. /etc/os-release

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Overwrite file tree
"$DIR/do_overwrite.sh"

# Hide some irrelevant shortcuts for Borger
PTH="/home/.skjult/.local/share/applications"
mkdir --parents $PTH
# Note: Firmware Updater, Snap Store and App Center are snaps, so they don't have desktop files under /usr/share/applications/
# Instead, their desktop files are found under /var/lib/snapd/desktop/applications
PROGRAMS="update-manager.desktop usb-creator-gtk.desktop software-properties-drivers.desktop software-properties-gtk.desktop software-properties-livepatch.desktop org.gnome.font-viewer.desktop org.gnome.SystemMonitor.desktop gnome-system-monitor-kde.desktop org.gnome.PowerStats.desktop org.gnome.DiskUtility.desktop nm-connection-editor.desktop org.gnome.seahorse.Application.desktop org.gnome.Logs.desktop org.gnome.baobab.desktop gnome-session-properties.desktop gnome-language-selector.desktop app-center.desktop snap-store_snap-store.desktop firmware-updater_firmware-updater-app.desktop firmware-updater_firmware-updater.desktop"
for program in $PROGRAMS; do
  touch "$PTH/$program"
  chmod a-rwx "$PTH/$program"
done

# Install all necessary packages and dependencies
"$DIR/install_dependencies.sh"

# Ensure the correct, restrictive permissions on this client directory
chmod 700 /var/lib/os2borgerpc

# Prepare for security scripts
mkdir --parents /etc/os2borgerpc/security/

# Set product in configuration
PRODUCT="os2borgerpc"
set_os2borgerpc_config os2_product "$PRODUCT"

# Set version in configuration
VERSION=$(cat "$DIR"/../../VERSION)
set_os2borgerpc_config os2borgerpc_version "$VERSION"

# Remove Bluetooth indicator applet from Borger user
systemctl disable --now bluetooth.service

# Download the dbus-x11 and libllvm19 .deb files to a known folder
# We need dbus-x11 to activate desktop shortcuts and libllvm19 is
# included to stop apt from complaining about "missing file list files"
# Installing/removing these packages during image building does not work
# so we do this instead.
# The packages are later installed from the .deb files by post-install.sh
cd /etc/os2borgerpc/
apt download dbus-x11 libllvm19
cd -

# Prevent future upgrade notifications
sed --in-place "s/Prompt=.*/Prompt=never/" /etc/update-manager/release-upgrades

printf "\n\n%s\n\n" "=== About to run assorted OS2borgerPC scripts ==="

echo "Running scripts from within this image repo"

# Improve Firefox browser security and set other relevant policies
"$DIR/firefox_global_policies.sh" https://borger.dk

# Install Okular and set it as default PDF reader, mostly because it can conveniently also edit PDFs
"$DIR/pdf_reader_switch_default.sh" okular

echo "Running scripts from the scripts repo"

# Cloning script repository
apt-get install --assume-yes git
git clone --depth 1 "$SCRIPTS_CLONE_URL"

# Cloned script directory
SCRIPT_DIR="/os2borgerpc-scripts"

# Move the script for securing grub to another location so post-install can execute it, as somehow only grub-common and not grub2 (and thus not the update-grub command) is available in the image.
cp "$SCRIPT_DIR/common/system/grub_set_password.py" /usr/share/os2borgerpc/bin/

# Initially disable unattended upgrades to prevent problems with initial setup
"$SCRIPT_DIR/common/system/apt_periodic_control.sh" false

# Move unattended upgrades script to another folder so that the related service can run it later
mv "$SCRIPT_DIR/common/system/apt_periodic_control.sh" "/etc/os2borgerpc/"

# Randomize checkins with server.
"$SCRIPT_DIR/common/system/randomize_jobmanager.sh" 5

# Block suspend, shut down and reboot and remove them from the menu
"$SCRIPT_DIR/os2borgerpc/sikkerhed/polkit_policy_shutdown_suspend.sh" True True

# Set background images on login screen and desktop
# Multi user image uses a different image because the Danish one has Danish text on it
if [ "$LANG_ALL" = "true" ]; then
  BG="/usr/share/backgrounds/default_login.png"
else
  BG="/usr/share/backgrounds/default_desktop.svg"
fi
"$SCRIPT_DIR/os2borgerpc/desktop/dconf_desktop_background.sh" $BG

# Hide libreoffice tip of the day
"$SCRIPT_DIR/os2borgerpc/libreoffice/overwrite_libreoffice_config.sh" True False

# Make firefox start maximized
"$SCRIPT_DIR/os2borgerpc/browser/firefox_start_maximized.sh" True

# Remove cloned script repository
rm --recursive "$SCRIPT_DIR"
apt-get remove --assume-yes git

printf "\n\n%s\n\n" "=== Finished running assorted OS2borgerPC scripts ==="

# Enable FSCK automatic fixes
sed --in-place "s/FSCKFIX=no/FSCKFIX=yes/" /lib/init/vars.sh
