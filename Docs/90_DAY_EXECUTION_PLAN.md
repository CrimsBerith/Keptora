# Mac App Store Araştırması — Ürün Kararı ve 90 Günlük Uygulama Planı

**Tarih:** 3 Ağustos 2026  
**Karar durumu:** Araştırma tamamlandı; ürün seçimi uygulama aşamasına geçirildi.  
**Birinci ürün:** **Keptora — Photo Library Triage**  
**İkinci ürün kuyruğu:** GPX & Photo Geotagging Toolkit  
**Üçüncü ürün kuyruğu:** Local-First Personal CRM

> Bu belge, tamamlanan Mac App Store araştırmasındaki ürün skorları, finalist analizi, fiyatlandırma kararı, Keptora teknik paketleri ve nihai GO/HOLD kararlarını uygulanabilir bir işletim planına dönüştürür.

---

## 1. Yönetici kararı

### GO — Keptora

Keptora'nın seçilme nedeni yalnızca duplicate fotoğraf bulması değildir. Ürün tezi:

- büyük fotoğraf arşivlerinde güvenli inceleme,
- RAW/JPEG/XMP, Live Photo, burst ve edited/export ilişkilerini anlama,
- her öneriyi açıklama,
- geri alınabilir Safety Plan,
- tamamen local-first çalışma,
- büyük kütüphanelerde yarıda kalmadan devam etme,
- Photos, klasörler ve harici diskleri tek güven modeliyle yönetme.

### HOLD — GPX & Photo Geotagging Toolkit

Profesyonel fiyat gücü ve düşük-orta rekabet avantajı var. Ancak format çeşitliliği, EXIF/XMP güvenliği, timestamp drift ve export doğruluğu daha geniş test matrisi gerektiriyor. Keptora v1 sonrası ikinci ürün adayıdır.

### HOLD — Local-First Personal CRM

En büyük uzun vadeli şirket vizyonunu taşıyor. Buna karşılık sync, migration, permissions, hassas veri saklama ve uzun dönem destek yükü ilk ürün için gereksiz risk yaratıyor.

### VALIDATE — Daha küçük ürünler

1. Passport / ID Photo Maker
2. Tournament & League Manager
3. Offline OCR Menu-Bar Capture

Bu ürünler yalnız Keptora'nın launch takvimini bozmayacak şekilde küçük doğrulama deneyleri olarak ele alınmalıdır.

---

## 2. Ürün portföyü sıralaması

| Sıra | Ürün | Araştırma kararı | Stratejik rol | İlk fiyat hipotezi |
|---:|---|---|---|---|
| 1 | Keptora — Photo Library Triage | GO | Ana Mac ürünü | Ücretsiz scan + $24.99 lifetime; $19.99 launch |
| 2 | GPX & Photo Geotagging Toolkit | HOLD | İkinci profesyonel Mac ürünü | $24.99–39.99 lifetime |
| 3 | Local-First Personal CRM | HOLD | Uzun vadeli platform ürünü | Free limited + $29.99–49.99 lifetime |
| 4 | Passport / ID Photo Maker | VALIDATE | Hızlı gelir deneyi | $9.99–14.99 lifetime |
| 5 | Tournament & League Manager | VALIDATE | Küçük, düşük destekli utility | $7.99–14.99 lifetime |

---

## 3. Keptora v1 ürün sözü

**Tek cümlelik değer önerisi**

> Keptora, Mac'inizdeki fotoğraf karmaşasını cihazdan çıkarmadan analiz eder; hangi karelerin neden tutulması gerektiğini açıklar ve hiçbir şeyi geri dönüşsüz silmeden güvenli bir temizlik planı oluşturur.

**Kısa marka sözü**

> Clean the clutter. Keep the memories. Every decision explained.

### Hedef kullanıcılar

- 20.000+ fotoğraflı Apple Photos kullanıcıları
- RAW + JPEG arşivi bulunan fotoğrafçılar
- iPhone, kamera, WhatsApp ve scanner kaynaklarını birleştirmiş aile arşivleri
- Harici disklerde yıllara yayılmış klasörleri bulunan kullanıcılar
- Lightroom/Capture One ve Apple Photos'u birlikte kullanan prosumer kullanıcılar
- Yeni depolama satın almadan önce arşivini küçültmek isteyenler

