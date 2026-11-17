# App Store Hazırlık Planı — Keptora macOS + iOS

**Durum:** Plan onaylandı — yerel düzeltmeler ve odaklı simulator doğrulamaları geçti; fiziksel cihaz/ASC kabulü açık  
**Hedef:** Her iki platform için App Store sürümü  
**Kabul ortamı:** Kullanıcı yalnız simulator erişimi bildirdi  
**Minimum mobil performans sınıfı:** iPhone 11 düzeyi (60 Hz)  
**Plan tarihi:** 2026-11-16
**Revizyon:** 3 — file-backed scan ve tarama sırasında gallery projection concurrency kanıtı eklendi.

## “%100 hazır” ölçütü

Mutlak “hatasız” veya her koşulda sıfır frame hitch garantisi verilemez. Bu planın hedefi: bilinen P0/P1 yok, kritik kullanıcı akışlarının her biri aynı release commit’inde kanıtlı, performans iddiaları ölçülü, kalan riskler açıkça kabul edilmiş olsun. “Kasmama” için önerilen doğrulanabilir hedef: iPhone 11’de 50K öğe gallery senaryosunda, **tarama sürerken kullanıcı etkileşimi de devam ederken**, p95 frame süresi ≤16.7 ms, 100 ms’den uzun hitch yok; tap/selection görünür geri bildirimi p95 ≤100 ms; memory warning/jetsam yok. Arama/filtre sonuç süresi ayrıca ölçülüp ilk baseline’dan sonra eşik onaylanır. Kanıtlanmamış fiziksel cihaz veya App Store Connect adımı `PASS` değil, `UNVERIFIED` kalır.

**Mevcut ön karar: NO-GO / UNVERIFIED.** 2026-11-16 önceki yerel doğrulamada Core 142 test (1 benchmark skip), macOS 37 test, iOS 5 odaklı regresyon testi geçti; macOS/iOS Debug test-build ve beş release/localization validator’ı geçti. Revizyon 2–3 simulator kanıtları aşağıda kaydedildi. Fiziksel cihaz performans kabulü, gerçek Photos/iCloud, Release archive, StoreKit sandbox ve App Store Connect kanıtı yok. Bu, uygulamanın kesin bozuk olduğunu değil, App Store’a hazır olduğunun henüz kanıtlanmadığını ifade eder.

## Hedef ve kapsam

**Hedef:** macOS ve iOS’ta izin, tarama, inceleme, kullanıcı seçimi, onay, geri alma/kurtarma, satın alma ve destek akışları veriyi koruyarak çalışsın; build, test, privacy ve release kanıtları aynı aday sürüme bağlansın.

**Dahil**
- Mevcut uncommitted kodun ve doğrudan bağlı akışların tam denetimi; ayrıca release blocker/checklist’teki her maddeyi güncel kanıtla yeniden sınıflandırma.
- KeptoraCore, macOS, iOS, Photos/Files/iCloud, StoreKit, erişilebilirlik/yerelleştirme, performans, CI ve App Store submission hazırlığı.
- Güvenli test planı, ölçüm planı, insan/cihaz bağımlılıkları ve uygulanabilir çok-agent sıralaması.

**Hariç**
- Bu turda kod düzeltmesi, build/test çalıştırma, commit/push veya release.
- Gerçek kullanıcı arşivinde yıkıcı işlem veya destructive stress test.
- Kullanıcının onayı olmadan App Store Connect, satın alma, sözleşme, fiyat, yayın veya hesap değişikliği.
- Kanıtlanmamış büyük refactor ve yeni özellik.

## Mevcut kanıt ve önemli sınırlamalar

