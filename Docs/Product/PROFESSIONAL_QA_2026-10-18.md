# Keptora — ikinci derin kalite denetimi, 18 Ekim 2026

Başlangıç: `c0aa5eccce616cdc8d5ee92bb9ea8af7b6bfc7f2`, `codex/keptora-readiness-fixes`, temiz çalışma ağacı. Önceki [184 düzeltme raporu](READINESS_FIXES_2026-10-18.md) tarihsel kanıttır. Bu denetim daha geniş UI kapsamını ve önceki testlerde bulunmayan veri güvenliği senaryolarını ekler.

Yeni yerel aday: **1.0.0 (185)**. İki platformun plain Release arşivi ve App Store yöntemiyle yerel `.pkg` / `.ipa` exportu oluşturuldu. Dışa aktarılmış uygulamalar strict codesign kontrolünden geçti; debug yetkisi `get-task-allow` kapalı/yok. Mac paketi arm64+x86_64, iPhone arm64; iki privacy manifestinde tracking kapalı ve collected-data listesi boş. Bu teknik kontroller kalite kabulü veya Apple onayı değildir.

Paketler `Build/ReleaseCandidates/1.0.0-185/`; boyut/hash `packages.json`, kaynak ve kabul durumu `provenance.json` içinde tutulur. Eski 184 paketleri korundu.

**Karar:** İşlev testlerinin yeşil olması, kusursuz kullanıcı deneyimi veya tamamlanmış cihaz kabulü değildir. Aşağıdaki dört veri/işlem sorunu önce başarısız native testle yeniden üretildi, sonra düzeltildi. Tam erişilebilirlik tanısı ve fiziksel cihaz kabulü ayrı kapılardır; bütün uygulamaya “sıfır sorun” onayı verilmez.

## Yeniden üretilen ve düzeltilen sorunlar

| Öncelik | Sorun ve gerçek etkisi | Düzeltme / regresyon kanıtı |
|---|---|---|
| P1 | iPhone'da **Koru** işaretli öğe normal dokunuş, toplu seçim veya eski kaydedilmiş seçim üzerinden kaldırılabiliyordu. Gerçek geçici dosya testinde dosya kurtarma alanına taşındı; koruma uygulanmadı. | Manuel/toplu seçim korunan ID'leri dışlar. Son işlem kapısı korunan öğeyi dosyaya dokunmadan reddeder. Açık **Korumayı Kaldır ve Seç** eylemi geri alınabilir. Önce 2 test başarısız; sonra ikisi de geçti. |
| P1 | iPhone önizleme önbelleği yalnız öğe kimliği ve değiştirilme tarihini esas alıyordu. Dosya aynı inode/tarih ile değişince eski görsel yeni içeriğin önizlemesi olarak kalabiliyordu. | Önbellek anahtarına fiziksel kimlik ve nanosecond değişim revizyonu eklendi. Gerçek dosya yeniden yazılıp eski tarih geri verildiğinde eski görsel artık alınmıyor. Aynı test düzeltmeden önce eski `UIImage` nesnesini bulup başarısız oldu. |
| P1 | iPhone'da ikinci taşıma başarısız olup ilk dosyanın geri dönüş yolu başka dosyayla dolunca kısmi kurtarma kaydı hemen işlenmiyordu. Taşınmış öğe seçimde kalıyor, sonuç mesajı tamamlanan işi saymıyordu. | `FolderCleanupFailure` içindeki kalıcı işlem kaydı Geçmiş'e aktarılır. Yalnız gerçekten taşınmış öğeler seçimden çıkarılır; kalanlar korunur. Sonuç mesajı 1 taşındı / 1 taşınmadı der. Test iki gerçek dosya, kasıtlı hata ve dolu geri dönüş yolu kullanır; mevcut hedefin üzerine yazılmaz. |
| P1 | Aynı kısmi geri taşıma hatasında Mac sonucu doğru sayıyor fakat seçim/katalog uzlaştırması hata işleyicisinden önce çalışıyordu. Taşınmış öğe işlem dönüşünde hâlâ seçiliydi. | Uzlaştırma `defer` bloğu hata işleyicisinden sonra çalışır. Native test tamamlanan öğe, kalan seçim, Geçmiş, kurtarma baytları ve dolu hedefin korunmasını birlikte doğrular. Önce başarısız, sonra geçti. |

Kurtarma motoruna eklenen opsiyonel taşıma kancası, mevcut restore hata enjeksiyonlarıyla aynı modelde native hata senaryosunu üretir. Üretim çağrılarında varsayılan `nil`; dosya doğrulama ve üzerine yazmama kontrolleri korunur.

