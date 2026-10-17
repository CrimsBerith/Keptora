# Keptora yayın hazırlık denetimi — 17 Ekim 2026

Sonuç: %100 hazır olduğu doğrulanmadı. iPhone, Mac ve Pro ürünü Apple inceleme kuyruğunda; yerel yayın/test zincirinde yeniden üretilen açıklar var. Aşağıdaki bulguların tümü üretim uygulamasının çöktüğü anlamına gelmez: ürün davranışı, test yapılandırması, dağıtım ve kabul kanıtları ayrı değerlendirilmiştir.

## Denetlenen durum

- Depo: `CrimsBerith/Keptora`; dal: `main`; HEAD: `c0df35a7644519d5f0325154ef2e2e9920525dcf`.
- `git fetch origin --prune` sonrası yerel HEAD ve `origin/main` farkı: `0 / 0`.
- Başlangıçta 14 değiştirilmiş takipli dosya ve 9 takip edilmeyen ekran görüntüsü vardı. Bunlar korunmuştur; uygulama kodunda düzeltme, commit, push, başvuru veya yayın değişikliği yapılmamıştır.
- Xcode 26.6 (`17F113`), macOS 26.5.2 (`25F84`); iOS 26.5 simülatörü.
- Ayrıntılı komut çıktıları ve xcresult dosyaları: `/tmp/keptora-audit-20261017/`. Bu geçici klasör kalıcı arşiv değildir.

## Yeniden üretilen bulgular

### R01 — P1: Mac Debug mimari ayarları paketle uyuşmuyor

`Keptora.xcodeproj/project.pbxproj:1023` uygulamayı `$(ARCHS_STANDARD)` ile, `:1043` ise `ONLY_ACTIVE_ARCH=NO` ile derliyor. Debug paket bağımlılığı bu Mac'te yalnız arm64 üretilirken uygulamanın x86_64 derlemesi de isteniyor. Varsayılan Debug UI test derlemesi `AccessPolicy.swift:2` içindeki `import KeptoraCore` satırında durdu. Derleyici arm64 modülünü x86_64 için uyumsuz bildirdi.

`project.yml:57` hâlâ `ARCHS: arm64` diyor; kaynak proje tanımı ile Xcode projesi de farklı. Düzeltme, desteklenen mimarileri iki dosyada ve paket bağımlılıklarında tutarlı yapmak. Bu denetimde kaynak değiştirilmeden `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` komut seçenekleriyle test çalıştırma aşamasına geçildi. Bu seçenekler kalıcı düzeltme sayılmaz.

Kanıt: `mac-ui.log`, `mac-ui.xcresult`, `mac-ui-arm64.log`.

### R02 — P1: iPhone Release testleri mevcut yapılandırmayla derlenmiyor

`Scripts/release_gate_on_mac.sh:37` Release test istiyor. `KeptoraiOS` Release için etkin `ENABLE_TESTABILITY=NO`; testler `@testable import KeptoraiOS` kullanıyor. İlk çalıştırma `module built without '-enable-testing'` tanısıyla durdu.

Yalnız komut satırında `ENABLE_TESTABILITY=YES` verilerek ikinci engel de doğrulandı: `MobileKeptoraStore.swift:78` altındaki `replaceAssetsForTesting` ve `replaceSimilarityGroupsForTesting` yardımcıları `#if DEBUG` içinde, Release'te ise bunları çağıran testler derleniyor. Sonuç `has no member` hataları. Yalnız testability ayarını açmak yeterli değil. Test hedefi/yardımcıları ve yayın kontrolü birlikte düzenlenmeli; Release'e DEBUG tanımlayıp sonucu gerçek Release kanıtı saymak doğru olmaz.

Kanıt: `ios-test.log`, `ios-tests.xcresult`, `ios-release-testable.log`, `ios-release-testable.xcresult`.

### R03 — P1: Tam yayın betiği eski dosyalara bağlı ve başta duruyor

