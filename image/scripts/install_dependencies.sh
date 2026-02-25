#!/usr/bin/env bash

set -x

printf "\n\n%s\n\n" "Installing dependencies"

# Find current directory

DIR=$(dirname "${BASH_SOURCE[0]}")

# The DEPENDENCIES file contains packages/programs
# required by OS2borgerPC.
DEPENDENCIES=( $(cat "$DIR/DEPENDENCIES") )

if [ "$LANG_ALL" = "true" ]; then
  # Add support for specific languages besides those preinstalled
  LN="sv"
else
  # The current default: Only add support for Danish
  LN="da"
fi

dpkg --list | grep "^ii" > /tmp/scripts_installed_packages_list.txt

for package in "${DEPENDENCIES[@]}"
do
    grep --word-regexp "ii  $package " /tmp/scripts_installed_packages_list.txt > /dev/null
    if [[ $? -ne 0 ]]; then
        PKGS_TO_INSTALL=$PKGS_TO_INSTALL" "$package
    fi
done


if [ "$PKGS_TO_INSTALL" != "" ]; then
    echo  -n "Some dependencies are missing."
    echo " The following packages will be installed: $PKGS_TO_INSTALL"

    # Step 2: Do the actual installation. Abort if it fails.
    # and install
    # shellcheck disable=SC2086 # We want word-splitting here
    apt-get --assume-yes install $PKGS_TO_INSTALL | tee /tmp/os2borgerpc_install_log.txt
    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
        echo "" 1>&2
        echo "ERROR: Installation of dependencies failed." 1>&2
        echo "Please note that \"universe\" repository MUST be enabled" 1>&2
        echo "" 1>&2
        exit 1
    fi
else
    echo "No dependencies missing...?"
fi

echo "Install any missing language support packages for the missing target languages specifically"
# shellcheck disable=SC2046 # We want word-splitting here
apt-get install --assume-yes $(check-language-support -l $LN) $(check-language-support -l en)
# Mark language support packages as explicitly installed as otherwise it seems later stages gets rid of some of them
# shellcheck disable=SC2046 # We want word-splitting here
apt-mark manual $(check-language-support -l $LN --show-installed) $(check-language-support -l en --show-installed)

# Download the language support packages to a known folder because the Ubuntu 24.04 installer seems to get rid of
# some of them even if they're marked as explicitly installed
cd /etc/os2borgerpc
apt download $(check-language-support -l $LN --show-installed) $(check-language-support -l en --show-installed) language-pack-$LN-base language-pack-en-base language-pack-gnome-$LN-base language-pack-gnome-en-base hyphen-$LN libreoffice-help-$LN libreoffice-l10n-$LN mythes-$LN
cd -

# Necessary pipx setup
echo 'PIPX_BIN_DIR="/usr/local/bin"' >> /etc/environment

# Even though we've added PIPX_BIN_DIR to /etc/environment, we still set it here
# because changes to /etc/environment do not take effect until the session is reloaded
# We fix the version of chardet to prevent a dependency warning from requests
# Check if this is still necessary during next image build
PIPX_BIN_DIR="/usr/local/bin" pipx install os2borgerpc-client --pip-args "chardet<6.0"
