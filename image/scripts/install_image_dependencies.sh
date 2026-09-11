#!/usr/bin/env bash

set -x

printf "\n\n%s\n\n" "Installing dependencies"

# The DEPENDENCIES file contains packages/programs required by OS2borgerPC.
DEPENDENCIES="pulseaudio-utils pwgen pipx"

if [ "$LANG_ALL" = "true" ]; then
  # Add support for specific languages besides those preinstalled
  LN="sv"
else
  # The current default: Only add support for Danish
  LN="da"
fi

# shellcheck disable=SC2086 # We want word-splitting here
if ! apt-get install --assume-yes $DEPENDENCIES; then
  printf "%s\n" "ERROR: Installation of dependencies failed." 1>&2
  exit 1
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
apt download $(check-language-support -l $LN --show-installed) $(check-language-support -l en --show-installed) language-pack-$LN-base language-pack-en-base language-pack-gnome-$LN-base language-pack-gnome-en-base libreoffice-help-common hyphen-$LN libreoffice-help-$LN libreoffice-l10n-$LN mythes-$LN
cd -

# Necessary pipx setup
echo 'PIPX_BIN_DIR="/usr/local/bin"' >> /etc/environment

# Even though we've added PIPX_BIN_DIR to /etc/environment, we still set it here
# because changes to /etc/environment do not take effect until the session is reloaded
# We fix the version of chardet because newer versions were rewritten using an LLM
PIPX_BIN_DIR="/usr/local/bin" pipx install os2borgerpc-client --pip-args "chardet<6.0"
