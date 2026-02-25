#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Heini Leander Ovason, Marcus Funch

PDF_READER_TO_SWITCH_TO=$1

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

set -x

if [ "$PDF_READER_TO_SWITCH_TO" != "evince" ] && [ "$PDF_READER_TO_SWITCH_TO" != "okular" ]; then
  echo "Currently this script only supports evince and okular, so specify either of those."
  echo "Exiting."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"
OLD_GLOBAL_MIME_FILE="/usr/share/applications/defaults.list"
OKULAR_CONFIG_1="/home/.skjult/.config/okularpartrc"
OKULAR_CONFIG_2="/home/.skjult/.local/share/kxmlgui5/okular/part.rc"

PDF_TYPE_1=application/pdf
PDF_TYPE_2=application/x-bzpdf
PDF_TYPE_3=application/x-gzpdf
PDF_TYPE_4=application/x-lzpdf
PDF_TYPE_5=application/x-xzpdf
PROGRAMS_TO_REMOVE="libreoffice-draw.desktop;com.google.Chrome.desktop;google-chrome.desktop;microsoft-edge.desktop;chromium_chromium.desktop;firefox_firefox.desktop"

# Removes PDF programs from the Default Applications section in the specified file
cleanup_mime_file_default() {
  MIME_FILE=$1
  sed --in-place "/Default Applications/,/Removed Associations/ \
  {\@$PDF_TYPE_1\|$PDF_TYPE_2\|$PDF_TYPE_3\|$PDF_TYPE_4\|$PDF_TYPE_5@d}" "$MIME_FILE"
}

set_default_pdf_reader() {

  PROGRAM=$1

  [ "$PROGRAM" = "okular" ] && DESKTOP_FILE=okularApplication_kimgio.desktop
  [ "$PROGRAM" = "evince" ] && DESKTOP_FILE=org.gnome.Evince.desktop

  # Idempotency and cleanup
  cleanup_mime_file_default $GLOBAL_MIME_FILE
  [ -f $OLD_GLOBAL_MIME_FILE ] && cleanup_mime_file_default $OLD_GLOBAL_MIME_FILE

  # Clean up from earlier versions of this script
  OLD_USER_MIME_FILE="/home/.skjult/.config/mimeapps.list"
  [ -f $OLD_USER_MIME_FILE ] && cleanup_mime_file_default $OLD_USER_MIME_FILE

  sed --in-place "/Default Applications/a \
$PDF_TYPE_1=$DESKTOP_FILE\n\
$PDF_TYPE_2=$DESKTOP_FILE\n\
$PDF_TYPE_3=$DESKTOP_FILE\n\
$PDF_TYPE_4=$DESKTOP_FILE\n\
$PDF_TYPE_5=$DESKTOP_FILE" "$GLOBAL_MIME_FILE"
}

# SCRIPT PROPER

apt-get update

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
EOF
fi
# Delete everything after "[Removed Associations] for idempotency
sed --in-place "/Removed Associations/q" $GLOBAL_MIME_FILE

cat <<- EOF >> "$GLOBAL_MIME_FILE"
$PDF_TYPE_1=$PROGRAMS_TO_REMOVE
$PDF_TYPE_2=$PROGRAMS_TO_REMOVE
$PDF_TYPE_3=$PROGRAMS_TO_REMOVE
$PDF_TYPE_4=$PROGRAMS_TO_REMOVE
$PDF_TYPE_5=$PROGRAMS_TO_REMOVE
EOF