---

## 4. V1 kapsam kilidi

### V1'de mutlaka bulunacak

1. Klasör ve harici disk seçimi
2. Security-scoped bookmark ile kalıcı erişim
3. Incremental SQLite index
4. Exact SHA-256 duplicate grupları
5. Review-only perceptual similarity
6. RAW/JPEG/XMP ve Live Photo aile grafiği
7. Burst ve edited/export uyarıları
8. Protected keeper
9. Açıklanabilir karar kanıtı
10. Geri alınabilir quarantine
11. İmzalı cleanup manifest
12. Restore ve recovery reconciliation
13. Pause/resume ve force-quit recovery
14. Bounded thumbnail cache
15. Free scan ve StoreKit lifetime unlock
16. Accessibility, keyboard navigation ve error states
17. İngilizce App Store sürümü

### V1 dışında bırakılacak

- Otomatik near-duplicate silme
- Photos library içinde kalıcı silme
- Cloud AI zorunluluğu
- Hesap sistemi
- Ekip işbirliği
- Windows sürümü
- Mobil companion
- Video quality scoring
- Yüz tanıma tabanlı kişi temizliği
- Abonelik
- Plugin API
- Multi-library merge

Bu sınırlar v1'in güvenilir ve App Store'a gönderilebilir kalmasını sağlar.

---

## 5. 90 günlük çalışma planı

## Gün 1–14 — Build hardening ve kapsam dondurma

### Hafta 1

- Faz 5I projesini Mac'te Xcode ile aç
- Tüm target, scheme, entitlement ve signing ayarlarını doğrula
- Swift concurrency warning'lerini temizle
- macOS 13–26 uyumluluk matrisi oluştur
- Unit ve integration testlerini gerçek macOS SDK ile çalıştır
- Crash-safe logging ve privacy manifest kontrolü
- V1 scope freeze belgesini repoya ekle

**Çıkış kapısı:** Temiz build, testlerin tamamı yeşil, fotoğraf/dosya yolları loglanmıyor.

### Hafta 2

- Similarity checkpoint ve retry inventory
- Bozuk/desteklenmeyen dosyalar için retry UI
- Scan resume ve reconciliation edge-case testleri
- Harici disk rename, eject ve replacement testleri
- SQLite migration v1→v4 temiz kurulum ve upgrade testleri
- StoreKit configuration gerçek ürün kimliklerine hazırlanır

**Çıkış kapısı:** Zorla kapatma, disk çıkarma ve migration senaryolarında veri kaybı yok.

---

## Gün 15–35 — Review Studio ve kullanıcı güveni

### Hafta 3

- Synchronized zoom/pan karşılaştırması
- Metadata differences paneli
- Dosya yolu, boyut, çözünürlük, tarih, format ve aile ilişkisi görünümü
- Klavye ile next/previous, keep, skip ve reveal
- Quick Look/Finder açma
- Büyük gruplarda sanallaştırılmış liste

**Çıkış kapısı:** Kullanıcı fare kullanmadan bir review oturumunu tamamlayabiliyor.

### Hafta 4

- Calibration paneli
- İnsan etiketli test çiftleri
- Conservative threshold profilleri
- High/medium/low confidence açıklaması
- Similar mode'da cleanup eylemlerinin bulunmadığını UI düzeyinde garanti et
- Exact ve Similar modlarının görsel olarak ayrılması

**Çıkış kapısı:** Near-duplicate sonuç hiçbir yoldan otomatik cleanup planına giremiyor.

### Hafta 5

- Safety Plan son tasarımı
- Protected keeper değiştirme akışı
- Pre-commit yeniden hash doğrulaması
- İmzalı manifest görünümü
- Restore history
- Çakışan hedef yolu ve değiştirilmiş dosya uyarıları
- Quarantine alanının kullanıcıya anlaşılır biçimde açıklanması

**Çıkış kapısı:** Her dosya hareketi öncesi simüle edilebilir ve sonradan geri alınabilir.

---

## Gün 36–56 — Performans, kalite ve ödeme

### Hafta 6

