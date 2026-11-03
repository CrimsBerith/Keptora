# Keptora — Safety & Threat Model Report
**Agent:** 05 `keptora-safety-recovery` (GUARDIAN / Cleanup, Quarantine & Restore)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED (Tüm P0 ve P1 Tehditleri Karşılandı)

---

## 1. Dört Katmanlı Güvenlik Kapısı (Safety Gates)
1. **Katman 1 - Revizyon ve Anlık Görüntü Doğrulaması (Snapshot Lock):**
   - Tarama anındaki dosya `inode`, `ctime`, `mtime`, `byteCount` ve Photos `modificationDate/creationDate/isFavorite` değerleri kilitlenir.
   - Temizleme anında `LibraryRevisionValidator.validate(snapshot)` (`MacArchiveModel.swift:800`, `MobileKeptoraStore.swift:988`) çalıştırılır; dosyada herhangi bir dış değişiklik olmuşsa işlem derhal durdurulur (TOCTOU koruması).
2. **Katman 2 - Açık Kullanıcı Onay Modalı:**
   - Asla arka planda, zamanlayıcıyla veya otomatik çalışan bir silme işlemi yoktur.
   - macOS: `confirmationDialog("Remove selected items?")` (`MacArchiveView.swift:783-792`). Seçilen öğe sayısı ve bayt açıkça belirtilir.
   - iOS: `.alert("Remove selected items?")` (`MobileArchiveView.swift:1219-1230`).
3. **Katman 3 - Sistem İzin Kapısı & Ön Kontrol:**
   - Photos: Apple'ın yerel sistem uyarısı ("Delete [X] photos and iCloud Photos on all your devices") kullanıcıdan onay almadan hiçbir işlem yürütülemez.
   - Files: Taşıma öncesi SHA-256 doğrulaması yapılır.
4. **Katman 4 - Koordineli Taşıma ve Telafi (Rollback):**
   - `NSFileCoordinator` ile taşınır. Taşıma sonrası SHA-256 doğrulaması uyuşmazsa geri alma (compensation rollback) tetiklenir.

---

## 2. Karantina ve Geri Yükleme Mimarisi
- **Apple Photos (PhotoKit):**
  - Kaldırılan fotoğraflar `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(fetched) }` ile Apple'ın sistem denetimindeki **"Recently Deleted" (Son Silinenler)** albümüne aktarılır (30 gün süreyle kurtarılabilir).
  - iCloud Photos etkinse tüm cihazlarda güvenle senkronize olur.
- **Dosyalar / Klasörler (Folder Quarantine):**
  - Dosyalar kalıcı olarak silinmez; aynı disk bölümündeki `.Keptora Quarantine/<UUID>/` klasörüne taşınır.
  - **Açık İletişim Kuralı:** UI kullanıcıya `"Space is not freed right away"` uyarısını zorunlu gösterir (`MacArchiveView.swift:805`).
- **Ön-Kayıtlı Manifest (Write-Ahead Ledger):**
  - İlk bayt taşınmadan önce `.Keptora Quarantine/<UUID>/recovery.json` diske atomik yazılır (`FolderQuarantineExecutor.swift:70`).
  - Uygulama çökse veya ayarlar sıfırlansa dahi `FolderQuarantineExecutor.recoveryCatalogue(root:)` diski doğrudan tarayarak tüm karantinaları bulur ve kurtarır.
- **Üzerine Yazmama Güvencesi (No-Overwrite Invariant):**
  - `FolderQuarantineExecutor.swift:193-195`:
    ```swift
    let inRecovery = FileManager.default.fileExists(atPath: operation.quarantineURL.path)
    let atOriginal = FileManager.default.fileExists(atPath: operation.originalURL.path)
    if operation.state == .restored && !inRecovery { continue }
    guard inRecovery != atOriginal else {
        throw UniversalScanError.cleanupNotPermitted("Restore stopped because an original path is occupied or quarantine content is missing.")
    }
    ```
  - Hedef konumda aynı isimde dosya varsa geri yükleme kesinlikle reddedilir; üzerine yazılmaz. Test kanıtı: `testFolderRestoreFailsClosedWhenOriginalPathIsOccupied`.

---

## 3. Korunan Öğe (Keeper) ve Manuel Seçim Ayrımı
- **Keeper Belirleme Hiyerarşisi (`UniversalKeeperPolicy.swift:205-255`):**
  1. Favori (`isFavorite` +10,000)
  2. Düzenlenmiş (`hasAdjustments` +5,000)
  3. Paylaşılan kütüphane (`isSharedLibraryAsset` +2,000)
  4. Gizli öğe (`isHidden` +1,000)
  5. Çözünürlük (`pixelWidth * pixelHeight`)
  6. Dosya boyutu ve süre
- **Öneri ile Manuel Seçim Ayrımı:**
  - Önerili toplu temizlik (`PhotosRemovalIntent.suggestedCopies`): Korunan veya favori öğelerin silinmesini **kesinlikle engeller**.
  - Manuel tekil seçim (`PhotosRemovalIntent.manualSelection`): Kullanıcı kendi hür iradesiyle seçtiğinde özel uyarı ile işleme izin verir (`"Includes favorites, hidden, edited or shared items you selected manually"`).

---

## 4. Tehdit Modeli ve Güvenlik Matrisi (P0-P3)
| Tehdit ID | Vektör | Seviye | Doğrulama & Kod Yolu | Sonuç |
|---|---|---|---|---|
| **TM-01** | Sessiz / Otomatik Veri Kaybı | **P0** | UI onay dialogu + sistem izin kapısı zorunlu. Otomatik silme yolu yok. | **MITIGATED (PASS)** |
| **TM-02** | Geri Yüklemede Orijinalin Üzerine Yazma | **P0** | `inRecovery != atOriginal` kontrolü; dolu yol varsa durdurur. | **MITIGATED (PASS)** |
| **TM-03** | TOCTOU / Taşıma Sırasında Dosya Değişimi | **P1** | Pre-flight hash + `NSFileCoordinator` + post-move hash. | **MITIGATED (PASS)** |
| **TM-04** | Çökme / Kesilen Karantina | **P1** | İlk bayttan önce write-ahead `recovery.json` yazılır. | **MITIGATED (PASS)** |
| **TM-05** | Eksik Dosya Ailesi (Orphan XMP/RAW) | **P1** | `LibraryFileFamilies.omittedCompanions` parçalı taşımayı engeller. | **MITIGATED (PASS)** |
| **TM-06** | Hard Link ctime Geçersizliği | **P2** | Fiziksel inode revizyon takibi döngüde güncellenir. | **MITIGATED (PASS)** |
| **TM-07** | Ayarlar Sıfırlandığında Kurtarmanın Kaybolması | **P2** | `recoveryCatalogue(root:)` dosya sisteminden dinamik keşif yapar. | **MITIGATED (PASS)** |

