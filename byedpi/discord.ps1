# Jerb-DpiDiscord - Discord Başlatıcı
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

# Bu sürümün numarası (güncelleme kontrolü bununla karşılaştırır). "1", "1.1", "2.0.1" gibi yazılabilir.
$SURUM = '1'

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
        # "işlem bulunamadı", "dosya yok" gibi beklenen, zararsız hataları kayda yazma
        if ("$($h.FullyQualifiedErrorId)" -match 'NoProcessFoundForGivenName|PathNotFound|ItemNotFound|CmdletizationQuery_NotFound|NoServiceFoundForGivenName') { continue }
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
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"$ekArg"
    }
    catch {
        # Kullanıcı yönetici iznine "Hayır" dedi
        Kaydet 'Yönetici izni verilmedi, başlatıcı açılmadı'
        if (-not $Gizli) {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("Yönetici izni verilmediği için başlatıcı açılmadı.`n`nGoodbyeDPI'ın ağ sürücüsü yönetici izni olmadan çalışamıyor.", 'Discord Başlatıcı', 'OK', 'Warning') | Out-Null
        }
    }
    exit
}

# İnternetten indirilen dosyalardaki "internetten geldi" işaretini kaldır
# (yoksa Baslat.bat her açılışta "Yayımcı doğrulanamadı" uyarısı veriyor)
# Sadece programın kendi dosyalarına dokunur: Baslat.bat, byedpi ve goodbyedpi klasörleri
$anaKlasor = Split-Path $PSScriptRoot -Parent
Unblock-File -Path (Join-Path $anaKlasor 'Baslat.bat')
Get-ChildItem -Path $PSScriptRoot -Recurse -File | Unblock-File
Get-ChildItem -Path (Join-Path $anaKlasor 'goodbyedpi') -Recurse -File | Unblock-File

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string sinif, string baslik);
'@

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

# Farklı internet sağlayıcıları farklı yöntemlerle engelliyor; çalışan bulunana kadar sırayla denenir
$script:onAyarlar = @(
    '--disorder 1 --tlsrec 1+s',
    '--split 1+s --disorder 3+s',
    '--tlsrec 3+s --split 2',
    '--disorder 1 --split 2 --tlsrec 1+s',
    '--fake -1 --ttl 8',
    '--fake -1 --ttl 5 --disorder 1',
    '--fake -1 --ttl 3 --tlsrec 1+s',
    '--oob 1 --tlsrec 1+s',
    '--disoob 1 --split 1+s',
    '--disorder 1 --fake -1 --ttl 6 --tlsrec 3+s',
    '--split 1+s --oob 2+s --tlsrec 1+s',
    '--disorder 1 --tlsrec 1+s --auto torst,ssl_err --fake -1 --ttl 5 --auto torst,ssl_err --split 1+s --oob 2+s'
)

# GoodbyeDPI ayarları (sadece açılıştaki Discord güncelleme kontrolü için kullanılır).
# GoodbyeDPI-Turkey paketindeki ayarlar: ana ayar ve Superonline için 6 alternatif.
$script:gdpiAyarlari = @(
    '-5 --set-ttl 5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253',
    '--set-ttl 3',
    '-5',
    '--set-ttl 3 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253',
    '-5 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253',
    '-9 --dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253',
    '-9'
)
# Bir GoodbyeDPI ayarına kaç saniye şans verilsin (güncelleme bu sürede bitmezse sıradakine geçilir)
$script:gdpiDenemeSuresi = 20

# ---------------------------------------------------------------------------
# Yardımcı fonksiyonlar
# ---------------------------------------------------------------------------

# Bu başlatıcının açtığı goodbyedpi.exe işlemleri (klasör yoluna bakarak ayırt edilir)
function BizimGoodbyeDpi {
    if (-not $script:gdpiExe) { return @() }
    $bizimki = [System.IO.Path]::GetFullPath($script:gdpiExe)
    return @(Get-Process goodbyedpi | Where-Object { $_.Path -and [System.IO.Path]::GetFullPath($_.Path) -eq $bizimki })
}

