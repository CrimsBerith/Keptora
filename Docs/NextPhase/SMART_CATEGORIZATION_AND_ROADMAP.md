# 🚀 Keptora: Akıllı Fotoğraf Kategorileme & Yeni Nesil Yol Haritası

> **Tarih:** 2026-09-29  
> **Durum:** Çekirdek Motor Prototipi Tamamlandı & Doğrulandı (`11 / 11 Test PASS`)  
> **Temel İlke:** %100 On-Device · Sıfır Gizlilik Sızıntısı · Deterministik Güvenlik · Apple Neural Engine Destekli  

---

## 1. 🎯 Yönetici Özeti

Keptora 1.0; bayt-bayt SHA-256 tam eşleşmeler, geri alınabilir Güvenlik Planları (`Safety Plans`) ve görsel benzerlik inceleme motoruyla Mac & iOS App Store için benzersiz bir güven çıtası belirledi.

Bir sonraki büyük sıçrama: Kullanıcıların fotoğraf kütüphanelerini sadece kopya dosyalardan arındırmakla kalmayıp, **dağınıklığı (clutter), bağlamsızlığı ve çöp medyayı zahmetsizce yönetilebilir kılmaktır**.

Bu doğrultuda geliştirilen **Akıllı Kategorileme Motoru (`SmartCategorizationEngine`)**, Apple Vision ve CoreGraphics altyapısını kullanarak fotoğrafları hem **semantik**, hem **kalite**, hem de **zamansal/olay** boyutunda sınıflandırır.

---

## 2. 🧠 Çekirdek Motor: `SmartCategorizationEngine` (Kodlandı & Test Edildi)

