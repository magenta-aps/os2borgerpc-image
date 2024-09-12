#! /usr/bin/env sh

set -x

# We don't want these files to affect the installation itself, so adding them after the installation has completed.
# Regarding late-commands: "The commands are run in the installer environment with the installed system mounted at ."
# https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html#user-data

DIR="$(dirname "$0")"
POST_INSTALL_LOG=/home/superuser/post-install-log.txt

echo "Base dir: $DIR" > $POST_INSTALL_LOG

# Create our default post session config for gdm, which runs user-cleanup
cp "$DIR/files/Default" /etc/gdm3/PostSession/Default >> $POST_INSTALL_LOG

# Restrict the ability to change network settings
# 50-local.d isn't there by default: Create it
mkdir --parents /etc/polkit-1/localauthority/50-local.d
cp "$DIR/files/networkmanager.pkla" /etc/polkit-1/localauthority/50-local.d/ >> $POST_INSTALL_LOG

# Make gdm3 start the firstboot script at login manager startup
sed --in-place "\@exit 0@i/usr/share/os2borgerpc/bin/firstboot.sh > /home/superuser/firstboot-log.txt" /etc/gdm3/Init/Default >> $POST_INSTALL_LOG

# Create our default config for gdm
cat << EOF > /etc/gdm3/custom.conf
[daemon]

[security]
DisallowTCP=true

[xdmcp]

[chooser]

# Without this, Borger isn't show because it defaults to being passwordless
[greeter]
Include=user,superuser

[debug]
EOF
