#!/bin/bash
# NamazVakti menü bar uygulamasını derleyip .app paketi ve paylaşılabilir DMG oluşturur.
#   ./build_app.sh           → NamazVakti.app + dist/NamazVakti-<sürüm>.dmg
#   ./build_app.sh install   → ayrıca ~/Applications'a kurar ve yeniden başlatır
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NamazVakti"
VERSION="1.7"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
ICON="Resources/AppIcon.icns"
DMG="dist/$APP_NAME-$VERSION.dmg"
MODE="${1:-}"

# İkon: yoksa ya da çizim betiği değiştiyse yeniden üret.
if [ ! -f "$ICON" ] || [ Scripts/make_icon.swift -nt "$ICON" ]; then
    echo "▸ İkon üretiliyor…"
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    swift Scripts/make_icon.swift "$ICONSET"
    mkdir -p Resources
    iconutil -c icns "$ICONSET" -o "$ICON"
    rm -rf "$(dirname "$ICONSET")"
fi

echo "▶︎ Release derleniyor…"
swift build -c release

echo "▸ .app paketi hazırlanıyor…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Namaz Vakti</string>
    <key>CFBundleIdentifier</key>
    <string>com.namazvakti.menubar</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>tr</string>
        <string>en</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.lifestyle</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Namaz vakitleri: Diyanet İşleri Başkanlığı (EzanVakti API)</string>
</dict>
</plist>
PLIST

# İmzalama: "Developer ID Application" sertifikası varsa onunla (hardened runtime + zaman damgası),
# yoksa ad-hoc. Notarize için anahtar zincirinde notarytool profili gerekir (README > Notarize).
NOTARY_PROFILE="${NOTARY_PROFILE:-namazvakti-notary}"
SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
CAN_NOTARIZE=0
if [ -n "$SIGN_ID" ]; then
    echo "▸ İmzalanıyor: $SIGN_ID"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP_BUNDLE"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        CAN_NOTARIZE=1
    else
        echo "  Notarize atlanacak: '$NOTARY_PROFILE' profili bulunamadı."
    fi
else
    echo "▸ Developer ID bulunamadı, ad-hoc imzalanıyor (DMG'yi açanlar Gatekeeper uyarısı görür)."
    codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

# Dosyayı Apple'a gönderir, sonucu bekler; "Accepted" değilse durur.
notarize() {
    local out
    out="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)" || true
    echo "$out" | grep -E "id:|status:" | tail -2
    if ! echo "$out" | grep -q "status: Accepted"; then
        echo "✗ Notarize başarısız. Ayrıntı: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE"
        exit 1
    fi
}

if [ "$CAN_NOTARIZE" = 1 ]; then
    echo "▸ Uygulama notarize ediliyor (birkaç dakika sürebilir)…"
    ZIP_DIR="$(mktemp -d)"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_DIR/$APP_NAME.zip"
    notarize "$ZIP_DIR/$APP_NAME.zip"
    rm -rf "$ZIP_DIR"
    xcrun stapler staple -q "$APP_BUNDLE"
fi

echo "▸ DMG hazırlanıyor…"
mkdir -p dist
STAGING="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Namaz Vakti" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

if [ -n "$SIGN_ID" ]; then
    codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
fi
if [ "$CAN_NOTARIZE" = 1 ]; then
    echo "▸ DMG notarize ediliyor…"
    notarize "$DMG"
    xcrun stapler staple -q "$DMG"
    echo "✓ Notarize edildi, Gatekeeper uyarısı çıkmaz."
fi

echo "✓ Hazır: $(pwd)/$APP_BUNDLE"
echo "✓ DMG:   $(pwd)/$DMG"

if [ "$MODE" = "install" ]; then
    echo "▸ ~/Applications'a kuruluyor…"
    pkill -x "$APP_NAME" || true
    mkdir -p ~/Applications
    rm -rf ~/Applications/"$APP_BUNDLE"
    cp -R "$APP_BUNDLE" ~/Applications/
    open ~/Applications/"$APP_BUNDLE"
    echo "✓ Kuruldu ve başlatıldı."
else
    echo "  Çalıştır:  open \"$APP_BUNDLE\"   (kurmak için: ./build_app.sh install)"
fi
