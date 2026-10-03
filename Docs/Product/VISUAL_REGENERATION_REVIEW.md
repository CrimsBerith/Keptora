# 67 görselin yeniden üretimi ve tek tek incelemesi

2026-10-03. Önceki envanterdeki **67 yolun tamamı değişti**. 66 görüntülenebilir dosya ayrı ayrı açıldı; 1 bozuk JPEG beklenen hata davranışıyla doğrulandı.

| Tür | Sayı | Kabul |
|---|---:|---|
| İkon / logo | 34 | Dosya düzeyinde görsel kabul |
| İllüstrasyon | 8 | 4 PNG + aynı yeni kaynakları içeren 4 SVG ayrı açıldı |
| Test girdisi | 13 | 12 görüntü ayrı açıldı; 1 kasıtlı bozuk JPEG negatif test kabulü |
| Ekran tasarımı | 12 | Yalnızca tasarım önizlemesi kabulü |

**12 ekran gerçek uygulama çekimi değildir.** Üzerlerinde TASARIM ÖNİZLEMESİ yazıyor. App Store gönderimi, mevcut native UI doğrulaması veya uygulamaya yeni ekran tasarımının kodlandığı anlamına gelmez. Linux ortamında Xcode/simülatör yok; Apple CI/cihazda gerçek çekim ve yeniden kabul gerekir.

SVG dosyaları yeni PNG kaynaklarını içerir; vektör kaynak olarak sunulmaz. macOS ikonlarında şeffaf pay, iOS ikonlarında opak tam yüzey kullanılır. Ekranlar yüksek kaliteli üretilmiş kaynaklardan hedef dosya boyutlarına oran korunarak dışa aktarıldı; kaynak piksel ölçüleri sources.json içinde kayıtlıdır. Büyütme yeni gerçek ayrıntı eklemez.

Tüm fotoğraflar ve kişiler kurgu üretimidir. EXIF tarih/koordinatları kurgu test bilgisidir. Exact kopyalar byte düzeyinde aynı; Sunset ve özgün/düzenlenmiş çifti farklıdır. Benzerlik eşik kalibrasyonu native Vision üzerinde ayrıca gerekir.

[Tek tek gezilebilir galeri](VISUAL_GALLERY.html) · [SHA-256 ve inceleme kaydı](VISUAL_REGENERATION_MANIFEST.json) · [Kaynaklar](../../AppStore/SourceAssets/2026-10/sources.json)

## İncelemede düzeltilenler

- Rejected noisy first transparent mark; regenerated clean colored and mono marks.
- Removed inconsistent generated logo symbols from all desktop previews; use Keptora text wordmark.
- Removed nonexistent object/background retouching from desktop history and unsupported easy recovery claims.
- Narrowed desktop privacy copy to on-device photo analysis; removed Pro crown and handwritten ornaments.
- Corrected desktop duplicates counter to 2 groups / 6 photos.
- Fixed macOS icon export composition; reopened every affected PNG and SVG.

## Dosya bazında kabul