- `main`/`origin/main` HEAD `bb96ab8`; başlangıçta 34 takipli dosya değişmiş ve birden fazla untracked dosya/rapor vardı. Bunlar kullanıcı değişikliği; korunmalı. İnceleme raporları mevcut dirty worktree’ye aittir.
- [GitHub Actions run 43616844843](https://github.com/CrimsBerith/Keptora/actions/runs/43616844843), 14 Kasım’da yalnız committed `bb96ab8` için başarısızdı: `portable-core` `BurstSequenceGroup` bulamadı; `native-mac` ve `native-storekit` macOS target uyuşmazlığı yaşadı (app 11, Core 13); `native-ios` `MobileArchiveView.swift:1495` type-check timeout’uyla durdu. Dirty worktree’de tekrar üretmeden bunları mevcut kodun kesin hatası saymayacağız.
- Release agent’in dirty worktree’de salt-okunur çalıştırdığı validator’lar `validate_universal_release.py` için 48 hata, `validate_mac_localization.py` için üç dilde eksik “Updating gallery…” bildirdi; Store metadata validator’ı geçti. Güncel snapshot’ta yeniden çalıştırılıp tek tek sınıflandırılmalı.
- Sürüm/build kayıtları uyuşmuyor: bazı yerler `1.0.3 (189)`, checklist’ler `1.0.0 (181/182)` diyor. Doğru aday App Store Connect ile eşleştirilmeden arşiv alınmamalı.
- Eski readiness raporları farklı commit/SHA için “pass” diyor. Güncel snapshot’ın kanıtı değildir. [Release blocker listesi](../../Docs/RELEASE_BLOCKERS.md), [submission checklist](../../AppStore/SUBMISSION_CHECKLIST.md), [Docs checklist](../../Docs/APP_STORE_RELEASE_CHECKLIST.md), [privacy answers](../../AppStore/APP_PRIVACY_ANSWERS.md) ve ilgili raporlar satır satır güncel durumla uzlaştırılmalı.
- Üç önceki alan incelemesi ve beş geniş kapsamlı salt-okunur uzman incelemesi tamamlandı. Hiçbiri bu turda kod değiştirmedi veya test çalıştırmadı; aday bulgular aşağıda “yeniden üretilecek” olarak ele alınıyor.
- [Galeri performans raporu](../../reports/Keptora%20Galeri%20Performans%20Optimizasyonu.md) sentetik 50K builder testinde önceki ölçümlere göre iOS ~%83, macOS ~%56 süre azalması rapor ediyor. Bu yalnız projection builder ölçümü; gerçek tarama, yeni UIKit grid snapshot/diff, FPS/hitch, iCloud, gerçek cihaz veya uçtan uca etkileşim kanıtı değil.
- GitHub’da ilgili açık takip işleri: [#2](https://github.com/CrimsBerith/Keptora/issues/2), [#14](https://github.com/CrimsBerith/Keptora/issues/14), [#15](https://github.com/CrimsBerith/Keptora/issues/15), [#17](https://github.com/CrimsBerith/Keptora/issues/17), [#18](https://github.com/CrimsBerith/Keptora/issues/18). Önce mevcut issue’larla eşleştir; duplicate açma.

## Kullanıcı güvenliği değişmezleri

- Kesin kopya yalnız tam içerik hash’iyle kanıtlanır; perceptual/preview hash yalnız aday eleme aracıdır.
- Manuel seçim ve kullanıcı onayı, önerili/bulk kurallardan ayrı kalır. Favori/keeper/protected öğeler ve manuel benzersiz seçim davranışı korunur.
- Photos işlemi Apple sistem onayını ve Recently Deleted akışını izler. Files recovery aynı depolamada geri alınabilir taşıma olabilir; boş alan açtığı söylenmez.
- Restore manifest/route kaybolamaz; orijinal üzerine yazma, çift/eksik kopya belirsizliği otomatik yıkıcı çözülmez.
- Photos/EXIF/GPS/path/source identity kullanıcı cihazında kalır; gerçek medya üçüncü tarafa gönderilmez. “No upload” iddiası archive/SDK/privacy kanıtından ayrı doğrulanır.
- iCloud/provider indirmesi yalnız açık, görünür kullanıcı kararıyla yapılır. Özel WhatsApp sandbox erişimi vaat edilmez.
- Manuel seçim, temel güvenlik ve restore ödeme duvarına alınmaz; lifetime Pro entitlement atomik ve tutarlı olmalı; yeni abonelik eklenmez.
- Testler sentetik veya açıkça izinli fixture kullanır. Fiziksel cihaz, mağaza, gerçek izin ve gerçek medya testleri için insan onayı gerekir.

## İlk denetim bulguları — tarihsel kayıt; güncel durum aşağıda

### P0 — Release kapıları

1. **Güncel snapshot build/test/validator durumu belirsiz.** Önceki GitHub failures committed `bb96ab8` için; mevcut local diff aynı değil. CI compile/typecheck hataları ve 48 localization validation bulgusu güncel worktree’de tekrar çalıştırılıp kök nedenleriyle raporlanmalı.
2. **Target/version drift.** XcodeGen, pbxproj, package minimum deployment targets, scheme configurations ve release metadata tek aday ayarına getirilmeli. CI gerçek committed project’i derlemeli; yalnız project generator sonucu varsayılmamalı.
3. **Release kanıtı eksik veya eski.** App Store Connect, hukuk/hesap bilgileri, ürün/fiyat, privacy/SDK manifest, imza/archive, screenshots ve review notları için sahip/onay ve güncel kanıt belli değil.

### P1 — Kullanıcı verisi, izin ve doğruluk

4. **iOS Swipe Clean cloud-only içeriği onaysız indirebilir.** Kart/thumbnail yolunda `allowNetwork: true`; açık “Download and Scan” akışından ayrı. Simulator’da sentetik cloud-only varlıkla doğrula, kullanıcı onayı olmadan network/download olmamasını şart koş.  
   Kanıt: `KeptoraiOS/UI/MobileSwipeCleanView.swift:228-234`; `MobileAssetThumbnail.swift:80-86,140-145`; karşılaştırma `MobileArchiveView.swift:598`.
5. **iOS tarih gruplarında tekrarlanan block ID asset kaybettirebilir.** Ocak–Şubat–Ocak fixture’ını collection aşamasına kadar çalıştır; üç bölümün tüm ID’leri bir kez görünsün.  
   Kanıt: `MobileArchiveView.swift:679-712`; `MobileGalleryCollectionView.swift:186-189`; fixture `KeptoraiOSTests/GalleryPerformanceTests.swift:91-125`.
6. **macOS önerileri seçme no-op’i free review allowance tüketebilir.** Unhealthy/terminating session’da model seçim reddetmeden önce authorization çağırıyor olabilir. Model guard ve UI disable birlikte test edilmeli; reddedilen işlem allowance’ı değiştirmemeli.  
   Kanıt: `MacArchiveView.swift:869-878`; `MacArchiveModel.swift:383-408`.
7. **Exact grouping preview pruning false negative üretebilir.** Farklı edit/Live Photo preview’ları aynı original resource ailesinin tam-hash eşleşmesini engelleyebilir. İzinli fixture’da prefilter/full fingerprint sonuçları kıyasla; kanıtlanırsa pruning’i daralt.  
   Kanıt: `Packages/KeptoraCore/Sources/KeptoraCore/ExactGrouping.swift:256-260,320-345`; `PhotoLibrarySourceAdapter.swift:265-280,461-487,630-642`.
8. **iOS Photos cleanup history işlemin ardından kalıcılaştırılıyor.** Termination aralığında uygulama içi receipt/history eksik kalabilir; bu fotoğraf kaybı kanıtı değildir. Fake adapter ile işlem/çökme/yeniden başlatma sınırını test et; sistem Recently Deleted akışını koru.  
   Kanıt: `MobileKeptoraStore.swift:1188,1196-1209,1344-1346`; Mac karşılaştırması `MacArchiveModel.swift:939-941`.

### Yerel uygulama durumu (release kabulü değildir)

| İlk bulgu | Yerel durum | Regresyon kanıtı | Açık kabul |
|---|---|---|---|
| #4 Swipe Clean thumbnail cloud download | Düzeltildi | `testSwipeDeckThumbnailDoesNotRequestNetworkDownloads` geçti. | Gerçek iCloud/File Provider davranışı. |
| #5 yinelenen tarih-section kimliği | Düzeltildi | `testGallerySectionsPreserveNoncontiguousMonthOrder`, `testRepeatedDateGroupsHaveStableUniqueIdentity` geçti. | Fiziksel cihaz galeri performansı. |
| #6 busy macOS seçim no-op’i | Düzeltildi | `testRecommendationSelectionBlockedByBusyModelDoesNotConsumeTrialAllowance` geçti. | Ayrı UI erişilebilirlik kabulü. |
| #7 exact grouping preview pruning | Düzeltildi; tam fingerprint kullanılıyor. | `testImageCandidatesUseFullFingerprintsAndOnlyMatchingDigestsGroup` geçti. | Fiziksel kütüphanede full-hash maliyeti. |
| #8 Photos cleanup history dayanıklılığı | Düzeltildi; silme öncesi `.planned`, sonuçta `.moved`/`.failed`, kullanıcı iptalinde receipt kaldırılıyor. | İki fake-adapter history testi geçti. | Force-termination ve gerçek PhotoKit kabulü. |
| İlk localization validator bulguları | Düzeltildi. | Universal ve Mac localization validator’ları geçti. | İnsan dil/erişilebilirlik incelemesi. |

### P2 — Kaynak kimliği, state ve kullanıcıya verilen söz

9. **Tamamlandı:** `PhotoLibrarySourceAdapter` albüm üyelik cache TTL'i 120s'den 15s'ye indirildi; `invalidateAlbumMembershipCache()` API'si eklendi. `MobileKeptoraStore` içinde `photoLibraryDidChange` tetiklendiğinde albüm cache'i anında temizlenerek stale üyelik riski giderildi. `LibraryWorkflowTests.testPhotoLibrarySourceAdapterAlbumCacheInvalidation` ile doğrulandı. `PhotoLibrarySourceAdapter.swift:129-139,161`; `MobileKeptoraStore.swift:888`.
10. **Tamamlandı:** ID sabitken asset revision değişince thumbnail yenilenmiyordu; `MobileGalleryAssetCell` revision/changeToken içeren `representedThumbnailKey` takibi ile güncellendi. `testCellReloadsThumbnailWhenAssetRevisionChangesWithSameID` ile RED ve GREEN kanıtlandı. `MobileGalleryCollectionView.swift:462,605-625,673-685`, `ThumbnailCacheTests.swift:39-84`.
11. Folder source identity fallback’i canonical path’e düşebilir; aynı path’te değiştirilen disk/provider’ı eski kaynak saymama kontrolü gerekli. `LibrarySessionInfrastructure.swift:88-115`; `FolderSourceAdapter.swift:25-28`.
12. **Tamamlandı:** enumeration symlink’leri atlıyor; tarama sonrasında enumerated file dış-root symlink ile değiştirilirse fingerprint erişimi canonical-root containment kontrolünde reddediliyor. `FolderSourceAdapterPathSafetyTests.testEnumerationSkipsSymlinksAndAccessRejectsLateEscape` sentetik geçici dosyalarla geçti. Aynı kontrol ile `exactFingerprint` dosyayı açmadan önce root containment doğruluyor. Eşzamanlı path swap TOCTOU riski root-relative/no-follow erişim gerektirdiğinden açık.
13. PhotoKit cache’inde identifier/filename/modification/adjustment metadata izin iptalinden sonra yerelde kalabilir. Bu upload kanıtı değil; retention/purge politikasını ürün/privacy cevabıyla eşleştir. `PhotoLibrarySourceAdapter.swift:94-124`; `MobileKeptoraStore.swift:420-438`.
14. iOS file swipe karantina davranışında açık confirm bulunmuyor. Swipe’ın ürün sözleşmesindeki yeterli onay olup olmadığını owner kararıyla doğrula; iptal varsa dosya byte’ları değişmeden kalmalı. Bug varsayma. `MobileSwipeCleanView.swift:390-400`; bulk confirm `MobileArchiveView.swift:1709-1720`.
15. **Tamamlandı:** `MobileOnboardingView.swift:63`'teki yanıltıcı “Recoverable Anytime” ifadesi, sistem Photos Recently Deleted (30 gün) ve klasör kurtarma prensibiyle uyumlu “Recently Deleted & Recovery” olarak güncellendi; EN/TR/DE/FR katalog çevirileri eklendi.
16. **Tamamlandı:** `skippedCloudItems` ve `skippedSimilarityPreviews` için tekil/çoğul şablonları (`L10n.plural`) ve `Localizable.xcstrings` çoğul varyasyonları (one/other) EN, TR, DE, FR dillerinde uygulandı. `PluralLocalizationTests` içinde `testSkippedOriginalsCountUsesSingularAndPlural` ve `testSkippedPreviewsCountUsesSingularAndPlural` ile RED ve GREEN kanıtlandı. `MobileArchiveView.swift:1292,1996`; `MacArchiveView.swift:422,425`; `Localizable.xcstrings`.
17. **Tamamlandı:** iOS 27 iPhone 11 Simulator’da opt-in `testAccessibilityAuditLibraryAndRemovalReview` ve `testAccessibilityAuditHistorySettingsAndPro` çalıştırıldı. Hit-area, contrast, Dynamic Type ve synthetic bridge düzeltmeleri sonrası her iki UI testi de PASS (2 test, 0 failure). Limited Photos UI, izin değişikliği sonrası refresh ve Mac/manual VoiceOver acceptance açık. UI testi `KeptoraiOSUITests.swift:16-64`, Mac `KeptoraUITests.swift:9-27`.
18. File Provider/iCloud placeholder network davranışı, offline/online, izin revoke/regrant ve source-volume reconnect fiziksel/provider düzeyinde `UNVERIFIED`.

## Performans incelemesi ve ölçüm planı

- Yeni iOS grid, projection sonrası main actor’da full diffable snapshot ve asset dictionary kuruyor; uzun taramada 1.5 sn coalesced analysis revisions bu işi tekrarlatabilir. Snapshot oluşturma/uygulama/allocations ölçülmedi.  
  Kanıt: `MobileArchiveView.swift:488-511,672-717`; `MobileGalleryCollectionView.swift:165-215`; `MobileKeptoraStore.swift:87-97`.
- Warm fingerprint cache hit başına SQLite `last_access` write yapıyor; büyük scan’de write amplification olasılığı var. `MediaFingerprintDiskCache.swift:67-76,215-225`.
- Photos album üyeliklerini enumerate etme, her öğede resource lookup ve tam image `Data` ile hashing bellek/süre maliyeti yaratabilir. `PhotoLibrarySourceAdapter.swift:150-187,701-718,282-312`; folder hash 1 MiB stream karşılaştırması `ExactGrouping.swift:408-430`.
- Hash collision bucket’larında negative comparisons; tarih header lookup’ında O(S²); PhotoKit prefetch cancellation sonrası outstanding work adayları mevcut. Bunlar ölçülmemiştir, doğrudan optimization task sayılmaz.
- Mevcut sentetik 50K builder ölçümleri geçmiş benchmark’tır. Yeni full grid ve full scan path’i için scroll hitch/FPS ya da gerçek cihaz performans sign-off’u değildir.
- iOS’ta UIKit tabanlı `MobileGalleryCollectionView` worktree’de zaten var. UIKit varsayılan olarak daha hızlı sayılmayacak: mevcut UIKit yolu, SwiftUI/reference yolu ve profiling’in işaret ettiği en küçük alternatif aynı iPhone 11 corpus/scroll senaryosunda kıyaslanacak. En iyi seçenek; performans hedefini karşılayan, semantiği/erişilebilirliği koruyan en basit uygulamadır.

### Simulator kapsamı: fonksiyonel/stres tanısı, donanım sign-off’u değil

Mevcut testlerin sınırı açık tutulmalı:

- `GalleryPerformanceTests.testGalleryProjectionComputationFor50kItems` asset modellerini ve `/tmp` URL’lerini ölçümden önce kurar; ölçülen iş yalnız projection builder’dır. Dosya enumeration, Photos/Files taraması, hash, thumbnail, main-actor snapshot apply ve scroll ölçülmez.
- `KeptoraiOSUITests.testSeededGalleryStressUI` seeded UI üzerinde scroll/filter akışını dener. `seedThousandsStressUITesting()` fixture’ı `scanState = .completed` yapar; bu test aktif tarama ile eşzamanlı kullanım kanıtı değildir.
- Dolayısıyla mevcut simulator regression testleri galeri doğruluğu ve builder süresi için yararlı; düşük seviye iPhone akıcılığı veya scan sırasında jank için PASS değildir.

Simulator testlerini üç ayrı katmanda çalıştır:

| Katman | Sentetik düzenek | Kullanım | Sonuç neyi kanıtlar |
|---|---|---|---|
| Projection mikrobenchmark | Gerçek dosya oluşturmayan 1K/10K/50K/100K `UniversalMediaAsset` modelleri; fixture hazırlığı ölçüm dışında. | Projection, sort/filter, grouping ve ölçüm dağılımını karşılaştır. | Builder maliyeti; tam tarama veya FPS değil. 100K kaynak/bellek kısıtı varsa tanı amaçlı atlanır ve kaydedilir. |
| Aktif tarama + UI | DEBUG-only `SyntheticScanSourceAdapter` → `UnifiedLibraryAdapter` → `LibraryAnalysisCoordinator`; ilk 1K asset, sonra 100’lük cumulative batch’ler 500 ms arayla, toplam 10K. Deterministik sahte fingerprint; video-only fixture ve similarity kapalı. Adapter gerçek dosya okuma/hash’i, PhotoKit’i veya kullanıcı arşivini kullanmaz. | Aktif enumeration/progress sırasında scroll, arama, filtre, seçim ve iptali çalıştır. | iPhone 11 Simulator’da galeri etkileşimi ve artan scan progress; gerçek iPhone 11 perf, gerçek dosya I/O/hash/Vision, scan’in 10K’yı tamamlaması veya hardware frame pacing kanıtı değildir. |
| Dosya tabanlı synthetic scan | Geçici test root’unda küçük/orta büyüklükte geçerli sentetik görsel/video fixture’ları; her run sonunda yalnız test root temizlenir. | Enumeration, gerçek decoding/hash, cache cold/warm, cancellation ve scan progress’i exercise et. | Scan pipeline’ın dosya I/O/CPU/worker davranışı; Photos/iCloud provider davranışı değil. |

`testGalleryRemainsInteractiveDuringSyntheticScan` XCUITest, scan coordinator’a bağlı DEBUG-only synthetic source adapter ve ilerleyen progress erişilebilirliği eklendi. iPhone 11 Simulator (iOS 27.0) son run’ında test 40.615 sn’de PASS: progress ve görünür katalog sayısı arttı; scroll, arama, Videos filtresini değiştirme, seçim ve cancel assertion’ları geçti. Önceki run’da scroll öncesi search field kaybolduğu için sequence düzeltildi. iPhone 16 Simulator’da progress assertion eklenmeden önce aynı flow 43.656 sn’de PASS. Synthetic run iptal edilerek tamamlandı; 10K enumeration/analysis full completion ölçülmedi. `testSeededGalleryStressUI` iPhone 11 Simulator’da 52.105 sn’de PASS: scroll/filter ve galeride photo/video copy görünümleri; scan tamamlanmış fixture olduğu için concurrent scan kanıtı değildir. Gerçek Photos asset’inde cleanup/delete yok.

Dosya tabanlı katman için mevcut opt-in `NativeAnalysisBenchmarkTests.testLargeLocalCorpusColdAndWarm` 2.000 geçerli, yerel JPEG üretti; `FolderSourceAdapter` + `LibraryAnalysisCoordinator` ile cold/warm tam tarama, ImageIO/Vision decode, tam hash ve cache yollarını çalıştırdı. macOS host testinde cold **41.56 sn** (2.000 preview decode/feature-print request + 2.000 original hash), warm **1.63 sn** (2.000 exact/photo cache hit, 0 original hash), peak RSS **305,168,384 bytes**, 200 exact groups; test PASS. Ek iPhone 11 Simulator testi 100 geçerli JPEG ile gerçek ImageIO decode/quality, tam hash, cold/warm cache ve enumeration cancellation’ı kapsıyor; similarity kapalı. Son tekrar PASS: cold **1.205 sn**, warm **0.190 sn**, 100 exact hash cache hit, 100 preview/quality cache hit, 10 exact groups, cancellation sonrası tek batch. `CVPixelBufferCreate returned err -6680` mesajları hem similarity-enabled, hem similarity-disabled run’larda görüldü; log kaynağı kesinleştirilmedi. Simulator Vision feature-print doğrulaması hâlâ `UNVERIFIED`. Eşzamanlı iPhone 11 Simulator testi 500 JPEG folder scan’in photo-analysis aşamasında 50K gallery projection’ı main actor’da **25.8 ms**’de tamamladı (45K öğe); bu functional concurrency ölçümü, UIKit frame/hitch/tap performansı değil. iPhone 11 Simulator’daki ayrı 50K projection mikrobenchmark 5 ölçümde **22.213–22.891 ms**, ortalama **22.659 ms**, relative SD **1.192%**; yalnız builder maliyetidir. Hiçbir test fiziksel cihaz veya video kullanmıyor.

Önerilen seri simulator komutları:

```bash
rtk xcodebuild test -project Keptora.xcodeproj -scheme KeptoraiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' -parallel-testing-enabled NO \
  -only-testing:KeptoraiOSTests/GalleryPerformanceTests/testGalleryProjectionComputationFor50kItems

rtk xcodebuild test -project Keptora.xcodeproj -scheme KeptoraiOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' -parallel-testing-enabled NO \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testSeededGalleryStressUI

rtk xcodebuild test -project Keptora.xcodeproj -scheme KeptoraiOS \
  -destination 'platform=iOS Simulator,name=iPhone 11' -parallel-testing-enabled NO \
  -only-testing:KeptoraiOSUITests/KeptoraiOSUITests/testGalleryRemainsInteractiveDuringSyntheticScan
```

Simulator donanımının CPU/GPU, gerçek bellek basıncı, termal davranış veya 60 Hz frame pacing’i iPhone 11’i güvenilir biçimde modellediği varsayılmayacak. Simulator’da ≤16.7 ms/p95 gibi sonuçlar tanı/karşılaştırma verisidir; final perf PASS yalnız fiziksel en düşük desteklenen cihaz sınıfında, Release build ile verilebilir.

**Revizyon 2 run kaydı (2026-11-16):** iPhone 16 Simulator’da 50K projection testi 5 ölçümde ortalama **23 ms** verdi (22.264–23.163 ms); iPhone 11 Simulator’da yeni run **22.659 ms ortalama** verdi (22.213–22.891 ms, relative SD 1.192%). İkisi de builder-only Debug/XCTest sonucu, FPS/scroll/scan akıcılığı değildir. İlk UI runner denemelerinde simulator bootstrap/SDK log sorunları görüldü; sonraki iPhone 16 UI run’ı ~5 dk çıktı üretmeyince durduruldu. iPhone 11 Simulator (iOS 27.0) üzerinde `testGalleryRemainsInteractiveDuringSyntheticScan` **1 PASS / 0 failure**, son test case 40.615 sn; `archive.scanProgress` ve `archive.visibleCount` değişti, scroll/search/Videos filter/select/cancel geçti. `testSeededGalleryStressUI` ayrıca 52.105 sn’de **1 PASS / 0 failure**; completed seeded gallery’de scroll/filter çalıştı. İlk iPhone 11 active-scan run’ında scroll’dan sonra search field görünmedi; sequence düzeltildi. Core `SyntheticScanSourceAdapterTests`: 3 PASS, cancellation ve cumulative/final Unified catalogue batch’leri dahil. 2K generated-JPEG native benchmark macOS host’ta **1 PASS / 0 failure**: cold 41.56 sn, warm 1.63 sn, peak RSS 305,168,384 bytes; full synthetic file-backed scan/decode/hash/cache çalıştı, device/UI concurrency değil. `rtk swift test --package-path Packages/KeptoraCore`: 145 PASS, 1 benchmark skip, 0 failure (opt-in benchmark ayrıca env ile çalıştırıldı). Bu kanıtlar fiziksel iPhone 11 değildir; gerçek cihaz frame/hitch/input latency, bellek/energy kabulü hâlâ `UNVERIFIED`.

**Takip run kaydı (2026-11-17):** iPhone 11 Simulator’da yeni `testFileBackedSyntheticScanUsesRealDecodeHashAndWarmCache` 100 gerçek JPEG dosyasıyla **1 PASS / 0 failure**, test case 1.307 sn; cold 1.122 sn, warm 0.095 sn, 100 exact hash cache hit, 100 preview/quality cache hit, 10 exact group. Aynı test FolderSourceAdapter enumeration’ını ilk batch sonrası iptal etti. İlk similarity-enabled run’da preview cache hit varsayımı tutmadı; tekrarlayan `CVPixelBufferCreate ... err -6680` logları hem bu hem sonraki similarity-disabled run’da görüldü. İkinci run similarity kapalıyken geçti; log kaynağı belirlenmedi. Bu nedenle Vision feature-print performansı simulator’da `UNVERIFIED`; dosya scan’i UI ile eşzamanlı değil. Bütün `GalleryPerformanceTests` sınıfını yeniden çalıştırma denemesi 5 dakikadan uzun süre test sonucu üretmedi ve durduruldu; yalnız odaklı yeni test için PASS kanıtı var. Herhangi bir üretim kod optimizasyonu yapılmadı; 41.56 sn macOS host cold-sonucu profiling adayı gösterir, tek başına düşük uç iPhone darboğazı kanıtı değildir.

**Eşzamanlılık takip kanıtı (2026-11-17):** `testGalleryProjectionRunsDuringFileBackedScan` iPhone 11 Simulator’da **1 PASS / 0 failure**, test case 12.366 sn. 500 JPEG’lik gerçek folder scan’in `.photos` analysis stage’i `.running` iken 50K gallery projection main actor’da **25.8 ms** sürdü ve 45K öğe üretti. Bu worker scan + projection concurrency’sini işlevsel olarak kanıtlar; gerçek UIKit frame pacing, swipe/tap latency veya physical device performansı değil. `rtk swift test --package-path Packages/KeptoraCore`: 145 PASS, 1 benchmark skip, 0 failure.

**Ölçülecek sınırlar:** katalog/source enumeration; hash/thumbnail/Vision; cache I/O; projection input snapshot; worker queue + builder safhaları (filter/sort/sections/review); main actor diffable snapshot apply; görsel fetch/prefetch; eşzamanlı scroll, arama, filtre/sıralama ve seçim/geri alma.

**Metod:** Önce simulator’da synthetic katmanları seri çalıştır; aynı host/runtime/commit/seed ile sonuçları kıyasla, Instruments signpost/Time Profiler/Allocations ve XCTest clock/CPU/memory metriklerini kullan. UI run’ında aynı başlangıç noktası ve interaction script ile scan başlangıcı, scan ortası, sonuç uygulaması ve iptal anında scroll + arama + filtre + seçim uygula. Ardından aynı doğrulama fiziksel iPhone 11/eşdeğer düşük uç cihazda Release build ile 10K/50K/100K uygulanabilir senaryolarda tekrarlanır; UIKit/reference kıyası yalnız aynı corpus/cihaz/koşulda yapılır. Her koşuda cihaz/OS/Xcode/commit, item count, cache, filtre, ısınma ve corpus kaydı; cihaz testinde 5 warmup + 30 ölçüm/koşu, üç bağımsız tekrar; p50/p95, peak RSS, CPU, I/O, energy, cache hit/miss, SQLite writes, hash comparisons, outstanding prefetch ve frame hitch raporlanır. 50K aktif-scan senaryosunda p95 frame ≤16.7 ms, >100 ms hitch yok, tap/selection feedback p95 ≤100 ms ve memory warning/jetsam yok hedefleri ölçülür. Arama/filtre sonuç gecikmesi için emulator baseline’ı alınır ve fiziksel cihaz kabulünden önce açık eşik kayda geçirilir; eşik belirlenmeden “PASS” denmez. Profiling önce; yalnız darboğaz kanıtlanırsa değişiklik. Eşik sağlanmazsa optimizasyon geri alınır veya kapsam dışı bırakılır.

## Uçtan uca App Store kabul matrisi

1. **İlk açılış/izin:** fresh install, Photos denied/limited/full, sonradan grant/revoke/relaunch, Files picker, boş kütüphane; kullanıcıya doğru durum/eylem göster.
2. **Kaynak/scan:** birden çok Photos/Files kaynağı, scope/bookmark, iCloud placeholder, offline/provider hata, harici volume replacement; kaynaklar arası seçim ve cancellation stale sonuç üretmesin.
3. **Analiz/galeri:** exact duplicate hash, similarity/quality false positive, RAW/HEIC/video/Live Photo, bozuk/eksik medya, album/favorite/date/search/sort, grup kimliği ve stable thumbnail revision.
4. **Karar/temizlik:** manuel benzersiz/favori seçim, önerili keeper koruması, tekrar tıklama, son onayda kapsam/adet/unknown byte, cancellation, partial success/failure, undo/history.
5. **Recovery/restore:** manifest/journal restart, cancel, occupied original, missing/tampered file, partial restore, external-volume swap; overwrite veya silent recovery-route loss yok.
6. **StoreKit:** entitlement/lifetime kontrolü, purchase success/cancel/pending/offline, restore/revocation ve ikinci cihaz davranışı; test config, ürün ID, fiyat ve paywall aynı release kaydıyla eşleşir.
7. **UX/i18n/accessibility:** desteklenen dört dilde localization validator + plural/format + uzun metin; VoiceOver, keyboard/focus, Dynamic Type, contrast, Reduce Motion, empty/error/loading states ve ilgili accessibility audit.
8. **Release/security/privacy:** final signed-equivalent archive; bundle/team/version/entitlements/privacy manifests/SDK declarations/permission copy; source review’de no-upload/no-analytics iddialarını final binary/traffic ile karşılaştır; App Store screenshots/review instructions/privacy label final build’e ait.
9. **Performance/reliability:** yukarıdaki gerçekçi synthetic/izinli corpus ve profiling; low disk, memory pressure, cancellation, app background/force quit, volume disconnect için güvenli fault injection.
10. **Mağaza/yayın:** agreements/tax/banking, regional disclosures, legal identity, URLs/support, age/category/rights/export answers, IAP pricing/localizations, review notes, uploaded build processing ve manual/phased release kararı owner tarafından doğrulanır. Bu plan bunları kendiliğinden değiştirmez.

## Fazlar, durma koşulları

### Faz 0 — Güncel snapshot kanıtı
- Status/diff’i koruyarak snapshot ve exact source SHA kaydet; hiçbir kullanıcı değişikliğini revert/stage etme.
- Validator’lar, KeptoraCore, Mac/iOS build/test, ReleaseTesting ve StoreKit’i güncel tree’de tekrar çalıştır; ilk compiler failure ve `.xcresult`/job log’unu sakla.
- 48 localization bulgusunu dosya/anahtar bazında eşleştir; CI run `bb96ab8` ile dirty tree sonuçlarını ayrı raporla.
- `RELEASE_BLOCKERS.md`, iki submission checklist, App Store metadata, test/QA raporları ve current GitHub issues için Pass/Fail/Unverified/Obsolete envanteri hazırla.

**Dur:** güncel hata listesi, test komutları ve exact candidate version/target net değilse düzeltme işine geçme.

### Faz 1 — P0 build, localization, release identity
- Kök build/typecheck hatalarını minimal düzelt; project.yml/pbxproj/package deployment target’larını eşleştir.
- Tüm localization validator bulgularını çöz; plural/placeholder format testleri ekle.
- macOS+iOS version/build/Team/Bundle/StoreKit product kayıtlarını owner onayıyla tek aday build’e eşleştir; release credentials/secrets’i rapora koyma.

**Gate:** portable-core, native Mac, native iOS, StoreKit ve static/localization job’ları aynı aday commit’te yeşil.

### Faz 2 — P1 data/privacy/source
- Cloud download consent, date section identity, trial allowance no-op, exact-grouping prefilter ve Photos history persistence için önce failing regression test.
- Path/source identity, symlink containment, revoke/cache retention, permission transitions ve File Provider davranışını güvenli test doubles/simulator ile doğrula.
- Swipe cleanup onay sözleşmesini product owner ile netleştir; onay olmadan davranış değişikliği yapma.

**Gate:** onaysız download yok; içerik kaybı/selection kaybı yok; exact hash iddiası ve recovery/undo invariant’ları testli.

### Faz 3 — UX, localization, accessibility
- Onboarding recovery copy, partial scan plurals, empty/error/permission states ve tüm aktif çevirileri düzelt.
- Accessibility audit opt-in bayrağını çalıştır; simulator UI testleri, keyboard/focus/VoiceOver/Dynamic Type/contrast/reduced motion senaryoları.
- macOS ve iOS için screenshot/UX evidence’i final candidate build’e bağla.

**Gate:** hiçbir required localization string eksik değil; tüm kritikleri testli; physical/manual gerektirenler `UNVERIFIED` olarak işaretli.

### Faz 4 — Profiling ve ölçüme dayalı optimizasyon
- Ölçüm instrumentation’ını veri-minimize/redacted tut; sentetik/izinli fixture ile uçtan uca profiling yap.
- Öncelik: yeni iOS grid snapshot/main actor, Photos enumeration/resource/hash memory, warm SQLite cache writes, cancellation/prefetch; sort/index değişimini ancak profil gösterirse düşün.
- Her optimizasyonu aynı corpus/cihaz koşulunda önce/sonra karşılaştır; sıra, grouping, keeper, exact-match ve invalidation equivalence testleri geçsin.

**Gate:** önceden tanımlanan metrikte gürültü üstü kazanım, ölçülmüş bellek/energy etkisi ve sıfır semantik regresyon. Fiziksel cihaz yoksa perf sign-off `UNVERIFIED`.

### Faz 5 — Release candidate ve insan kabulü
- Aynı final commit için Debug/Release, analyzer, unit/integration/UI, StoreKit, privacy/entitlements, project references, archive/export ve CI sonuçlarını kaydet.
- Fiziksel Mac + iPhone üzerinde Photos limited/revoke/regrant, iCloud/provider download consent, real StoreKit sandbox, restore, VoiceOver ve gerçek scroll/memory/hardware testlerini yürüt.
- App Store Connect/legal/account/checklist satırlarını owner kanıtıyla güncelle; final signed build için screenshots, privacy answers, review notes ve upload processing’i doğrula.

**Gate:** tüm required AC’ler PASS ve aynı release candidate’e bağlı; P0/P1 açık yok; bilinçli kabul edilmiş P2 listesi var. Aksi halde `NO-GO`.

## Çok-agent uygulama düzeni

| Alan/uzman | Sorumluluk | Dosya sınırı / kontrol |
|---|---|---|
| Coordinator + `keptora-architecture` | Snapshot, faz/bağımlılık, issue eşlemesi, contract ve entegrasyon | Başlangıç diff’i koru; agent’ları aynı dosyaya eşzamanlı yazdırma |
| `keptora-quality` | CI/test/validator triage, verification matrix, son kanıt review | SHA, komut, SDK/OS, test sayısı, artifacts zorunlu |
| `keptora-sources` + `keptora-privacy-security` | PhotoKit/Files/iCloud izin, download, source identity, privacy | Synthetic source/provider; live/private data yok |
| `keptora-safety-recovery` | Cleanup, confirmation, history, cancel, manifest, restore | Temp root/fake adapter; destructive user library yok |
| `keptora-macos` + `keptora-iphone` + `keptora-experience` | Platform akışları, gallery, copy, accessibility/localization | Platform başına ayrı files/tests; UI acceptance kanıtı |
| `keptora-media-intelligence` | Exact hash, grouping, similarity/quality false positives | Etiketli izinli corpus; hash ve recommendation semantics |
| `keptora-storekit` + `keptora-release-growth` | Entitlement, product metadata, submission evidence | Sandbox/manual owner approval; satın alma/yayın yok |
| Performance lane (`keptora-quality` + `keptora-architecture`) | Instrumentation, benchmark, profile sonrası optimize | Ölçüm öncesi refactor/cache yok |

İlk PR’lar build blocker ve P1 davranış konularını ayrı tutar. Bir agent değişiklik yaparken başka agent aynı path’i düzenlemez; merge öncesi bağımsız reviewer dosya diff’ini ve test kanıtını inceler. Büyük refactor #14/#15 ancak P0/P1 kapandıktan ve ayrı tasarım onayı alındıktan sonra değerlendirilir.

## Kabul kriterleri

### AC-001 — Aday build tekrarlanabilir
- **Senaryo:** Dirty worktree’den release candidate hazırlanıyor.
- **Eylem:** Core, Mac, iOS, StoreKit ve release/localization gates aynı exact commit’te çalıştırılır.
- **Beklenen:** Required CI/test/build kontrolleri yeşil; ilk hata ve `.xcresult` saklı; version/target ayarları tutarlı.
- **Must not:** Başka SHA’nın eski PASS’ı current candidate kanıtı diye sunulmaz.
- **Doğrulama:** GitHub Actions + yerel Xcode/Swift test çıktısı; static validator sonucu.
- **Öncelik:** Required.

### AC-002 — Photo/Files/iCloud erişimi izinli ve görünür
- **Senaryo:** Denied/limited/full, cloud-only, offline, provider failure veya source replacement.
- **Eylem:** Kullanıcı kaynak bağlar, tarar veya Swipe Clean açar.
- **Beklenen:** Yalnız OS izinli kapsam taranır; network indirme öncesi açık onay alınır; iptal/izin kaybı anlaşılır durum verir.
- **Must not:** Gizli/başka uygulama verisine erişim veya sessiz cloud download.
- **Doğrulama:** Mock/synthetic + simulator permission/provider senaryosu; limited Photos ve gerçek provider davranışı ayrıca fiziksel cihazda.
- **Öncelik:** Required.

### AC-003 — Galeri hiçbir varlığı sessizce atlamaz veya eski görsel göstermez
- **Senaryo:** Tekrarlanan tarih aralığı grupları; stable asset ID ile revision değişimi; hızlı source/filter/scroll değişimi.
- **Eylem:** Projection ve collection view yeni snapshot uygular.
- **Beklenen:** Tüm uygun asset ID’leri tam bir kez gösterilir; thumbnail yeni revision’a geçer; stale/cancelled sonuç uygulanmaz.
- **Must not:** Section collision nedeniyle görünür medya kaybı veya eski isteğin yeni state’i ezmesi.
- **Doğrulama:** Üç tarih bloğu fixture’ı, cache/fetch mock ve iOS UI/XCTest.
- **Öncelik:** Required.

### AC-004 — Exact grouping ve selection semantiği korunur
- **Senaryo:** Edit’li/Live Photo, RAW/format varyasyonu, eşit perceptual preview veya hash; ayrıca empty/unhealthy selection session.
- **Eylem:** Exact analysis ve “Select All Suggestions” çalışır.
- **Beklenen:** Exact iddia yalnız full-content hash ile kurulur; no-op seçim entitlement tüketmez; manual seçim öneri korumalarıyla karışmaz.
- **Must not:** Preview farkı nedeniyle doğrulanmış tam kopya sessizce atlanmaz; hatalı öneri otomatik destructive action başlatmaz.
- **Doğrulama:** İzinli fixtures, karşılaştırmalı fingerprint sonucu, entitlement spy ve regresyon testleri.
- **Öncelik:** Required.

### AC-005 — Cleanup, cancel ve recovery işlemleri restart sonrasında izlenebilir
- **Senaryo:** PhotoKit/folder operation success, partial failure, cancel veya app termination boundary.
- **Eylem:** Kullanıcı son inceleme/onayı verir ve işlem başlatır; uygulama kapanıp yeniden açılır.
- **Beklenen:** Manifest/history route ve tamamlandı/failed/not attempted state’i açık; Photos Recently Deleted mesajı doğru; Files restore no-overwrite.
- **Must not:** Sessiz route kaybı, orijinal üzerine yazma, ambiguous duplicate/missing-copy için otomatik kalıcı müdahale.
- **Doğrulama:** Fake adapters/temp directory crash-restart/cancel tests; gerçek PhotoKit/restore acceptance ayrı cihazda.
- **Öncelik:** Required.

### AC-006 — StoreKit ve ücretsiz/Pro davranışı tutarlı
- **Senaryo:** Yeni, mevcut, offline, pending, cancelled, restored/revoked entitlement; Mac/iOS aynı lifetime ürün.
- **Eylem:** Kullanıcı paywall/restore ve manuel/önerili seçim akışını kullanır.
- **Beklenen:** Aynı product ID/entitlement/veri anahtarları; purchase state doğru; temel manuel seçim, güvenlik ve restore erişilebilir.
- **Must not:** Test config veya stale UserDefaults ile satın alma durumu kaybı; temel güvenlik ödeme duvarına girmez.
- **Doğrulama:** StoreKit unit tests + sandbox purchase/restore owner-approved; ürün, fiyat ve family sharing ASC eşleşmesi.
- **Öncelik:** Required.

### AC-007 — Metinler, erişilebilirlik ve kritik UX akışları hazır
- **Senaryo:** EN/TR/DE/FR, count 1/2, uzun metin, denied/empty/error/recovery, Dynamic Type/VoiceOver/keyboard.
- **Eylem:** İlk açılış, galeri, review, cleanup, settings/paywall ekranları kullanılır.
- **Beklenen:** Localization validator temiz; çoğul/iddia doğru; focus order, target ve status erişilebilir.
- **Must not:** “Recoverable anytime” gibi desteklenmeyen garanti veya erişilemeyen confirmation/error.
- **Doğrulama:** Localization/UI automation + accessibility audit simulator; human VoiceOver/keyboard acceptance Mac+iPhone’da.
- **Öncelik:** Required.

### AC-008 — Performans iddiası gerçek ölçümle desteklenir
- **Senaryo:** Simulator’da synthetic 10K/50K (100K kaynak/bellek uygunsa) ve fiziksel iPhone 11/eşdeğer düşük uç cihazda sentetik/izinli 10K/50K/100K, cold/warm/resume; scan aktifken eşzamanlı scroll, arama, filtre ve seçim. macOS ölçümü ayrı desteklenen Mac’te.
- **Eylem:** Scan, analysis, cache, projection, main actor apply ve image loading; scan öncesi, aktif scan, sonuç apply ve cancellation anlarında profillenir.
- **Beklenen:** Reproducible JSON/trace; 50K iPhone 11 senaryosunda p95 frame ≤16.7 ms, >100 ms hitch yok, tap/selection feedback p95 ≤100 ms, memory warning/jetsam yok; p50/p95/RSS/CPU/I/O/energy ve hot-path work counts kaydedilir. UIKit/reference kıyası aynı koşulda yapılır.
- **Must not:** 50K builder süresi gerçek FPS/full scan performansı diye sunulmaz; simulator cihaz profili iPhone 11 hardware eşdeğeri sayılmaz; ölçülmeyen sort cache eklenmez.
- **Doğrulama:** XCTest/XCUITest synthetic simulator matrix + Instruments; sonra fiziksel iPhone 11/eşdeğer düşük uç cihaz ve gerçek supported Mac. Simulator-only sonuç final perf sign-off değildir.
- **Öncelik:** Required.

### AC-009 — Tarama sürerken uygulama etkileşimleri yanıt verir
- **Senaryo:** Test-only synthetic tarama artan batch/progress ile sürüyor; kullanıcı kütüphanesi ve canlı Photos erişimi kullanılmıyor.
- **Eylem:** Galeriyi kaydır, arama yaz, filtre/sıralama değiştir, öğe seçip geri al, taramayı iptal et.
- **Beklenen:** UI güncel progress ve sonuçları gösterir; etkileşimler scan tamamlanmasını beklemeden yanıt verir; iptalden sonra geç gelen eski projection state’i ezmez. Simulator’da functional/stress regressions geçer; fiziksel düşük uç cihazda AC-008 frame ve input hedefleri de sağlanır.
- **Must not:** Test fixture’ı gerçek Photos silme/download başlatmaz; geç/stale sonuç kullanıcı seçimini veya yeni sorguyu ezmez.
- **Doğrulama:** Yeni `testGalleryRemainsInteractiveDuringSyntheticScan` simulator XCUITest + DEBUG-only deterministic synthetic scan fixture; gerçek cihazda aynı interaction script ve Instruments hitch/frame trace.
- **Öncelik:** Required.

### AC-010 — Privacy ve binary beyanı uyumlu
- **Senaryo:** Final signed-equivalent macOS/iOS archive.
- **Eylem:** Entitlements, privacy manifests, SDK declarations, permission copy, archive network davranışı ve App Privacy answers karşılaştırılır.
- **Beklenen:** Medya upload/analytics iddiaları binary ve network evidence ile desteklenir; StoreKit/Photos/provider network farkı kullanıcıya dürüstçe anlatılır.
- **Must not:** Kaynak incelemesi tek başına final binary/privacy compliance PASS sayılmaz.
- **Doğrulama:** Archive/SDK/privacy-manifest review + authorized synthetic traffic check; hiçbir gerçek medya payload’ı dışarı çıkmaz.
- **Öncelik:** Required.

### AC-011 — App Store submission kanıtı aynı release candidate’e bağlı
- **Senaryo:** Public submission hazırlığı, macOS+iOS.
- **Eylem:** Owner release checklist, ASC, IAP, metadata, legal, screenshots, review notes ve upload processing’i doğrular.
- **Beklenen:** Bütün required satırlar exact version/build ile PASS; unresolved item’lar blocker/owner olarak açık.
- **Must not:** Agent App Store Connect veya yasal/finansal ayarları kullanıcı onayı olmadan değiştirmez; eski checklist PASS’ı güncel kabul edilmez.
- **Doğrulama:** Owner-confirmed ASC evidence, final signed archive, screenshot/privacy/review artifact.
- **Öncelik:** Required.

## Açık blokajlar ve kararlar

- Kullanıcı yalnız simulator erişimi verdi. PhotoKit limited/revoke/regrant, gerçek iCloud/File Provider, physical scroll/memory/energy, gerçek StoreKit sandbox ve cihaz erişilebilirliği kapanamaz; cihaz kabulü sağlanana kadar `UNVERIFIED`, final App Store readiness `NO-GO`.
- iPhone 11-class perf gate’i simulator’da final olarak kanıtlanamaz. Fiziksel iPhone 11/eşdeğer cihaz erişimi sağlanana kadar UIKit/reference seçimi ve “kasmıyor” iddiası `UNVERIFIED`.
- App Store Connect, legal/account, fiyat ve submission yetkisi verilmedi. Bu işler yalnız owner onayıyla yapılır.
- Kullanıcı iPhone 11 sınıfında akıcılık hedeflerini onayladı: p95 frame ≤16.7 ms, >100 ms hitch yok, tap/selection feedback p95 ≤100 ms ve memory warning/jetsam yok. Arama/filtre completion eşiği baseline ölçümünden önce belirlenecek.
- Kullanıcı, Swipe Clean’de sola kaydırmanın Files öğelerini app recovery alanına taşıma için final intent olduğunu onayladı. Bu onay kalıcı silmeye izin vermez; Photos kaldırması Apple sistem onayını ve Recently Deleted akışını izler.

## Bu uygulama turundaki tamamlanma durumu

- Onaylı plan multi-agent iş akışıyla uygulandı; Photos history işi fake adapter ile tamamlandı.
- P1 #4–#8 düzeltmeleri: swipe thumbnail ağ indirmesi engellendi; tekrarlanan tarih bölümlerine benzersiz kimlik verildi; busy macOS seçim no-op’i allowance tüketmiyor; exact gruplama preview hash ile aday elemek yerine tam fingerprint’e dayanıyor; Photos history silmeden önce `.planned` olarak kaydediliyor ve başarı/iptal durumuna göre güncelleniyor.
- Localization düzeltmeleri uygulandı. `validate_universal_release.py`, `validate_mac_localization.py`, `validate_project_references.py`, `validate_app_store_metadata.py` ve `validate_photo_cleaner_assets.py` geçti.
- Symlink containment regresyonu eklendi: ilk test, enumerated path dış-root symlink ile değiştirildiğinde fingerprint’in reddedilmediğini gösterdi; canonical-root kontrolü sonrası odaklı test geçti. Kontrol ile open arasındaki eşzamanlı TOCTOU riski ayrıca açık.
- 2026-11-17 doğrulama: KeptoraCore 146 test, 1 benchmark skip, 0 failure; beş release/localization/project/metadata/asset validator’ı PASS; `git diff --check` PASS.
- KeptoraCore: 142 test, 1 benchmark skip, 0 failure. macOS: 37 test, 0 failure. iOS: 5 odaklı regresyon testi, 0 failure. macOS ve iOS `build-for-testing` geçti.
- Revizyon 2 simulator matrix’ini, `SyntheticScanSourceAdapter` ile gerçek scan coordinator enumeration’ını ve `testGalleryRemainsInteractiveDuringSyntheticScan` UI testini ekledi. iPhone 11 Simulator’da functional UI testi ve artan progress PASS. Gerçek iPhone 11 cihazı, frame/hitch/input latency, bellek/energy ve gerçek hash/I/O perf ölçülmedi; bu performans iddiaları `UNVERIFIED`.
- Revizyon 3, 100 JPEG cold/warm file-backed scan ve iptal testini, ayrıca 500 JPEG photo-analysis sürerken 50K gallery projection testini ekledi. iPhone 11 Simulator’da projection 25.8 ms’de tamamlandı; bu UIKit/FPS/cihaz perf sign-off’u değildir. Vision feature-print `CVPixelBufferCreate ... err -6680` uyarılarıyla hâlâ `UNVERIFIED`.
- TDD RED/GREEN eşlemesi ve sınırlamalar: [TDD kanıt raporu](../tdd/errors-and-performance.tdd.md).
- Fiziksel iPhone/Mac, gerçek PhotoKit/iCloud/Files provider, gerçek StoreKit sandbox, Release archive/analyzer ve ASC/legal kabulü **çalıştırılmadı**; App Store readiness `NO-GO / UNVERIFIED`.
- Başlangıçtaki kullanıcı worktree değişiklikleri korundu; bu turda hiçbir değişiklik stage/commit/push edilmedi.