if [ "$PDF_READER_TO_SWITCH_TO" = "okular" ]; then

  apt-get install --assume-yes okular
  set_default_pdf_reader "$PDF_READER_TO_SWITCH_TO"

	cat <<- EOF > $OKULAR_CONFIG_1
	[General]
	ttsEngine=flite

	[Reviews]
	AnnotationTools=<tool type="typewriter" id="1"><engine type="PickPoint" block="true"><annotation type="Typewriter" width="0" textColor="#ff000000" color="#00ffffff"/></engine><shortcut>1</shortcut></tool>,<tool type="note-linked" id="2"><engine type="PickPoint" hoverIcon="tool-note" color="#ffffff00"><annotation type="Text" color="#ffffff00" icon="Note"/></engine><shortcut>2</shortcut></tool>,<tool type="note-inline" id="3"><engine type="PickPoint" hoverIcon="tool-note-inline" color="#ffffff00" block="true"><annotation type="FreeText" color="#ffffff00"/></engine><shortcut>3</shortcut></tool>,<tool type="ink" id="4"><engine type="SmoothLine" color="#ff00ff00"><annotation type="Ink" width="2" color="#ff00ff00"/></engine><shortcut>4</shortcut></tool>,<tool type="highlight" id="5"><engine type="TextSelector" color="#ffffff00"><annotation type="Highlight" color="#ffffff00"/></engine><shortcut>5</shortcut></tool>,<tool type="straight-line" id="6"><engine type="PolyLine" color="#ffffe000" points="2"><annotation type="Line" width="1" color="#ffffe000"/></engine><shortcut>6</shortcut></tool>,<tool type="polygon" id="7"><engine type="PolyLine" color="#ff007eee" points="-1"><annotation type="Line" width="1" color="#ff007eee"/></engine><shortcut>7</shortcut></tool>,<tool type="stamp" id="8"><engine type="PickPoint" hoverIcon="okular" size="64" block="true"><annotation type="Stamp" icon="okular"/></engine><shortcut>8</shortcut></tool>,<tool type="underline" id="9"><engine type="TextSelector" color="#ff000000"><annotation type="Underline" color="#ff000000"/></engine><shortcut>9</shortcut></tool>,<tool type="ellipse" id="10"><engine type="PickPoint" color="#ff00ffff" block="true"><annotation type="GeomCircle" width="5" color="#ff00ffff"/></engine></tool>
	EOF

  mkdir --parents "$(dirname $OKULAR_CONFIG_2)"

	cat <<- EOF > $OKULAR_CONFIG_2
	<!DOCTYPE kpartgui>
	<kpartgui name="okular_part" version="42">
	 <MenuBar>
	  <Menu name="file" noMerge="1">
	   <text translationDomain="okular">&amp;File</text>
	   <Action name="get_new_stuff" group="file_open"/>
	   <Action name="import_ps" group="file_open"/>
	   <Action name="file_save" group="file_save"/>
	   <Action name="file_save_as" group="file_save"/>
	   <Action name="file_reload" group="file_save"/>
	   <Action name="file_print" group="file_print"/>
	   <Action name="file_print_preview" group="file_print"/>
	   <Action name="open_containing_folder" group="file_print"/>
	   <Action name="properties" group="file_print"/>
	   <Action name="embedded_files" group="file_print"/>
	   <Action name="file_export_as" group="file_print"/>
	   <Action name="file_share" group="file_print"/>
	  </Menu>
	  <Menu name="edit" noMerge="1">
	   <text translationDomain="okular">&amp;Edit</text>
	   <Action name="edit_undo"/>
	   <Action name="edit_redo"/>
	   <Separator/>
	   <Action name="edit_copy"/>
	   <Separator/>
	   <Action name="edit_select_all"/>
	   <Action name="edit_select_all_current_page"/>
	   <Separator/>
	   <Action name="edit_find"/>
	   <Action name="edit_find_next"/>
	   <Action name="edit_find_prev"/>
	  </Menu>
	  <Menu name="view" noMerge="1">
	   <text translationDomain="okular">&amp;View</text>
	   <Action name="presentation"/>
	   <Separator/>
	   <Action name="view_zoom_in"/>
	   <Action name="view_zoom_out"/>
	   <Action name="view_actual_size"/>
	   <Action name="view_fit_to_width"/>
	   <Action name="view_fit_to_page"/>
	   <Action name="view_auto_fit"/>
	   <Separator/>
	   <Action name="view_continuous"/>
	   <Action name="view_render_mode"/>
	   <Separator/>
	   <Menu name="view_orientation" noMerge="1">
	    <text translationDomain="okular">&amp;Orientation</text>
	    <Action name="view_orientation_rotate_ccw"/>
	    <Action name="view_orientation_rotate_cw"/>
	    <Action name="view_orientation_original"/>
	   </Menu>
	   <Action name="view_pagesizes"/>
	   <Action name="view_trim_mode"/>
	   <Separator/>
	   <Action name="view_toggle_forms"/>
	  </Menu>
	  <Menu name="go" noMerge="1">
	   <text translationDomain="okular">&amp;Go</text>
	   <Action name="go_previous"/>
	   <Action name="go_next"/>
	   <Separator/>
	   <Action name="first_page"/>
	   <Action name="last_page"/>
	   <Separator/>
	   <Action name="go_document_back"/>
	   <Action name="go_document_forward"/>
	   <Separator/>
	   <Action name="go_goto_page"/>
	  </Menu>
	  <Menu name="bookmarks" noMerge="1">
	   <text translationDomain="okular">&amp;Bookmarks</text>
	   <Action name="bookmark_add"/>
	   <Action name="rename_bookmark"/>
	   <Action name="previous_bookmark"/>
	   <Action name="next_bookmark"/>
	   <Separator/>
	   <ActionList name="bookmarks_currentdocument"/>
	  </Menu>
	  <Menu name="tools" noMerge="1">
	   <text translationDomain="okular">&amp;Tools</text>
	   <Action name="mouse_drag"/>
	   <Action name="mouse_zoom"/>
	   <Action name="mouse_select"/>
	   <Action name="mouse_textselect"/>
	   <Action name="mouse_tableselect"/>
	   <Action name="mouse_magnifier"/>
	   <Separator/>
	   <Action name="mouse_toggle_annotate"/>
	   <Separator/>
	   <Action name="speak_document"/>
	   <Action name="speak_current_page"/>
	   <Action name="speak_stop_all"/>
	   <Action name="speak_pause_resume"/>
	  </Menu>
	  <Menu name="settings" noMerge="1">
	   <text translationDomain="okular">&amp;Settings</text>
	   <Action name="show_leftpanel" group="show_merge"/>
	   <Action name="show_bottombar" group="show_merge"/>
	   <Action name="options_configure_generators" group="configure_merge"/>
	   <Action name="options_configure" group="configure_merge"/>
	  </Menu>
	  <Menu name="help" noMerge="1">
	   <text translationDomain="okular">&amp;Help</text>
	   <Action name="help_about_backend" group="about_merge"/>
	  </Menu>
	 </MenuBar>
	 <ToolBar name="mainToolBar" noMerge="1">
	  <text translationDomain="okular">Main Toolbar</text>
	  <Action name="go_previous"/>
	  <Action name="go_next"/>
	  <Separator name="separator_0"/>
	  <Action name="zoom_to"/>
	  <Action name="view_zoom_out"/>
	  <Action name="view_zoom_in"/>
	  <Separator name="separator_1"/>
	  <Action name="mouse_drag"/>
	  <Action name="mouse_zoom"/>
	  <Action name="mouse_selecttools"/>
	  <Action name="mouse_toggle_annotate"/>
	 </ToolBar>
	 <ActionProperties scheme="Default">
	  <Action name="mouse_toggle_annotate" iconText="Indsæt tekst"/>
	 </ActionProperties>
	</kpartgui>
	EOF
else
  apt-get install --assume-yes evince
  apt-get remove --assume-yes okular
  set_default_pdf_reader "$PDF_READER_TO_SWITCH_TO"

  rm --force $OKULAR_CONFIG_1 $OKULAR_CONFIG_2
fi
