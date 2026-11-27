﻿# Jerb-DpiDiscord - Discord Başlatıcı
# Copyright (C) 2026 Jerb
#
# Bu program özgür bir yazılımdır: Free Software Foundation tarafından yayımlanan
# GNU Genel Kamu Lisansı'nın 3. sürümü ya da (tercihinize göre) daha sonraki bir
# sürümü altında yeniden dağıtabilir ve/veya değiştirebilirsiniz.
# Bu program faydalı olması umuduyla, ancak HİÇBİR GARANTİ OLMADAN dağıtılmaktadır.
# Ayrıntılar için LICENSE dosyasına bakın.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Discord Başlatıcı - sistem tepsisinde çalışır
# GoodbyeDPI'ı Discord güncelleme kontrolü için kısa süre açar,
# Discord'u ByeDPI üzerinden çalıştırır, Discord kapanınca ByeDPI'ı da kapatır.
# Discord kurulu değilse indirip kurar.

param([switch]$Gizli)

# Projenin GitHub sayfası (tepsi menüsünün en üstündeki bağlantı)
$GITHUB_ADRESI = 'https://github.com/erendmrbs/JerbDpiDiscord'
$BAGIS_ADRESI  = 'https://github.com/sponsors/erendmrbs'

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# Olay kayıtları: bağlantı kopmalarının ve hataların nedenini bulmak için
$script:olayLog = Join-Path $PSScriptRoot 'baslatici.log'

function Kaydet($mesaj) {
    $satir = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $mesaj
    Add-Content -Path $script:olayLog -Value $satir -Encoding UTF8
}

# PowerShell'in topladığı hataları kayda yaz ve listeyi temizle
function HatalariKaydet($nerede) {
    foreach ($h in @($Error)) {
        $konum = ''
        if ($h.InvocationInfo) { $konum = " (satır $($h.InvocationInfo.ScriptLineNumber))" }
        Kaydet "HATA [$nerede]$konum $($h.ToString())"
    }
    $Error.Clear()
}

# Kayıt dosyası çok büyümesin (500 KB'ı geçerse son 2000 satır kalsın)
if ((Test-Path $script:olayLog) -and ((Get-Item $script:olayLog).Length -gt 500KB)) {
    $son = Get-Content $script:olayLog -Tail 2000 -Encoding UTF8
    Set-Content -Path $script:olayLog -Value $son -Encoding UTF8
}

# Yönetici değilse kendini yönetici olarak yeniden başlat
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $ekArg = ''
    if ($Gizli) { $ekArg = ' -Gizli' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"$ekArg"
    HatalariKaydet 'yetki yükseltme'
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);'

# Mesaj pencereleri her zaman en önde açılsın (yoksa başka pencerelerin arkasında kalıp görünmüyor)
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System.Windows.Forms;
public static class MesajKutusu {
    public static DialogResult Goster(string metin, string baslik, MessageBoxButtons butonlar, MessageBoxIcon simge) {
        using (Form sahip = new Form()) {
            sahip.TopMost = true;
            sahip.ShowInTaskbar = false;
            sahip.FormBorderStyle = FormBorderStyle.None;
            sahip.StartPosition = FormStartPosition.CenterScreen;
            sahip.Size = new System.Drawing.Size(1, 1);
            sahip.Opacity = 0;
            sahip.Show();
            sahip.Activate();
            return MessageBox.Show(sahip, metin, baslik, butonlar, simge);
        }
    }
}
'@

$script:tepsi       = $null
$script:betikYolu   = $PSCommandPath
$script:gorevAdi    = 'Discord Baslatici'
$script:sabitKlasor = Join-Path $env:LOCALAPPDATA 'DiscordBaslatici'
$script:gizliBaslat = [bool]$Gizli
$script:tabanBmp    = $null
$script:sonHicon    = [IntPtr]::Zero
$script:asama       = 'baslangic'
$script:sonBaslatma = Get-Date

# Denenecek ByeDPI ayarları (ilk çalışan kaydedilir)
$script:byedpiBaglantiSiniri = 4096

$script:onAyarlar = @(
    '--disorder 1 --tlsrec 1+s',
    '--split 1+s --disorder 3+s',
    '--tlsrec 3+s --split 2',
    '--disorder 1 --split 2 --tlsrec 1+s',
    '--fake -1 --ttl 8'
)

# ---------------------------------------------------------------------------
# Yardımcı fonksiyonlar
# ---------------------------------------------------------------------------

function GoodbyeDpiKapat {
    if (Get-Process goodbyedpi) {
        Get-Process goodbyedpi | Stop-Process -Force
        Start-Sleep -Milliseconds 1500
    }
    sc.exe stop WinDivert | Out-Null
}

function TepsiKaldir {
    if ($script:tepsi) {
        $script:tepsi.Visible = $false
        $script:tepsi.Dispose()
        $script:tepsi = $null
    }
}

# Hata mesajı göster, açılanları kapat ve çık
function Hata($mesaj, [switch]$Temizle) {
    if ($Temizle) {
        GoodbyeDpiKapat
        Get-Process ciadpi | Stop-Process -Force
    }
    TepsiKaldir
    [MesajKutusu]::Goster($mesaj, 'Discord Başlatıcı', 'OK', 'Error') | Out-Null
    exit
}

function Durum($metin) {
    if ($script:durumOgesi) { $script:durumOgesi.Text = "Durum: $metin" }
    $ipucu = "Discord Başlatıcı - $metin"
    if ($ipucu.Length -gt 63) { $ipucu = $ipucu.Substring(0, 63) }
    if ($script:tepsi) { $script:tepsi.Text = $ipucu }
}

function Bildirim($baslik, $metin, $tur = 'Info') {
    if ($script:sessizMod -and $tur -eq 'Info') { return }
    if ($script:tepsi) { $script:tepsi.ShowBalloonTip(5000, $baslik, $metin, $tur) }
}

