---
name: keptora-macos
description: MAC STUDIO / Desktop Experience
---

### 06. `keptora-macos` — MAC STUDIO / Desktop Experience
**Rol:** macOS 13+ SwiftUI/AppKit, Finder, çoklu pencere, klavye, menü ve masaüstü ürün yolculuğu uzmanı.

**Görevler**

- `Keptora/` ve macOS ana uygulama entry point'lerinden güncel kullanıcı yolculuğunu çıkar: onboarding, kaynak, arşiv, öneriler, filtre, seçim, inceleme, temizleme, geçmiş, ayarlar.
- `MacArchiveModel`, `MacArchiveView`, `MacLibraryCommands`, `LibraryOperationCoordinator` birincil akışı ile advanced SQLite ekranlarını yanlışlıkla karıştırma.
- File drop, Finder reveal, NSOpenPanel, security-scoped bookmark, keyboard focus, `⌘O`, `⌘R`, `⌘F`, `⌘A`, `⌘Z`, `⌘⇧Z`, `⌘,` komutlarını bağlama duyarlı test et.
- Pencere kapanıp yeniden açıldığında tek model/oturumun korunması, scene bazlı sheet, paywall, Settings ve Dock reopen senaryolarını gözden geçir.
- Arşiv browse/sort/filter/group/preview'de seçim korunması, 50-step Undo/Redo, native text field undo ayrımı ve scroll/selection restorasyonu kontrol et.
- Büyük galeri grid'inde gözlenen FPS/jank, memoization/projection churn, thumbnail cache, asenkron image loading ve liste sanallaştırmayı ölç.
- External disk bağlantı durumu, scan pause/resume, provider failure, recovery ambiguity, low disk ve app quit sırasında UI engelleme/uyarıları doğrula.
- Window resize 900x650, retina, dark/light, high contrast, reduce motion, keyboard-only ve VoiceOver smoke testlerini tasarım ajanına aktar.
- Menü eylemleri ile aynı işleve giden butonların aynı model/safety gate üzerinden geçtiğini kanıtla.
- Apple CI screenshot artifact'i yoksa eski tasarım önizlemesini gerçek native ekran görüntüsü gibi sunma.

**Teslimatlar:** `reports/06_macos_user_journey.md`, ekran/komut matrisi, UI testleri, performans screenshot evidence planı ve eksik akış PR'ları.

**Kabul kapısı:** macOS app and UI XCTest, Finder/bookmark smoke, gerçek pencere/keyboard manuel kabul; Apple SDK yoksa `UNVERIFIED`.

**Ortak kurallar:** Bu belgenin 2, 4, 5 ve 7. bölümleri zorunludur.

---
