#!/bin/sh
# Jerb-DpiDiscord: exe, taşınabilir zip ve kurulum programını derler.
# Gerekenler (Linux): gcc-mingw-w64-x86-64, nsis, zip
# Kullanım: sh kaynak/derle.sh 1.0.0
set -e
SURUM="${1:-1.0.0}"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
CIKTI="$KOK/cikti"
PAKET="$CIKTI/JerbDpiDiscord"

# Betiğin başında çift BOM olmasın (PowerShell ilk satırı bozuk okur)
if head -c 6 "$KOK/byedpi/discord.ps1" | od -An -tx1 | tr -d ' \n' | grep -q '^efbbbfefbbbf'; then
  echo "HATA: byedpi/discord.ps1 başında çift BOM var" >&2; exit 1
fi

rm -rf "$CIKTI"; mkdir -p "$PAKET"
cd "$KOK/kaynak"

# 1) Başlatıcı exe
x86_64-w64-mingw32-windres launcher.rc -O coff -o "$CIKTI/launcher.res"
x86_64-w64-mingw32-gcc -municode -mwindows -Os -s -Wall -o "$PAKET/JerbDpiDiscord.exe" launcher.c "$CIKTI/launcher.res"
rm "$CIKTI/launcher.res"

# 2) Paket klasörü
cp -r "$KOK/byedpi" "$KOK/goodbyedpi" "$PAKET/"
cp "$KOK/Baslat.bat" "$KOK/LICENSE" "$KOK/README.md" "$KOK/README.en.md" "$PAKET/"
rm -f "$PAKET/byedpi/byedpi_ayar.txt" "$PAKET/byedpi/sessiz_mod.txt" "$PAKET/byedpi/dns_sorma.txt" "$PAKET/byedpi/baslatici.log"

# 3) Taşınabilir zip
(cd "$CIKTI" && zip -q -r "JerbDpiDiscord-v$SURUM-Tasinabilir.zip" JerbDpiDiscord)

# 4) Kurulum programı
makensis -V2 -DSURUM="$SURUM" -DPAKET="$PAKET" -DCIKTI="$CIKTI/JerbDpiDiscord-v$SURUM-Kurulum.exe" setup.nsi

# 5) Tek dosya exe (her şeyi içinde taşır, %LocalAppData%'ya çıkarıp açar)
makensis -V2 -DSURUM="$SURUM" -DPAKET="$PAKET" -DCIKTI="$CIKTI/JerbDpiDiscord-v$SURUM-TekDosya.exe" tekdosya.nsi

cd "$CIKTI" && sha256sum JerbDpiDiscord-v$SURUM-Kurulum.exe JerbDpiDiscord-v$SURUM-Tasinabilir.zip JerbDpiDiscord-v$SURUM-TekDosya.exe > SHA256SUMS.txt
cat SHA256SUMS.txt
