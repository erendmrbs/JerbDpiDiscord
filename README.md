# Jerb-DpiDiscord

**🇹🇷 Türkçe** | [🇬🇧 English](README.en.md)

**Discord Başlatıcı:** Türkiye'de erişim engeli bulunan Discord'u, **oyunlarla çakışmadan** kullanmanı sağlayan, sistem tepsisinde çalışan küçük bir Windows aracı.

ByeDPI ve GoodbyeDPI'ı birlikte, her birini en uygun olduğu anda kullanır. Discord açılırken güncelleme kontrolünü GoodbyeDPI ile geçer, ardından GoodbyeDPI'ı tamamen kapatır ve Discord'u sürücü kullanmayan ByeDPI üzerinden çalıştırmaya devam eder. Böylece Discord açıkken oyun oynayabilirsin. Ağ sürücüsüne hassas olan hile koruma sistemleri ya da oyun hızlandırıcı programlar (ping düşürücüler) bundan etkilenmez.

---

## İçindekiler

- [Neden bu araç var?](#neden-bu-araç-var)
- [Nasıl çalışır?](#nasıl-çalışır)
- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
- [Tepsi menüsü](#tepsi-menüsü)
- [Simge renkleri](#simge-renkleri)
- [Bilgisayar açılınca başlatma](#bilgisayar-açılınca-başlatma)
- [Oluşturulan dosyalar](#oluşturulan-dosyalar)
- [Sorun giderme](#sorun-giderme)
- [Sık sorulan sorular](#sık-sorulan-sorular)
- [Güvenlik ve doğrulama](#güvenlik-ve-doğrulama)
- [Kaldırma](#kaldırma)
- [Teşekkürler](#teşekkürler)
- [Lisans](#lisans)
- [Destek ol](#destek-ol)
- [Sorumluluk reddi](#sorumluluk-reddi)

---

## Neden bu araç var?

Türkiye'de Discord'a erişmek için en yaygın yöntem **GoodbyeDPI**. GoodbyeDPI sorunsuz çalışıyor, ama arkasında **WinDivert** adlı bir ağ sürücüsü kullanıyor. Bu sürücü bilgisayardaki ağ trafiğine çekirdek seviyesinde müdahale ediyor ve şu sorunlara yol açabiliyor:

- Bazı oyunların **hile koruma sistemleri** WinDivert sürücüsü yüklüyken oyunu açmıyor ya da oyun açıldıktan sonra çöküyor.
- **Oyun hızlandırıcı / ping düşürücü** programlar da kendi ağ sürücülerini kullandığı için GoodbyeDPI ile çakışıyor.
- GoodbyeDPI'ın `--blacklist` özelliğiyle sadece Discord adreslerine uygulanması da bu sorunu çözmüyor. Sorun trafikte değil, sürücünün kendisinin yüklü olmasında.

Diğer yöntem **ByeDPI** ise sürücü kullanmıyor. Bilgisayarında küçük bir SOCKS5 proxy olarak çalışıyor ve sadece kendisine yönlendirilen trafiğe dokunuyor. Oyunlar onu hiç görmüyor. Ama burada da bir sorun var: **Discord'un güncelleyicisi proxy ayarlarını dikkate almıyor.** Discord her açılışta güncelleme kontrolü yapıyor ve ByeDPI ile bu kontrol engele takılıyor. Sonuç: "Update failed" ekranı.

**Discord Başlatıcı bu iki aracı birleştiriyor:**

| Aşama | Kullanılan araç | Neden |
|---|---|---|
| Discord açılırken (güncelleme kontrolü) | GoodbyeDPI + ByeDPI | Güncelleyici sadece GoodbyeDPI ile geçebiliyor |
| Discord açıldıktan sonra | **Sadece ByeDPI** | Sürücü yok, oyunlarla çakışma yok |

GoodbyeDPI sadece birkaç saniye açık kalıyor, güncelleme kontrolü biter bitmez kapanıyor ve sürücüsü bellekten kaldırılıyor.

---

## Nasıl çalışır?

```
 Baslat.bat
     │
     ▼
 discord.ps1 (gizli, yönetici olarak)
     │
     ├─► ByeDPI'ı gizli başlat (127.0.0.1:1080)
     │
     ├─► GoodbyeDPI'ı geçici başlat (sadece Discord adresleri için)
     │
     ├─► Discord kurulu değilse → indir ve kur
     │
     ├─► Discord'u ByeDPI proxy ayarıyla aç
     │         │
     │         ▼
     │   Güncelleme kontrolü bitti mi? (her saniye kontrol)
     │         │
     │         ▼ evet
     ├─► GoodbyeDPI'ı ve WinDivert sürücüsünü kapat  🟢
     │
     └─► Arka planda izle:
           • ByeDPI çöktü mü?            → yeniden başlat
           • Discord proxy'siz mi açıldı? → proxy ile yeniden aç
           • Bağlantı koptu mu?           → çalışan ByeDPI ayarını bul
           • Discord tamamen kapandı mı?  → ByeDPI'ı kapat, çık
```

Güncelleme kontrolünün bittiği şu yollardan biriyle anlaşılıyor:
- Discord'un kayıtlarında (log) güncellemenin bittiğini gösteren satır
- Güncelleme penceresinin kapanıp asıl Discord penceresinin açılması
- (Gizli başlatmada) Discord'un ByeDPI üzerinden bağlantı kurması

---

## Özellikler

- 🎮 **Oyunlarla uyumlu.** Discord açıkken WinDivert sürücüsü yüklü değil.
- 🔄 **Discord güncellemeleri çalışıyor.** "Update failed" sorunu yok.
- 🖥️ **Sistem tepsisinde çalışıyor.** Siyah komut penceresi yok.
- 🟢 **Renkli durum simgesi.** Durumu bir bakışta gösteriyor.
- 📥 **Discord kurulu değilse** kendisi indirip kuruyor.
- 🔧 **Bağlantı koparsa kendini düzeltiyor.** Her dakika bağlantıyı test ediyor. Koparsa önce ByeDPI'ı yeniden başlatıyor, yetmezse 5 farklı ayarı deneyip çalışanı kaydediyor.
- 📝 **Olay kayıtları.** Kopmaları, otomatik düzeltmeleri ve hataları `baslatici.log` dosyasına yazıyor.
- 🛡️ **ByeDPI çökerse** kendiliğinden yeniden başlatıyor.
- 🔁 **Discord proxy'siz açılırsa** (örneğin büyük bir güncellemeden sonra) bunu fark edip doğru ayarla yeniden açıyor.
- 🚀 **Bilgisayar açılınca başlatma.** Yönetici izni sormadan, Discord tepsiye küçülmüş olarak başlıyor.
- 📁 **Klasörün adını değiştirsen ya da taşısan da** açılışta çalışmaya devam ediyor.
- 🩺 **Sürücü hatasını onarma.** Sık görülen WinDivert "1058" hatasını tek tıkla temizliyor.
- 🔕 **Sessiz mod.** Sadece sorun bildirimlerini gösteriyor.
- 📶 **Bağlantı bilgisi.** Discord'a bağlanma süresini ve kullanılan ByeDPI ayarını gösteriyor.
- 🌐 **DNS ayarını kendisi yapıyor.** Sağlayıcının DNS engelini fark edip izin isteyerek şifreli DNS'e geçiyor, istersen geri alıyor.
- 🧹 **Discord kapanınca her şeyi kapatıyor.** Arka planda hiçbir şey açık kalmıyor.

---

## Gereksinimler

- **Windows 10 veya Windows 11** (64 bit)
- **Yönetici yetkisi** (GoodbyeDPI'ın sürücüsü için gerekli. Başlatıcı izni kendisi istiyor.)
- **Windows PowerShell 5.1** (Windows'ta hazır geliyor)
- **curl** (Windows 10 1803 ve sonrasında hazır geliyor)
- ByeDPI ve GoodbyeDPI (depoyla birlikte geliyor)
- **Şifreli DNS (DNS over HTTPS)** ayarı (başlatıcı kendisi yapabiliyor, Windows 11 gerekiyor)

---

## Kurulum

### 1. İndir

Bu depoyu indir: yeşil **Code** butonu → **Download ZIP**. İstediğin bir klasöre çıkar.

ByeDPI ve GoodbyeDPI **depoyla birlikte geliyor**, ayrıca bir şey indirmene gerek yok.

### 2. Klasör düzeni

Zip'ten çıkan klasör şöyle görünmeli:

```
JerbDpiDiscord\
├── Baslat.bat
├── LICENSE
├── README.md
├── README.en.md
├── byedpi\
│   ├── ciadpi.exe               ← ByeDPI 17.3 (64 bit)
│   ├── discord.ps1        ← başlatıcının kendisi
│   └── LICENSE-byedpi.txt
└── goodbyedpi\
    ├── goodbyedpi.exe           ← GoodbyeDPI 0.2.3rc3 (64 bit)
    ├── WinDivert.dll
    ├── WinDivert64.sys
    ├── discord.txt              ← GoodbyeDPI'ın sadece dokunacağı Discord adresleri
    └── licenses\               ← GoodbyeDPI ve WinDivert lisansları
```

Ana klasörün adı önemli değil. İstediğin yere koyabilir, istediğin adı verebilirsin. Sadece `Baslat.bat`, `byedpi` ve `goodbyedpi` yan yana kalsın.

> **Daha yeni sürüm kullanmak istersen:** [ByeDPI](https://github.com/hufrea/byedpi/releases) ve [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI/releases) dosyalarını resmi sayfalarından indirip aynı yerlere koyabilirsin. GoodbyeDPI dosyalarını `goodbyedpi\x86_64\` klasörünün içine koyarsan da çalışır.

### 3. DNS ayarı (başlatıcı kendisi yapıyor)

İnternet sağlayıcın Discord adreslerini DNS seviyesinde de engelliyor. Discord'u sorduğunda gerçek adres yerine engel sayfasının adresini veriyor. Bu durumda Discord bağlanamaz, tarayıcıda da **"Bağlantınız gizli değil" / `NET::ERR_CERT_AUTHORITY_INVALID`** hatası görürsün.

**Başlatıcı bunu her açılışta kontrol ediyor.** `discord.com` yanlış adrese çözülüyorsa, DNS ayarını **Cloudflare şifreli DNS'e (1.1.1.1, DNS over HTTPS)** çevirmeyi teklif ediyor:

- Değişiklik yapılmadan önce **izin isteniyor.**
- Eski DNS ayarın `%LocalAppData%\DiscordBaslatici\dns_yedek.json` dosyasına **yedekleniyor.**
- Tepsi menüsünden **DNS → Eski haline döndür** ile istediğin zaman geri alabilirsin.
- "Hayır" dersen bir daha sorulmuyor. Sonradan menüden **DNS → DNS ayarını kontrol et / yap** ile yapabilirsin.
- Bilgisayar açılınca gizli başlatmada soru sorulmuyor, sadece uyarı bildirimi gösteriliyor.

> **Windows 10:** Şifreli DNS (DNS over HTTPS) özelliği Windows 11'de var. Windows 10'da başlatıcı DNS'i 1.1.1.1 yapıyor, ama bu sağlayıcın DNS engelini aşmaya yetmeyebilir.

#### Elle yapmak istersen

Otomatik ayar çalışmazsa başlatıcı bu adımları gösteriyor:

1. **Ayarlar → Ağ ve İnternet →** kullandığın bağlantı (Ethernet ya da Wi-Fi)
2. **DNS sunucusu ataması → Düzenle → El ile**
3. **IPv4: Açık**
   - Tercih edilen DNS: `1.1.1.1` → **DNS over HTTPS: Açık (otomatik şablon)**
   - Alternatif DNS: `1.0.0.1` → **DNS over HTTPS: Açık (otomatik şablon)**
4. **Kaydet**
5. Yönetici olarak açtığın komut isteminde: `ipconfig /flushdns`

**Kontrol:** Komut isteminde `ping discord.com` çalıştır. Çıkan adres `162.159.` ile başlıyorsa doğru.

> Sadece `1.1.1.1` yazmak yetmez, **"DNS over HTTPS"** kısmının açık olması şart. Sağlayıcılar şifresiz DNS isteklerini yakalayıp kendi cevaplarını verebiliyor.

### 4. Eski GoodbyeDPI kurulumunu kaldır (varsa)

Daha önce GoodbyeDPI'ı **servis olarak** kurduysan (örneğin `service_install` dosyalarıyla) kaldır. Yoksa sürücü çakışması olur. Yönetici olarak açtığın komut isteminde:

```bat
sc stop GoodbyeDPI
sc delete GoodbyeDPI
sc stop WinDivert
sc delete WinDivert
```

Ardından **bilgisayarı yeniden başlat.** Eski GoodbyeDPI klasörünü de silebilirsin. Başlatıcı sadece kendi klasöründeki kopyayı kullanıyor.

### 5. Discord'un kendi otomatik başlatmasını kapat

Discord'da **Kullanıcı Ayarları → Windows Ayarları → "Discord'u Aç"** seçeneğini kapat. Yoksa bilgisayar açılınca Discord bir de proxy'siz açılmaya çalışır ve başlatıcıyla çakışır.

Aynı yerdeki **"Kapat düğmesi Discord'u sistem tepsisine küçültsün"** seçeneğini de açmanı öneririm.

---

## Kullanım

1. **`Baslat.bat`** dosyasına çift tıkla.
2. Windows yönetici izni isteyecek, **Evet** de.
3. Sistem tepsisinde (saatin yanında) bir **Discord simgesi** belirecek. Köşesindeki nokta **sarı**.
4. Discord açılıyor ve güncelleme kontrolü yapıyor. Simgenin üstüne gelince durumu görebilirsin.
5. Nokta **yeşile** döndüğünde GoodbyeDPI kapanmış ve Discord ByeDPI ile çalışıyor demektir.
6. Artık oyununu açabilirsin.

> ⚠️ **Oyunu, simge yeşile dönmeden açma.** Güncelleme kontrolü sırasında GoodbyeDPI açık olduğu için, ağ sürücüsüne hassas oyunlar o birkaç saniye içinde açılırsa çökebilir.

**Discord'u kapatmak:** Tepsideki Discord simgesine sağ tıkla → **Discord'dan Çık.** Başlatıcı bunu birkaç saniye içinde fark edip ByeDPI'ı kapatıyor ve kendisi de kapanıyor.

**Tepside iki Discord simgesi göreceksin:** biri Discord'un kendisi, diğeri başlatıcı. Başlatıcınınkinde renkli nokta var ve üstüne gelince "Discord Başlatıcı" yazıyor.

---

## Tepsi menüsü

Başlatıcı simgesine **sol tıklayınca** tepsideki Discord penceresi öne geliyor.

**Sağ tıklayınca** şu menü açılıyor:

| Seçenek | Ne yapar |
|---|---|
| **Jerb-DpiDiscord GitHub** | Bu projenin GitHub sayfasını tarayıcıda açar |
| **Destek ol (bağış)** | Projeyi desteklemek için GitHub Sponsors sayfasını açar |
| **Durum** | Şu anda ne olduğunu gösterir (güncelleme bekleniyor, çalışıyor, vb.) |
| **Bağlantı süresi** | Discord'a ByeDPI üzerinden bağlanmanın kaç ms sürdüğü. Menü her açıldığında yeniden ölçülür. |
| **ByeDPI ayarı** | Şu anda kullanılan ByeDPI parametreleri |
| **Discord'u yeniden başlat** | Discord'u kapatır, güncelleme kontrolünden geçirip yeniden açar |
| **Programı yeniden başlat** | Başlatıcının tamamını (Discord, ByeDPI, GoodbyeDPI dahil) kapatıp baştan açar |
| **ByeDPI ayarını otomatik bul** | Bağlantıyı test eder, çalışmıyorsa diğer ayarları deneyip çalışanı kaydeder |
| **Kayıtları aç** | Olay kayıtlarını (`baslatici.log`) Not Defteri'nde açar |
| **Sürücü hatasını onar** | WinDivert sürücü kaydını temizler, yeniden başlatma önerir |
| **DNS → DNS ayarını kontrol et / yap** | DNS'in Discord'u doğru adrese çözüp çözmediğine bakar, gerekirse şifreli DNS'e geçirir |
| **DNS → Eski haline döndür** | DNS ayarını başlatıcı değiştirmeden önceki haline getirir |
| **Bilgisayar açılınca başlat** | Otomatik başlatmayı açar/kapatır |
| **Sessiz mod** | Sadece uyarı ve hata bildirimlerini gösterir |
| **Her şeyi kapat** | Discord, ByeDPI ve GoodbyeDPI'ı kapatıp başlatıcıdan çıkar |

> ⚠️ **"Discord'u yeniden başlat"** GoodbyeDPI'ı birkaç saniyeliğine açar. Ağ sürücüsüne hassas bir oyun açıkken kullanma.

---

## Simge renkleri

| Renk | Anlamı |
|---|---|
| 🟡 **Sarı** | Başlatılıyor, güncelleme kontrolü bekleniyor ya da ByeDPI ayarı aranıyor. **GoodbyeDPI açık olabilir.** |
| 🟢 **Yeşil** | Her şey hazır. Discord ByeDPI ile çalışıyor, GoodbyeDPI kapalı. |
| 🔴 **Kırmızı** | Sorun var: GoodbyeDPI açılamadı, güncelleme bitmedi ya da Discord'a ulaşılamıyor. |

---

## Bilgisayar açılınca başlatma

Sağ tık menüsünden **"Bilgisayar açılınca başlat"** seçeneğini işaretle.

- Windows **Görev Zamanlayıcı**'ya **"Discord Baslatici"** adında bir görev ekleniyor. Görev yönetici yetkisiyle çalıştığı için her açılışta izin penceresi çıkmıyor.
- Oturum açtıktan **30 saniye sonra** başlıyor, internet bağlantısının hazır olmasına zaman kalsın diye.
- Discord penceresi açılmıyor, doğrudan **tepsiye küçülmüş** başlıyor. "Discord hazır" bildirimi de gösterilmiyor.

### Klasörü taşırsan ya da adını değiştirirsen

Otomatik başlatma açıldığında `%LocalAppData%\DiscordBaslatici\` klasörüne küçük bir **bulucu** betik konuyor. Görev doğrudan bu bulucuyu çalıştırıyor. Bulucu:

1. Başlatıcının son bilinen yerine bakıyor.
2. Orada yoksa eski konumun çevresinde, **Masaüstü**'nde, **Belgeler**'de, **İndirilenler**'de ve kullanıcı klasöründe arıyor.
3. Bulduğu dosyanın gerçekten bu başlatıcı olduğunu kontrol ediyor, yeni yeri kaydediyor ve başlatıyor.
4. Hiçbir yerde bulamazsa uyarı veriyor. Bu durumda `Baslat.bat` ile bir kere elle açman yeterli.

---

## Oluşturulan dosyalar

| Dosya | Yer | Ne işe yarar |
|---|---|---|
| `byedpi_ayar.txt` | `byedpi\` | Otomatik bulunan, çalışan ByeDPI ayarı |
| `sessiz_mod.txt` | `byedpi\` | Varsa sessiz mod açık |
| `baslatici.log` | `byedpi\` | Olay kayıtları: bağlantı kopmaları, otomatik düzeltmeler ve hatalar. Menüden **"Kayıtları aç"** ile açılır. |
| `dns_sorma.txt` | `byedpi\` | Varsa açılışta DNS ayarı sorulmaz |
| `dns_yedek.json` | `%LocalAppData%\DiscordBaslatici\` | Başlatıcı değiştirmeden önceki DNS ayarın |
| `bulucu.ps1` | `%LocalAppData%\DiscordBaslatici\` | Otomatik başlatmada başlatıcıyı bulan betik |
| `yol.txt` | `%LocalAppData%\DiscordBaslatici\` | Başlatıcının son bilinen yeri |
| `discord_baslat.log` | `%TEMP%\` | Son açılıştaki Discord kayıtları (sorun giderme için) |
| `DiscordSetup.exe` | `%TEMP%\` | Discord kurulu değilse indirilen kurulum dosyası |

Ayarları sıfırlamak istersen `byedpi_ayar.txt` dosyasını silmen yeterli.

---

## Sorun giderme

### "GoodbyeDPI başlatılamadı" / `Error opening filter: 1058`

WinDivert sürücüsünün Windows'taki kaydı bozuk bir durumda kalmış. Genelde sürücü defalarca açılıp kapatıldığında ya da farklı klasörlerdeki GoodbyeDPI kopyaları aynı sürücüyü kullanmaya çalıştığında oluyor.

**Çözüm:** Başlatıcı bunu fark edince onarmayı öneriyor. Ya da menüden **"Sürücü hatasını onar"** seç, sonra **bilgisayarı yeniden başlat.** Yeniden başlatma şart. Silinen sürücü kaydı ancak o zaman tamamen temizleniyor.

Elle yapmak istersen, yönetici komut isteminde:
```bat
sc stop WinDivert
sc delete WinDivert
sc stop WinDivert14
sc delete WinDivert14
```
ve yeniden başlat.

> Bu komutları her açılışta çalıştırma. Kullanımdaki bir sürücüyü silmek onu "silinmek üzere" olarak işaretliyor ve yeniden başlatana kadar aynı hatayı veriyor.

### Discord "Update failed" diyor

- Simgenin **sarı** kaldığından emin ol, GoodbyeDPI'ın çalışması lazım. Kırmızıysa yukarıdaki sürücü onarımını yap.
- **Windows proxy ayarı** açık kalmış olabilir: Ayarlar → Ağ ve İnternet → **Ara sunucu** → "Ara sunucu kullan" **Kapalı** olmalı.
- Yönetici komut isteminde `netsh winhttp show proxy` çalıştır, "Direct access" yazmalı. Yazmıyorsa: `netsh winhttp reset proxy`
- `%AppData%\discord\settings.json` dosyasında `SKIP_HOST_UPDATE` ya da `SKIP_MODULE_UPDATE` satırları varsa sil.
- Hiçbiri işe yaramazsa Discord'u kaldır, `%LocalAppData%\Discord` ve `%AppData%\discord` klasörlerini sil, başlatıcıyı çalıştır. Discord'u kendisi indirip kuracak.

### Tarayıcıda "Bağlantınız gizli değil" / `ERR_CERT_AUTHORITY_INVALID`

Bu engelin aşıldığını ama sağlayıcının engel sayfasına bağlandığını gösteriyor. Sebebi DNS. Tepsi menüsünden **DNS → DNS ayarını kontrol et / yap** seç ya da [elle ayarla](#3-dns-ayarı-başlatıcı-kendisi-yapıyor).

### Discord açılıyor ama bağlanamıyor ("Bağlanılıyor…" ekranında kalıyor)

- Menüden **"ByeDPI ayarını otomatik bul"** seç.
- Hiçbir ayar çalışmazsa simge kırmızıya döner. İnternet bağlantını ve DNS ayarını kontrol et.
- Sağlayıcı engelleme yöntemini değiştirmiş olabilir. `discord.ps1` içindeki `$script:onAyarlar` listesine yeni ByeDPI parametreleri ekleyebilirsin.

### Bir süre çalışıyor, sonra bağlantı kopuyor (yeniden başlatınca düzeliyor)

En sık nedeni **DNS**. Şifreli DNS bir anlığına başarısız olunca Windows normal DNS'e geri dönebiliyor, sağlayıcı da o anda `discord.com` için sahte bir adres (örneğin `195.175.254.2`) veriyor. Başlatıcı açılırken çalışan GoodbyeDPI DNS'i geçici olarak düzelttiği için yeniden başlatmak sorunu birkaç dakikalığına çözüyor gibi görünüyor.

Başlatıcı bunu her dakika kontrol ediyor. Sahte cevap görürse DNS önbelleğini temizliyor ve şifreli DNS ayarını yeniden uyguluyor. Elle kontrol etmek için:

```powershell
Resolve-DnsName discord.com -Type A | Select-Object -First 1 IPAddress
```

Adres `162.159.` ile başlamıyorsa DNS ayarına git ve DNS over HTTPS'in altındaki **"Düz metne geri dön"** (Fallback to plaintext) seçeneğini **Kapalı** yap.

### Simge sarıda kalıyor, sonra kırmızıya dönüyor ("güncelleme bitmedi")

Güncelleme kontrolü 2 dakika içinde bitmemiş. Bu durumda GoodbyeDPI güvenlik için kapatılıyor. Menüden **"Discord'u yeniden başlat"** dene. Sorun devam ederse `%TEMP%\discord_baslat.log` dosyasına bak.

### Başlatıcı hiç açılmıyor

- `Baslat.bat` dosyasının `byedpi` klasörünün **yanında** olduğundan emin ol.
- Windows SmartScreen uyarısı çıkarsa **Ek bilgi → Yine de çalıştır.**
- Antivirüs programın WinDivert sürücüsünü engelliyor olabilir. Bkz. [Antivirüs uyarıları](#antivirüs-uyarıları).

### "Discord Başlatıcı zaten çalışıyor"

Başlatıcı zaten açık. Tepsideki simgeye bak. Gizli simgelerin içinde olabilir (saatin yanındaki **^** okuna tıkla).

---

## Sık sorulan sorular

**Neden yönetici izni gerekiyor?**
GoodbyeDPI'ın kullandığı WinDivert sürücüsünü yükleyebilmek için. ByeDPI ve Discord'un kendisi yönetici izni gerektirmiyor.

**Oyun hesabım bundan dolayı banlanır mı?**
Discord açıkken bilgisayarda yüklü bir ağ sürücüsü kalmıyor. ByeDPI sadece Discord'un trafiğini taşıyan sıradan bir yerel proxy. Yine de hiçbir oyunun hile koruma sistemi adına garanti verilemez. Kullanım kendi sorumluluğundadır.

**Sesli sohbet çalışıyor mu?**
Evet. Discord'un sesli sohbeti farklı bir yoldan (UDP) gidiyor ve proxy'den geçmiyor, ama engel genelde site adreslerine konduğu için ses sorunsuz çalışıyor.

**Discord'u tarayıcıdan kullanabilir miyim?**
Bu araç masaüstü uygulaması için. Tarayıcıda kullanmak istersen ByeDPI'ı tek başına çalıştırıp tarayıcının proxy ayarına `socks5://127.0.0.1:1080` girebilirsin. Firefox'ta "SOCKS v5 kullanırken DNS'i vekil sunucu üzerinden yönlendir" kutusunu işaretlemeyi unutma.

**Neden sadece ByeDPI kullanılmıyor?**
Discord'un güncelleyicisi proxy ayarlarını dikkate almıyor. Ne `--proxy-server` parametresini, ne ortam değişkenlerini, ne Windows proxy ayarını kullanıyor. `SKIP_HOST_UPDATE` gibi ayarlarla güncelleme kontrolünü atlatmak da güvenilir çalışmıyor. Bu yüzden güncelleme kontrolü için kısa süreliğine GoodbyeDPI gerekiyor.

**Neden sadece GoodbyeDPI kullanılmıyor?**
Çünkü asıl sorun bu. WinDivert sürücüsü yüklüyken bazı oyunlar açılmıyor ya da çöküyor.

**Diğer DPI aşma araçlarıyla (zapret vb.) çalışır mı?**
zapret de WinDivert kullandığı için oyunlarla aynı sorunu yaşar. Güncelleme aşamasında GoodbyeDPI yerine zapret kullanılabilir, ama bu sürümde desteklenmiyor.

**İnternet sağlayıcım önemli mi?**
Başlatıcı Türkiye'deki yaygın sağlayıcılarla test edilmek üzere hazırlandı. Engelleme yöntemi sağlayıcıya göre değişebilir. ByeDPI ayarını otomatik bulma özelliği bu yüzden var.

---

## Güvenlik ve doğrulama

Başlatıcı yönetici yetkisiyle çalışıyor, bir ağ sürücüsünü yüklüyor ve istersen DNS ayarını değiştiriyor. Bu yüzden ne yaptığını bilmen önemli. Projenin açık kaynak olmasının en büyük faydası da bu.

### Kodu kendin incele

Başlatıcının tamamı düz metin dosyalarından oluşuyor, derlenmiş gizli bir kısmı yok:
- `Baslat.bat`: sadece `discord.ps1` dosyasını gizli pencerede başlatıyor.
- `byedpi/discord.ps1`: her şeyi yapan betik. Not Defteri ile açıp her satırını okuyabilirsin. Kod Türkçe açıklamalarla yazıldı.

Başlatıcı internete sadece şunlar için bağlanıyor: Discord'un kendi sunucuları (bağlantı testi ve Discord kurulumu indirme) ve DNS ayarında Cloudflare (1.1.1.1). Hiçbir veri toplamıyor, hiçbir yere bir şey göndermiyor.

### Program dosyalarını doğrula (SHA-256)

Depodaki `.exe`, `.dll` ve `.sys` dosyaları okunabilir kod değil. Bunların resmi ByeDPI ve GoodbyeDPI dosyalarıyla aynı olduğunu kendin doğrulayabilirsin. Depodaki dosyaların SHA-256 özetleri:

| Dosya | Kaynağı | SHA-256 |
|---|---|---|
| `byedpi/ciadpi.exe` | ByeDPI 17.3, `byedpi-17.3-x86_64-w64.zip` | `eb53ceeeb981cc6735ac24bb1e51e725280b86630e80fdf19ddc4ee4a5b54ef4` |
| `goodbyedpi/goodbyedpi.exe` | GoodbyeDPI 0.2.3rc3, `x86_64` | `8d412b094bb9c137ff25ba9a794d1122ecc84bb776debff6c249723a13cc31cd` |
| `goodbyedpi/WinDivert.dll` | GoodbyeDPI 0.2.3rc3, `x86_64` | `6110bfa44667405179c3e15e12af1b62037e447ed59b054b19042032995e6c7e` |
| `goodbyedpi/WinDivert64.sys` | GoodbyeDPI 0.2.3rc3, `x86_64` | `e69b5ba3f0cd6cfb2983e442636e7f0b342b61b15264b0328317d4559c82cf50` |

**Nasıl kontrol edilir:**
1. Depodaki dosyanın özetini hesapla. PowerShell'de:
   ```powershell
   Get-FileHash .\byedpi\ciadpi.exe -Algorithm SHA256
   ```
   ya da komut isteminde:
   ```bat
   certutil -hashfile byedpi\ciadpi.exe SHA256
   ```
2. Aynı sürümü resmi sayfadan ([ByeDPI](https://github.com/hufrea/byedpi/releases), [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI/releases)) indirip onun da özetini hesapla.
3. İki özet birebir aynıysa dosya aynıdır, değiştirilmemiştir.

Özetler eşleşmiyorsa ya da içine güvenmiyorsan, bu dosyaları sil ve resmi sayfalardan indirdiğin dosyaları aynı yerlere koy. Başlatıcı onlarla da aynı şekilde çalışır.

> Projeyi sadece **bu depodan** indir. Başka sitelerde ya da kopyalanmış (fork) depolarda paylaşılan sürümler değiştirilmiş olabilir.

### Antivirüs uyarıları

Bazı antivirüs programları (Windows Defender dahil) bu projedeki dosyaları **şüpheli** olarak işaretleyebilir. Bunun nedenleri:

- **WinDivert** sürücüsü ağ trafiğine çekirdek seviyesinde müdahale ediyor. Aynı sürücü bazı zararlı yazılımlarda da kullanıldığı için antivirüsler sürücünün kendisini işaretleyebiliyor. WinDivert'in kendisi açık kaynak ve meşru bir araç.
- **DPI aşma araçları** (GoodbyeDPI, ByeDPI) ağ paketlerini değiştirdiği için bazı antivirüslerde "HackTool" ya da "RiskWare" gibi genel bir uyarıyla görünebiliyor. Bu bir virüs olduğu anlamına gelmiyor, "bu araç ağ trafiğini değiştiriyor" demek.
- **Gizli çalışan PowerShell betiği** ve **yönetici yetkisi isteyen** bir `.bat` dosyası da bazı güvenlik programlarına şüpheli görünebiliyor.

**Ne yapmalı:**
1. Önce yukarıdaki SHA-256 özetleriyle dosyaları doğrula.
2. İstersen dosyaları [VirusTotal](https://www.virustotal.com/)'e yükleyip onlarca antivirüsün sonucunu birlikte görebilirsin. Birkaç antivirüsün "HackTool" demesi bu tür araçlar için normal.
3. Güveniyorsan proje klasörünü antivirüsünün **istisnalar** listesine ekle. Windows Defender'da: **Windows Güvenliği → Virüs ve tehdit koruması → Ayarları yönet → Dışlamalar → Dışlama ekle → Klasör.**

---

## Kaldırma

1. Menüden **"Bilgisayar açılınca başlat"** işaretini kaldır (görev silinir).
2. DNS ayarını başlatıcı değiştirdiyse menüden **DNS → Eski haline döndür** seç.
3. Menüden **"Her şeyi kapat"** seç.
4. Klasörü sil.
5. `%LocalAppData%\DiscordBaslatici` klasörünü sil.
6. İstersen WinDivert sürücü kaydını da temizle:
   ```bat
   sc delete WinDivert
   ```

---

## Teşekkürler

Bu araç, aşağıdaki açık kaynak projelerin üzerine kurulu bir başlatıcıdır. Asıl işi onlar yapıyor:

- [**ByeDPI**](https://github.com/hufrea/byedpi): hufrea
- [**GoodbyeDPI**](https://github.com/ValdikSS/GoodbyeDPI): ValdikSS
- [**WinDivert**](https://github.com/basil00/WinDivert): basil00

Kolay kurulum için bu programların derlenmiş Windows sürümleri, kendi lisanslarıyla birlikte, değiştirilmeden bu depoya eklenmiştir:

| Program | Sürüm | Lisans | Lisans dosyası |
|---|---|---|---|
| ByeDPI | 17.3 (x86_64) | MIT | `byedpi/LICENSE-byedpi.txt` |
| GoodbyeDPI | 0.2.3rc3 (x86_64) | Apache 2.0 | `goodbyedpi/licenses/LICENSE-goodbyedpi.txt` |
| WinDivert | GoodbyeDPI ile gelen | LGPL v3 | `goodbyedpi/licenses/LICENSE-windivert.txt` |

Kaynak kodlarına yukarıdaki bağlantılardan ulaşabilirsin.

---

## Lisans

**Jerb-DpiDiscord**'un kendi kodu (`Baslat.bat`, `byedpi/discord.ps1`) **GNU Genel Kamu Lisansı v3.0 (GPL-3.0)** ile açık kaynaktır. Ayrıntılar için [LICENSE](LICENSE) dosyasına bak.

Kısaca:
- ✅ Kodu ücretsiz kullanabilir, inceleyebilir, değiştirebilir ve paylaşabilirsin.
- ✅ Değiştirilmiş sürümünü de dağıtabilirsin, ama **aynı GPL-3.0 lisansıyla ve kaynak koduyla birlikte** paylaşmak zorundasın.
- ❌ Bu kodu alıp kapalı kaynak bir programa çeviremezsin.
- ⚠️ Yazılım hiçbir garanti olmadan sunulur.

Depoya eklenen ByeDPI, GoodbyeDPI ve WinDivert bu lisansın kapsamında değildir. Her biri kendi lisansına tabidir (bkz. [Teşekkürler](#teşekkürler)).

---

## Destek ol

Bu proje ücretsiz ve öyle kalacak. İşine yaradıysa ve desteklemek istersen:

- 💖 [**GitHub Sponsors ile bağış yap**](https://github.com/sponsors/erendmrbs)
- ⭐ Depoya **yıldız** ver, daha çok kişiye ulaşsın.
- 🐛 Bir sorun bulursan ya da bir fikrin varsa [**Issues**](https://github.com/erendmrbs/JerbDpiDiscord/issues) kısmından bildir.

Bağış sayfasına tepsi menüsündeki **"Destek ol (bağış)"** seçeneğinden de ulaşabilirsin.

---

## Sorumluluk reddi

Bu araç kişisel kullanım için hazırlanmıştır ve olduğu gibi sunulmaktadır. Herhangi bir garanti verilmez. Erişim engellerini aşmaya yönelik araçların kullanımına ilişkin yasal durum ülkeden ülkeye değişebilir. Kullanımdan doğacak her türlü sorumluluk kullanıcıya aittir. Bu proje Discord Inc., ByeDPI, GoodbyeDPI ya da herhangi bir oyun şirketiyle bağlantılı değildir.