Çekirdek motor [`Packages/KeptoraCore/Sources/KeptoraCore/SmartCategorizationEngine.swift`](file:///Users/khankartal/Desktop/MAC%20APPS%20NEARLY%20FINISHED/Cullora_Phase_5O_Calisan_Xcode_Projesi/Packages/KeptoraCore/Sources/KeptoraCore/SmartCategorizationEngine.swift) dosyası altında sıfır üçüncü parti kütüphane bağımlılığıyla inşa edilmiş ve birim testlerinden başarıyla geçmiştir.

### 2.1 Çok Boyutlu Analiz Mimarisi

```
+---------------------------------------------------------------------------------+
|                               Görsel Girdisi (CGImage)                          |
+---------------------------------------------------------------------------------+
                                        |
       +--------------------------------+--------------------------------+
       |                                |                                |
       v                                v                                v
+----------------------+     +----------------------+     +----------------------+
| 1. Semantik Sınıf     |     | 2. Hızlı OCR Metin   |     | 3. Görsel Kalite     |
| VNClassifyImage      |     | VNRecognizeText      |     | VisualQualityEngine  |
| - 1300+ Apple Sınıfı |     | - Fiş, Fatura, IBAN  |     | - Netlik / Blur     |
| - Doğa, İnsan, Şehir |     | - Finansal Anahtarlar|     | - Işık & Pozlama     |
| - Hayvan, Yemek vb.  |     | - Ekran Yazı Yoğunluğu|    | - Göz Açık / Kapalı  |
+----------------------+     +----------------------+     +----------------------+
       |                                |                                |
       +--------------------------------+--------------------------------+
                                        |
                                        v
+---------------------------------------------------------------------------------+
|                   Akıllı Sepet & Eylem Belirleme (SmartBucket)                   |
|  • Fişler & Faturalar    • Ekran Görüntüleri   • Bulanık & Hatalı Kareler       |
|  • Seri Çekimler         • En İyi Vitrin Kareleri (Best Shots)                  |
+---------------------------------------------------------------------------------+
```

### 2.2 Sınıflandırma Taksonomisi (`PhotoCategory`)

| Kategori | Sistem İkonu | Açıklama ve Apple Vision Eşleşmesi |
|---|---|---|
| **`natureLandscape`** | `leaf.fill` | Manzara, deniz, gökyüzü, orman, dağ, bitkiler (`plant`, `tree`, `water`, `sky`) |
| **`peoplePortrait`** | `person.2.fill` | Portreler, insan yüzleri, grup fotoğrafları, selfie'ler (`human`, `face`, `crowd`) |
| **`animalsPets`** | `pawprint.fill` | Evcil hayvanlar, kedi, köpek, kuş, yaban hayatı (`dog`, `cat`, `animal`, `wildlife`) |
| **`foodDrink`** | `fork.knife` | Yemekler, kahvaltı, tatlı, içecekler, restoran anları (`food`, `meal`, `drink`) |
| **`architectureCity`** | `building.2.fill`| Binalar, köprüler, kentsel yapılar, iç mekanlar (`building`, `city`, `tower`) |
| **`documentsReceipts`** | `doc.text.fill` | Fiş, fatura, basılı evrak, menü, tahta notu (`document`, `paper`, `receipt`) |
| **`screenshotsGraphics`**| `macwindow` | Ekran görüntüleri, infografikler, telefon ekran alıntıları (`screenshot`, `screen`) |
| **`vehiclesTransport`** | `car.fill` | Arabalar, uçaklar, trenler, tekneler, bisikletler (`vehicle`, `car`, `airplane`) |

### 2.3 Eyleme Dönüştürülebilir Akıllı Sepetler (`SmartBucket`)

Kullanıcıların tek bir dokunuşla kütüphanelerinde devasa yer açmasını sağlayan akıllı kümeler:

1. 🧾 **`receiptsAndInvoices` (Fişler ve Faturalar):**
   - Metin karakter sayısı > 60 olan ve `fatura`, `kdv`, `receipt`, `total`, `iban`, `tutar`, `eur`, `usd` gibi finansal göstergeler içeren kareler.
   - *Eylem:* "Fişleri Güvenle Arşivle / Temizle" seçeneği.
2. 📱 **`screenshots` (Ekran Görüntüleri):**
   - iPhone / Mac / iPad ekran oranı taşıyan ve PNG formatında yüksek metin yoğunluğu barındıran geçici ekran görüntüleri.
   - *Eylem:* "6 Aydan Eski Ekran Görüntülerini Gözden Geçir".
3. 🌫️ **`blurryAndDefective` (Bulanık ve Kusurlu Çekimler):**
   - Sobel/Laplacian netlik skoru < 28 olan ve pozlama dengesi aşırı bozuk (kapkaranlık veya tamamen patlamış) kareler.
   - *Eylem:* "Kusurlu Kareleri İncele".
4. 👯 **`burstSequences` (Seri Çekim Fazlalıkları):**
   - 2-3 saniye aralıklarla çekilmiş 5-15 karelik kümeler.
   - *Eylem:* En net ve gözlerin açık olduğu tek bir kareyi saklayıp kalan kopyaları plana ekleme.
5. ⭐ **`bestShots` (En İyi Vitrin Kareleri):**
   - Netlik skoru > 65, kompozisyon ve ışık dengesi yüksek, yüz ifadelerinde gözlerin açık olduğu vitrin fotoğrafları.

### 2.4 Zamansal & Olay Kümeleme (`EventCluster`)
- Fotoğraflar arasındaki çekim zaman farkı (`DateTimeOriginal`) hesaplanır.
- 4 saat ve üzeri boşluklar yeni bir etkinlik/gezi sınırını belirler.
- Her küme için `VisualQualityEngine` üzerinden en yüksek kompozisyon ve netlik puanına sahip olan fotoğraf otomatik olarak **"Kapak Fotoğrafı (Hero Cover)"** seçilir.

---

## 3. 💡 Keptora'ya Eklenebilecek 8 Büyük Ürün Fırsatı

### 1. 🏆 "Best Shot" (En İyi Kare) Seçici — AI Burst & Sequence Culler
- **Pazar Durumu:** Düğün ve etkinlik fotoğrafçıları için *Aftershoot* veya *Narrative Select* gibi araçlar aylık 30$ abonelik satmaktadır.
- **Keptora'daki Fırsat:** Kullanıcı doğum gününde 10 benzer fotoğraf çektiğinde, Keptora yüz ifadeleri (`VNDetectFaceLandmarksRequest`), gülümseme ve odak netliğini birleştirerek otomatik **"⭐ En İyi Kare"** rozeti koyar. Kullanıcı tek tıkla en iyiyi saklayıp diğer 9 tanesini temizler.

### 2. 🎬 "Heavy Media Hunter" (Dev Video & Ekran Kaydı Avcısı)
- **Problem:** Fotoğraf kütüphanesindeki depolamanın **%75'i videolara aittir**.
- **Keptora Çözümü:**
  - Boyut/süre oranı anomalisi (örneğin 6 saniye ama 350 MB ProRes video).
  - Karanlık veya cepte yanlışlıkla kaydedilmiş video tespiti (`AVAssetImageGenerator` ile anahtar kare örneklemesi).
  - Ağır videoları listeleme ve harici diske kolay transfer imkanı.

### 3. 🛡️ "Privacy Vault & Sensitive Media Scanner" (Hassas Veri / Fiş Dedektörü)
- **Problem:** Kullanıcılar aceleyle çektikleri kimlik kartı, pasaport, kredi kartı veya şifre fotoğraflarını albümlerinde unuturlar.
- **Keptora Çözümü:** Yerel OCR ile hassas kart ve kimlik formatlarını tespit edip kullanıcıyı uyarır:
  - *"Albümlerinizde 6 adet hassas finansal/kimlik belgesi tespit edildi. Bunları şifreli kasaya taşımak ister misiniz?"*

### 4. 🧭 "EXIF & Metadata Doctor" (Kayıp Tarih & Konum Tamir Atölyesi)
- **Problem:** WhatsApp, Telegram veya eski makinelerden aktarılan fotoğraflarda çekim tarihi kaybolur ve "bugün" olarak görünür.
- **Keptora Çözümü:** Dosya adı timestamp'ine (`IMG_20240815_1423.jpg`) veya klasör adına göre kronolojik tarihi tek tıkla geri yazma.
- **Konum Temizleyici (EXIF Stripper):** Sosyal medyada paylaşmadan önce fotoğraftan ev/iş GPS koordinatlarını sıyırma.

### 5. 🎯 "Storage Diet" (Hedef Odaklı Alan Açma Asistanı)
- **Çözüm:** Kullanıcıya hedef belirletme: *"Diskinde 25 GB yer açmak istiyorsun"*.
- Keptora riski en düşükten en yükseğe doğru sepet oluşturur:
  - *12 GB Tam Eşleşen Kopyalar (0 Risk)*
  - *8 GB Eski Ekran Görüntüleri & Fişler (Çok Düşük Risk)*
  - *5 GB Kötü Çekilmiş Seri Fotoğraf Fazlalıkları (İncelemeye Hazır)*

### 6. 🗂️ "Physical Archive Exporter" (Finder Düzenleme Motoru)
- **Çözüm:** Fotoğrafları Apple Photos kütüphanesine mahkûm etmeden, harici SSD veya NAS sürücülerine `Yıl / Ay - Olay Adı` şeklinde fiziksel klasör ağacında sıfır kayıpla organize etme.

### 7. ⚡ "Swipe / Ergonomik Hızlı Ayıklama Modu" (Tinder-Style Culling)
- **Mac:** Klavyeden el kaldırmadan (Space = Büyüt, Sol Ok = Güvenlik Planı, Sağ Ok = Sakla, 1 = Yıldızla) saniyede 3 fotoğraf değerlendirme hızı.
- **iOS:** Dokunsal haptic titreşimlerle akıcı kart kaydırma deneyimi.

### 8. 🐕 "Folder Watchdog" (Düşük Güçlü Arka Plan Nöbetçisi)
- **Mac:** macOS `FSEvents` API'siyle İndirilenler veya Masaüstü klasörünü sıfır pil harcayarak izler; mükerrer bir görsel indiğinde bildirim verir: *"İndirilen 'IMG_012.jpg' zaten kütüphanenizde mevcut."*

---

## 4. 🗺️ Uygulama Yol Haritası (Milestones)

| Faz | Kapsam | Durum |
|---|---|:---:|
| **Faz A: Çekirdek Motor & Algoritma** | `SmartCategorizationEngine` + `EventCluster` + OCR + Kalite analizi | ✅ **Tamamlandı (`Packages/KeptoraCore`)** |
| **Faz B: Veritabanı Şeması v5** | `asset_categories`, `asset_quality_metrics`, `smart_clusters` tablolarının SQLite'a eklenmesi | ⏳ Sıradaki Adım |
| **Faz C: Akıllı Sepetler Kullanıcı Arayüzü** | SwiftUI "Akıllı Sepetler" (Smart Buckets Studio) ekranı ve filtreleri | ⏳ Planlandı |
| **Faz D: Best Shot & Video Avcısı** | Seri çekimlerde en iyi kare rozeti + 4K ağır video analizi | ⏳ Planlandı |
