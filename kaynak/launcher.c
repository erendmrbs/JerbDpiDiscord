/*
 * Jerb-DpiDiscord - başlatıcı (JerbDpiDiscord.exe)
 * Copyright (C) 2026 Jerb
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Bu küçük program sadece byedpi\discord.ps1 betiğini, hiç pencere açmadan
 * PowerShell ile başlatır. Yönetici iznini (UAC) kendi manifestiyle ister,
 * böylece PowerShell'in ayrıca izin istemesine gerek kalmaz.
 * Başka hiçbir şey yapmaz; bütün mantık discord.ps1 içindedir.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

#define UZUN 4096

static void hata(const wchar_t *mesaj) {
    MessageBoxW(NULL, mesaj, L"Jerb-DpiDiscord", MB_OK | MB_ICONERROR);
}

int WINAPI wWinMain(HINSTANCE h, HINSTANCE onceki, PWSTR komut, int goster) {
    (void)h; (void)onceki; (void)komut; (void)goster;

    /* Bu exe'nin bulunduğu klasör */
    wchar_t klasor[UZUN];
    DWORD n = GetModuleFileNameW(NULL, klasor, UZUN);
    if (n == 0 || n >= UZUN) { hata(L"Program konumu okunamadı."); return 1; }
    wchar_t *bolu = wcsrchr(klasor, L'\\');
    if (bolu) *(bolu + 1) = L'\0';

    /* byedpi\discord.ps1 */
    wchar_t betik[UZUN];
    _snwprintf(betik, UZUN, L"%lsbyedpi\\discord.ps1", klasor);
    betik[UZUN - 1] = L'\0';
    if (GetFileAttributesW(betik) == INVALID_FILE_ATTRIBUTES) {
        hata(L"byedpi\\discord.ps1 bulunamadı.\n\n"
             L"JerbDpiDiscord.exe, byedpi ve goodbyedpi klasörlerinin yanında olmalı.");
        return 1;
    }

    /* PowerShell'i pencere açmadan başlat */
    wchar_t satir[UZUN * 2];
    _snwprintf(satir, UZUN * 2,
        L"powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%ls\"", betik);
    satir[UZUN * 2 - 1] = L'\0';

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof si);
    ZeroMemory(&pi, sizeof pi);
    si.cb = sizeof si;
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    if (!CreateProcessW(NULL, satir, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                        NULL, klasor, &si, &pi)) {
        hata(L"PowerShell başlatılamadı.");
        return 1;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
