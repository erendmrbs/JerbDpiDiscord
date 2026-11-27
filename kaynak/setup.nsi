; Jerb-DpiDiscord kurulum programı (NSIS)
; Copyright (C) 2026 Jerb - SPDX-License-Identifier: GPL-3.0-or-later
;
; Derlemek için: makensis -DSURUM=1.0.0 -DPAKET=<hazırlanan klasör> -DCIKTI=<setup.exe yolu> setup.nsi

Unicode true
SetCompressor /SOLID lzma

!ifndef SURUM
  !define SURUM "1.0.0"
!endif
!define UYGULAMA "Jerb-DpiDiscord"
!define KLASOR   "JerbDpiDiscord"
!define EXE      "JerbDpiDiscord.exe"
!define KALDIR_ANAHTARI "Software\Microsoft\Windows\CurrentVersion\Uninstall\${KLASOR}"

Name "${UYGULAMA}"
OutFile "${CIKTI}"
InstallDir "$PROGRAMFILES64\${KLASOR}"
InstallDirRegKey HKLM "${KALDIR_ANAHTARI}" "InstallLocation"
RequestExecutionLevel admin
BrandingText "${UYGULAMA} ${SURUM}"

VIProductVersion "${SURUM}.0"
VIAddVersionKey "ProductName"     "${UYGULAMA}"
VIAddVersionKey "FileDescription" "${UYGULAMA} Kurulum"
VIAddVersionKey "FileVersion"     "${SURUM}"
VIAddVersionKey "ProductVersion"  "${SURUM}"
VIAddVersionKey "CompanyName"     "Jerb"
VIAddVersionKey "LegalCopyright"  "Copyright (C) 2026 Jerb - GPL-3.0"

!include "MUI2.nsh"
!define MUI_ICON   "simge.ico"
!define MUI_UNICON "simge.ico"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PAKET}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Turkish"
!insertmacro MUI_LANGUAGE "English"

Section "Kurulum"
  ; Çalışan kopyalar dosyaları kilitlemesin
  nsExec::Exec 'taskkill /f /im ciadpi.exe'
  nsExec::Exec 'taskkill /f /im goodbyedpi.exe'
  Sleep 1000

  SetOutPath "$INSTDIR"
  File "${PAKET}\${EXE}"
  File "${PAKET}\Baslat.bat"
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

  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Kaldir.exe"

  ; Kısayollar
  SetShellVarContext current
  CreateDirectory "$SMPROGRAMS\${UYGULAMA}"
  CreateShortcut "$SMPROGRAMS\${UYGULAMA}\${UYGULAMA}.lnk" "$INSTDIR\${EXE}"
  CreateShortcut "$SMPROGRAMS\${UYGULAMA}\${UYGULAMA} Kaldır.lnk" "$INSTDIR\Kaldir.exe"
  CreateShortcut "$DESKTOP\${UYGULAMA}.lnk" "$INSTDIR\${EXE}"

  ; Programlar ve Özellikler kaydı
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "DisplayName"     "${UYGULAMA}"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "DisplayVersion"  "${SURUM}"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "Publisher"       "Jerb"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "DisplayIcon"     "$INSTDIR\${EXE}"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "URLInfoAbout"    "https://github.com/erendmrbs/JerbDpiDiscord"
  WriteRegStr   HKLM "${KALDIR_ANAHTARI}" "UninstallString" '"$INSTDIR\Kaldir.exe"'
  WriteRegDWORD HKLM "${KALDIR_ANAHTARI}" "NoModify" 1
  WriteRegDWORD HKLM "${KALDIR_ANAHTARI}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  ; Çalışan her şeyi kapat
  nsExec::Exec 'taskkill /f /im ciadpi.exe'
  nsExec::Exec 'taskkill /f /im goodbyedpi.exe'
  nsExec::Exec 'sc stop WinDivert'
  ; Otomatik başlatma görevini sil
  nsExec::Exec 'schtasks /Delete /TN "Discord Baslatici" /F'
  Sleep 1000

  RMDir /r "$INSTDIR\byedpi"
  RMDir /r "$INSTDIR\goodbyedpi"
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\Baslat.bat"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\README.en.md"
  Delete "$INSTDIR\Kaldir.exe"
  RMDir "$INSTDIR"

  SetShellVarContext current
  Delete "$DESKTOP\${UYGULAMA}.lnk"
  RMDir /r "$SMPROGRAMS\${UYGULAMA}"
  ; Bulucu betik ve DNS yedeği (DNS ayarı kaldırmadan önce menüden geri alınmalı)
  RMDir /r "$LOCALAPPDATA\DiscordBaslatici"

  DeleteRegKey HKLM "${KALDIR_ANAHTARI}"
SectionEnd