- 10K, 50K ve 100K gerçekçi corpus testleri
- Intel ve Apple silicon karşılaştırması
- Peak RAM, CPU, thumbnail throughput ve DB büyümesi
- UI responsiveness ölçümü
- Warm scan ve delta scan benchmark'ları
- Büyük grup ve bozuk dosya stres testi

**Planlama hedefleri:**

- Exact duplicate precision: %100
- UI ana thread bloklanması: kullanıcı tarafından fark edilmeyecek düzey
- Warm scan: değişmeyen dosyalarda hash reuse
- 100K katalogda kesintiden sonra devam
- Core feature network trafiği: 0 byte

### Hafta 7

- StoreKit lifetime unlock
- Free kullanıcı: scan + ilk 100 öneri review
- Paid kullanıcı: unlimited groups + cleanup commit + Pro rules
- Restore purchases
- Family Sharing
- Paywall yalnız değer gösterildikten sonra
- Refund riskini azaltan açık güven mesajları

**Fiyat:**

- Standart lifetime: **$24.99**
- İlk 14 gün launch fiyatı: **$19.99**
- Abonelik: **Yok**

### Hafta 8

- Accessibility audit
- VoiceOver labels
- macOS text scaling kontrolleri
- Reduced motion
- High contrast
- Full keyboard access
- Empty/loading/error/offline states
- İngilizce metin sonlandırma
- German/Japanese/French/Spanish/Turkish localization altyapısı

**Çıkış kapısı:** Klavye ve VoiceOver ile ana akış tamamlanabiliyor.

---

## Gün 57–75 — Beta ve App Store hazırlığı

### Hafta 9

- 20–30 kişilik private beta
- Büyük aile arşivi, fotoğrafçı, external-drive ve Apple Photos kullanıcı segmentleri
- In-app feedback export; fotoğraf içeriği veya path içermeyecek
- Beta issue taxonomy
- Crash, freeze, wrong-group ve trust-confusion etiketleri
- Support FAQ taslağı

### Hafta 10

- App Store metadata
- Screenshots
- Privacy policy
- Terms
- Support page
- Restore purchases testi
- IAP review screenshot ve açıklamaları
- Age rating ve category
- App icon ve screenshot contrast kontrolü

**App Store taslağı**

- Name: `Keptora — Photo Library Triage`
- Subtitle: `Clean safely. Keep what matters.`
- Primary category: Photo & Video
- Secondary: Utilities, yalnız işlevle uyumluysa
- Age rating: 4+
- Sign-in: Yok

### Hafta 11

- TestFlight/Notarized internal distribution
- Clean-install testi
- Upgrade-install testi
- Offline launch
- Permission denied/revoked
- External disk unavailable
- Low disk space
- Corrupt DB recovery
- StoreKit purchase/restore
- Localization clipping

**Çıkış kapısı:** P0/P1 hata yok; bütün güvenlik senaryoları belgeli.

---

## Gün 76–90 — Launch ve ölçüm

### Hafta 12

- Release candidate
- App Review notları
- Demo library ve review yönergeleri
- Final performance capture
- Final privacy audit
- Marketing site minimum sürümü
- Press kit ve 6 temel görsel
- Beta kullanıcılarından izinli kısa referanslar

### Hafta 13

- App Store submission
- Launch fiyatını etkinleştirme
- Support inbox takibi
- İlk gün crash ve purchase kontrolü
- Review prompt yalnız başarılı cleanup/restore sonrası
- İlk 14 gün fiyat ve funnel analizi
- V1.0.1 hotfix dalı hazır tutulur

---

## 6. Launch başarı metrikleri

Aşağıdaki rakamlar araştırma verisi değil, ürün yönetimi için başlangıç hedefleridir.

| Metrik | 30 günlük hedef |
|---|---:|
| Crash-free sessions | ≥ %99,5 |
| Scan completion | ≥ %85 |
| Warm scan reuse | ≥ %95 değişmeyen asset |
| Exact-group yanlış pozitif | 0 doğrulanmış vaka |
| Free → paid dönüşüm | %4–8 |
| Refund oranı | <%5 |
| Cleanup sonrası restore ihtiyacı | <%2 |
| Paywall öncesi değer görme | Kullanıcıların ≥ %80'i en az 1 grup görür |
| Ortalama App Store puanı | ≥ 4,3 |
| P1 destek yanıtı | 24 saat içinde |

