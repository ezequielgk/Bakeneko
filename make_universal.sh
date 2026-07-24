#!/bin/sh
set -e

echo "==> Rebuilding Flutter app..."
nix-shell --command "cd app && flutter build linux --release"

echo "==> Creating AppDir..."
rm -rf AppDir squashfs-root
mkdir -p AppDir/usr/bin/lib
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/scalable/apps
cp -r app/build/linux/x64/release/bundle/* AppDir/usr/bin/
cp daemon/build/libs/bakeneko-daemon.jar AppDir/usr/bin/lib/

echo "==> Bundling libepoxy to fix appimage-run on NixOS..."
EPOXY_PATH=$(nix-build '<nixpkgs>' -A libepoxy --no-out-link)/lib/libepoxy.so.0
cp "$EPOXY_PATH" AppDir/usr/bin/lib/


# Icon in root and in share
cat << 'SVG' > AppDir/bakeneko.svg
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#3b82f6" rx="32"/><text x="128" y="160" font-family="sans-serif" font-weight="bold" font-size="120" fill="white" text-anchor="middle">B</text></svg>
SVG
cp AppDir/bakeneko.svg AppDir/usr/share/icons/hicolor/scalable/apps/

# Desktop in root and in share
cat << 'DESK' > AppDir/bakeneko.desktop
[Desktop Entry]
Name=Bakeneko Reader
Exec=bakeneko
Icon=bakeneko
Type=Application
Categories=Utility;
DESK
cp AppDir/bakeneko.desktop AppDir/usr/share/applications/

echo "==> Bundling fonts and fontconfig for universal compatibility..."
mkdir -p AppDir/usr/share/fonts/roboto
curl -sL "https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Regular.ttf" -o AppDir/usr/share/fonts/roboto/Roboto-Regular.ttf

mkdir -p AppDir/usr/etc/fonts
cat << 'FONTCONF' > AppDir/usr/etc/fonts/fonts.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir prefix="relative">../../share/fonts</dir>
  <dir>/usr/share/fonts</dir>
  <dir>/usr/local/share/fonts</dir>
  <dir>~/.fonts</dir>
  <cachedir>~/.cache/fontconfig</cachedir>
  <config></config>
</fontconfig>
FONTCONF

cat << 'RUN' > AppDir/AppRun
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
export FONTCONFIG_FILE="${HERE}/usr/etc/fonts/fonts.conf"
export FONTCONFIG_PATH="${HERE}/usr/etc/fonts"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS:-/usr/share}"
exec "${HERE}/usr/bin/bakeneko" "$@"
RUN
chmod +x AppDir/AppRun

echo "==> Bundling standard JRE for Universal TLS/SSL compatibility..."
if [ ! -f "jre.tar.gz" ]; then
  curl -sL "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jre_x64_linux_hotspot_21.0.3_9.tar.gz" -o jre.tar.gz
fi
rm -rf AppDir/usr/bin/jre jdk-21.0.3+9-jre
tar -xzf jre.tar.gz
mv jdk-21.0.3+9-jre AppDir/usr/bin/jre

echo "==> Patching binary interpreter and RPATHs for Universal FHS compatibility..."
nix-shell -p patchelf --command "
patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 AppDir/usr/bin/bakeneko
patchelf --set-rpath '\$ORIGIN/lib' AppDir/usr/bin/bakeneko
patchelf --set-rpath '\$ORIGIN' AppDir/usr/bin/lib/libflutter_linux_gtk.so
"

echo "==> Repackaging Universal AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage AppDir Bakeneko-Universal-v14.AppImage
rm -rf AppDir
echo "DONE!"