# Tepsi simgesini renklendir: 'sari' = bekleniyor, 'yesil' = hazır, 'kirmizi' = sorun
function Renk($renk) {
    if (-not $script:tepsi) { return }
    $boyut = 32
    $bmp = New-Object System.Drawing.Bitmap($boyut, $boyut)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    if ($renk -eq 'yesil')       { $c = [System.Drawing.Color]::FromArgb(35, 165, 90) }
    elseif ($renk -eq 'kirmizi') { $c = [System.Drawing.Color]::FromArgb(218, 55, 60) }
    else                         { $c = [System.Drawing.Color]::FromArgb(240, 178, 50) }
    $firca = New-Object System.Drawing.SolidBrush($c)

    if ($script:tabanBmp) {
        $g.DrawImage($script:tabanBmp, 0, 0, $boyut, $boyut)
        $g.FillEllipse([System.Drawing.Brushes]::White, 15, 15, 17, 17)
        $g.FillEllipse($firca, 17, 17, 13, 13)
    }
    else {
        $g.FillEllipse($firca, 2, 2, 28, 28)
    }
    $g.Dispose()
    $firca.Dispose()

    $h = $bmp.GetHicon()
    $script:tepsi.Icon = [System.Drawing.Icon]::FromHandle($h)
    if ($script:sonHicon -ne [IntPtr]::Zero) { [Win32.Native]::DestroyIcon($script:sonHicon) | Out-Null }
    $script:sonHicon = $h
    $bmp.Dispose()
}

# --- ByeDPI ---

