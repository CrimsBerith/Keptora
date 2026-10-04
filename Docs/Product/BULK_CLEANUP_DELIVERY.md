# Keptora — kolay kullanım ve toplu temizleme teslimi

**Tarih:** 4 Ekim 2026. **Dal:** `feat/photo-cleaner-library`. **Başlangıç:** `ba17d50`.

[Onaylanan planın](USABILITY_AND_RELIABILITY_PLAN.md) ortak çekirdek ve iPhone/Mac uygulaması kodlandı. Bu rapor, çalıştırılmış Linux doğrulamasını hazırlanmış Apple testlerinden ayırır. Xcode ve gerçek cihaz kabulü son aşamadadır.

## Kullanıcının yeni akışı

1. Fotoğraflar ve sistemin sunduğu dosya/bulut klasörleri Kaynaklar ekranında bağlanır ve tiklenir. iCloud Fotoğrafları, Fotoğraflar kaynağının içindedir.
2. Ana galeride kısa kaynak özeti ve tek tarama eylemi bulunur. Bulut asıllarını indirme seçeneği ikincil menüdedir; ayrıca onay ister.
3. Bütün listelenebilir seçili öğeler aynı galeride görünür. Varsayılan akıllı düzen ilişkili kareleri yan yana getirir; her ID bir kez görünür. Tarih düzenine geçilebilir.
4. Tümü, Birebir Kopyalar, Çok Benzer ve İncelemeye Değer filtreleri kullanılır. Kısa kaynak rozetleri ile kalite bulguları farklı gösterilir.
5. Grup karşılaştırmasında yakınlaştırma, **Bu Fotoğrafı Sakla**, **Diğerlerini Seç** ve **Grubu Koru** kullanılır. Kullanıcı korumayı sonradan kaldırabilir. Saklama gerekçesi gösterilir.
6. Ana galeri ve ayrıntılı inceleme aynı seçim sepetini kullanır. Görünüm dışındaki seçimler korunur. Son inceleme bir anlık görüntüye sabitlenir; değişen seçim/revizyon kaldırmadan önce reddedilir.
7. Erişilemeyen kaynakların seçimleri bekler. Kullanıcı kaynağı yeniden bağlar veya yalnız seçimden çıkarır. Dosya gerçekten kaldırılmışsa ancak başarılı tam sayım bunu doğrulayınca uzlaştırılır. Eski kayıtta metadata yoksa kimlik sessizce düşürülmez.

WhatsApp'a özel kaynak, sohbet/depo okuma veya özel izin akışı eklenmedi. WhatsApp'tan galeriye/dosyalara kaydedilmiş öğeler kendi gerçek kaynaklarında görünür.

## Paketlerin durumu

| Paket | Kodlanan sonuç | Doğrulama / kalan kabul |
|---|---|---|
| 1 — Tarama/seçim | Katalog, exact, fotoğraf ve video için ortak aşamalar; kısmi/iptal durumu; neden bazında sorunlar; kalıcı bekleyen seçim; sürümlü checkpoint ve geç yazım engeli. | Taşınabilir politika testleri geçti. Sistem izin kaybı ve arka plan yaşam döngüsü cihazda kabul edilecek. |
| 2 — Analiz/cache | Bir katalog; üç bağımsız sınırlı analiz geçişi; kaynak ve hazır sonuçların artımlı aktarımı; kalite/benzerlik için tek fotoğraf önizlemesi; gerçek hash/Vision/kalite cache bağlantısı. | Cache revizyon/algoritma, bozuk dosya ve sınır testleri geçti. Apple cache arşivleme ve gerçek hız ölçümü hazırlandı. |
| 3 — Kalite/benzerlik | Oran/yön koruması; değerlendirilmiş/yetersiz detay/değerlendirilemedi ayrımı; bulanıklık şüphesi, düşük asıl çözünürlük ve uç ışık bulguları; ayrı Vision/hash eşikleri; güçlü ve daha zayıf ilişki ayrımı. | Sentetik sayısal karşı örnekler geçti. Gerçek fotoğraflarda yanlış eşleşme/kaçırma ve kalite kalibrasyonu henüz ölçülmedi. |
| 4 — Akıllı galeri/sepet | Örtüşen ilişkilerde tekil hücreler, karşılaştırma, kullanıcı keeper/koruma kararları, yalnız exact için genel toplu öneri, ortak sepet, sabit son inceleme. | 3.000 öğe ve 1.500 örtüşen ilişki testi geçti. Native kaydırma, zoom ve etkileşim kabulü bekliyor. |
| 5 — UI/metin | Daraltılmış kaynak özeti, kısa kaynak rozetleri, kalite simgeleri, erişim/işlem açıklamaları, duraklat/devam, dört dilde 53 metin, mevcut kaliteli varlıkların korunması. | Proje/görsel/yerelleştirme kontrolleri geçti. Güncel native ekranlar, büyük yazı ve VoiceOver cihazda incelenecek. |
| 6 — Teslim | 48 taşınabilir test; Apple aşama/checkpoint/hata testleri; iPhone ortak sepet testleri; yeni akışa uyarlanan UI testleri; isteğe bağlı gerçek JPEG benchmark; Linux CI işi. | Burada Apple SDK bulunmadığından native testler çalıştırılmadı. Mevcut Apple CI ve aşağıdaki cihaz kabulü sonuçları ayrıca doğrulanacak. |

## Güvenlik ve karar politikası