function GoodbyeDpiKapat {
    $bizim = BizimGoodbyeDpi
    if ($bizim.Count -gt 0) {
        $bizim | Stop-Process -Force
        Start-Sleep -Milliseconds 1500
    }
    # Sürücüyü sadece başka bir GoodbyeDPI kullanmıyorsa kapat
    if (-not (Get-Process goodbyedpi)) { sc.exe stop WinDivert | Out-Null }
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
    if ($script:tepsi) {
        $script:sonBildirimBasligi = $baslik
        $script:tepsi.ShowBalloonTip(5000, $baslik, $metin, $tur)
    }
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
# curl çıkış kodunu anlaşılır yazıya çevir
function CurlHataMetni($kod) {
    switch ($kod) {
        0       { 'beklenmeyen cevap' }
        5       { 'proxy adı çözülemedi' }
        6       { 'adres çözülemedi (DNS)' }
        7       { "ByeDPI'a bağlanılamadı" }
        28      { 'zaman aşımı' }
        35      { 'TLS el sıkışması başarısız (engel)' }
        52      { 'boş cevap' }
        56      { 'bağlantı kesildi / sıfırlandı (engel)' }
        97      { 'proxy (SOCKS) hatası' }
        $null   { 'curl bulunamadı' }
        default { "curl hata kodu $kod" }
    }
}

function ByeDpiTest {
    $global:LASTEXITCODE = $null
    $cikti = & curl.exe -s -o NUL -w '%{http_code} %{time_total}' --max-time 5 -x socks5h://127.0.0.1:1080 'https://discord.com/api/v9/gateway'
    $script:sonTestHatasi = CurlHataMetni $LASTEXITCODE
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
        $tamam = ByeDpiTest
        if (-not $tamam) { Kaydet "  ByeDPI ayarı çalışmadı: $ayar ($script:sonTestHatasi)" }
        if ($tamam) {
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

# GoodbyeDPI ayarlarının deneme sırası: önce en son çalışan (kayıtlı) ayar, sonra diğerleri
function GdpiSirasiniHazirla {
    $kayitli = $script:gdpiAyarlari[0]
    if (Test-Path $script:gdpiAyarDosyasi) {
        $okunan = (Get-Content $script:gdpiAyarDosyasi -TotalCount 1)
        if ($okunan -and $script:gdpiAyarlari -contains $okunan.Trim()) { $kayitli = $okunan.Trim() }
    }
    $script:gdpiSira    = @($kayitli) + @($script:gdpiAyarlari | Where-Object { $_ -ne $kayitli })
    $script:gdpiSiraNo  = 0
    $script:gdpiAyar    = $script:gdpiSira[0]
}

# Güncelleme kontrolü geçmiyorsa sıradaki GoodbyeDPI ayarına geç. Başka ayar kalmadıysa $false döner.
function GdpiSonrakiAyar {
    if ($script:gdpiSiraNo + 1 -ge $script:gdpiSira.Count) { return $false }
    $script:gdpiSiraNo++
    $script:gdpiAyar = $script:gdpiSira[$script:gdpiSiraNo]
    # Sürücüyü kapatmadan sadece işlemi değiştir (sürücüyü sık açıp kapatmak 1058 hatasına yol açabiliyor)
    BizimGoodbyeDpi | Stop-Process -Force
    Start-Sleep -Milliseconds 800
    Kaydet "GoodbyeDPI ayarı değiştiriliyor ($($script:gdpiSiraNo + 1)/$($script:gdpiSira.Count)): $script:gdpiAyar"
    GoodbyeDpiAc | Out-Null
    return $true
}

function GoodbyeDpiAc {
    if (-not $script:gdpiAyar) { GdpiSirasiniHazirla }
    if ((BizimGoodbyeDpi).Count -eq 0) {
        Start-Process $script:gdpiExe -WorkingDirectory $script:gdpiKlasor -WindowStyle Hidden -ArgumentList "$script:gdpiAyar --blacklist `"$script:blacklist`""
        Start-Sleep -Seconds 3
    }
    return ((BizimGoodbyeDpi).Count -gt 0)
}

# --- Arka planda çalışan başka GoodbyeDPI'lar ---

# Bu başlatıcının açmadığı GoodbyeDPI'ları bul: servis olarak kurulanlar ve başka klasörden çalışanlar
function DisGoodbyeDpiBul {
    $sonuc = @()
    $servisler = @(Get-CimInstance Win32_Service | Where-Object { $_.PathName -match 'goodbyedpi' -or $_.Name -match '^goodbyedpi' })
    foreach ($sv in $servisler) {
        if ($sv.State -eq 'Running' -or $sv.StartMode -eq 'Auto') {
            $sonuc += [PSCustomObject]@{ Tur = 'servis'; Ad = $sv.Name; Id = $null }
        }
    }
    $bizimki = [System.IO.Path]::GetFullPath($script:gdpiExe)
    foreach ($islem in @(Get-Process goodbyedpi)) {
        $yol = $islem.Path
        if (-not $yol -or [System.IO.Path]::GetFullPath($yol) -ne $bizimki) {
            $ad = if ($yol) { $yol } else { 'goodbyedpi.exe' }
            $sonuc += [PSCustomObject]@{ Tur = 'program'; Ad = "$ad (PID $($islem.Id))"; Id = $islem.Id }
        }
    }
    return ,$sonuc
}

# Bulunanları kapat. Servislerin otomatik başlaması da kapatılır (geri açmak için: services.msc).
function DisGoodbyeDpiKapat($liste) {
    foreach ($x in $liste) {
        if ($x.Tur -eq 'servis') {
            Stop-Service -Name $x.Ad -Force
            Set-Service -Name $x.Ad -StartupType Disabled
            Kaydet "Arka plandaki GoodbyeDPI servisi durduruldu ve otomatik başlaması kapatıldı: $($x.Ad)"
        }
        else {
            Stop-Process -Id $x.Id -Force
            Kaydet "Arka planda çalışan GoodbyeDPI kapatıldı: $($x.Ad)"
        }
    }
    Start-Sleep -Seconds 1
    # Bizim GoodbyeDPI'ımız da çalışmıyorsa sürücüyü de kapat
    if (-not (Get-Process goodbyedpi)) { sc.exe stop WinDivert | Out-Null }
}

# Arka planda başka GoodbyeDPI var mı bak; varsa sor (ya da önceden "hep kapat" dendiyse sormadan kapat).
# $Elle: menüden istendi; hiçbir şey bulunmazsa da bildir, daha önce "hayır" dendiyse yine sor.
function DisGoodbyeDpiKontrol([switch]$Elle) {
    $liste = DisGoodbyeDpiBul
    if ($liste.Count -eq 0) {
        if ($Elle) { Bildirim 'Bulunamadı' 'Arka planda başka bir GoodbyeDPI çalışmıyor.' }
        return
    }

    if (Test-Path $script:disGdpiOtomatikDosya) {
        DisGoodbyeDpiKapat $liste
        Bildirim 'Arka plandaki GoodbyeDPI kapatıldı' "Oyunlarla çakışmaması için kapatıldı: $(($liste | ForEach-Object { $_.Ad }) -join ', ')" 'Warning'
        return
    }

    # Bu oturumda zaten "hayır" dendiyse kendiliğinden tekrar sorma
    if (-not $Elle -and $script:disGdpiReddedildi) { return }

    $adlar = ($liste | ForEach-Object { "  • $($_.Tur): $($_.Ad)" }) -join "`n"
    $cevap = [MesajKutusu]::Goster(
        "Arka planda bu başlatıcının açmadığı bir GoodbyeDPI çalışıyor:`n`n$adlar`n`n" +
        "Bu, oyunlarla çakışmaya (oyunun açılmaması / çökmesi) yol açabilir.`n`n" +
        "Kapatılsın mı? Servisse, bilgisayar açılınca kendiliğinden başlaması da kapatılır.`n" +
        "Evet dersen bu seçim hatırlanır, bir dahakine sormadan kapatılır.",
        'Discord Başlatıcı', 'YesNo', 'Warning')
    if ($cevap -eq 'Yes') {
        Set-Content -Path $script:disGdpiOtomatikDosya -Value '1' -Encoding ASCII
        DisGoodbyeDpiKapat $liste
        Bildirim 'Kapatıldı' 'Arka plandaki GoodbyeDPI kapatıldı.'
    }
    else {
        $script:disGdpiReddedildi = $true
        Kaydet "Arka planda başka GoodbyeDPI var, kullanıcı kapatmak istemedi: $(($liste | ForEach-Object { $_.Ad }) -join ', ')"
    }
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
    DiscorduNormalYetkiyleAc $kurulum '' 'discord_kurulum.lnk'

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

# Discord'u yönetici olarak DEĞİL, normal kullanıcı yetkisiyle aç.
# Başlatıcı yönetici olarak çalıştığı için doğrudan açılan Discord da yönetici olur; o zaman
# Gezgin'den Discord'a dosya sürükle-bırak çalışmaz ve bildirimden açılan kopyalar karışır.
# Bunun için geçici bir kısayol oluşturulup Windows Gezgini (explorer) üzerinden açılır.
function DiscorduNormalYetkiyleAc($exe, $argumanlar, $kisayolAdi = 'discord_baslat.lnk') {
    New-Item -ItemType Directory -Path $script:sabitKlasor -Force | Out-Null
    $lnk = Join-Path $script:sabitKlasor $kisayolAdi
    $kabuk = New-Object -ComObject WScript.Shell
    $kisayol = $kabuk.CreateShortcut($lnk)
    $kisayol.TargetPath       = $exe
    $kisayol.Arguments        = $argumanlar
    $kisayol.WorkingDirectory = Split-Path $exe -Parent
    $kisayol.Save()
    if (Get-Process explorer) {
        Start-Process explorer.exe "`"$lnk`""
    }
    else {
        # Gezgin çalışmıyorsa (çok nadir) mecburen doğrudan aç
        Start-Process $exe -ArgumentList $argumanlar
    }
}

# Discord'u (yeniden) başlat: GoodbyeDPI'ı aç, Discord'u ByeDPI ile aç, güncelleme beklemeye geç
function DiscordBaslat([switch]$Kucuk) {
    Get-Process Discord | Stop-Process -Force
    Start-Sleep -Seconds 1

    Renk 'sari'
    ByeDpiAc
    if ((BizimGoodbyeDpi).Count -eq 0) { GdpiSirasiniHazirla }
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
    DiscorduNormalYetkiyleAc $exe $discordArg

    $script:asama       = 'bekle'
    $script:sayac       = 0
    $script:yok         = 0
    $script:kucukAcildi = [bool]$Kucuk
    $script:sonBaslatma = Get-Date
    Durum 'güncelleme bekleniyor'
}

# Discord proxy'siz mi çalışıyor?
# Bizim açtığımız (proxy'li) ana Discord işlemi hâlâ çalışıyorsa $false döner: Discord bildirimine
# tıklamak gibi durumlarda Windows bir anlığına proxy'siz ikinci bir kopya açıyor, o kopya açık olan
# Discord'a pencereyi göstermesini söyleyip kapanıyor. Bunu "proxy'siz açılmış" sanmamak gerekiyor.
function ProxysizDiscordVarMi {
    $ana = @(Get-CimInstance Win32_Process -Filter "Name='Discord.exe'" |
             Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '--type=' })
    if ($ana.Count -eq 0) { return $false }
    if ($ana | Where-Object { $_.CommandLine -match '--proxy-server' }) { return $false }
    return $true
}

# Discord ByeDPI üzerinden bağlantı kurdu mu? (pencere gizliyken kullanılır)
function DiscordProxyBaglantisiVarMi {
    $pidler = @((Get-Process Discord).Id)
    if ($pidler.Count -eq 0) { return $false }
    return [bool](Get-NetTCPConnection -RemotePort 1080 -State Established | Where-Object { $pidler -contains $_.OwningProcess })
}

# --- İnternet bağlantısı ---

# İnternete çıkılabiliyor mu? (Cloudflare 1.1.1.1:443'e kısa bir TCP bağlantısı dener)
function InternetVarMi {
    $istemci = New-Object System.Net.Sockets.TcpClient
    try {
        $deneme = $istemci.ConnectAsync('1.1.1.1', 443)
        return ($deneme.Wait(2000) -and $istemci.Connected)
    }
    catch { return $false }
    finally { $istemci.Dispose() }
}

# İnternet gelene kadar bekle. Beklerken menü çalışmaya devam eder (ör. "Her şeyi kapat").
function InterneteKadarBekle {
    if (InternetVarMi) { return }
    Kaydet 'İnternet bağlantısı yok, bekleniyor'
    Renk 'sari'
    $baslangic = Get-Date
    $uyarildi = $false
    while (-not (InternetVarMi)) {
        $gecen = [int]((Get-Date) - $baslangic).TotalSeconds
        Durum "internet bekleniyor ($gecen sn)"
        if (-not $uyarildi -and $gecen -ge 60) {
            Bildirim 'İnternet bekleniyor' 'İnternet bağlantısı gelince Discord kendiliğinden açılacak.' 'Warning'
            $uyarildi = $true
        }
        # 2 saniye bekle, bu sırada menü tıklamalarına cevap ver
        for ($i = 0; $i -lt 20; $i++) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
    }
    Kaydet "İnternet bağlantısı geldi ($([int]((Get-Date) - $baslangic).TotalSeconds) sn beklendi)"
}

# --- DNS ---

# Discord'un gerçek adresleri: Cloudflare'in şifreli DNS'ine (DoH) doğrudan sorulur, 10 dakika saklanır.
# Böylece Discord ileride adres değiştirirse de "sahte cevap" kontrolü yanılmaz.
$script:gercekAdresler     = @()
$script:gercekAdresZamani  = [datetime]::MinValue

function GercekDiscordAdresleri {
    if ($script:gercekAdresler.Count -gt 0 -and ((Get-Date) - $script:gercekAdresZamani).TotalMinutes -lt 10) {
        return $script:gercekAdresler
    }
    $json = & curl.exe -s --max-time 5 -H 'accept: application/dns-json' 'https://1.1.1.1/dns-query?name=discord.com&type=A'
    if ($json) {
        $veri = ($json -join "`n") | ConvertFrom-Json
        $liste = @($veri.Answer | Where-Object { $_.type -eq 1 } | ForEach-Object { $_.data })
        if ($liste.Count -gt 0) {
            $script:gercekAdresler    = $liste
            $script:gercekAdresZamani = Get-Date
        }
    }
    return $script:gercekAdresler
}

# Verilen adres Discord'un gerçek adresi mi? (Cloudflare 162.159.* ya da DoH'un verdiği adreslerden biri)
function AdresDiscordunMu($ip) {
    if (-not $ip) { return $false }
    if ($ip -like '162.159.*') { return $true }
    return (@(GercekDiscordAdresleri) -contains $ip)
}

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
    if (AdresDiscordunMu $adres) { return $true }

    Kaydet "DNS yanlış cevap veriyor: discord.com -> $adres (sağlayıcının engel adresi olabilir)"
    Clear-DnsClientCache
    Start-Sleep -Seconds 1
    $adres = DiscordAdresi
    if (AdresDiscordunMu $adres) {
        Kaydet 'DNS önbelleği temizlenince düzeldi'
        return $true
    }

    # DNS'i daha önce başlatıcı (kullanıcının izniyle) ayarladıysa ayarı sessizce yeniden uygula.
    # İzin verilmemişse kullanıcının DNS ayarına dokunma.
    if (Test-Path $script:dnsYedekDosyasi) {
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
    return ($kayit -and (AdresDiscordunMu $kayit.IPAddress))
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
        $statik4 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid").NameServer
        $statik6 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$guid").NameServer
        $yedek += [PSCustomObject]@{
            Index      = $ag.InterfaceIndex
            Ad         = $ag.InterfaceAlias
            Guid       = $guid
            Dhcp       = [string]::IsNullOrWhiteSpace($statik4)
            Dhcp6      = [string]::IsNullOrWhiteSpace($statik6)
            Sunucular  = @((Get-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -AddressFamily IPv4).ServerAddresses)
            Sunucular6 = @((Get-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -AddressFamily IPv6).ServerAddresses)
        }
    }
    New-Item -ItemType Directory -Path $script:sabitKlasor -Force | Out-Null
    $yedek | ConvertTo-Json -Depth 3 | Set-Content -Path $script:dnsYedekDosyasi -Encoding UTF8
}

# DNS'i Cloudflare şifreli DNS'e (DNS over HTTPS) çevir
function DnsAyarla {
    DnsYedekle
    $win11 = [Environment]::OSVersion.Version.Build -ge 22000
    $sunucular  = @('1.1.1.1', '1.0.0.1')
    # IPv6: sağlayıcının IPv6 DNS'i de sahte cevap verebiliyor, onu da Cloudflare'e çevir
    $sunucular6 = @('2606:4700:4700::1111', '2606:4700:4700::1001')

    if ($win11) {
        foreach ($s in ($sunucular + $sunucular6)) {
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
        # Bağlantıda IPv6 DNS kullanılıyorsa onu da değiştir
        $ipv6Var = @((Get-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -AddressFamily IPv6).ServerAddresses).Count -gt 0
        $liste = $sunucular
        if ($ipv6Var) { $liste = $sunucular + $sunucular6 }
        Set-DnsClientServerAddress -InterfaceIndex $ag.InterfaceIndex -ServerAddresses $liste
        if ($win11) {
            $guid = $ag.NetAdapter.InterfaceGuid
            foreach ($s in $sunucular) {
                $anahtar = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$guid\DohInterfaceSettings\Doh\$s"
                New-Item -Path $anahtar -Force | Out-Null
                New-ItemProperty -Path $anahtar -Name 'DohFlags' -Value 1 -PropertyType QWord -Force | Out-Null
            }
            if ($ipv6Var) {
                foreach ($s in $sunucular6) {
                    $anahtar = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$guid\DohInterfaceSettings\Doh6\$s"
                    New-Item -Path $anahtar -Force | Out-Null
                    New-ItemProperty -Path $anahtar -Name 'DohFlags' -Value 1 -PropertyType QWord -Force | Out-Null
                }
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
        # Önce otomatiğe (DHCP) döndür, sonra elle girilmiş eski adresler varsa onları geri yaz
        Set-DnsClientServerAddress -InterfaceIndex $y.Index -ResetServerAddresses
        $eski = @()
        if (-not $y.Dhcp) { $eski += @($y.Sunucular) }
        if ($y.PSObject.Properties['Dhcp6'] -and -not $y.Dhcp6) { $eski += @($y.Sunucular6) }
        $eski = @($eski | Where-Object { $_ })
        if ($eski.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex $y.Index -ServerAddresses $eski
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

# --- Güncelleme kontrolü ---

$script:guncellemeAdresi = $null
$script:bildirilenSurum  = $null

# "v1", "1.1", "v2.0.1" gibi sürüm yazılarını karşılaştırılabilir hale getir ("1" = "1.0" = "1.0.0")
function SurumCevir($metin) {
    $metin = "$metin".Trim() -replace '^[vV]', ''
    $parcalar = @($metin -split '\.' | Where-Object { $_ -ne '' })
    if ($parcalar.Count -eq 0 -or $parcalar.Count -gt 4) { return $null }
    $sayilar = @()
    foreach ($p in $parcalar) {
        $n = 0
        if (-not [int]::TryParse($p, [ref]$n)) { return $null }
        $sayilar += $n
    }
    while ($sayilar.Count -lt 4) { $sayilar += 0 }
    return New-Object System.Version($sayilar[0], $sayilar[1], $sayilar[2], $sayilar[3])
}

# GitHub'daki son sürümü sor. Dönüş: @{ Surum; Metin; Adres } ya da $null (ulaşılamazsa / release yoksa)
function SonSurumuGetir {
    $json = & curl.exe -s --max-time 10 -H 'User-Agent: JerbDpiDiscord' -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/erendmrbs/JerbDpiDiscord/releases/latest"
    if (-not $json) { return $null }
    $veri = ($json -join "`n") | ConvertFrom-Json
    if (-not $veri.tag_name) { return $null }
    $metin = ($veri.tag_name -replace '^[vV]', '').Trim()
    $surum = SurumCevir $metin
    if (-not $surum) { return $null }
    return @{ Surum = $surum; Metin = $metin; Adres = $veri.html_url }
}

# Yeni sürüm varsa menüde göster ve (bu sürüm için bir kere) bildirim ver.
# $Elle: menüden istendiyse "güncel" ya da "kontrol edilemedi" sonucunu da bildir.
function GuncellemeKontrol([switch]$Elle) {
    $son = SonSurumuGetir
    if (-not $son) {
        if ($Elle) { Bildirim 'Kontrol edilemedi' "GitHub'a ulaşılamadı ya da henüz yayınlanmış bir sürüm yok." 'Warning' }
        return
    }
    if ($son.Surum -gt (SurumCevir $SURUM)) {
        $script:guncellemeAdresi = $son.Adres
        $script:guncellemeOgesi.Text = "⬆ Yeni sürüm var: v$($son.Metin) (indir)"
        $script:guncellemeOgesi.Visible = $true
        $script:guncellemeAyrac.Visible = $true
        if ($Elle -or $script:bildirilenSurum -ne $son.Metin) {
            $script:bildirilenSurum = $son.Metin
            Kaydet "Yeni sürüm bulundu: v$($son.Metin) (bu sürüm: v$SURUM)"
            Bildirim 'Yeni sürüm var' "Jerb-DpiDiscord v$($son.Metin) yayınlandı (sende v$SURUM). İndirmek için bu bildirime ya da menüdeki bağlantıya tıkla."
        }
    }
    elseif ($Elle) {
        Bildirim 'Güncel' "En son sürümü kullanıyorsun (v$SURUM)."
    }
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
        $tetik.Delay = 'PT5S'
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
$script:gdpiAyarDosyasi = Join-Path $klasor 'goodbyedpi_ayar.txt'
$script:sessizDosya  = Join-Path $klasor 'sessiz_mod.txt'
$script:dnsSormaDosyasi = Join-Path $klasor 'dns_sorma.txt'
$script:disGdpiOtomatikDosya = Join-Path $klasor 'dis_goodbyedpi_kapat.txt'
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

# Menüden gelen işlemleri güvenle çalıştır:
# - Açılış henüz bitmediyse (soru penceresi açıkken menüye basılırsa) beklet
# - Arka plan kontrolü sürüyorsa iç içe çalıştırma
function MenuIslemi([scriptblock]$islem) {
    if (-not $script:acilisBitti) {
        Bildirim 'Biraz bekle' 'Başlatıcı hâlâ açılıyor, bitince tekrar dene.' 'Warning'
        return
    }
    if ($script:tikCalisiyor) {
        Bildirim 'Biraz bekle' 'Başka bir işlem sürüyor, birkaç saniye sonra tekrar dene.' 'Warning'
        return
    }
    $script:tikCalisiyor = $true
    try { & $islem }
    finally { $script:tikCalisiyor = $false }
}

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

# Bilgisayar yeni açıldıysa görev çubuğu henüz hazır olmayabilir; hazır olmadan eklenen
# tepsi simgesi hiç görünmüyor. Görev çubuğu penceresi oluşana kadar bekle (en fazla 2 dakika).
for ($i = 0; $i -lt 120 -and [Win32.Native]::FindWindow('Shell_TrayWnd', $null) -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Seconds 1
}
if ($script:gizliBaslat) { Start-Sleep -Seconds 3 }

$script:tepsi = New-Object System.Windows.Forms.NotifyIcon
$script:tepsi.Text = 'Discord Başlatıcı'
Renk 'sari'

$menu = New-Object System.Windows.Forms.ContextMenuStrip

# Yeni sürüm varsa en üstte görünen satır (başta gizli)
$script:guncellemeOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Yeni sürüm var')
$script:guncellemeOgesi.Font = New-Object System.Drawing.Font($script:guncellemeOgesi.Font, [System.Drawing.FontStyle]::Bold)
$script:guncellemeOgesi.ForeColor = [System.Drawing.Color]::FromArgb(35, 140, 75)
$script:guncellemeOgesi.Visible = $false
$script:guncellemeOgesi.add_Click({ if ($script:guncellemeAdresi) { Start-Process explorer.exe $script:guncellemeAdresi } })
$menu.Items.Add($script:guncellemeOgesi) | Out-Null
$script:guncellemeAyrac = New-Object System.Windows.Forms.ToolStripSeparator
$script:guncellemeAyrac.Visible = $false
$menu.Items.Add($script:guncellemeAyrac) | Out-Null

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

# Menü açılınca son ölçülen bağlantı bilgisini göster (ölçüm her dakika arka planda yapılıyor;
# menü açılırken ölçmek, bağlantı yoksa menünün 6 saniye donmasına yol açıyordu)
$menu.add_Opening({ BaglantiBilgisiGuncelle })

$yenidenOgesi = New-Object System.Windows.Forms.ToolStripMenuItem("Discord'u yeniden başlat")
$yenidenOgesi.add_Click({ MenuIslemi { Kaydet "Discord yeniden başlatılıyor (kullanıcı isteği)"; DiscordBaslat } })
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
        MenuIslemi { ByeDpiAyarBul | Out-Null }
    }
})
$menu.Items.Add($ayarBulOgesi) | Out-Null

$denetleOgesi = New-Object System.Windows.Forms.ToolStripMenuItem("Güncellemeleri denetle (sürüm v$SURUM)")
$denetleOgesi.add_Click({ MenuIslemi { GuncellemeKontrol -Elle } })
$menu.Items.Add($denetleOgesi) | Out-Null

$kayitOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Kayıtları aç')
$kayitOgesi.add_Click({
    if (-not (Test-Path $script:olayLog)) { Kaydet 'Kayıt dosyası oluşturuldu' }
    Start-Process notepad.exe $script:olayLog
})
$menu.Items.Add($kayitOgesi) | Out-Null

$disGdpiOgesi = New-Object System.Windows.Forms.ToolStripMenuItem("Arka plandaki GoodbyeDPI'ı kapat")
$disGdpiOgesi.add_Click({ MenuIslemi { DisGoodbyeDpiKontrol -Elle } })
$menu.Items.Add($disGdpiOgesi) | Out-Null

$onarOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Sürücü hatasını onar')
$onarOgesi.add_Click({ MenuIslemi { SurucuOnar } })
$menu.Items.Add($onarOgesi) | Out-Null

$dnsOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('DNS')

$dnsKontrolOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('DNS ayarını kontrol et / yap')
$dnsKontrolOgesi.add_Click({
    MenuIslemi {
        if (DnsDogruMu) {
            Bildirim 'DNS doğru' 'Discord adresi doğru çözülüyor, bir şey yapmaya gerek yok.'
        }
        else {
            DnsAyarlaSorarak | Out-Null
        }
    }
})
$dnsOgesi.DropDownItems.Add($dnsKontrolOgesi) | Out-Null

$dnsGeriOgesi = New-Object System.Windows.Forms.ToolStripMenuItem('Eski haline döndür')
$dnsGeriOgesi.add_Click({ MenuIslemi {
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
} })
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

# "Yeni sürüm var" bildirimine tıklayınca indirme sayfasını aç
$script:tepsi.add_BalloonTipClicked({
    if ($script:guncellemeAdresi -and $script:sonBildirimBasligi -eq 'Yeni sürüm var') {
        Start-Process explorer.exe $script:guncellemeAdresi
    }
})

# Simgeye sol tıklayınca Discord penceresini öne getir
# (Discord zaten açıkken tekrar çalıştırılınca açık olan pencereyi gösterir)
$script:tepsi.add_MouseClick({
    param($kaynak, $olay)
    if ($olay.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $exe = DiscordBul
    if ($exe -and (Get-Process Discord)) {
        DiscorduNormalYetkiyleAc $exe '--proxy-server=socks5://127.0.0.1:1080'
    }
})
$script:tepsi.Visible = $true

# ---------------------------------------------------------------------------
# İlk açılış
# ---------------------------------------------------------------------------

# Bizim önceki çalışmadan açık kalmış GoodbyeDPI'ımızı ve Discord'u kapat
# (başka paketlerin GoodbyeDPI'ına burada dokunulmaz; onlar için ayrıca sorulur)
Get-Process Discord | Stop-Process -Force
GoodbyeDpiKapat
Start-Sleep -Seconds 1

# İnternet henüz yoksa (bilgisayar yeni açıldıysa) gelene kadar bekle
Durum 'internet kontrol ediliyor'
InterneteKadarBekle

# DNS kontrolü (GoodbyeDPI kendi DNS yönlendirmesini yaptığı için o açılmadan önce bakılır)
Durum 'DNS kontrol ediliyor'
if (-not (DnsDogruMu)) {
    if ($script:gizliBaslat) {
        # Daha önce izin verildiyse (yedek varsa) sessizce düzeltmeyi dene, yoksa sadece haber ver
        if (-not (DnsZehirlenmesiniDuzelt)) {
            Bildirim 'DNS ayarı uygun değil' "Discord bağlanamayabilir. Tepsi menüsünden DNS > 'DNS ayarını kontrol et / yap' seçeneğini kullan." 'Warning'
        }
    }
    elseif (-not (Test-Path $script:dnsSormaDosyasi)) {
        if (-not (DnsAyarlaSorarak)) {
            # Kullanıcı istemediyse bir daha açılışta sorma (menüden yapılabilir)
            if (-not (DnsDogruMu)) { Set-Content -Path $script:dnsSormaDosyasi -Value '1' -Encoding ASCII }
        }
    }
}

ByeDpiAc

# Arka planda başka bir GoodbyeDPI (servis vb.) çalışıyorsa önce onu hallet
Durum 'arka plan kontrol ediliyor'
DisGoodbyeDpiKontrol

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

Kaydet "Başlatıcı açıldı (sürüm: $SURUM, gizli: $script:gizliBaslat, ByeDPI ayarı: $script:byedpiAyar)"
if ($script:gizliBaslat) { DiscordBaslat -Kucuk } else { DiscordBaslat }
HatalariKaydet 'açılış'
$script:acilisBitti = $true

# ---------------------------------------------------------------------------
# Her saniye çalışan kontrol
# ---------------------------------------------------------------------------

$script:tik = 0

$zamanlayici = New-Object System.Windows.Forms.Timer
$zamanlayici.Interval = 1000
$script:tikCalisiyor   = $false
$script:byedpiCokmeler = @()
$script:byedpiDurdu    = $false

# Her saniye çalışan tur. Fonksiyon yerine doğrudan blok olarak saklanıyor; zamanlayıcı onu
# isimle aramadan çağırıyor (isimle aramak bazı durumlarda sessizce başarısız olabiliyor).
$script:zamanlayiciTuru = {
    $script:tik++
    $script:sayac++

    # Bilgisayar açılışında simge kaybolmuş olabilir: 15., 45. ve 90. saniyede simgeyi yeniden ekle
    if ($script:gizliBaslat -and $script:tepsi -and ($script:tik -eq 15 -or $script:tik -eq 45 -or $script:tik -eq 90)) {
        $script:tepsi.Visible = $false
        $script:tepsi.Visible = $true
    }

    # 3 saniyede bir: ByeDPI ve proxy'siz Discord kontrolü
    if ($script:tik % 3 -eq 0) {

        # ByeDPI çöktüyse yeniden aç. 1 dakikada 3 kereden fazla çöküyorsa (ör. 1080 portunu
        # başka bir program kullanıyorsa) sürekli denemek yerine dur ve bir kere haber ver.
        if (-not $script:byedpiDurdu -and -not (Get-Process ciadpi)) {
            $simdi = Get-Date
            $script:byedpiCokmeler = @($script:byedpiCokmeler | Where-Object { ($simdi - $_).TotalSeconds -lt 60 }) + $simdi
            if ($script:byedpiCokmeler.Count -gt 3) {
                $script:byedpiDurdu = $true
                $portSahibi = Get-NetTCPConnection -LocalPort 1080 -State Listen | Select-Object -First 1
                $sahipAdi = if ($portSahibi) { (Get-Process -Id $portSahibi.OwningProcess).ProcessName } else { $null }
                $neden = if ($sahipAdi) { "1080 portunu '$sahipAdi' kullanıyor olabilir." } else { 'Neden bilinmiyor.' }
                Kaydet "ByeDPI sürekli kapanıyor, yeniden başlatma durduruldu. $neden"
                Renk 'kirmizi'
                Durum 'ByeDPI çalışmıyor'
                Bildirim 'ByeDPI çalışmıyor' "ByeDPI açılır açılmaz kapanıyor. $neden Tepsiden 'Programı yeniden başlat'ı dene." 'Error'
            }
            else {
                Kaydet 'ByeDPI kapanmış bulundu, yeniden başlatılıyor'
                ByeDpiAc
                Bildirim 'ByeDPI yeniden başlatıldı' 'ByeDPI kapanmıştı, tekrar açıldı.' 'Warning'
            }
        }

        # Discord kendini proxy'siz açtıysa düzelt (başlatmadan sonraki ilk 15 saniye hariç).
        # Anlık kopyalara takılmamak için üst üste iki kontrolde (yaklaşık 6 sn) görülmesi gerekiyor.
        if (((Get-Date) - $script:sonBaslatma).TotalSeconds -gt 15 -and (ProxysizDiscordVarMi)) {
            $script:proxysizSayac++
        }
        else {
            $script:proxysizSayac = 0
        }
        if ($script:proxysizSayac -ge 2) {
            $script:proxysizSayac = 0
            Kaydet "Discord proxy'siz açılmış bulundu, yeniden başlatılıyor"
            Bildirim "Discord proxy'siz açılmıştı" 'ByeDPI ile yeniden açılıyor...' 'Warning'
            DiscordBaslat
            return
        }
    }

    if ($script:asama -eq 'bekle') {
        # Güncelleme bitti mi? Ana pencere açıldıysa ya da Discord ByeDPI üzerinden bağlantı kurduysa
        # (güncelleyici proxy kullanmıyor; ByeDPI'a bağlanan şey ancak asıl Discord olabilir)
        $pencere = Get-Process Discord | Where-Object { $_.MainWindowTitle -match 'Discord' -and $_.MainWindowTitle -notmatch 'Updater' }
        $hazir = $pencere -or (DiscordProxyBaglantisiVarMi)

        if ($hazir) {
            # Bu GoodbyeDPI ayarı işe yaradı; varsayılandan farklıysa bir dahaki sefere önce bu denensin
            $oncekiKayitli = if (Test-Path $script:gdpiAyarDosyasi) { (Get-Content $script:gdpiAyarDosyasi -TotalCount 1) } else { $script:gdpiAyarlari[0] }
            if ($script:gdpiAyar -and "$oncekiKayitli".Trim() -ne $script:gdpiAyar) {
                Set-Content -Path $script:gdpiAyarDosyasi -Value $script:gdpiAyar -Encoding ASCII
                Kaydet "Çalışan GoodbyeDPI ayarı kaydedildi: $script:gdpiAyar"
            }
            $script:asama = 'tampon'
            $script:sayac = 0
        }
        elseif ($script:sayac -lt $script:gdpiDenemeSuresi * $script:gdpiSira.Count -and
                $script:sayac -ge $script:gdpiDenemeSuresi * ($script:gdpiSiraNo + 1)) {
            # Bu ayarla güncelleme kontrolü geçmedi, sıradakini dene
            if (GdpiSonrakiAyar) {
                Durum "GoodbyeDPI ayarı deneniyor ($($script:gdpiSiraNo + 1)/$($script:gdpiSira.Count))"
            }
        }
        elseif ($script:sayac -ge $script:gdpiDenemeSuresi * $script:gdpiSira.Count + 10) {
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
        # 3 saniyede bir bak; Discord yaklaşık 15 saniye boyunca yoksa her şeyi kapat.
        # (Discord kendini güncellerken bir süre kapanıp yeniden açılıyor; o arada kapanmamak için
        # güncelleyici çalışırken de bekleniyor.)
        if ($script:sayac % 3 -eq 0) {
            if ((Get-Process Discord) -or (Get-Process Update | Where-Object { $_.Path -like "*\Discord\*" })) { $script:yok = 0 } else { $script:yok++ }
            if ($script:yok -ge 5) { Bitir; return }
        }

        # 30 saniyede bir arka planda başka GoodbyeDPI açılmış mı bak
        if ($script:sayac % 30 -eq 15) {
            DisGoodbyeDpiKontrol
        }

        # Hazır olduktan 30 saniye sonra ve sonra her 6 saatte bir güncelleme kontrolü
        if ($script:sayac -eq 30 -or ($script:sayac -gt 30 -and $script:sayac % 21600 -eq 0)) {
            GuncellemeKontrol
        }

        # Hazır olduktan 10 saniye sonra ve sonra her dakika bağlantıyı test et
        if ($script:sayac -eq 10 -or ($script:sayac -gt 10 -and $script:sayac % 60 -eq 0)) {
            $baglanti = ByeDpiBaglantiSayisi
            if (-not (ByeDpiTest)) {
                Start-Sleep -Seconds 2
                if (-not (ByeDpiTest)) {
                    Kaydet "Bağlantı testi başarısız: $script:sonTestHatasi (ByeDPI'a açık bağlantı: $baglanti, ayar: $script:byedpiAyar, discord.com -> $(DiscordAdresi))"

                    # 0) Arka planda başka bir GoodbyeDPI çalışıyorsa ByeDPI'ın paketlerini de bozuyor olabilir.
                    #    Bu durumda ayar aramak boşuna; önce onu kapatmayı öner.
                    $disGdpi = DisGoodbyeDpiBul
                    if ($disGdpi.Count -gt 0) {
                        Kaydet "Arka planda başka GoodbyeDPI çalışıyor, ByeDPI ile çakışıyor olabilir: $(($disGdpi | ForEach-Object { $_.Ad }) -join ', ')"
                        DisGoodbyeDpiKontrol -Elle
                        if ((DisGoodbyeDpiBul).Count -eq 0) {
                            Start-Sleep -Seconds 1
                            if (ByeDpiTest) {
                                Kaydet "Arka plandaki GoodbyeDPI kapatılınca bağlantı düzeldi ($($script:sonGecikme) ms)"
                                Renk 'yesil'
                                Durum 'Discord ByeDPI ile çalışıyor'
                                return
                            }
                        }
                        else {
                            Renk 'kirmizi'
                            Durum 'başka GoodbyeDPI çakışıyor'
                            Bildirim 'Bağlantı kurulamıyor' "Arka planda çalışan başka bir GoodbyeDPI, ByeDPI ile çakışıyor. Tepsiden 'Arka plandaki GoodbyeDPI'ı kapat'ı seç." 'Error'
                            return
                        }
                    }

                    # 1) Önce DNS: sağlayıcının sahte cevabı en sık neden
                    $dnsDuzeldi = $false
                    if (-not (AdresDiscordunMu (DiscordAdresi))) {
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
            elseif (-not (AdresDiscordunMu (DiscordAdresi))) {
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
}

$script:sonTurHatasi = $null
$script:yazilanTurHatalari = @{}
$zamanlayici.add_Tick({
    # Bir önceki tur henüz bitmediyse (soru penceresi açık, ayar aranıyor vb.) bu turu atla.
    # Yoksa iç içe çalışan turlar aynı soruyu tekrar tekrar sorabiliyor ya da birbirini bozuyordu.
    if ($script:tikCalisiyor) { return }
    $script:tikCalisiyor = $true
    try {
        if ($script:tik -eq 0) { Kaydet 'Zamanlayıcı çalışmaya başladı' }
        & $script:zamanlayiciTuru
    }
    catch {
        # Turda oluşan hatayı kayda yaz (aynı hatayı her saniye tekrar tekrar yazma)
        $mesaj = "$($_.Exception.Message) (satır $($_.InvocationInfo.ScriptLineNumber))"
        if ($mesaj -ne $script:sonTurHatasi) {
            $script:sonTurHatasi = $mesaj
            Kaydet "HATA [zamanlayıcı] $mesaj"
        }
    }
    finally {
        # Sessiz moddaki (SilentlyContinue) hatalar catch'e düşmüyor; onları da kayda yaz.
        # Zararsız "işlem bulunamadı" türlerini atla, aynı hatayı bir kereden fazla yazma.
        foreach ($h in @($Error)) {
            if ("$($h.FullyQualifiedErrorId)" -match 'NoProcessFoundForGivenName|PathNotFound|ItemNotFound|CmdletizationQuery_NotFound|NoServiceFoundForGivenName') { continue }
            $satir = if ($h.InvocationInfo) { $h.InvocationInfo.ScriptLineNumber } else { '?' }
            $anahtar = "$($h.ToString()) (satır $satir)"
            if (-not $script:yazilanTurHatalari.ContainsKey($anahtar)) {
                $script:yazilanTurHatalari[$anahtar] = $true
                Kaydet "HATA [zamanlayıcı] $anahtar"
            }
        }
        $Error.Clear()
        $script:tikCalisiyor = $false
    }
})

$zamanlayici.Start()
$script:donguCalisiyor = $true
[System.Windows.Forms.Application]::Run($script:ctx)
HatalariKaydet 'kapanış'
if (-not $script:mutexBirakildi) { $mutex.ReleaseMutex() }
