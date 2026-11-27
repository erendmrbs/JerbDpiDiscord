#!/bin/sh
# Jerb-DpiDiscord: release zip dosyasını hazırlar.
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
cp -r "$KOK/byedpi" "$KOK/goodbyedpi" "$PAKET/"
cp "$KOK/Baslat.bat" "$KOK/LICENSE" "$KOK/README.md" "$KOK/README.en.md" "$PAKET/"
rm -f "$PAKET/byedpi/byedpi_ayar.txt" "$PAKET/byedpi/sessiz_mod.txt" "$PAKET/byedpi/dns_sorma.txt" "$PAKET/byedpi/baslatici.log"

cd "$CIKTI"
zip -q -r "JerbDpiDiscord-v$SURUM.zip" JerbDpiDiscord
sha256sum "JerbDpiDiscord-v$SURUM.zip" > SHA256SUMS.txt
cat SHA256SUMS.txt