- Kullanıcının sakladığı veya koruduğu kareler toplu öneriden çıkarılır. Favori, gizli, düzenlenmiş ve paylaşımlı öğeler için mevcut varsayılan koruma korunur. Sıradan albüm üyeliği bütün kopyaları koruma gerekçesi değildir.
- RAW formatı kalite üstünlüğü; yüz/göz landmark'ları açık göz veya iyi ifade kanıtı sayılmaz. Genel estetik kalite yüzdesi gösterilmez.
- Metadata aday bulmayı ve karşılaştırma bağlamını destekler; farklı sahneleri görsel eşik dışında birleştiremez. Bütün grup üyeleri görsel olarak uygun olmalıdır. Örtüşen grupların birleşik yerleşimi geçişli benzerlik iddiası değildir.
- Hash fallback, güçlü Vision kanıtıyla aynı eşikle değerlendirilmez ve tek başına **Çok Benzer** sınıfı vermez. Benzer/kalite bulguları otomatik kaldırma kararı değildir.
- Revizyon tarihi bilinmiyorsa kalıcı analiz kanıtı yeniden kullanılmaz. Dosyada boyut da bilinmelidir. Tarihin kesirli kısmı ve algoritma sürümü anahtara dahildir.
- Cache 10.000 giriş ve tahmini 64 MB sınırıyla yönetilir; sınır aşılana kadar her yazımda bütün kayıtlar tekrar sıralanmaz. Önizleme cache'leri platform başına 64 MB / 250 görüntü sınırındadır; maliyet gerçek piksel belleği üzerinden hesaplanır. Dosya thumbnail decode kuyruğu dört işle sınırlıdır.
- iPhone'daki mevcut ücretsiz inceleme sınırı ve fiyatlandırma değiştirilmedi. Kullanıcının manuel arşiv seçimi ile öneri inceleme yetkisi mevcut ayrımı korur.
- Fotoğraflar Son Silinenler'e, dosyalar aynı depolamadaki kurtarma klasörüne gider. Dosyayı kurtarma klasörüne taşımak disk alanı açmaz. Asıl kaldırma/senkronizasyon ve kurtarma koşulları son incelemede açıklanır.

## Burada çalıştırılan kontroller

| Kontrol | Sonuç |
|---|---|
| Swift 6.0.3 ile ortak Linux paketi | 48 test geçti: önceki 29 + yeni 19. |
| Swift sözdizimi | 138 dosya geçti; Apple tip kontrolü/derlemesi yerine geçmez. |
| Xcode proje referansları | Bütün uygulama Swift dosyaları referanslı. Yeni ortak dosyalar paket tarafından alınır. |
| Görseller | Önceki 67 dosyanın inceleme manifesti ve hash/boyut/fixture kontrolleri geçti. Bu teslimde yeniden üretilmedi. 54 kabul varlığı, 12 tasarım önizlemesi, 1 kasıtlı bozuk test fixture'ı. |
| Yerelleştirme | Değişen 53 metinde EN/TR/FR/DE mevcut; format yer tutucuları kontrol edildi. |
| Diff | Boşluk/patch hatası kontrolü geçti. |

## Apple kabulü — kullanıcı en son çalıştırır

Önce ortak Apple testleri ve Xcode'da iki uygulamanın build/unit/UI testleri çalıştırılır. Mevcut `.github/workflows/apple-validation.yml` bu adımları da içerir; GitHub sonucunun başarılı olduğu bu raporda varsayılmamıştır.

Gerçek JPEG decode, Vision ve SHA-256 ölçümü için Mac'te ayrı test:

```sh
KEPTORA_BENCHMARK_ITEMS=2000 KEPTORA_BENCHMARK_OUTPUT=/tmp/keptora-2000.json \
  swift test --package-path Packages/KeptoraCore --filter NativeAnalysisBenchmarkTests
KEPTORA_BENCHMARK_ITEMS=3000 KEPTORA_BENCHMARK_OUTPUT=/tmp/keptora-3000.json \
  swift test --package-path Packages/KeptoraCore --filter NativeAnalysisBenchmarkTests
```

Bu test gerçek JPEG dosyaları oluşturur; ilk ve tekrar taramada tekil adet/exact grupları karşılaştırır, ilk katalog/grup ve aşama sürelerini, hash/decode/Vision/cache iş sayılarını ve process peak belleğini JSON'a yazar. Sentetik yerel corpus ölçümüdür; kullanıcının gerçek fotoğraflarında doğruluk, bulut veya UI performansı iddiası değildir.

Son cihaz kabulünde:

1. iPhone tam/kısıtlı/reddedilmiş Fotoğraflar izni; iCloud Fotoğrafları; Dosyalar sağlayıcıları. Mac Fotoğraflar + bağlı klasör/iCloud Drive/erişilebilir disk.
2. 2.000/3.000 karma öğe; örtüşen kaynaklar; metadata'sız ve yeniden sıkıştırılmış görseller; Live Photo/düzenlenmiş/RAW sürümleri.
3. Net düz yüzey, bokeh, noise, gece/siluet ve kontrollü bulanık dönüşümler; izinli, etiketli gerçek çiftlerle Vision/hash eşikleri ve yanlış pozitif/kaçırma oranları.
4. Her aşamada iptal/duraklat/devam; arka plan; indirme; geçici izin/disk kaybı; yeniden başlatınca bekleyen seçim.
5. Tek sepet, saklama/koruma, filtre dışı seçim, sabit inceleme, kaldırma iptali/kısmi başarı ve kurtarma çakışması.
6. Büyük yazı, VoiceOver, uygulama içi dört dil, dar Mac penceresi; kaydırma p50/p95, iptal gecikmesi, bellek, pil ve ısı. PhotoKit ön yükleme miktarı bu ölçümlerden sonra ayarlanır.

Gerçek fotoğrafta kalibrasyon ve cihaz ölçümleri yayın kabulünün parçasıdır; ölçüm olmadan “3.000 fotoğraf X saniye” veya “anında tekrar tarama” vaadi verilmez.