Yayın betiğinde simülatörün hazırlık/ilk test derlemesi de timeout kapsamına alındı. Varsayılan çıktı adına süreç kimliği eklendi; aynı saniyedeki iki çalıştırma çıktı paylaşmaz. Betik `destination=upload` içeren bir export plistini reddeder; yerel paket üretme komutunun yanlışlıkla mağazaya yükleme yapmasına izin vermez.

## Görsel ve erişilebilirlik düzeltmeleri

- Mac marka metni ve iPhone Pro başlığı, düşük kontrastlı çok renkli yazı yerine açık/koyu temaya uyarlanan metin rengini kullanır.
- İkincil açıklamalar, renkli panel üzerinde de okunabilen opak açık/koyu tema rengine geçti. iPhone kontrast testi bu rengi sistem yüzeyleri ve renkli düğme zeminlerinde **4.5:1** sınırıyla kontrol eder.
- iPhone Geçmiş simgesinin VoiceOver'a `photo.badge.checkmark` diye okunması engellendi; yanında gerçek başlık zaten var. Geçmiş kartlarının erişilebilirlik sınırı açık hale getirildi.
- Mac son inceleme küçük resmi, yanında dosya adı bulunduğu için dekoratif işaretlendi. Ana pencere/çalışma alanı etiketleri eklendi.
- En büyük erişilebilirlik yazısında Geçmiş başlığı, büyüyen dekoratif simge yüzünden dar bir sütuna sıkışıp kelimeleri bölüyordu. Bu boyutlarda simge kaldırıldı, başlık tam genişliğe alındı ve adet/boyut rozetleri alt alta yerleştirildi. Türkçe ekran testine başlığın kart genişliğini kullanması koşulu eklendi.

## Çalıştırılan doğrulama

| Alan | Kanıt |
|---|---|
| Ortak çekirdek | 126 geçti; isteğe bağlı büyük benchmark atlandı. Değişen kurtarma motoruyla yeniden çalıştırıldı. |
| Mac optimize native testleri | 33/33 geçti; gerçek kısmi geri taşıma regresyonu ve 6 StoreKitTest senaryosu dahil. |
| iPhone optimize native testleri | 33/33 geçti; koruma, eski önizleme, kısmi kurtarma ve kontrast regresyonları dahil. Gerçek simülatör Fotoğraflar girdileriyle tarama da geçti. |
| Mac işlevsel UI | 6/6 geçti: izin reddi, seçim, çok adımlı klavye undo/redo, arama alanında metin undo, kaldırma/restore, dolu hedef, Ayarlar/Pro. |
| iPhone geniş UI | 30/30 geçti. İlk kullanım, izin yardımı, dosya seçici iptali, kaynak seçimlerinin kalıcılığı, filtreler, görünüm dışındaki seçimler, son inceleme, video, 3.000 öğelik stres görünümü, dört dil, en büyük yazı, Almanca/Fransızca görüntüler dahil. |
| Son 185 Mac çalışması | **39/39 geçti**: 33 native + 6 işlevsel UI; skip/hata yok. Son kaynakla optimize native set ayrıca **33/33** geçti. |
| Son 185 iPhone çalışması | **64/64 geçti**: 33 native + 31 UI; skip/hata yok. Yeni koruma → açıkça korumayı kaldırıp seçme → undo akışı gerçek UI üzerinden geçti. |
| Küçük ekran / koyu tema | iOS 26.5, 6.3 inç simülatörde **4/4 geçti**. Normal/en büyük Türkçe yazı ve seçim hedefleri, koruma akışı, Ayarlar/Pro kapatma ve geniş Geçmiş başlığı dahil. Simülatörün açık tema ve kapalı durum ayarları test sonrasında geri verildi. |

İlk geniş 30/6 UI çalışması bu turdaki değişikliklerden **önceki** 184 kaynaklarıyla başlatıldı; tablodaki son 185 sonuçları güncel kaynakla tekrar çalıştırıldı. Görsel fixture'lar gerçek kişisel fotoğraflar değildir; ekran görüntüsünde başarı metni görünmesi gerçek satın alma veya fiziksel dosya işlemi kanıtı sayılmaz.

Tam `release_gate_on_mac.sh` bu turda tek komutla baştan sona çalıştırılmadı. Paket kapısı, native/UI testleri, Analyze, archive ve export bileşenleri ayrı doğrulandı; isteğe bağlı büyük benchmark yeniden çalıştırılmadı. `destination=upload` engeli gerçek yayın betiği üzerinde olumsuz senaryoyla test edildi; betik build/export aşamasına geçmeden durdu.

## Tam erişilebilirlik tanısı

