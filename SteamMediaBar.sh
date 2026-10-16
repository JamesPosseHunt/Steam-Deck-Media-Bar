#!/bin/sh
printf '\033c\033]0;%s\a' SMB
base_path="$(dirname "$(realpath "$0")")"
"$base_path/SteamMediaBar.x86_64" "$@"
