#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason, Marcus Funch

: << 'COMMENT'
Policy-script developed by Magenta ApS for Aarhus Municipality.

Learn more about Firefox "Policy Names" here:
https://github.com/mozilla/policy-templates/blob/master/README.md

It's only possible to have ONE policy-file. In the future this script
should have to evolve to be a more dynamic solution if we want to be
able to, e.g. use the same script across machines and handpick which
Policies we want to use. Until then there will be set some default static
Policies with OS2borgerPC in mind.

TODO: Add some background for why we have each policy
COMMENT

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

STARTPAGE="$1"
ADDITIONAL_PAGES="$2"

POLICY_DIR="/etc/firefox/policies"
POLICY_FILE="$POLICY_DIR/policies.json"
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"

PDF_TYPE_1=application/pdf
PDF_TYPE_2=application/x-bzpdf
PDF_TYPE_3=application/x-gzpdf
PDF_TYPE_4=application/x-lzpdf
PDF_TYPE_5=application/x-xzpdf
PROGRAMS_TO_REMOVE="libreoffice-draw.desktop;google-chrome.desktop;microsoft-edge.desktop;chromium_chromium.desktop;firefox_firefox.desktop"

if [ -z "$STARTPAGE" ]; then
  echo "WARNING: Missing <URL> argument. Unable to set Firefox startpage."
  exit 1
fi

mkdir --parents "$POLICY_DIR"

PAGES_STRING=""
if [ -n "$ADDITIONAL_PAGES" ]; then
  IFS='|' read -ra PAGES_ARRAY <<< "$ADDITIONAL_PAGES"

  PAGES_STRING="\"Additional\": [" # start array-string
  for PAGE in "${PAGES_ARRAY[@]}"; do
    PAGES_STRING+="\"$PAGE\","
  done
  PAGES_STRING=${PAGES_STRING::-1} # remove comma at end of list
  PAGES_STRING+="]," # finish array-string
fi

cat << EOF > "$POLICY_FILE"
{
  "policies": {
    "BlockAboutAddons": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "DisableBuiltinPDFViewer": true,
    "DisableDeveloperTools": true,
    "DisableFirefoxAccounts": true,
    "DisableFormHistory": true,
    "DisableProfileImport": true,
    "EnableTrackingProtection": {
      "Cryptomining": true,
      "Fingerprinting": true,
      "Locked": true,
      "Value": true
    },
    "FirefoxHome": {
      "SponsoredTopSites": false,
      "Pocket": false,
      "SponsoredPocket": false,
      "Locked": true
    },
    "Handlers": {
      "extensions": {
         "pdf": {
            "action": "useSystemDefault",
            "ask": false
        }
      }
    },
    "Homepage": {
      "URL": "$STARTPAGE",
      "Locked": true,
      $PAGES_STRING
      "StartPage": "homepage"
    },
    "InstallAddonsPermission": {
      "Default": false
    },
    "OfferToSaveLogins": false,
    "OfferToSaveLoginsDefault": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "PasswordManagerEnabled": false,
    "Preferences": {
      "datareporting.policy.dataSubmissionPolicyBypassNotification": true
    },
    "SanitizeOnShutdown": {
      "Cache": true,
      "Cookies": true,
      "Downloads": false,
      "FormData": true,
      "History": true,
      "Locked": true,
      "OfflineApps": true,
      "Sessions": true,
      "SiteSettings": true
    },
    "SearchEngines": {
      "PreventInstalls": true
    }
  }
}
EOF

# Make sure the mime file exists
if [ ! -f $GLOBAL_MIME_FILE ]; then
	cat <<- EOF > $GLOBAL_MIME_FILE
[Default Applications]
EOF
fi

# Force Okular OR Evince to be the only PDF applications listed for the PDF filetypes,
# to prevent programs like firefox from making gnome-desktop-portal prompt for which application to open the PDF with, when Firefox is set to use the external PDF reader
# The contents of this section is shared by the firefox and okular scripts
if ! grep "Removed Associations" $GLOBAL_MIME_FILE; then
	cat <<- EOF >> "$GLOBAL_MIME_FILE"
		[Removed Associations]
		$PDF_TYPE_1=$PROGRAMS_TO_REMOVE
		$PDF_TYPE_2=$PROGRAMS_TO_REMOVE
		$PDF_TYPE_3=$PROGRAMS_TO_REMOVE
		$PDF_TYPE_4=$PROGRAMS_TO_REMOVE
		$PDF_TYPE_5=$PROGRAMS_TO_REMOVE
	EOF
fi

# Remove the policy from its former standard location if present.
rm --force /usr/lib/firefox/distribution/policies.json
