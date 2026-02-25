#!/usr/bin/env bash

printf "\n\n%s\n\n" "===== RUNNING: $0 ====="

# Now do the deed
DIR=$(dirname "$(realpath "$0" )")
cp --recursive "$DIR"/../overwrites/* /

# Permissions fixup
chmod 0400 "/home/.skjult/.local/share/keyrings/Standardnøglering.keyring"
# Set more restrictive permissions on some system files
chmod 0700 "/usr/share/os2borgerpc/bin/user-cleanup.bash"

# Set correct permissions on the gio scripts
chmod u+x "/usr/share/os2borgerpc/bin/gio-fix-desktop-file-permissions.sh"
chmod +x "/usr/share/os2borgerpc/bin/gio-dbus.sh"

# Set the correct, default permissions on files related to the login manager
chmod 755 /etc/gdm3/PostSession/Default

# Update dconf with settings from overwrites.
dconf update
