#!/bin/sh
# Build an unsigned local test package. It is not a public release:
# licenses are still pending, and this script does not sign or notarize.
# It never installs the package and never writes to /Applications.
set -eu

root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
out=${SNATIVE_PKG_DIR:-/tmp/SNativeStudio-Local-Package}
derived=${SNATIVE_DERIVED:-/tmp/SNativeStudio-Release-Candidate-DerivedData}
source=${NXNATIVE_SRC:-$root/../nxnative}
version=0.1.0
identifier=com.abadx.SNativeStudio.local-candidate
pkg_name=${SNATIVE_PKG_NAME:-SNative-Studio-${version}-release-candidate-unsigned.pkg}
work="$out/release-candidate"

case "$out" in
  /Applications|/Applications/*)
    echo "build_local_pkg: refusing to use /Applications as the work directory" >&2
    exit 1
    ;;
esac

echo "build_local_pkg: Release build"
xcodebuild \
  -project "$root/SNative Studio.xcodeproj" \
  -scheme "SNative Studio" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$derived" \
  build

app="$derived/Build/Products/Release/SNative Studio.app"
resources="$app/Contents/Resources"
if [ ! -d "$app" ]; then
  echo "build_local_pkg: Release app was not produced" >&2
  exit 1
fi

echo "build_local_pkg: prepare the engine copy"
/bin/sh "$root/scripts/bundle_engine.sh" "$source" "$resources"

verify() {
  engine="$resources/Engine"
  for relative in \
    scripts/build_ipa_from_nsp.py \
    dm/tools/nx_extract/Program.cs \
    dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate \
    dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate.dll \
    dm/gfx/tools/dmsh_xlate_bin/Gommon.dll \
    dm/gfx/tools/dmsh_xlate_bin/Humanizer.dll \
    dm/gfx/tools/dmsh_xlate_bin/Microsoft.IO.RecyclableMemoryStream.dll \
    dm/gfx/tools/dmsh_xlate_bin/MsgPack.dll \
    dm/gfx/tools/dmsh_xlate_bin/System.CodeDom.dll \
    dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate.deps.json \
    dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate.runtimeconfig.json \
    LICENSE
  do
    if [ ! -e "$engine/$relative" ]; then
      echo "build_local_pkg: missing $relative" >&2
      exit 1
    fi
  done
  if ! grep -q 'def snative_tool_paths(base):' "$engine/scripts/build_ipa_from_nsp.py"; then
    echo "build_local_pkg: distributable script was not prepared" >&2
    exit 1
  fi
  if cmp -s "$source/scripts/build_ipa_from_nsp.py" "$engine/scripts/build_ipa_from_nsp.py"; then
    echo "build_local_pkg: engine script is still the checkout original" >&2
    exit 1
  fi
  for notice in \
    Notices/README.md \
    Notices/PENDIENTES.md \
    Notices/nxnative/third_party/libvpx/LICENSE
  do
    if [ ! -f "$resources/$notice" ]; then
      echo "build_local_pkg: missing $notice" >&2
      exit 1
    fi
  done
  if [ -e "$resources/Tools" ] || [ -e "$resources/LICENSE" ] || [ -e "$resources/LICENSE.txt" ] || [ -e "$resources/COPYING" ]; then
    echo "build_local_pkg: Tools or a flattened license is in Resources" >&2
    exit 1
  fi
  if [ -e "$engine/.git" ] || [ -e "$engine/dm/ios/Gen" ] || [ -e "$engine/SNative Studio" ]; then
    echo "build_local_pkg: excluded engine material is present" >&2
    exit 1
  fi
  if [ -n "$(find "$app" \( -name '*.nsp' -o -name '*.ipa' -o -name '*.keys' -o -name 'prod.keys' \) -print -quit)" ]; then
    echo "build_local_pkg: a game or key file is inside the app" >&2
    exit 1
  fi
  if [ -n "$(find "$app" -type f \( -name 'python3' -o -name 'dotnet' -o -name 'xcodegen' -o -name 'spirv-cross' -o -name 'zstd' -o -name 'brew' \) -print -quit)" ]; then
    echo "build_local_pkg: an external tool binary is inside the app" >&2
    exit 1
  fi
}

verify

stage="$work/root"
rm -rf "$work"
mkdir -p "$stage"
ditto "$app" "$stage/SNative Studio.app"

components="$work/components.plist"
/usr/bin/pkgbuild --analyze --root "$stage" "$components"
/usr/bin/python3 - "$components" << 'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, "rb") as handle:
    items = plistlib.load(handle)
kept = [item for item in items if item.get("RootRelativeBundlePath") == "SNative Studio.app"]
if len(kept) != 1:
    raise SystemExit("build_local_pkg: expected one application component")
kept[0]["BundleIsRelocatable"] = False
kept[0]["BundleIsVersionChecked"] = True
kept[0]["BundleOverwriteAction"] = "upgrade"
with open(path, "wb") as handle:
    plistlib.dump(kept, handle)
PY

pkg="$out/$pkg_name"
if [ -e "$pkg" ]; then
  echo "build_local_pkg: refusing to overwrite $pkg" >&2
  exit 1
fi
echo "build_local_pkg: unsigned local candidate"
/usr/bin/pkgbuild \
  --root "$stage" \
  --component-plist "$components" \
  --identifier "$identifier" \
  --version "$version" \
  --install-location /Applications \
  "$pkg"

expand="$work/expanded"
rm -rf "$expand"
/usr/sbin/pkgutil --expand "$pkg" "$expand"
info="$expand/PackageInfo"
if [ -f "$info" ] && grep -q 'Engine/dm/ios/Sources' "$info"; then
  /usr/bin/python3 - "$info" << 'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
needle = 'Engine/dm/ios/Sources'
lines = [line for line in path.read_text().splitlines(keepends=True) if needle not in line]
path.write_text("".join(lines))
PY
  flattened="$work/repacked.pkg"
  rm -f "$flattened"
  /usr/sbin/pkgutil --flatten "$expand" "$flattened"
  mv "$flattened" "$pkg"
  rm -rf "$expand"
  /usr/sbin/pkgutil --expand "$pkg" "$expand"
fi
if [ ! -f "$info" ]; then
  echo "build_local_pkg: PackageInfo is missing" >&2
  exit 1
fi
if ! grep -q 'install-location="/Applications"' "$info"; then
  echo "build_local_pkg: install location is not /Applications" >&2
  exit 1
fi
if [ -d "$expand/Scripts" ] || grep -q '<scripts>' "$info" || ! grep -q 'postinstall-action="none"' "$info"; then
  echo "build_local_pkg: the package contains installer scripts" >&2
  exit 1
fi

payload=$(find "$expand" -name Payload -type f)
if [ -z "$payload" ]; then
  echo "build_local_pkg: payload is missing" >&2
  exit 1
fi
listing="$work/payload.txt"
gzip -dc "$payload" | cpio -it > "$listing"
for needle in \
  "SNative Studio.app/Contents/Resources/Engine/scripts/build_ipa_from_nsp.py" \
  "SNative Studio.app/Contents/Resources/Engine/dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate" \
  "SNative Studio.app/Contents/Resources/Notices/PENDIENTES.md" \
  "SNative Studio.app/Contents/Resources/Notices/nxnative/third_party/libvpx/LICENSE"
do
  if ! grep -F -q "$needle" "$listing"; then
    echo "build_local_pkg: payload is missing $needle" >&2
    exit 1
  fi
done
if grep -q 'Engine/dm/ios/Sources' "$info" || grep -q 'PRODUCT_BUNDLE_IDENTIFIER' "$info"; then
  echo "build_local_pkg: PackageInfo still registers the engine Info.plist as a bundle" >&2
  exit 1
fi
if ! grep -F -q "SNative Studio.app/Contents/Resources/Engine/dm/ios/Sources/Info.plist" "$listing"; then
  echo "build_local_pkg: the engine Info.plist is missing from the payload" >&2
  exit 1
fi
if grep -E -q '(^|/)(\.git|dm/ios/Gen|dm/host/gen|DmIOS\.xcodeproj|Tools)(/|$)|/obj/|/bin/|prod\.keys|\.nsp$|\.ipa$|\.keys$' "$listing"; then
  echo "build_local_pkg: payload contains excluded material" >&2
  exit 1
fi
if grep -E '(^|/)(python3|dotnet|xcodegen|spirv-cross|zstd|brew)$' "$listing" | grep -v 'Contents/Resources/Notices/' | grep -q .; then
  echo "build_local_pkg: payload contains an external tool" >&2
  exit 1
fi

cat > "$work/NOT-FOR-DISTRIBUTION.txt" << EOF
This file is an unsigned local Release candidate of the installer procedure.
It is not the earlier local-test package, not signed, not notarized, and not a public release.
Pending third-party notices are listed in Resources/Notices/PENDIENTES.md.
The package was not installed. It does not write to /Applications by itself.
EOF

echo "build_local_pkg: wrote $pkg"
echo "build_local_pkg: not installed"