---

## 7. Launch gate checklist

Uygulama aşağıdakiler tamamlanmadan gönderilmez:

- [ ] Gerçek Mac'te Release build
- [ ] Intel + en az iki Apple silicon sınıfı
- [ ] 10K/50K/100K corpus
- [ ] Exact duplicate precision doğrulaması
- [ ] Similar mode cleanup izolasyonu
- [ ] Force-quit recovery
- [ ] Disk eject/reconnect
- [ ] Signed manifest verification
- [ ] Restore conflict handling
- [ ] StoreKit purchase ve restore
- [ ] Privacy manifest
- [ ] App Sandbox
- [ ] VoiceOver ve keyboard
- [ ] İngilizce metin QA
- [ ] App Store screenshots
- [ ] Privacy policy ve support URL
- [ ] App Review demo açıklaması

---

## 8. Gelir senaryoları

Aşağıdaki hesaplar planlama senaryosudur; satış tahmini değildir.

| Senaryo | Aylık indirme | Paid dönüşüm | Net olmayan brüt satış |
|---|---:|---:|---:|
| Muhafazakâr | 1.000 | %4 | 40 × $24.99 = $999,60 |
| Temel | 3.000 | %6 | 180 × $24.99 = $4.498,20 |
| Güçlü | 10.000 | %8 | 800 × $24.99 = $19.992,00 |

Apple komisyonu, vergiler, iadeler, launch indirimi ve storefront fiyatları bu basit tabloda düşülmemiştir.

### Gelir artırma sırası

1. Conversion ve güven mesajı
2. ASO ve screenshots
3. German/Japanese localization
4. Scheduled Library Health
5. Paid major v2 upgrade
6. Profesyonel archive/report özellikleri

Abonelik, v1 ve mevcut strateji için önerilmez.

---

## 9. Ürün sonrası geliştirme sırası

### Keptora v1.1

- İnsan etiketli threshold calibration
- Daha gelişmiş keyboard triage
- Screenshot ve large-video review
- Library Health raporu
- Otomatik olmayan smart presets

### Keptora v1.5

- Photos read-only genişletme
- Multi-source identity
- Profesyonel signed report
- German/Japanese/French/Spanish/Turkish
- Scheduled health scan

### Keptora v2

- Multi-library catalogue
- Professional archive workflows
- Plugin/export API
- Ücretli major upgrade değerlendirmesi

### İkinci ürün

Keptora gelir ve destek akışı stabil olduktan sonra **GPX & Photo Geotagging Toolkit** teknik spike başlatılır.

---

## 10. Codex/Xcode çalışma emri

1. Faz 5I Xcode paketini temel al.
2. Yeni özellik eklemeden önce tüm build/test hatalarını temizle.
3. V1 kapsam kilidine aykırı özellikleri ayrı backlog'a taşı.
4. Her dosya mutation'ını manifest ve restore testi olmadan birleştirme.
5. Similar sonuçlara cleanup yetkisi verme.
6. Fotoğraf içeriği, tam path veya metadata'yı analytics/log sistemine gönderme.
7. Her haftanın sonunda build, tests, benchmark, privacy, accessibility ve App Store readiness raporu üret.
8. Release build gerçek macOS/Xcode ortamında doğrulanmadan “hazır” kabul etme.

---

## 11. Nihai işletim kararı

**Önümüzdeki 90 günün tek ana ürünü Keptora'dır.**

GPX ve Personal CRM geliştirmeye başlanmayacak; araştırma ve fikir deposunda HOLD durumunda tutulacaktır. Passport/ID Photo Maker veya Tournament Manager yalnız Keptora ekibinin ana takvimini bozmayan, en fazla 1–2 günlük landing-page/keyword doğrulaması olarak ele alınabilir.

Başarı ölçütü yalnız uygulamanın çalışması değildir:

> Kullanıcı, Keptora'nın ne bulduğunu, neden önerdiğini, hangi dosyaya dokunacağını ve geri dönüş yolunu her aşamada anlayabilmelidir.
