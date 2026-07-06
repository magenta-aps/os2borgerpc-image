# Technical information about the image building process

## Script execution order

From earliest to latest.

Relevant when determining where something should be inserted, and to know what has been done/exists at a given stage.

build_image.sh
-> build/install_dependencies.sh
-> build/extract_iso.sh
-> build/chroot.sh squashfs-root ./build/prepare.sh
  -> /mnt/image/scripts/setup.sh
    -> scripts/do_overwrite.sh
    -> scripts/install_dependencies.sh
-> build/chroot.sh squashfs-root build/create_manifest.sh > iso/casper/filesystem.manifest