function ByeDpiBaslat {
    # -c: aynı anda en fazla kaç bağlantı (varsayılan 512, Discord'a yetmeyebiliyor)
    Start-Process $script:ciadpi -ArgumentList "-i 127.0.0.1 -p 1080 -c $script:byedpiBaglantiSiniri $script:byedpiAyar" -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

function ByeDpiAc {
    if (-not (Get-Process ciadpi)) { ByeDpiBaslat }
}

function ByeDpiYenidenBaslat($ayar) {
    Get-Process ciadpi | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    $script:byedpiAyar = $ayar
    ByeDpiBaslat
}

# ByeDPI'a şu an açık bağlantı sayısı
function ByeDpiBaglantiSayisi {
    return @(Get-NetTCPConnection -LocalPort 1080 -State Established).Count
}

# ByeDPI üzerinden Discord'a ulaşılabiliyor mu?
function ByeDpiTest {
    $cikti = & curl.exe -s -o NUL -w '%{http_code} %{time_total}' --max-time 6 -x socks5h://127.0.0.1:1080 'https://discord.com/api/v9/gateway'
    $parca = "$cikti".Trim() -split ' '
    if ($parca[0] -eq '200') {
        $sure = 0.0
        if ([double]::TryParse($parca[1], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$sure)) {
            $script:sonGecikme = [int]($sure * 1000)
        }
        return $true
    }
    $script:sonGecikme = $null
    return $false
}

# Menüdeki bağlantı bilgisini güncelle
function BaglantiBilgisiGuncelle {
    if ($script:sonGecikme) { $script:gecikmeOgesi.Text = "Bağlantı süresi: $($script:sonGecikme) ms" }
    else                    { $script:gecikmeOgesi.Text = 'Bağlantı süresi: -' }
    $script:ayarOgesi.Text = "ByeDPI ayarı: $script:byedpiAyar"
}

# Çalışan ByeDPI ayarını bul ve kaydet (GoodbyeDPI kapalıyken çalıştırılmalı)
function ByeDpiAyarBul {
    Renk 'sari'
    Durum 'ByeDPI ayarı aranıyor'
    $eskiAyar = $script:byedpiAyar
    $sira = @($eskiAyar) + @($script:onAyarlar | Where-Object { $_ -ne $eskiAyar })
    $i = 0
    foreach ($ayar in $sira) {
        $i++
        Durum "ByeDPI ayarı aranıyor ($i/$($sira.Count))"
        [System.Windows.Forms.Application]::DoEvents()
        ByeDpiYenidenBaslat $ayar
        if (ByeDpiTest) {
            Set-Content -Path $script:ayarDosyasi -Value $ayar -Encoding ASCII
            Renk 'yesil'
            Durum 'Discord ByeDPI ile çalışıyor'
            if ($ayar -ne $eskiAyar) {
                Bildirim 'ByeDPI ayarı bulundu' "Çalışan ayar kaydedildi:`n$ayar"
            }
            else {
                Bildirim 'Bağlantı çalışıyor' 'Mevcut ByeDPI ayarı sorunsuz.'
            }
            return $true
        }
    }
    ByeDpiYenidenBaslat $eskiAyar
    Renk 'kirmizi'
    Durum "Discord'a ulaşılamıyor"
    Bildirim "Discord'a ulaşılamıyor" "Hiçbir ByeDPI ayarı çalışmadı. İnternet bağlantını kontrol et ya da sonra tekrar dene." 'Error'
    return $false
}

# --- GoodbyeDPI ---

function GoodbyeDpiAc {
    if (-not (Get-Process goodbyedpi)) {
        Start-Process $script:gdpiExe -WorkingDirectory $script:gdpiKlasor -WindowStyle Hidden -ArgumentList "-5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253 --blacklist `"$script:blacklist`""
        Start-Sleep -Seconds 3
    }
    return [bool](Get-Process goodbyedpi)
}

# WinDivert sürücü kaydını temizle (1058 gibi hatalar için), yeniden başlatma öner
function SurucuOnar {
    Get-Process goodbyedpi | Stop-Process -Force
    Start-Sleep -Seconds 1
    foreach ($servis in @('GoodbyeDPI', 'WinDivert', 'WinDivert14')) {
        sc.exe stop $servis | Out-Null
        sc.exe delete $servis | Out-Null
    }
    $cevap = [MesajKutusu]::Goster(
        "Sürücü kaydı temizlendi.`nOnarımın tamamlanması için bilgisayarın yeniden başlatılması gerekiyor.`n`nŞimdi yeniden başlatılsın mı?",
        'Discord Başlatıcı', 'YesNo', 'Question')
    if ($cevap -eq 'Yes') { shutdown.exe /r /t 5 }
}

# --- Discord ---

# En yeni Discord sürüm klasöründeki Discord.exe'yi bul
function DiscordBul {
    $app = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Discord') -Directory -Filter 'app-*' |
           Where-Object { Test-Path (Join-Path $_.FullName 'Discord.exe') } |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($app) { return (Join-Path $app.FullName 'Discord.exe') }
    return $null
}

# Discord kurulumunu indir ve kur (önce GoodbyeDPI üzerinden, olmazsa ByeDPI üzerinden)
function DiscordIndirKur {
    $kurulum = Join-Path $env:TEMP 'DiscordSetup.exe'
    $adresler = @(
        'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64',
        'https://discord.com/api/download?platform=win'
    )
    $indi = $false
    foreach ($proxy in @($null, 'socks5h://127.0.0.1:1080')) {
        foreach ($adres in $adresler) {
            Remove-Item $kurulum -Force
            if ($proxy) { & curl.exe -L -s --max-time 300 -x $proxy -o $kurulum $adres }
            else        { & curl.exe -L -s --max-time 300 -o $kurulum $adres }
            if ((Test-Path $kurulum) -and ((Get-Item $kurulum).Length -gt 1MB)) { $indi = $true; break }
        }
        if ($indi) { break }
    }
    if (-not $indi) { return $false }

    Durum 'Discord kuruluyor'
    Start-Process $kurulum

    # Kurulum bitip Discord kendi kendine açılana kadar bekle (en fazla 3 dakika)
    for ($i = 0; $i -lt 180; $i++) {
        if ((DiscordBul) -and (Get-Process Discord)) { break }
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds 5

    # Kurulumun açtığı proxy'siz Discord'u kapat, kendimiz proxy ile açacağız
    Get-Process Discord, Update | Stop-Process -Force
    Start-Sleep -Seconds 2
    return [bool](DiscordBul)
}

# Discord'u (yeniden) başlat: GoodbyeDPI'ı aç, Discord'u ByeDPI ile aç, güncelleme beklemeye geç
function DiscordBaslat([switch]$Kucuk) {
    Get-Process Discord | Stop-Process -Force
    Start-Sleep -Seconds 1

    Renk 'sari'
    ByeDpiAc
    Durum 'GoodbyeDPI açılıyor'
    if (-not (GoodbyeDpiAc)) {
        Renk 'kirmizi'
        Bildirim 'GoodbyeDPI başlatılamadı' "Sürücü sorunu olabilir. Tepsiden 'Sürücü hatasını onar'ı dene." 'Error'
    }

    $exe = DiscordBul
    if (-not $exe) {
        Renk 'kirmizi'
        Bildirim 'Discord bulunamadı' 'Başlatıcıyı kapatıp yeniden çalıştır.' 'Error'
        return
    }
    if (-not $script:tabanBmp) {
        $simge = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
        if ($simge) { $script:tabanBmp = $simge.ToBitmap() }
        Renk 'sari'
    }

    $discordArg = '--proxy-server=socks5://127.0.0.1:1080'
    if ($Kucuk) { $discordArg += ' --start-minimized' }

    Remove-Item $script:log, $script:logHat -Force
    Start-Process $exe -ArgumentList $discordArg -RedirectStandardOutput $script:log -RedirectStandardError $script:logHat

    $script:asama       = 'bekle'
    $script:sayac       = 0
    $script:yok         = 0
    $script:kucukAcildi = [bool]$Kucuk
    $script:sonBaslatma = Get-Date
    Durum 'güncelleme bekleniyor'
}

# Proxy'siz çalışan ana Discord işlemi var mı?
function ProxysizDiscordVarMi {
    $ana = Get-CimInstance Win32_Process -Filter "Name='Discord.exe'" |
           Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '--type=' }
    return [bool]($ana | Where-Object { $_.CommandLine -notmatch '--proxy-server' })
}

# Discord ByeDPI üzerinden bağlantı kurdu mu? (pencere gizliyken kullanılır)
function DiscordProxyBaglantisiVarMi {
    $pidler = @((Get-Process Discord).Id)
    if ($pidler.Count -eq 0) { return $false }
    return [bool](Get-NetTCPConnection -RemotePort 1080 -State Established | Where-Object { $pidler -contains $_.OwningProcess })
}

# --- DNS ---

# discord.com şu an hangi adrese çözülüyor?
function DiscordAdresi {
    $kayit = Resolve-DnsName -Name 'discord.com' -Type A -QuickTimeout |
             Where-Object { $_.IPAddress } | Select-Object -First 1
    if ($kayit) { return $kayit.IPAddress }
    return $null
}

# DNS sahte cevap veriyorsa düzeltmeyi dene. Düzeldiyse $true döner.
function DnsZehirlenmesiniDuzelt {
    $adres = DiscordAdresi
    if ($adres -like '162.159.*') { return $true }

    Kaydet "DNS yanlış cevap veriyor: discord.com -> $adres (sağlayıcının engel adresi olabilir)"
    Clear-DnsClientCache
    Start-Sleep -Seconds 1
    $adres = DiscordAdresi
    if ($adres -like '162.159.*') {
        Kaydet 'DNS önbelleği temizlenince düzeldi'
        return $true
    }

    # DNS'i daha önce başlatıcı ayarladıysa (ya da şifreli DNS kuruluysa) ayarı sessizce yeniden uygula
    if ((Test-Path $script:dnsYedekDosyasi) -or (Get-DnsClientDohServerAddress -ServerAddress '1.1.1.1')) {
        if (DnsAyarla) {
            Kaydet 'Şifreli DNS ayarı yeniden uygulandı, düzeldi'
            return $true
        }
    }
    Kaydet "DNS düzeltilemedi (discord.com -> $(DiscordAdresi))"
    return $false
}

# discord.com doğru (Discord'un gerçek) adrese mi çözülüyor?
function DnsDogruMu {
    Clear-DnsClientCache
    $kayit = Resolve-DnsName -Name 'discord.com' -Type A -DnsOnly -QuickTimeout |
             Where-Object { $_.IPAddress } | Select-Object -First 1
    return ($kayit -and $kayit.IPAddress -like '162.159.*')
}

# İnternete bağlı (varsayılan ağ geçidi olan, açık) ağ bağdaştırıcıları
function AktifAglar {
    return @(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' })
}

# Mevcut DNS ayarlarını yedekle (sadece ilk seferde, geri alabilmek için)
function DnsYedekle {
    if (Test-Path $script:dnsYedekDosyasi) { return }
    $yedek = @()
    foreach ($ag in AktifAglar) {
        $guid = $ag.NetAdapter.InterfaceGuid
        $statik = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid").NameServer
        $yedek += [PSCustomObject]@{
            Index     = $ag.InterfaceIndex
            Ad        = $ag.InterfaceAlias
            Guid      = $guid
            Dhcp      = [string]::IsNullOrWhiteSpace($statik)
            Sunucular = @((Get-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -AddressFamily IPv4).ServerAddresses)
        }
    }
    New-Item -ItemType Directory -Path $script:sabitKlasor -Force | Out-Null
    $yedek | ConvertTo-Json -Depth 3 | Set-Content -Path $script:dnsYedekDosyasi -Encoding UTF8
}

# DNS'i Cloudflare şifreli DNS'e (DNS over HTTPS) çevir
function DnsAyarla {
    DnsYedekle
    $win11 = [Environment]::OSVersion.Version.Build -ge 22000
    $sunucular = @('1.1.1.1', '1.0.0.1')

    if ($win11) {
        foreach ($s in $sunucular) {
            if (Get-DnsClientDohServerAddress -ServerAddress $s) {
                Set-DnsClientDohServerAddress -ServerAddress $s -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true | Out-Null
            }
            else {
                Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true | Out-Null
            }
        }
        $dnscache = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
        New-ItemProperty -Path $dnscache -Name 'EnableAutoDoh' -Value 2 -PropertyType DWord -Force | Out-Null
    }

    foreach ($ag in AktifAglar) {
        Set-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -ServerAddresses $sunucular
        if ($win11) {
            $guid = $ag.NetAdapter.InterfaceGuid
            foreach ($s in $sunucular) {
                $anahtar = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$guid\DohInterfaceSettings\Doh\$s"
                New-Item -Path $anahtar -Force | Out-Null
                New-ItemProperty -Path $anahtar -Name 'DohFlags' -Value 1 -PropertyType QWord -Force | Out-Null
            }
        }
    }

    Clear-DnsClientCache
    Start-Sleep -Seconds 2
    return (DnsDogruMu)
}

# DNS ayarlarını yedekteki haline döndür
function DnsGeriAl {
    if (-not (Test-Path $script:dnsYedekDosyasi)) { return $false }
    $yedek = @(Get-Content $script:dnsYedekDosyasi -Raw | ConvertFrom-Json)
    foreach ($y in $yedek) {
        if ($y.Dhcp) {
            Set-DnsClientServerAddress -InterfaceIndex $y.Index -ResetServerAddresses
        }
        else {
            Set-DnsClientServerAddress -InterfaceIndex $y.Index -ServerAddresses @($y.Sunucular)
        }
        if ($y.Guid) {
            Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($y.Guid)\DohInterfaceSettings" -Recurse -Force
        }
    }
    Remove-Item $script:dnsYedekDosyasi -Force
    Clear-DnsClientCache
    return $true
}

function DnsElleAnlat {
    [MesajKutusu]::Goster(
        "DNS otomatik ayarlanamadı. Elle yapmak için:`n`n" +
        "1. Ayarlar > Ağ ve İnternet > kullandığın bağlantı`n" +
        "2. DNS sunucusu ataması > Düzenle > El ile`n" +
        "3. IPv4: Açık`n" +
        "   Tercih edilen DNS: 1.1.1.1 > DNS over HTTPS: Açık (otomatik şablon)`n" +
        "   Alternatif DNS: 1.0.0.1 > DNS over HTTPS: Açık (otomatik şablon)`n" +
        "4. Kaydet`n`n" +
        "Windows 10 kullanıyorsan bu seçenek olmayabilir.",
        'Discord Başlatıcı', 'OK', 'Information') | Out-Null
}

# Menüden ya da açılışta: izin sorup DNS'i ayarla
function DnsAyarlaSorarak {
    $cevap = [MesajKutusu]::Goster(
        "İnternet sağlayıcının DNS'i Discord için yanlış adres veriyor. Bu yüzden Discord bağlanamayabilir.`n`n" +
        "DNS ayarın Cloudflare şifreli DNS'e (1.1.1.1, DNS over HTTPS) çevrilsin mi?`n`n" +
        "Eski ayarın yedekleniyor. İstediğin zaman tepsi menüsünden DNS > Eski haline döndür ile geri alabilirsin.",
        'Discord Başlatıcı', 'YesNo', 'Question')
    if ($cevap -ne 'Yes') { return $false }

    Durum 'DNS ayarlanıyor'
    if (DnsAyarla) {
        Remove-Item $script:dnsSormaDosyasi -Force
        Bildirim 'DNS ayarlandı' 'Şifreli DNS açıldı, Discord adresi doğru çözülüyor.'
        return $true
    }
    DnsElleAnlat
    return $false
}

# --- Otomatik başlatma ---

function OtomatikBaslatVarMi {
    return [bool](Get-ScheduledTask -TaskName $script:gorevAdi)
}

# Sabit bir yere küçük bir "bulucu" betik koyar. Bilgisayar açılınca görev bu betiği çalıştırır.
# Bulucu, başlatıcının son bilinen yerine bakar; klasörün adı değişmiş ya da taşınmışsa
# Masaüstü, Belgeler, İndirilenler ve eski konumun çevresinde arayıp yeni yerini bulur.
function BulucuyuKur {
    New-Item -ItemType Directory -Path $script:sabitKlasor -Force | Out-Null
    $bulucu = @'
$ErrorActionPreference = 'SilentlyContinue'
$yolDosyasi = Join-Path $PSScriptRoot 'yol.txt'
$isaret = 'DiscordBaslaticiTepsi'

function Gecerli($p) {
    return ($p -and (Test-Path $p) -and (Select-String -Path $p -Pattern $isaret -SimpleMatch -Quiet))
}

$yol = Get-Content $yolDosyasi -TotalCount 1
if (-not (Gecerli $yol)) {
    $adaylar = @()
    if ($yol) {
        $eskiUst = Split-Path (Split-Path (Split-Path $yol -Parent) -Parent) -Parent
        if ($eskiUst) { $adaylar += $eskiUst }
    }
    $adaylar += [Environment]::GetFolderPath('Desktop')
    $adaylar += [Environment]::GetFolderPath('MyDocuments')
    $adaylar += (Join-Path $env:USERPROFILE 'Downloads')
    $adaylar += $env:USERPROFILE

    $yol = $null
    foreach ($aday in ($adaylar | Select-Object -Unique)) {
        if (-not (Test-Path $aday)) { continue }
        $bulunan = Get-ChildItem -Path $aday -Filter 'discord.ps1' -File -Recurse -Depth 4 |
                   Where-Object { $_.FullName -notmatch '\\AppData\\' -and (Gecerli $_.FullName) } |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($bulunan) { $yol = $bulunan.FullName; break }
    }

    if (-not $yol) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("Discord Baslatici bulunamadi.`nKlasoru tasidiysan Baslat.bat ile bir kere ac.", 'Discord Baslatici', 'OK', 'Warning') | Out-Null
        exit
    }
    Set-Content -Path $yolDosyasi -Value $yol -Encoding UTF8
}

& $yol -Gizli
'@
    Set-Content -Path (Join-Path $script:sabitKlasor 'bulucu.ps1') -Value $bulucu -Encoding ASCII
    Set-Content -Path (Join-Path $script:sabitKlasor 'yol.txt') -Value $script:betikYolu -Encoding UTF8
}

function OtomatikBaslatAyarla($ac) {
    if ($ac) {
        BulucuyuKur
        $bulucuYolu = Join-Path $script:sabitKlasor 'bulucu.ps1'
        $kullanici = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $eylem = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bulucuYolu`""
        $tetik = New-ScheduledTaskTrigger -AtLogOn -User $kullanici
        $tetik.Delay = 'PT30S'
        $yetki = New-ScheduledTaskPrincipal -UserId $kullanici -LogonType Interactive -RunLevel Highest
        $ayar  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName $script:gorevAdi -Action $eylem -Trigger $tetik -Principal $yetki -Settings $ayar -Force | Out-Null
    }
    else {
        Unregister-ScheduledTask -TaskName $script:gorevAdi -Confirm:$false
    }
}

# ---------------------------------------------------------------------------
# Başlangıç kontrolleri
# ---------------------------------------------------------------------------

# Aynı anda iki kopya çalışmasın
$yeniKopya = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\DiscordBaslaticiTepsi', [ref]$yeniKopya)
if (-not $yeniKopya) {
    if (-not $script:gizliBaslat) { Hata 'Discord Başlatıcı zaten çalışıyor. Tepsideki simgeye bak.' }
    exit
}

# Dosya yolları
$klasor              = $PSScriptRoot
$script:ciadpi       = Join-Path $klasor 'ciadpi.exe'
# goodbyedpi klasörü: byedpi klasörünün yanında (..\goodbyedpi) ya da içinde (goodbyedpi)
$ustKlasor = Split-Path $klasor -Parent
$gdpiAna   = Join-Path $ustKlasor 'goodbyedpi'
if (-not (Test-Path $gdpiAna)) { $gdpiAna = Join-Path $klasor 'goodbyedpi' }
$script:gdpiKlasor   = $gdpiAna
if (Test-Path (Join-Path $gdpiAna 'x86_64\goodbyedpi.exe')) { $script:gdpiKlasor = Join-Path $gdpiAna 'x86_64' }
$script:gdpiExe      = Join-Path $script:gdpiKlasor 'goodbyedpi.exe'
$script:blacklist    = Join-Path $gdpiAna 'discord.txt'
$script:ayarDosyasi  = Join-Path $klasor 'byedpi_ayar.txt'
$script:sessizDosya  = Join-Path $klasor 'sessiz_mod.txt'
$script:dnsSormaDosyasi = Join-Path $klasor 'dns_sorma.txt'
$script:dnsYedekDosyasi = Join-Path $script:sabitKlasor 'dns_yedek.json'
$script:log          = Join-Path $env:TEMP 'discord_baslat.log'
$script:logHat       = Join-Path $env:TEMP 'discord_baslat_hata.log'

if (-not (Test-Path $script:ciadpi))    { Hata "ciadpi.exe bulunamadı:`n$script:ciadpi" }
if (-not (Test-Path $script:gdpiExe))   { Hata "goodbyedpi.exe bulunamadı.`ngoodbyedpi.exe, WinDivert.dll ve WinDivert64.sys dosyalarını`n$gdpiAna klasörüne koy." }
if (-not (Test-Path $script:blacklist)) { Hata "discord.txt bulunamadı:`n$script:blacklist" }

# Kayıtlı ByeDPI ayarını oku
$script:byedpiAyar = $script:onAyarlar[0]
if (Test-Path $script:ayarDosyasi) {
    $kayitli = (Get-Content $script:ayarDosyasi -TotalCount 1)
    if ($kayitli) { $script:byedpiAyar = $kayitli.Trim() }
}

$script:sessizMod  = Test-Path $script:sessizDosya
$script:sonGecikme = $null

# Otomatik başlatma açıksa görevi ve kayıtlı yolu güncelle
if (OtomatikBaslatVarMi) { OtomatikBaslatAyarla $true }

# Programdan çık: mesaj döngüsü çalışıyorsa onu bitir, açılış sırasındaysa işlemi doğrudan sonlandır
function Cik {
    if ($script:donguCalisiyor) {
        $script:ctx.ExitThread()
    }
    else {
        if (-not $script:mutexBirakildi) { $mutex.ReleaseMutex() }
        [Environment]::Exit(0)
    }
}

$script:ctx = New-Object System.Windows.Forms.ApplicationContext

# Başlatıcının tamamını yeniden başlat (Discord, ByeDPI ve GoodbyeDPI dahil)
function ProgramiYenidenBaslat {
    Kaydet 'Program yeniden başlatılıyor (kullanıcı isteği)'
    if ($zamanlayici) { $zamanlayici.Stop() }
    Get-Process Discord | Stop-Process -Force
    GoodbyeDpiKapat
    Get-Process ciadpi | Stop-Process -Force
    TepsiKaldir
    if ($script:sonHicon -ne [IntPtr]::Zero) { [Win32.Native]::DestroyIcon($script:sonHicon) | Out-Null }
    # Yeni kopyanın açılabilmesi için kilidi bırak
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $script:mutexBirakildi = $true
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script:betikYolu`"" -WindowStyle Hidden
    Cik
}

function Bitir {
    if ($zamanlayici) { $zamanlayici.Stop() }
    GoodbyeDpiKapat
    Get-Process ciadpi | Stop-Process -Force
    TepsiKaldir
    if ($script:sonHicon -ne [IntPtr]::Zero) { [Win32.Native]::DestroyIcon($script:sonHicon) | Out-Null }
    Cik
}

# ---------------------------------------------------------------------------
# Tepsi simgesi ve menü
# ---------------------------------------------------------------------------

$script:tepsi = New-Object System.Windows.Forms.NotifyIcon
$script:tepsi.Text = 'Discord Başlatıcı'
Renk 'sari'

$menu = New-Object System.Windows.Forms.ContextMenuStrip

# En üstte: GitHub sayfasını aç
$githubOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Jerb-DpiDiscord GitHub')
$githubOgesi.Font = New-Object System.Drawing.Font($githubOgesi.Font, [System.Drawing.FontStyle]::Bold)
$githubOgesi.add_Click({
    # explorer üzerinden açılınca tarayıcı yönetici olarak değil, normal kullanıcı olarak açılır
    Start-Process explorer.exe $GITHUB_ADRESI
})
$menu.Items.Add($githubOgesi) | Out-Null

$bagisOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Destek ol (bağış)')
$bagisOgesi.add_Click({ Start-Process explorer.exe $BAGIS_ADRESI })
$menu.Items.Add($bagisOgesi) | Out-Null
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$script:durumOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Durum: başlatılıyor')
$script:durumOgesi.Enabled = $false
$menu.Items.Add($script:durumOgesi) | Out-Null

$script:gecikmeOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Bağlantı süresi: -')
$script:gecikmeOgesi.Enabled = $false
$menu.Items.Add($script:gecikmeOgesi) | Out-Null

$script:ayarOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('ByeDPI ayarı: -')
$script:ayarOgesi.Enabled = $false
$menu.Items.Add($script:ayarOgesi) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# Menü açılınca bağlantıyı ölç (Discord hazırsa)
$menu.add_Opening({
    if ($script:asama -eq 'izle') { ByeDpiTest | Out-Null }
    BaglantiBilgisiGuncelle
})

$yenidenOgesi = New-Object System.Windows.Forms.ToolStripMenuItem("Discord'u yeniden başlat")
$yenidenOgesi.add_Click({ Kaydet "Discord yeniden başlatılıyor (kullanıcı isteği)"; DiscordBaslat })
$menu.Items.Add($yenidenOgesi) | Out-Null

$programOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Programı yeniden başlat')
$programOgesi.add_Click({ ProgramiYenidenBaslat })
$menu.Items.Add($programOgesi) | Out-Null

$ayarBulOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('ByeDPI ayarını otomatik bul')
$ayarBulOgesi.add_Click({
    if ($script:asama -ne 'izle') {
        Bildirim 'Biraz bekle' "Discord açılıp hazır olduktan sonra tekrar dene." 'Warning'
    }
    else {
        ByeDpiAyarBul | Out-Null
    }
})
$menu.Items.Add($ayarBulOgesi) | Out-Null

$kayitOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Kayıtları aç')
$kayitOgesi.add_Click({
    if (-not (Test-Path $script:olayLog)) { Kaydet 'Kayıt dosyası oluşturuldu' }
    Start-Process notepad.exe $script:olayLog
})
$menu.Items.Add($kayitOgesi) | Out-Null

$onarOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Sürücü hatasını onar')
$onarOgesi.add_Click({ SurucuOnar })
$menu.Items.Add($onarOgesi) | Out-Null

$dnsOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('DNS')

$dnsKontrolOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('DNS ayarını kontrol et / yap')
$dnsKontrolOgesi.add_Click({
    if (DnsDogruMu) {
        Bildirim 'DNS doğru' 'Discord adresi doğru çözülüyor, bir şey yapmaya gerek yok.'
    }
    else {
        DnsAyarlaSorarak | Out-Null
    }
})
$dnsOgesi.DropDownItems.Add($dnsKontrolOgesi) | Out-Null

$dnsGeriOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Eski haline döndür')
$dnsGeriOgesi.add_Click({
    $cevap = [MesajKutusu]::Goster(
        "DNS ayarın, başlatıcının değiştirmeden önceki haline döndürülsün mü?`n`nDiscord bundan sonra bağlanamayabilir.",
        'Discord Başlatıcı', 'YesNo', 'Question')
    if ($cevap -eq 'Yes') {
        if (DnsGeriAl) {
            Set-Content -Path $script:dnsSormaDosyasi -Value '1' -Encoding ASCII
            Bildirim 'DNS geri alındı' 'DNS ayarın eski haline döndürüldü.'
        }
        else {
            Bildirim 'Yedek yok' 'Başlatıcı DNS ayarını hiç değiştirmemiş.' 'Warning'
        }
    }
})
$dnsOgesi.DropDownItems.Add($dnsGeriOgesi) | Out-Null

# Alt menü açılınca "Eski haline döndür" sadece yedek varsa aktif olsun
$dnsOgesi.add_DropDownOpening({ $dnsGeriOgesi.Enabled = (Test-Path $script:dnsYedekDosyasi) })
$menu.Items.Add($dnsOgesi) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$otoOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Bilgisayar açılınca başlat')
$otoOgesi.Checked = OtomatikBaslatVarMi
$otoOgesi.add_Click({
    $istenen = -not $otoOgesi.Checked
    OtomatikBaslatAyarla $istenen
    $otoOgesi.Checked = OtomatikBaslatVarMi
    if ($otoOgesi.Checked -ne $istenen) {
        Bildirim 'Ayar değiştirilemedi' 'Otomatik başlatma ayarı kaydedilemedi.' 'Warning'
    }
    elseif ($istenen) {
        Bildirim 'Otomatik başlatma açık' 'Bilgisayar açılınca Discord tepsiye küçülmüş olarak başlayacak.'
    }
    else {
        Bildirim 'Otomatik başlatma kapalı' 'Discord Başlatıcı artık kendiliğinden açılmayacak.'
    }
})
$menu.Items.Add($otoOgesi) | Out-Null

$sessizOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Sessiz mod (sadece sorun bildirimleri)')
$sessizOgesi.Checked = $script:sessizMod
$sessizOgesi.add_Click({
    $script:sessizMod = -not $script:sessizMod
    if ($script:sessizMod) { Set-Content -Path $script:sessizDosya -Value '1' -Encoding ASCII }
    else                   { Remove-Item $script:sessizDosya -Force }
    $sessizOgesi.Checked = $script:sessizMod
})
$menu.Items.Add($sessizOgesi) | Out-Null
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$kapatOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Her şeyi kapat (Discord + ByeDPI)')
$kapatOgesi.add_Click({
    Get-Process Discord | Stop-Process -Force
    Bitir
})
$menu.Items.Add($kapatOgesi) | Out-Null

$script:tepsi.ContextMenuStrip = $menu

# Simgeye sol tıklayınca Discord penceresini öne getir
# (Discord zaten açıkken tekrar çalıştırılınca açık olan pencereyi gösterir)
$script:tepsi.add_MouseClick({
    param($kaynak, $olay)
    if ($olay.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $exe = DiscordBul
    if ($exe -and (Get-Process Discord)) {
        Start-Process $exe -ArgumentList '--proxy-server=socks5://127.0.0.1:1080'
    }
})
$script:tepsi.Visible = $true

# ---------------------------------------------------------------------------
# İlk açılış
# ---------------------------------------------------------------------------

# Açık kalmış GoodbyeDPI ve Discord varsa kapat
Get-Process goodbyedpi, Discord | Stop-Process -Force
Start-Sleep -Seconds 1
sc.exe stop WinDivert | Out-Null

# DNS kontrolü (GoodbyeDPI kendi DNS yönlendirmesini yaptığı için o açılmadan önce bakılır)
Durum 'DNS kontrol ediliyor'
if (-not (DnsDogruMu)) {
    if ($script:gizliBaslat) {
        Bildirim 'DNS ayarı uygun değil' "Discord bağlanamayabilir. Tepsi menüsünden DNS > 'DNS ayarını kontrol et / yap' seçeneğini kullan." 'Warning'
    }
    elseif (-not (Test-Path $script:dnsSormaDosyasi)) {
        if (-not (DnsAyarlaSorarak)) {
            # Kullanıcı istemediyse bir daha açılışta sorma (menüden yapılabilir)
            if (-not (DnsDogruMu)) { Set-Content -Path $script:dnsSormaDosyasi -Value '1' -Encoding ASCII }
        }
    }
}

ByeDpiAc

Durum 'GoodbyeDPI açılıyor'
if (-not (GoodbyeDpiAc)) {
    Renk 'kirmizi'
    $cevap = [MesajKutusu]::Goster(
        "GoodbyeDPI başlatılamadı (sürücü sorunu olabilir).`n`nSürücüyü onarmak ister misin?",
        'Discord Başlatıcı', 'YesNo', 'Error')
    GoodbyeDpiKapat
    Get-Process ciadpi | Stop-Process -Force
    TepsiKaldir
    if ($cevap -eq 'Yes') { SurucuOnar }
    exit
}

# Discord kurulu değilse indir ve kur
if (-not (DiscordBul)) {
    Durum 'Discord indiriliyor'
    Bildirim 'Discord bulunamadı' 'Discord indiriliyor ve kuruluyor, birkaç dakika sürebilir...'
    if (-not (DiscordIndirKur)) {
        Hata "Discord indirilemedi veya kurulamadı.`nİnternet bağlantını kontrol edip tekrar dene." -Temizle
    }
    Bildirim 'Discord kuruldu' 'Discord açılıyor...'
}

Kaydet "Başlatıcı açıldı (gizli: $script:gizliBaslat, ByeDPI ayarı: $script:byedpiAyar)"
if ($script:gizliBaslat) { DiscordBaslat -Kucuk } else { DiscordBaslat }
HatalariKaydet 'açılış'

# ---------------------------------------------------------------------------
# Her saniye çalışan kontrol
# ---------------------------------------------------------------------------

$script:tik = 0

$zamanlayici = New-Object System.Windows.Forms.Timer
$zamanlayici.Interval = 1000
$zamanlayici.add_Tick({
    $script:tik++
    $script:sayac++

    # 3 saniyede bir: ByeDPI ve proxy'siz Discord kontrolü
    if ($script:tik % 3 -eq 0) {

        # ByeDPI çöktüyse yeniden aç
        if (-not (Get-Process ciadpi)) {
            Kaydet 'ByeDPI kapanmış bulundu, yeniden başlatılıyor'
            ByeDpiAc
            Bildirim 'ByeDPI yeniden başlatıldı' 'ByeDPI kapanmıştı, tekrar açıldı.' 'Warning'
        }

        # Discord kendini proxy'siz açtıysa düzelt (başlatmadan sonraki ilk 15 saniye hariç)
        if (((Get-Date) - $script:sonBaslatma).TotalSeconds -gt 15 -and (ProxysizDiscordVarMi)) {
            Kaydet "Discord proxy'siz açılmış bulundu, yeniden başlatılıyor"
            Bildirim "Discord proxy'siz açılmıştı" 'ByeDPI ile yeniden açılıyor...' 'Warning'
            DiscordBaslat
            return
        }
    }

    if ($script:asama -eq 'bekle') {
        $kayitta = Select-String -Path $script:log -Pattern 'splash-update-complete|mainscreen-launch-window' -Quiet
        if ($script:kucukAcildi) {
            # Pencere gizliyken: Discord ByeDPI üzerinden bağlandıysa güncelleme bitmiştir
            $hazir = $kayitta -or (DiscordProxyBaglantisiVarMi)
        }
        else {
            $pencere = Get-Process Discord | Where-Object { $_.MainWindowTitle -match 'Discord' -and $_.MainWindowTitle -notmatch 'Updater' }
            $hazir = $kayitta -or $pencere
        }

        if ($hazir) {
            $script:asama = 'tampon'
            $script:sayac = 0
        }
        elseif ($script:sayac -ge 120) {
            GoodbyeDpiKapat
            $script:asama = 'izle'
            $script:sayac = 0
            Renk 'kirmizi'
            Durum 'güncelleme bitmedi'
            Kaydet 'Güncelleme kontrolü 2 dakikada bitmedi'
            Bildirim 'Discord güncellenemedi' "Güncelleme kontrolü 2 dakikada bitmedi, GoodbyeDPI kapatıldı.`nTepsiden 'Discord'u yeniden başlat'ı dene." 'Warning'
        }
        else {
            Durum "güncelleme bekleniyor ($($script:sayac) sn)"
        }
    }
    elseif ($script:asama -eq 'tampon') {
        if ($script:sayac -ge 3) {
            GoodbyeDpiKapat
            $script:asama = 'izle'
            $script:sayac = 0
            Renk 'yesil'
            Durum 'Discord ByeDPI ile çalışıyor'
            Kaydet 'Discord hazır, GoodbyeDPI kapatıldı'
            HatalariKaydet 'güncelleme'
            if (-not $script:kucukAcildi) {
                Bildirim 'Discord hazır' 'Discord ByeDPI ile çalışıyor.'
            }
        }
    }
    elseif ($script:asama -eq 'izle') {
        # 3 saniyede bir bak; Discord iki kontrol üst üste yoksa her şeyi kapat
        if ($script:sayac % 3 -eq 0) {
            if (Get-Process Discord) { $script:yok = 0 } else { $script:yok++ }
            if ($script:yok -ge 2) { Bitir; return }
        }

        # Hazır olduktan 10 saniye sonra ve sonra her dakika bağlantıyı test et
        if ($script:sayac -eq 10 -or ($script:sayac -gt 10 -and $script:sayac % 60 -eq 0)) {
            $baglanti = ByeDpiBaglantiSayisi
            if (-not (ByeDpiTest)) {
                Start-Sleep -Seconds 2
                if (-not (ByeDpiTest)) {
                    Kaydet "Bağlantı testi başarısız (ByeDPI'a açık bağlantı: $baglanti, ayar: $script:byedpiAyar, discord.com -> $(DiscordAdresi))"

                    # 1) Önce DNS: sağlayıcının sahte cevabı en sık neden
                    $dnsDuzeldi = $false
                    if ((DiscordAdresi) -notlike '162.159.*') {
                        if (DnsZehirlenmesiniDuzelt) {
                            ByeDpiYenidenBaslat $script:byedpiAyar
                            Start-Sleep -Seconds 1
                            $dnsDuzeldi = ByeDpiTest
                        }
                        else {
                            Renk 'kirmizi'
                            Durum 'DNS sahte cevap veriyor'
                            Bildirim 'DNS engeli' "Sağlayıcının DNS'i Discord için sahte adres veriyor. Tepsi menüsünden DNS > 'DNS ayarını kontrol et / yap' seç." 'Error'
                            return
                        }
                    }

                    # 2) Sonra ByeDPI'ı aynı ayarla yeniden başlat
                    if (-not $dnsDuzeldi) {
                        ByeDpiYenidenBaslat $script:byedpiAyar
                        Start-Sleep -Seconds 1
                    }
                    if ($dnsDuzeldi -or (ByeDpiTest)) {
                        Kaydet "Bağlantı düzeldi ($($script:sonGecikme) ms)"
                        Bildirim 'Bağlantı düzeltildi' 'Bağlantı koptu ve otomatik olarak düzeltildi.' 'Warning'
                        Renk 'yesil'
                        Durum 'Discord ByeDPI ile çalışıyor'
                    }
                    else {
                        Kaydet 'Yeniden başlatma yetmedi, başka ByeDPI ayarı aranıyor'
                        Bildirim 'Bağlantı koptu' 'ByeDPI çalışan bir ayar arıyor...' 'Warning'
                        if (ByeDpiAyarBul) { Kaydet "Çalışan ayar bulundu: $script:byedpiAyar" }
                        else               { Kaydet "Hiçbir ayar çalışmadı" }
                    }
                }
            }
            elseif ((DiscordAdresi) -notlike '162.159.*') {
                # Bağlantı şimdilik çalışıyor ama DNS bozulmuş: önbellek bitince kopacak, şimdiden düzelt
                DnsZehirlenmesiniDuzelt | Out-Null
            }
            elseif ($baglanti -gt ($script:byedpiBaglantiSiniri * 0.8)) {
                Kaydet "Uyarı: ByeDPI bağlantı sınırına yaklaşıyor ($baglanti / $script:byedpiBaglantiSiniri)"
            }
            elseif ($script:tepsi -and $script:durumOgesi.Text -ne 'Durum: Discord ByeDPI ile çalışıyor') {
                Renk 'yesil'
                Durum 'Discord ByeDPI ile çalışıyor'
            }
        }
    }
})

$zamanlayici.Start()
$script:donguCalisiyor = $true
[System.Windows.Forms.Application]::Run($script:ctx)
HatalariKaydet 'kapanış'
if (-not $script:mutexBirakildi) { $mutex.ReleaseMutex() }
