; Jerb-DpiDiscord tek dosya exe (NSIS)
; Copyright (C) 2026 Jerb - SPDX-License-Identifier: GPL-3.0-or-later
;
; Çift tıklanınca programı sessizce %LocalAppData%\JerbDpiDiscord klasörüne çıkarır
; (varsa günceller, ayar dosyalarına dokunmaz) ve başlatıcıyı açar. Kurulum yapmaz.

Unicode true
SetCompressor /SOLID lzma

!ifndef SURUM
  !define SURUM "1.0.0"
!endif

Name "Jerb-DpiDiscord"
OutFile "${CIKTI}"
Icon "simge.ico"
RequestExecutionLevel user
SilentInstall silent
InstallDir "$LOCALAPPDATA\JerbDpiDiscord"

VIProductVersion "${SURUM}.0"
VIAddVersionKey "ProductName"     "Jerb-DpiDiscord"
VIAddVersionKey "FileDescription" "Jerb-DpiDiscord"
VIAddVersionKey "FileVersion"     "${SURUM}"
VIAddVersionKey "ProductVersion"  "${SURUM}"
VIAddVersionKey "CompanyName"     "Jerb"
VIAddVersionKey "LegalCopyright"  "Copyright (C) 2026 Jerb - GPL-3.0"

Section
  ; Başlatıcı zaten çalışıyorsa kilitli dosyaları atla, gerisini güncelle
  SetOverwrite try

  SetOutPath "$INSTDIR"
  File "${PAKET}\JerbDpiDiscord.exe"
  File "${PAKET}\LICENSE"
  File "${PAKET}\README.md"
  File "${PAKET}\README.en.md"

  SetOutPath "$INSTDIR\byedpi"
  File "${PAKET}\byedpi\ciadpi.exe"
  File "${PAKET}\byedpi\discord.ps1"
  File "${PAKET}\byedpi\LICENSE-byedpi.txt"

  SetOutPath "$INSTDIR\goodbyedpi"
  File "${PAKET}\goodbyedpi\goodbyedpi.exe"
  File "${PAKET}\goodbyedpi\WinDivert.dll"
  File "${PAKET}\goodbyedpi\WinDivert64.sys"
  File "${PAKET}\goodbyedpi\discord.txt"

  SetOutPath "$INSTDIR\goodbyedpi\licenses"
  File "${PAKET}\goodbyedpi\licenses\*.txt"

  ; Başlatıcıyı aç (yönetici iznini kendisi ister)
  SetOutPath "$INSTDIR"
  ExecShell "open" "$INSTDIR\JerbDpiDiscord.exe"
SectionEnd
