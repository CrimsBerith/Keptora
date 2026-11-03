# Keptora — macOS User Journey & Desktop Experience Report
**Agent:** 06 `keptora-macos` (MAC STUDIO / Desktop Experience)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** PASS (İyileştirme Önerileri ile Birlikte)

---

## 1. Mimari ve Navigasyon Rotaları
- **Kök Kapsayıcı (`Keptora/App/MainRootView.swift:22-42`):**
  - Üç panelli `NavigationSplitView` mimarisi (Sidebar genişlik sınırları: `min: 184, ideal: 208, max: 232`).
- **Kenar Çubuğu (Sidebar) Rotaları:**
  - *Library (Kütüphane):* `.archive` (`MacArchiveView.swift`)
  - *Smart Cleanup:* `.exact`, `.similar`, `.bursts`, `.screenshots`, `.videos`, `.review` (otomatik `archive.galleryContext` yapılandırır).
  - *Activity (Etkinlik):* `.history` (`CombinedCleanupHistoryView`)
  - *Pro Tier:* `proFooter` (`MainRootView.swift:289-315`) atomik olarak Lifetime Pro rozeti veya "Unlock Keptora Pro" paywall butonunu gösterir.
- **Klasör Sürükle-Bırak (Drag & Drop):**
  - `MainRootView.swift:69-86`: `.onDrop(of: [.fileURL], isTargeted: $isDropTargeted)` ile Finder'dan sürüklenen klasörleri tanır ve `archive.connectFolder(url)` çağırır.

---

## 2. Klavye Kısayolları ve Menü Komutları
- `⌘O` (**Klasör Ekle / Add Folder…**): `KeptoraApp.swift:128` (`MacLibraryCommands`), `.archive` rotasına geçer ve `archive.chooseFolder()` tetikler.
- `⌘R` (**Taramayı Başlat / Start Scan**): `KeptoraApp.swift:130` (`MacLibraryCommands`), `archive.analyze()` çağırır.
- `⌘F` (**Arama / Find**): `MacGalleryKeyboardMonitor` (`MacLibraryServices.swift:99`), `MacArchiveView:245` üzerindeki arama alanına odaklanır (`@FocusState searchFocused`).
- `⌘A` (**Tümünü Seç / Select All**): Metin kutularında (`NSTextView`) metin seçimini ezmez, galerideyken görünür öğeleri seçer (`archive.selectItems(visible)`).
- `⌘Z` / `⌘⇧Z` (**Geri Al / Yinele - Undo/Redo**):
  - Galeride 50 adımlık seçim geçmişini geri alır/yineler.
  - İnceleme sayfasında (`MacArchiveView.swift:849`) `.keyboardShortcut("z", modifiers: [.command])` ile silme öncesi inceleme seçimini geri alır.
  - Native UI Test Kanıtı: `testUnifiedMacGallerySupportsMultiStepKeyboardUndoRedo` (`KeptoraUITests.swift:243-256`) PASS.
- **Klavye Yön Tuşları ile Gezinme:** Hücreler `.onMoveCommand` dinler, `Shift` basılı tutulduğunda aralık seçimi (`LibraryRangeSelection`) yapar.

---

## 3. Yan Yana Karşılaştırma (Side-by-Side Comparison)
- `SideBySideCompareView.swift:1-327`:
  - $\ge 2$ öğeli benzerlik ve kopya gruplarında iki fotoğrafı yan yana koyar.
  - Çözünürlük, dosya boyutu, kamera, çekim tarihi diff kartları.
  - "Higher Res" ve "Larger" yeşil/mavi rozetler.
  - "Keep This" ile korunan öğeyi değiştirme ve seçim kutusu.
  - `Esc` kısayolu ile hızlı kapanma.

---

## 4. Pencere Yönetimi ve Yaşam Döngüsü
- **Minimum Boyut Kısıtı:** `MacLibraryServices.swift:185` ile `NSSize(width: 900, height: 650)` altına inmesi engellenmiştir.
- **Dock Reopen & İkili Pencere Güvenliği:** `KeptoraAppDelegate.showMainWindowIfNeeded()` (`KeptoraApp.swift:55-85`) pencere kapanmışsa `fallbackWindow` üzerinden temiz açar.
- **Güvenli Çıkış (Termination Invariant):** `applicationShouldTerminate` (`KeptoraApp.swift:42-53`) asenkron olarak `archive.prepareForTermination()` ve `operations.waitForIdle()` bekler; veri yazımı sırasında aniden kapanmaz.

---

## 5. Tespit Edilen Bulgular ve İyileştirmeler
- **UX-02 (P2):** macOS hücrelerinde farklı rozetler nedeniyle hücre yükseklikleri değişken (210-290pt) olabiliyor; iOS'taki gibi thumbnail üzeri overlay modeline taşınması önerilir.
- **UX-03 (P2):** macOS `MacArchiveView:584` satırında her hücrede `GeometryReader` bulunması 5.000+ öğelik kütüphanelerde 2 geçişli layout hesaplaması yaptırabiliyor; iOS stili `scrollPosition` tercih edilebilir.
- **UX-05 (P3):** macOS üst filtre çubuğunda 5 ayrı kontrol bulunmakta; ilerleyen sürümlerde tek birleşik filtre menüsüyle sadeleştirilebilir.

