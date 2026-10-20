#!/bin/sh
# Copy a distributable nxnative tree into an app's Resources/Engine and the
# notices into Resources/Notices. The checkout is only read. Directory names
# are kept, so LICENSE files are not flattened.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: bundle_engine.sh <nxnative checkout> <app Resources directory>" >&2
  exit 2
fi

source=$1
resources=$2
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
notices="$root/SNative Studio/Resources/Notices"

if [ ! -f "$source/scripts/build_ipa_from_nsp.py" ]; then
  echo "bundle_engine: nxnative checkout not found at $source" >&2
  exit 1
fi
if [ ! -f "$notices/README.md" ]; then
  echo "bundle_engine: notices folder not found at $notices" >&2
  exit 1
fi

mkdir -p "$resources/Engine"
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude '__pycache__/' \
  --exclude '.iosdd/' \
  --exclude '.iosdd_*' \
  --exclude 'dm/ios/Gen/' \
  --exclude 'dm/ios/DmIOS.xcodeproj/' \
  --exclude 'dm/host/gen/' \
  --exclude 'obj/' \
  --exclude 'bin/' \
  --exclude 'xcuserdata/' \
  --exclude '*.xcuserstate' \
  --exclude 'SNative Studio/' \
  --exclude '*.nsp' \
  --exclude '*.ipa' \
  --exclude '*.keys' \
  "$source/" "$resources/Engine/"

for relative in \
  scripts/build_ipa_from_nsp.py \
  dm/tools/nx_extract/Program.cs \
  dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate \
  dm/ios/Sources \
  dm/ios/project.yml \
  dm/games \
  dm/host \
  dm/gfx \
  dm/third_party \
  dm/tools \
  LICENSE
do
  if [ ! -e "$resources/Engine/$relative" ]; then
    echo "bundle_engine: missing $relative after copy" >&2
    exit 1
  fi
done

if [ -e "$resources/Engine/.git" ] || [ -e "$resources/Engine/dm/ios/Gen" ] || [ -e "$resources/Engine/SNative Studio" ]; then
  echo "bundle_engine: excluded material was copied" >&2
  exit 1
fi
if [ -e "$resources/Engine/dm/tools/nx_extract/obj" ] \
  || [ -e "$resources/Engine/dm/tools/nx_extract/bin" ] \
  || [ -e "$resources/Engine/dm/host/gen" ] \
  || [ -e "$resources/Engine/dm/ios/DmIOS.xcodeproj" ]; then
  echo "bundle_engine: build caches were copied" >&2
  exit 1
fi
if [ -n "$(find "$resources/Engine" \( -name '*.nsp' -o -name '*.keys' -o -name 'prod.keys' \) -print -quit)" ]; then
  echo "bundle_engine: game or key files were copied" >&2
  exit 1
fi

rm -rf "$resources/Notices"
ditto "$notices" "$resources/Notices"
if [ ! -f "$resources/Notices/nxnative/third_party/libvpx/LICENSE" ]; then
  echo "bundle_engine: notices were not copied with their folders" >&2
  exit 1
fi
if [ -e "$resources/LICENSE" ] || [ -e "$resources/LICENSE.txt" ] || [ -e "$resources/COPYING" ]; then
  echo "bundle_engine: a license file was flattened into Resources" >&2
  exit 1
fi

script="$resources/Engine/scripts/build_ipa_from_nsp.py"
before=$(cksum "$source/scripts/build_ipa_from_nsp.py")
/usr/bin/python3 "$root/scripts/prepare_distributable_script.py" "$script"
after=$(cksum "$source/scripts/build_ipa_from_nsp.py")
if [ "$before" != "$after" ]; then
  echo "bundle_engine: the nxnative checkout script changed" >&2
  exit 1
fi
if ! grep -q 'def snative_tool_paths(base):' "$script"; then
  echo "bundle_engine: the distributable script was not prepared" >&2
  exit 1
fi
if cmp -s "$source/scripts/build_ipa_from_nsp.py" "$script"; then
  echo "bundle_engine: the distributable script is still identical to the checkout" >&2
  exit 1
fi