`rtk bash Scripts/validate_package.sh` exit 1 verdi. `Scripts/validate_package.sh:56`, eski `validate_phase5s_static.py` denetimini çağırıyor; bu betik kaldırılmış `Keptora/Core/Models/CleanupModels.swift` dosyasını okumaya çalışıyor. Aynı eski denetim kaldırılmış başka sınıflara ve build 182'ye de bağlı. `release_gate_on_mac.sh:11` bu kapıdan geçemiyor.

Ayrıca yerel `Scripts/validate_universal_release.py` çalıştırılabilir değil; yayın betiği `:12` bunu doğrudan çalıştırıyor. `python3 Scripts/validate_universal_release.py` geçse bile doğrudan çağrı düzeltilmeden sonraki aşamaya geçilemez. Tam yayın kapısı bu denetimde archive/export adımlarına kadar yürütülmedi; mevcut arşivler silinmedi.

Kanıt: `package-gate.log`; `test -x Scripts/validate_universal_release.py` sonucu 1.

### R04 — P2: iPhone bozuk kurtarma kayıtlarının uyarılarını kaybediyor

`KeptoraiOS/App/MobileKeptoraStore.swift:643` yalnız `recoveryRecords(root:)` çağırıyor. `FolderQuarantineExecutor.swift:115` bu API'de `recoveryCatalogue(...).records` döndürüp `.issues` listesini atıyor. Bozuk veya güvenli olmayan bir manifest bu nedenle iPhone tarafında uyarı olarak taşınmıyor. Mac tarafı `MacArchiveModel.swift:624` ile tam kataloğu alıp sorunları kullanıcıya taşıyor.

Örnek: tercihler kaybolduktan sonra bir klasörü yeniden bağlama; klasörde sağlıklı ve bozuk kurtarma manifestleri birlikte var. Sağlıklı kayıt görünür, bozuk kayda ait kurtarma dosyaları diskte kalsa da kullanıcı o kaydın bulunamadığını öğrenmez. Bu bulgu dosyaların silindiği veya otomatik üzerine yazıldığı anlamına gelmez. iPhone, sağlıklı kayıtlarla birlikte katalog sorunlarını da göstermeli.

Kanıt: kaynak veri akışı ve geçen `testRecoveryCatalogueKeepsHealthyRecordsBesideCorruptAndUnsafeManifests`. Bozuk manifest senaryosu bu denetimde iPhone UI üzerinden ayrıca çalıştırılmadı.

### R05 — P2: Canlı web metinleri iPhone sürümüyle güncel değil

Üç URL de yönlendirme sonrası HTTPS 200 verdi:

- <https://alfagolab.com/keptora/>
- <https://alfagolab.com/keptora/privacy/>
- <https://alfagolab.com/keptora/support/>

Ancak pazarlama/destek hâlâ `macOS 13+` diyor; canlı gizlilik politikası 13 Ağustos 2026 tarihli ve işlemenin yalnız Mac'te yapıldığını anlatıyor. iPhone, Apple Photos, sınırlı erişim ve iCloud silme/kurtarma koşullarıyla güncel kapsam açıkça anlatılmıyor. Yerel `AppStore/PRIVACY_POLICY.md` güncellemesi canlı sayfaya yansımamış. Bu bir içerik tutarlılığı bulgusudur; Apple'ın kesin ret vereceği iddia edilmez.

Kanıt: `public-pages.json` içindeki bu denetimde indirilen metinler.

### R06 — P2: Yayın modu yerel kayıtla canlı mağazada farklı

`AppStore/app_store_metadata.json:6` yayın modunu `manual` tutuyor. Yenilenmiş canlı iOS sürüm sayfasında `Automatically release this version` seçili. Onaydan sonra otomatik yayın amaçlanıyorsa yerel kayıt güncellenmeli; manuel yayın amaçlanıyorsa canlı ayar ayrıca düzeltilmeli. Bu denetimde mağaza ayarı değiştirilmedi.

### R07 — P2: Build 183 değişiklikleri yeniden üretilebilir bir Git revizyonuna bağlanmamış

GitHub'daki son main kontrolü build 182 içeren `c0df35a` revizyonunda yeşil. Yerel build 183, mimari, imza, StoreKit fiyat, çoğul çeviri, test ve mağaza değişiklikleri commit edilmemiş durumda. GitHub CI bu yerel farkların kanıtı değil. Onaylanan dağıtımın kaynak/konfigürasyon eşlemesi için bu durum kapatılmalı.