| # | Dosya | Sonuç ve inceleme notu |
|---:|---|---|
| 1 | [AppStore/AppIcon/logo/keptora-icon-fullbleed.svg](../../AppStore/AppIcon/logo/keptora-icon-fullbleed.svg) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 2 | [AppStore/AppIcon/logo/keptora-icon-mac.svg](../../AppStore/AppIcon/logo/keptora-icon-mac.svg) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 3 | [AppStore/AppIcon/logo/keptora-mark-mono.svg](../../AppStore/AppIcon/logo/keptora-mark-mono.svg) | accepted_asset: Beyaz zeminde tek renk siluet, şeffaf iç alan ve tik boşluğu net. |
| 4 | [AppStore/AppIcon/logo/keptora-mark.svg](../../AppStore/AppIcon/logo/keptora-mark.svg) | accepted_asset: Şeffaf zeminde renkli işaret; çerçeve, dağ, güneş ve seçim rozeti temiz. |
| 5 | [AppStore/AppIcon/previous_icon_set/icon_1024.png](../../AppStore/AppIcon/previous_icon_set/icon_1024.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 6 | [AppStore/AppIcon/previous_icon_set/icon_120.png](../../AppStore/AppIcon/previous_icon_set/icon_120.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 7 | [AppStore/AppIcon/previous_icon_set/icon_128.png](../../AppStore/AppIcon/previous_icon_set/icon_128.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 8 | [AppStore/AppIcon/previous_icon_set/icon_16.png](../../AppStore/AppIcon/previous_icon_set/icon_16.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. Küçük boyutta çerçeve/tik silueti korunuyor; fotoğraf ayrıntıları doğal olarak azalıyor. |
| 9 | [AppStore/AppIcon/previous_icon_set/icon_180.png](../../AppStore/AppIcon/previous_icon_set/icon_180.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 10 | [AppStore/AppIcon/previous_icon_set/icon_256.png](../../AppStore/AppIcon/previous_icon_set/icon_256.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 11 | [AppStore/AppIcon/previous_icon_set/icon_32.png](../../AppStore/AppIcon/previous_icon_set/icon_32.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. Küçük boyutta çerçeve/tik silueti korunuyor; fotoğraf ayrıntıları doğal olarak azalıyor. |
| 12 | [AppStore/AppIcon/previous_icon_set/icon_40.png](../../AppStore/AppIcon/previous_icon_set/icon_40.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 13 | [AppStore/AppIcon/previous_icon_set/icon_512.png](../../AppStore/AppIcon/previous_icon_set/icon_512.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 14 | [AppStore/AppIcon/previous_icon_set/icon_58.png](../../AppStore/AppIcon/previous_icon_set/icon_58.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 15 | [AppStore/AppIcon/previous_icon_set/icon_60.png](../../AppStore/AppIcon/previous_icon_set/icon_60.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 16 | [AppStore/AppIcon/previous_icon_set/icon_64.png](../../AppStore/AppIcon/previous_icon_set/icon_64.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 17 | [AppStore/AppIcon/previous_icon_set/icon_80.png](../../AppStore/AppIcon/previous_icon_set/icon_80.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 18 | [AppStore/AppIcon/previous_icon_set/icon_87.png](../../AppStore/AppIcon/previous_icon_set/icon_87.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 19 | [AppStore/AppIcon/source-1024.png](../../AppStore/AppIcon/source-1024.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 20 | [AppStore/Generated/Keptora_Review_Corpus/EdgeCases/Corrupted.jpg](../../AppStore/Generated/Keptora_Review_Corpus/EdgeCases/Corrupted.jpg) | accepted_negative_fixture: Yeni plaj JPEG kaynağından 64 bayta kesildi; görüntülenememesi beklenen negatif testtir. Görsel onayı verilmez. |
| 21 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Copy.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Copy.jpg) | accepted_asset: Doğal altın saat koy fotoğrafı; kaya, tekne, ufuk ve su ayrıntıları net; birebir kopya grubu korundu. |
| 22 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Original.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Beach_Original.jpg) | accepted_asset: Doğal altın saat koy fotoğrafı; kaya, tekne, ufuk ve su ayrıntıları net; birebir kopya grubu korundu. |
| 23 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_1.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_1.jpg) | accepted_asset: Kurgu aile fotoğrafı: yüzler/eller, ışık ve kompozisyon incelendi; belirgin anatomi sorunu görülmedi; birebir kopyalar korundu. |
| 24 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_2.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Copy_2.jpg) | accepted_asset: Kurgu aile fotoğrafı: yüzler/eller, ışık ve kompozisyon incelendi; belirgin anatomi sorunu görülmedi; birebir kopyalar korundu. |
| 25 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Original.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Family_Original.jpg) | accepted_asset: Kurgu aile fotoğrafı: yüzler/eller, ışık ve kompozisyon incelendi; belirgin anatomi sorunu görülmedi; birebir kopyalar korundu. |
| 26 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Poster copy.png](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Poster%20copy.png) | accepted_asset: Mavi kemer, güneş, basamaklar ve yapraklarla temiz poster kompozisyonu; iki PNG aynı içerikte. |
| 27 | [AppStore/Generated/Keptora_Review_Corpus/Exact/Poster.png](../../AppStore/Generated/Keptora_Review_Corpus/Exact/Poster.png) | accepted_asset: Mavi kemer, güneş, basamaklar ve yapraklarla temiz poster kompozisyonu; iki PNG aynı içerikte. |
| 28 | [AppStore/Generated/Keptora_Review_Corpus/Families/DSC_0001.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Families/DSC_0001.jpg) | accepted_asset: Bisikletli köy sokağı net; özgün ve düzenlenmiş görüntü aynı sahne, farklı dosya; sıcak düzenleme kabul edildi. |
| 29 | [AppStore/Generated/Keptora_Review_Corpus/Families/DSC_0001_Edit.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Families/DSC_0001_Edit.jpg) | accepted_asset: Bisikletli köy sokağı net; özgün ve düzenlenmiş görüntü aynı sahne, farklı dosya; sıcak düzenleme kabul edildi. |
| 30 | [AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_1.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_1.jpg) | accepted_asset: Aynı deniz feneri sahnesi; dalga/ışıkta küçük değişiklikler; farklı dosya ve birer saniye aralıklı kurgu EXIF bilgileri. |
| 31 | [AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_2.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_2.jpg) | accepted_asset: Aynı deniz feneri sahnesi; dalga/ışıkta küçük değişiklikler; farklı dosya ve birer saniye aralıklı kurgu EXIF bilgileri. |
| 32 | [AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_3.jpg](../../AppStore/Generated/Keptora_Review_Corpus/Similar/Sunset_3.jpg) | accepted_asset: Aynı deniz feneri sahnesi; dalga/ışıkta küçük değişiklikler; farklı dosya ve birer saniye aralıklı kurgu EXIF bilgileri. |
| 33 | [AppStore/Generated/Screenshots/Mac/01_Keptora_Home_Overview.png](../../AppStore/Generated/Screenshots/Mac/01_Keptora_Home_Overview.png) | accepted_design_preview_only: Serbest fotoğraf seçimi; geniş ızgara, belirgin seçim işaretleri ve okunur ana başlık. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 34 | [AppStore/Generated/Screenshots/Mac/02_Keptora_Exact_Duplicates.png](../../AppStore/Generated/Screenshots/Mac/02_Keptora_Exact_Duplicates.png) | accepted_design_preview_only: İki üçlü kopya grubu; sayaç 2 grup / 6 fotoğraf olarak düzeltildi; koru ve seçim ayrımı açık. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 35 | [AppStore/Generated/Screenshots/Mac/03_Keptora_Similar_Comparison.png](../../AppStore/Generated/Screenshots/Mac/03_Keptora_Similar_Comparison.png) | accepted_design_preview_only: Yan yana benzer fotoğraflar; çekim zamanı/konum satırları ve koruma eylemi okunur. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 36 | [AppStore/Generated/Screenshots/Mac/04_Keptora_Safety_Plan.png](../../AppStore/Generated/Screenshots/Mac/04_Keptora_Safety_Plan.png) | accepted_design_preview_only: Üç seçili fotoğraf ile onay içeriği tutarlı; Sil kırmızı, Vazgeç ikincil. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 37 | [AppStore/Generated/Screenshots/Mac/05_Keptora_History_Restore.png](../../AppStore/Generated/Screenshots/Mac/05_Keptora_History_Restore.png) | accepted_design_preview_only: Geçmiş kayıtları fotoğraf temizliği olarak düzeltildi; nesne silme ve sınırsız geri alma iddiaları kaldırıldı. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 38 | [AppStore/Generated/Screenshots/Mac/06_Keptora_Privacy_Pro.png](../../AppStore/Generated/Screenshots/Mac/06_Keptora_Privacy_Pro.png) | accepted_design_preview_only: Kalkan ve fotoğraf kompozisyonu net; gizlilik metni yalnızca cihazda analizi anlatır; fiyat iddiası yok. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 39 | [AppStore/Generated/Screenshots/iOS/01_iPhone_Library.png](../../AppStore/Generated/Screenshots/iOS/01_iPhone_Library.png) | accepted_design_preview_only: Tümü / WhatsApp / Ekran görüntüleri filtreleri, büyük seçim halkaları ve inceleme eylemi okunur. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 40 | [AppStore/Generated/Screenshots/iOS/02_iPhone_Exact_Review.png](../../AppStore/Generated/Screenshots/iOS/02_iPhone_Exact_Review.png) | accepted_design_preview_only: İki kopya çifti; korunacak fotoğraflar ve seçili kopyalar görsel olarak ayrışıyor. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 41 | [AppStore/Generated/Screenshots/iOS/03_iPhone_Similar_Comparison.png](../../AppStore/Generated/Screenshots/iOS/03_iPhone_Similar_Comparison.png) | accepted_design_preview_only: Benzer fotoğraflar büyük gösteriliyor; çekim zamanı/konum bilgileri okunur; Koru eylemi belirgin. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 42 | [AppStore/Generated/Screenshots/iOS/04_iPhone_Cleanup_Confirm.png](../../AppStore/Generated/Screenshots/iOS/04_iPhone_Cleanup_Confirm.png) | accepted_design_preview_only: Üç seçili küçük resim, açık silme uyarısı ve Vazgeç; geri yükleme Fotoğraflar Son Silinenler üzerinden. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 43 | [AppStore/Generated/Screenshots/iOS/05_iPhone_History.png](../../AppStore/Generated/Screenshots/iOS/05_iPhone_History.png) | accepted_design_preview_only: Temizlik geçmişi ve Ayrıntılar bağlantıları okunur; geri yükleme Son Silinenler yönlendirmesiyle sınırlı. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 44 | [AppStore/Generated/Screenshots/iOS/06_iPhone_Paywall.png](../../AppStore/Generated/Screenshots/iOS/06_iPhone_Paywall.png) | accepted_design_preview_only: Pro kartı ve kalkan illüstrasyonu dengeli; plan fiyatı/deneme uydurulmadı; satın alımları geri yükle ayrı. TASARIM ÖNİZLEMESİ etiketi görünür; native UI veya App Store kabulü değildir. |
| 45 | [AppStore/Illustrations/onboarding_privacy.svg](../../AppStore/Illustrations/onboarding_privacy.svg) | accepted_asset: Kalkan/kilit net, fotoğraf baskıları doğal; mor tonlar ve odak dengeli. |
| 46 | [AppStore/Illustrations/onboarding_proof.svg](../../AppStore/Illustrations/onboarding_proof.svg) | accepted_asset: İki yakın fotoğraf ve büyüteç karşılaştırmayı anlatıyor; seçim rozeti açık. |
| 47 | [AppStore/Illustrations/onboarding_restore.svg](../../AppStore/Illustrations/onboarding_restore.svg) | accepted_asset: Fotoğraf, arşiv tepsisi ve dönüş oku net; süre/sınırsız kurtarma iddiası yok. |
| 48 | [AppStore/Illustrations/paywall_hero.svg](../../AppStore/Illustrations/paywall_hero.svg) | accepted_asset: Altı kaliteli seyahat fotoğrafı düzenli galeride; renkler ve baskı perspektifleri tutarlı. |
| 49 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 50 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024_ios.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024_ios.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 51 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_120.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_120.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 52 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_128.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_128.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 53 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_16.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_16.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. Küçük boyutta çerçeve/tik silueti korunuyor; fotoğraf ayrıntıları doğal olarak azalıyor. |
| 54 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_180.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_180.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 55 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 56 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_32.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_32.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. Küçük boyutta çerçeve/tik silueti korunuyor; fotoğraf ayrıntıları doğal olarak azalıyor. |
| 57 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_40.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_40.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 58 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_512.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_512.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 59 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_58.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_58.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 60 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_60.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_60.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 61 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_64.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_64.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. macOS maskesi düzeltildi; şeffaf dış pay ve köşeler tekrar incelendi. |
| 62 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_80.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_80.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 63 | [Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_87.png](../../Keptora/Resources/Assets.xcassets/AppIcon.appiconset/icon_87.png) | accepted_asset: Fotoğraf çerçevesi ve seçim rozeti net; yeni marka rengi ve merkezleme tutarlı. |
| 64 | [Keptora/Resources/Assets.xcassets/onboarding_privacy.imageset/onboarding_privacy.png](../../Keptora/Resources/Assets.xcassets/onboarding_privacy.imageset/onboarding_privacy.png) | accepted_asset: Kalkan/kilit net, fotoğraf baskıları doğal; mor tonlar ve odak dengeli. |
| 65 | [Keptora/Resources/Assets.xcassets/onboarding_proof.imageset/onboarding_proof.png](../../Keptora/Resources/Assets.xcassets/onboarding_proof.imageset/onboarding_proof.png) | accepted_asset: İki yakın fotoğraf ve büyüteç karşılaştırmayı anlatıyor; seçim rozeti açık. |
| 66 | [Keptora/Resources/Assets.xcassets/onboarding_restore.imageset/onboarding_restore.png](../../Keptora/Resources/Assets.xcassets/onboarding_restore.imageset/onboarding_restore.png) | accepted_asset: Fotoğraf, arşiv tepsisi ve dönüş oku net; süre/sınırsız kurtarma iddiası yok. |
| 67 | [Keptora/Resources/Assets.xcassets/paywall_hero.imageset/paywall_hero.png](../../Keptora/Resources/Assets.xcassets/paywall_hero.imageset/paywall_hero.png) | accepted_asset: Altı kaliteli seyahat fotoğrafı düzenli galeride; renkler ve baskı perspektifleri tutarlı. |

## Çalıştırılan kontroller

- 67 değişmiş yol, incelenen SHA-256, dosya ölçüleri, SVG içeriği, ikon opaklık/şeffaflığı, kaynak dosyaları ve ZIP eşleşmesi geçti.
- Exact kopyalar aynı; Sunset üç farklı dosya; özgün/düzenlenmiş çift farklı. Kurgu EXIF tarih/GPS bilgileri okunuyor.
- Tam dışa aktarma yeniden çalıştırıldı: 67 incelenmiş dosyanın SHA-256 değeri değişmedi.
- Dört runtime illüstrasyon, bütün asset referansları, Türkçe format yer tutucuları ve Xcode kaynak referansları geçti.
- Ortak Swift model/seçim/metadata testleri: 11 test, 0 hata.
- App Store kapısı 12 tasarım önizlemesini beklenen biçimde reddetti. Native ekran/erişilebilirlik ve Vision kalibrasyonu bu ortamda çalıştırılmadı.
- Galeri veri/bağlantı kontrolü yapıldı; tarayıcı çalıştırma kontrolü bu ortamın yönetilen tarayıcı politikasında file:// adresi engellendiği için tamamlanamadı. Bu, 66 dosyanın ayrı görsel incelemesini etkilemez.
