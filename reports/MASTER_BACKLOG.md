# Keptora — Master Backlog (Bulgular ve Görev Takibi)
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`

---

## 1. Çözülmüş ve Doğrulanmış Maddeler (Verified)

### KEP-STOREKIT-0001
- **Severity:** P1
- **State:** VERIFIED
- **Evidence:** TESTED (ASC Submissions & IAPs)
- **Platform:** StoreKit / AppStore / iOS
- **Source:** App Store Connect / `Keptora Pro Lifetime` (`com.keptora.app.pro.lifetime`)
- **Açıklama:** İlk non-consumable IAP uygulama sürümünden ayrı gönderildiğinde Apple `Developer Rejected` vermekteydi.
- **Çözüm:** Perşembe günkü tekli gönderim kaldırıldı; iOS 1.0 (Build 186) ile `Keptora Pro Lifetime` IAP tek bir review gönderiminde birleştirilerek Apple Review'a yollandı.
- **Durum:** Hem iOS Uygulaması hem IAP `Waiting for Review` durumunda.

### KEP-MACOS-0001
- **Severity:** P2
- **State:** VERIFIED
- **Evidence:** TESTED
- **Platform:** macOS
- **Source:** `Keptora/UI/MacArchiveView.swift:180-320`
- **Açıklama:** Çoklu filtreleme menüleri arasında geçiş yaparken galeri grid'i 1:1 en-boy oranını kaybedip titreme/kayma yapıyordu.
- **Çözüm:** Tekli birleşik filtre butonu ve 1:1 sabit en-boy oranlı zero-jitter grid uygulandı (Commit `4532350`).

### KEP-IOS-0001
- **Severity:** P1
- **State:** VERIFIED
- **Evidence:** TESTED
- **Platform:** iOS
- **Source:** `KeptoraiOSTests/KeptoraiOSTests.swift:45-52`
- **Açıklama:** Simülatörde 5+ fotoğraf olup hiç kopya grubu olmadığında `testRealPhotoLibraryDuplicateScanningOnSimulator` assertion fırlatıyordu.
- **Çözüm:** `guard !outcome.groups.isEmpty else { throw XCTSkip(...) }` ile test ortamına duyarlı hale getirildi (Commit `cb30a97`). iOS birim testleri 34/34 PASS.

---

## 2. Açık ve Gelecek Sürüm İyileştirmeleri (v1.0.2 Yol Haritası)

### UX-01
- **Severity:** P1
- **State:** OPEN (v1.0.2 Hedefi)
- **Platform:** iOS
- **Source:** `KeptoraiOS/UI/`
- **Açıklama:** Geçmiş `5641a610` commit'inde `MobileSplitComparisonView.swift` silinmişti; macOS'ta bulunan `SideBySideCompareView` iOS'ta eksik.
- **Aksiyon:** iOS dikey/yatay ekranına uyarlanmış `MobileSplitComparisonView` sayfası v1.0.2 ile tekrar eklenecek.
- **Owner:** 07 keptora-iphone; **Reviewer:** 08 keptora-experience

### ARCH-01
- **Severity:** P1
- **State:** OPEN (Teknik Borç / Refactor)
- **Platform:** Shared / macOS / iOS
- **Source:** `MacArchiveModel.swift` (1.142 satır), `MobileKeptoraStore.swift` (1.517 satır)
- **Açıklama:** View-model sınıfları tarama, filtre projeksiyonu, seçim, undo/redo ve ödeme kapısını tek dosyada toplamış durumda.
- **Aksiyon:** `MobileSelectionCoordinator` ve `MacProjectionEngine` gibi alt koordinatör sınıflarına bölünerek 600 satır altına çekilecek.
- **Owner:** 02 keptora-architecture; **Reviewer:** 11 keptora-quality

### UX-02
- **Severity:** P2
- **State:** OPEN
- **Platform:** macOS
- **Source:** `Keptora/UI/MacArchiveView.swift:537-580`
- **Açıklama:** macOS hücrelerinde rozet durumlarına göre hücre yükseklikleri 210-290pt arası dalgalanabiliyor.
- **Aksiyon:** iOS'taki gibi thumbnail üzerine overlay rozet mimarisine taşınacak.
- **Owner:** 06 keptora-macos; **Reviewer:** 08 keptora-experience

### UX-03
- **Severity:** P2
- **State:** OPEN
- **Platform:** macOS
- **Source:** `Keptora/UI/MacArchiveView.swift:584`
- **Açıklama:** Hücre içindeki per-cell `GeometryReader` 5.000+ öğelik kütüphanelerde layout gecikmesi oluşturuyor.
- **Aksiyon:** iOS stili `scrollPosition` tabanlı takip ile değiştirilecek.
- **Owner:** 06 keptora-macos; **Reviewer:** 11 keptora-quality

### UX-04
- **Severity:** P2
- **State:** OPEN
- **Platform:** iOS
- **Source:** `KeptoraiOS/UI/MobileArchiveView.swift:831-869`
- **Açıklama:** Thumbnail ile Keeper butonunun ayrı öğeler olması VoiceOver swipe sayısını ikiye katlıyor.
- **Aksiyon:** `.accessibilityElement(children: .combine)` ile birleştirilecek.
- **Owner:** 08 keptora-experience; **Reviewer:** 07 keptora-iphone

### QA-01
- **Severity:** P2
- **State:** OPEN (CI Ortamı)
- **Platform:** CI / macOS
- **Source:** `.github/workflows/apple-validation.yml`, `KeptoraUITests`
- **Açıklama:** macOS XCUITest headless oturumda pencere odaklanması bekliyor; CI runner etiketi `macos-14`/`macos-15` olarak doğrulanmalı.
- **Aksiyon:** Dedicated Aqua GUI oturumu ile çalıştırılacak.
- **Owner:** 11 keptora-quality; **Reviewer:** 01 keptora-command

### KEP-RELEASE-0001
- **Severity:** P3
- **State:** WONT_FIX_IN_CURRENT_SUBMISSION (v1.0.2'de Eklenecek)
- **Platform:** AppStore / iOS
- **Source:** App Store Connect `Header and Search Results`
- **Açıklama:** Opsiyonel pazarlama alanı (3840×1646 px) boş; sürüm incelemede kilitli olduğu için onay sırasını bozmamak adına sonraki güncellemeye bırakıldı.
- **Aksiyon:** İnceleme onayından sonra v1.0.2 ile banner yüklenecek.
- **Owner:** 12 keptora-release-growth; **Reviewer:** 01 keptora-command

### ARCH-02
- **Severity:** P3
- **State:** OPEN
- **Platform:** Shared
- **Source:** `MobileKeptoraStore.swift`, `MacArchiveModel.swift`
- **Açıklama:** Kodda kalan bazı inline string anahtarlar `AppStorageKeys.swift` içine taşınmalıdır.
- **Owner:** 02 keptora-architecture; **Reviewer:** 01 keptora-command