## Geçen kontroller

| Kontrol | Bu denetimdeki sonuç |
|---|---|
| Ortak Apple çekirdeği | 127 test keşfedildi; ilk çalıştırmada 126 geçti, isteğe bağlı benchmark atlandı. Benchmark ayrıca çalıştırılıp geçti. Hata yok. |
| Mac Release | Apple Development ile aynı kimlikte imzalanan uygulama/test paketiyle 32 test geçti; 6 yerel StoreKit yükleme/satın alma/restore testi dahil. |
| Mac Release mimarileri | Yerel derlenen uygulama `x86_64 arm64`; bu gerçek Intel Mac üzerinde çalışma kanıtı değildir. |
| iPhone Debug | 28 birim testi ve 4 UI testi geçti. PhotoKit taraması simülatördeki gerçek medya girdileriyle çalıştı. |
| iPhone UI kapsamı | Son inceleme/seçim geri alma, dört dilde ana etiketler, standart/büyük erişilebilirlik yazısında dokunma hedefleri, Ayarlar → Pro → kapatma. |
| iPhone Release Analyze | `ANALYZE SUCCEEDED`. `MobileKeptoraStore.swift:619` explicit-self ve TipKit makro Sendable uyarıları var. Proje Swift 5 modunda; bunlar mevcut derlemeyi durdurmuyor, Swift 6 geçişi için açık iş. |
| Mac Release Analyze | arm64 için `ANALYZE SUCCEEDED`; yalnız AppIntents metadata extraction bilgilendirme uyarısı. |
| Güncel Mac UI | Varsayılan Debug derlemesi R01 nedeniyle durdu. arm64 seçenekleriyle derleme tamamlandı; Apple Development ve ardından CI ile aynı ad-hoc imzalı runner denemelerinde testler başlayamadı. Başlangıçta yaklaşık iki dakikalık beklemeler sonrası denemeler durduruldu; 6 hedeflenen UI testi geçti sayılmadı. |
| Statik doğrulama | Xcode referansları, fotoğraf temizleyici varlıkları, yeniden üretilen görseller, Mac yerelleştirme, mağaza metadata ve güncel universal kaynak sözleşmesi geçti. |
| Görsel varlık doğrulaması | İzole geçici Python ortamında Pillow ile 67 kayıt doğrulandı: 54 varlık, 12 yalnız tasarım önizlemesi, 1 kasıtlı bozuk fixture. Tasarım önizlemeleri mağaza onayı sayılmadı. |
| GitHub CI | 14 Ekim 2026 main koşusu: portable-core, native-mac, native-ios, native-storekit, visual-assets başarılı. Büyük benchmark adımı bu CI koşusunda atlanmış. Açık PR yok. |

CI: <https://github.com/CrimsBerith/Keptora/actions/runs/38620018670>.

Yerel StoreKitTest başarıları Apple sandbox/üretim satışı veya iPhone-Mac çapraz satın alma kanıtı değildir. İlk Mac Release denemesinde ad-hoc imzalı test paketi library validation tarafından yüklenemedi; aynı kimlikte Apple Development imzalama seçenekleriyle tekrar çalıştırma geçti. Bu test düzeni sorunu üretim uygulaması çökmesi diye sayılmadı.

Bu turdaki büyük yazılı Türkçe son inceleme eki, 6.3 inç Türkçe mağaza son inceleme görüntüsü ve 6.9 inç Pro görüntüsü ayrıca açılıp gözle incelendi. Ana eylemler görünür. Büyük yazıda yüklenemeyen önizlemenin küçük hücre içindeki açıklaması kesiliyor; `MobileAssetThumbnail.swift:41` içeriği kırpıyor. Bu küçük görsel kusur için ayrıntılı hata açıklaması küçük thumbnail dışına alınmalı. Bütün ekran/dil/tema/VoiceOver matrisi tamamlandı diye sayılmadı. Güncel test ekleri: `ios-attachments/`.

## Ölçümün kapsamı

3.000 üretilmiş 320×240 JPEG, her grupta 10 birebir kopya:

- 300 birebir grup; soğuk geçişte 3.000 SHA-256, 3.000 önizleme decode ve 3.000 Vision feature print.
- Soğuk toplam: 93,80 sn; ilk katalog: 0,23 sn; ilk grup: 4,65 sn.
- Sıcak toplam: 4,24 sn; 3.000 cache hit; yeniden hash/decode/feature print yok.
- Sürecin peak RSS ölçümü: 415.318.016 bayt, yaklaşık 396 MiB.

Kaynak: `benchmark.json`. Ölçüm sırasında başka Xcode derlemeleri de çalışıyordu. Bu bir izole performans karşılaştırması, gerçek 3.000 HEIC/RAW/video arşivi, iPhone bellek sınırı, UI FPS veya doğruluk kalibrasyonu değildir.

## Canlı dağıtım durumu

Safari App Store Connect oturumu sunucudan yenilenerek kontrol edildi; eski açık sekme durumları kullanılmadı.

| Kayıt | Canlı durum |
|---|---|
| iOS 1.0 | `Waiting for Review`; seçili build `1.0.0 (183)`; 17 Ekim başvurusu, 2 öğe. |
| macOS 1.0 | `Waiting for Review`; seçili build `1.0.0 (183)`; 15 Ekim başvurusu, 1 öğe. |
| Pro Lifetime | `com.keptora.app.pro.lifetime`, Non-Consumable, `Waiting for Review`. |
| iOS TestFlight build 183 | `Ready to Submit`; görünen davet, kurulum, oturum ve çökme alanları `–`. |
| macOS TestFlight build 183 | `Ready to Submit`; görünen davet, kurulum, oturum ve çökme alanları `–`. |

TestFlight tablosundaki `Ready to Submit` beta durumudur; App Store incelemesine gönderilmedi anlamına gelmez. `–` alanları sıfır çökme veya fiziksel cihaz testi tamamlandı kanıtı değildir.

Mac başvurusunda Apple'ın önceki Guideline 2.1 bilgi/fiziksel cihaz kayıt isteği ve 15 Ekim yanıtı görüldü; iki mesaj var. Bu denetim fiziksel kayıt dosyasının gerçekten mevcut ve yeterli olduğunu doğrulamadı.

- Dağıtım: <https://appstoreconnect.apple.com/apps/6815902595/distribution>
- Mac başvurusu: <https://appstoreconnect.apple.com/apps/6815902595/distribution/reviewsubmissions/details/74277b1f-7681-47a9-83b9-813ef9da9312>
- IAP: <https://appstoreconnect.apple.com/apps/6815902595/distribution/iaps>

## Kapanmamış kabul alanları

- Fiziksel iPhone `xctrace` listesinde offline. Bu turda cihazda silme/Son Silinenler'den geri alma, gerçek IAP/sandbox restore veya iCloud/sınırlı erişim testi yapılmadı.
- Desteklenen en düşük macOS 13 ve iOS 17 üzerinde çalışma, gerçek Intel Mac, VoiceOver kullanımı, disk-full/harici disk çıkarma/üçüncü taraf File Provider kesintisi doğrulanmadı.
- Güncel Mac UI testleri runner başlangıcında takıldı. Otomasyon/runner bağlantısının kesin kök nedeni bu denetimde çözülemedi. İptal edilen ilk denemenin xcresult kapanışı da Xcode tarafından kaydedilemedi (`log hasn't finished recording after waiting 30 seconds`). Kayıtlar `mac-ui-arm64.log` ve `mac-ui-adhoc.log` içinde. Bu durum uygulamanın iş akışında gözlenmiş bir çökme diye sayılmadı; GitHub'ın eski yeşil UI sonucu güncel yerel kabulün yerine kullanılmadı.
- App Store ve IAP onayı henüz yok; iki uygulama sürümü ve Pro ürünü inceleme kuyruğunda.

Kapatma sırası: R04 kurtarma uyarısı → R01–R03 tekrarlanabilir build/test/yayın zinciri → R05–R07 içerik ve sürüm eşlemesi → fiziksel cihaz ve sandbox kabulü → Apple inceleme sonucu.
