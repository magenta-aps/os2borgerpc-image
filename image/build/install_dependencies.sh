#!/bin/bash

printf "\n\n%s\n\n" "===== RUNNING: $0 ====="

# Find current directory

export DEBIAN_FRONTEND=noninteractive
DEPENDENCIES="squashfs-tools genisoimage p7zip-full xorriso figlet"

PKGS_TO_INSTALL=""

dpkg -l | grep "^ii" > /tmp/build_installed_packages_list.txt

for package in $DEPENDENCIES; do
    if ! grep --quiet -w "ii  $package " /tmp/build_installed_packages_list.txt; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL $package"
    fi
done

if [ "$PKGS_TO_INSTALL" != "" ]; then
    echo  -n "Some build dependencies are missing on the host system."
    echo " The following packages will be installed: $PKGSTOINSTALL"

    sudo apt-get update --quiet
    # shellcheck disable=SC2086 # We want word-splitting here
    if ! apt-get install --assume-yes $PKGS_TO_INSTALL; then
        exit 1
    fi
fi