Apple'ın [`performAccessibilityAudit`](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit%28for%3A_%3A%29) API'si `.all` kapsamıyla Mac arşiv/son inceleme ve iPhone arşiv/son inceleme/Geçmiş/Ayarlar/Pro ekranlarında çalıştırıldı. Tanı, başarısızlıkları ve ekran eklerini saklar; hiçbir issue handler uyarıyı başarılı diye bastırmaz.

İlk çalışmada kontrast, Dynamic Type, küçük etkileşim alanı, etiket ve Mac yerel menü/grup/Touch Bar yapısı uyarıları çıktı. Bunlar otomatik kontrol bulgularıdır. Bir kısmı görünür ürün kusuruna karşılık gelir; sistem konteynerleri, dim edilen arka pencere ve element veremeyen görsel uyarılar için tek tek elle doğrulama gerekir. Yukarıdaki somut kontrast/etiket kusurları düzeltildi. Kalan tanılar temizlenmeden tam erişilebilirlik kabulü tamamlandı denmez.

Son iPhone 185 tanısı **54 uyarı örneği** verdi: 9 küçük alan, 17 kontrast, 2 sınırda kontrast, 4 metin kesilmesi, 22 Dynamic Type. İlk tanıda 78 örnek vardı. Bunlar 54 ayrı doğrulanmış ürün hatası değildir; tekrarlanan/sistem kaynaklı örnekler ayıklanmadı. Mac son tanısında 34 örnek kaldı; 16 grup açıklaması, 7 yerel menü eylemi, 2 parent/child ve 9 kontrast uyarısı var. Mac tanısından sonra çalışma alanının konteyner etiketi düzeltildi; Mac'in tam tanısı bu son semantik değişiklikle tekrar çalıştırılmış sayılmadı. **Tam tanı testleri başarısızdır; yeşil diye sunulmaz.**

Tam tanı ayrı ve açıkça çağrılan bir kabul testidir. Normal işlev testleriyle karıştırılmaz. Çalıştırmak için `xcodebuild` komutundan önce `TEST_RUNNER_KEPTORA_ACCESSIBILITY_AUDIT=1` verilir; hedefler `testAccessibilityAuditLibraryAndRemovalReview` ve iPhone'da ayrıca `testAccessibilityAuditHistorySettingsAndPro`. Bayrak verilmezse tanı testleri **skip** olur; geçmiş başarısız sonuçlar geçersiz sayılmaz.

## Kaynak incelemesinin diğer alanları

Fotoğraflar silme onayı ve revizyon denetimi, kısmi işlem uzlaştırması, kurtarma manifesti, yol sınırları/symlink denetimi, üzerine yazmama, kaynak izinleri/bookmark ömrü, iptal/arka plan, StoreKit doğrulama ve restore, fiyat/metin kapsamı, diagnostic gizliliği ve privacy manifesti incelendi. Diagnostic çıktısı fotoğraf/dosya adlarını veya yollarını içermez; yalnız sayılar ve uygulama durumu taşır. Bu inceleme bütün olası disk/provider/zamanlama kombinasyonlarının kanıtı değildir.

Apple'ın [geri alma HIG'i](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo) ve [In-App Purchase HIG'i](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase), mevcut kararların değerlendirilmesinde referans alındı. Uygulama bu belgelere bakıldığı için Apple tarafından onaylanmış sayılmaz.

## Tamamlanmamış kabul alanları

- Tam erişilebilirlik tanısındaki kalan uyarıların insan tarafından doğrulanması ve gerçek VoiceOver gezinmesi.
- Fiziksel iPhone son kontrolde `unavailable`. Gerçek cihazda Fotoğraflar silme/Son Silinenler, sınırlı erişim ve iCloud davranışı doğrulanmadı.
- Gerçek App Store sandbox satın alma/restore ve iPhone–Mac hak paylaşımı; yerel StoreKitTest bunun yerine geçmez.
- Desteklenen en düşük macOS 13/iOS 17, fiziksel Intel Mac, gerçek disk dolması, disk çıkarma ve üçüncü taraf File Provider kabulü.
- Önceki canlı denetimde başvuruda 183 vardı; bu turda mağazanın inceleme durumu yenilenmedi. Yeni yerel paket hazır olsa bile Apple incelemesi ve canlı dağıtım ayrıca değerlendirilir. Otomatik yayın tercihi değiştirilmedi; GitHub push veya mağaza yüklemesi yapılmadı.

Kanıt kökü: `ValidationArtifacts/Mac/ProfessionalQA-20261018/`. Önceki başarısız regresyonlar, geçen sonuçlar, tam erişilebilirlik tanıları ve ekran ekleri birlikte tutulur.
