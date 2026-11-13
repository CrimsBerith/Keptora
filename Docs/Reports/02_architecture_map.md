# Keptora — Architecture & Swift Data Integrity Report
**Agent:** 02 `keptora-architecture` (ARCHITECT / Swift & Data Integrity)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED PASS (Temiz Paket Ayrımı, Complete Concurrency ve Tip Güvenliği)

---

## 1. Mimari Katmanlar ve Paket Yapısı
- **Ortak Çekirdek (`Packages/KeptoraCore`):**
  - Platformdan bağımsız iş mantığı, tarama, SHA-256 hash motoru, Vision benzerlik analizcisi, karantina yöneticisi ve veri modellerini içerir.
  - Swift Package (`Package.swift`, tools-version 5.9, macOS 13+, iOS 17+).
  - Bağlı çerçeveler: `Photos`, `ImageIO`, `AVFoundation`, `Vision`, `CryptoKit`.
  - Linux ortamında temel modeller ve testler Apple framework stubs olmadan çalışabilir.
- **Sıkı Eşzamanlılık (Strict Concurrency):**
  - `project.yml` genelinde `SWIFT_STRICT_CONCURRENCY: complete` tanımlanmıştır. Tüm hedefler Swift 6 eşzamanlılık standartlarına hazırdır.
- **Masaüstü Katmanı (`Keptora/`):**
  - SwiftUI + AppKit (`MacArchiveModel`, `MacArchiveView`).
  - Çift pencereli oturum izolasyonu (`MacWindowIdentity.main` ve `fallbackWindow`).
  - Klavye komut köprüsü (`MacGalleryKeyboardMonitor`, `MacLibraryCommands`).
- **Mobil Katmanı (`KeptoraiOS/`):**
  - SwiftUI (`MobileKeptoraStore`, `MobileArchiveView`).
  - 1:1 normalize galeri ızgarası ve `LiquidGlassFilterButton`.
- **Gelişmiş Araçlar İzolasyonu (Legacy / Advanced SQLite):**
  - `AppModel`, `SQLiteDatabase`, `ScanCoordinator`, `QuarantineCoordinator`.
  - Birincil kullanıcı galerisinden tamamen yalıtılmış olup sadece gelişmiş rota seçildiğinde devreye girer.

---

## 2. Eşzamanlılık (Concurrency), Actor ve Sendable Mimarisi
- **Arka Plan Servis Actor'ları:**
  - `PhotoLibrarySourceAdapter`, `FolderSourceAdapter`, `UnifiedLibraryAdapter`, `FolderQuarantineExecutor`, `MediaFingerprintDiskCache`, `LibraryAnalysisCoordinator`, `FolderWatchdogService`, `MediaWorkGate` hepsi Swift `actor` olarak izoledir.
- **UI Ana İş Parçacığı (MainActor) Sınırları:**
  - `MacArchiveModel`, `MobileKeptoraStore`, `StoreEntitlementController`, `MobilePurchaseController`, `LibraryOperationCoordinator`, `MacSourceAccessCoordinator` `@MainActor` ile korunur.
- **Bellek Koruma Kapısı (`MediaWorkGate`):**
  - Bounded admission actor (en fazla 4 eşzamanlı decode işlemi) ile görsel ve video kare çözümlemelerinde cihaz belleğinin tükenmesini (OOM) engeller.
- **Senkronize `@unchecked Sendable` Yapıları:**
  - `LockedPhotoHasher`: `NSLock` ile korunur.
  - `SingleShotContinuation`: `NSLock` ve `isResumed` korumasıyla güvenli devamlılık sağlar.
  - `CancellablePhotosRequest`: `PHImageManager` isteklerini iptal anında temizler.
  - `MobileThumbnailCache` & `MacArchiveThumbnailCache`: `NSCache` tabanlı iplik-güvenli bellek önbelleği.

---

## 3. Kalıcılık Sözleşmeleri ve Veri Bütünlüğü
1. **Kritik Kullanıcı Durumu (`LibraryRepository<Value>`):**
   - Konum: `~/Library/Application Support/Keptora/`
   - Atomik disk yazımı (`Data.write(..., options: .atomic)`).
   - Otomatik `.backup` yedekleme. Bozulma durumunda `.unreadable-<UUID>` olarak izole edilir ve geçerli yedek korunur.
2. **Analiz Kontrol Noktaları (`LibraryCheckpointArchive`):**
   - Her 100 öğede veya 2 saniyede bir tarama ilerlemesini kaydeder. Kesinti sonrası güvenle devam etmeyi sağlar.
3. **Parmak İzi Disk Önbelleği (`MediaFingerprintDiskCache`):**
   - `Caches/KeptoraCache/media_fingerprints_v4.json`.
   - Limit: Maksimum 10.000 kayıt, 64 MB bütçe. LRU mantığıyla %90 eşiğine budanır.
   - Önbellek anahtarları `inode`, `ctime` ve dosya boyutuna bağlıdır (`MediaRevisionPolicy`).
4. **50 Adımlık Geri Al / Yinele (Bounded Undo/Redo):**
   - Kullanıcı seçimleri ve keeper tercihleri atomik 50 adımlık yığında saklanır.
   - Silinmiş/erişilemeyen ID'lerin hayalet öğe olarak geri gelmesi engellenmiştir.

---

## 4. Mimari İyileştirme Önerileri (Backlog)
- **ARCH-01 (P1):** `MacArchiveModel.swift` (1.142 satır) ve `MobileKeptoraStore.swift` (1.517 satır) büyük view-model'lerdir. İlerleyen fazlarda `MobileSelectionCoordinator` ve `MacProjectionEngine` gibi alt koordinatörlere bölünmesi kod okunabilirliğini artıracaktır.
- **ARCH-02 (P3):** Kod içinde kalan bazı inline storage anahtarları (`"Keptora.UnifiedFolderBookmarks.iOS"` vb.) `AppStorageKeys.swift` içine toplanmalıdır.
