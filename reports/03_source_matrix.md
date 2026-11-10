# Keptora — Source Matrix & Permissions Report
**Agent:** 03 `keptora-sources` (SOURCE / Photos, Files, iCloud & Permissions)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED PASS (PhotoKit ve Dosya Sistemi İzinleri Tam Uyumlu)

---

## 1. PhotoKit Entegrasyonu ve İzin Modları (`PhotoLibrarySourceAdapter.swift`)
- **Tüm İzin Durumları:**
  - `.notDetermined`: İlk açılışta açık izin talebi.
  - `.restricted` / `.denied`: Çökme olmaz; açıklayıcı durum ekranı ve "Ayarları Aç" butonu sunulur. Sürekli tekrar uyarı fırlatılmaz (`testPhotosAuthorizationRoutingNeverRequestsAgainAfterDenial` PASS).
  - `.limited`: `PHPhotoLibraryPreventAutomaticLimitedAccessAlert: true` ile sistem müdahalesi engellenir. `presentLimitedLibraryPicker(from:)` ile kullanıcı seçimini güncelleyebilir. Seçilmeyen öğeler `pendingSelection` olarak izole edilir, asla silinmiş varsayılmaz.
  - `.authorized`: Tüm kütüphaneye tam erişim.
- **Değişiklik Dinleyicileri (Change Observers):**
  - macOS: `MacArchivePhotoObserver` (`PHPhotoLibraryChangeObserver`).
  - iOS: `MobilePhotoChangeObserver` (`init`'te kaydolur, `deinit`'te temizlenir).
- **Apple Recently Deleted Silme Akışı:**
  - Silme çağrısı: `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(fetched) }`.
  - Kullanıcı sistem onayında "Vazgeç" derse (`NSUserCancelledError` / hata kodu 3072), işlem geri alınır ve durum bozulmaz.

---

## 2. Dosya Sistemi, Harici Diskler ve İzin Kapsamları (`FolderSourceAdapter.swift`)
- **macOS Güvenlik Kapsamlı Yer İmleri (Security-Scoped Bookmarks):**
  - `NSOpenPanel` ile dizin seçimi -> `.withSecurityScope` bookmark oluşturulur.
  - `MacSourceAccessCoordinator`, `startAccessingSecurityScopedResource()` ve `stopAccessingSecurityScopedResource()` çağrılarını dengeli yönetir.
- **iOS Belge Seçici (Document Picker):**
  - `DirectoryPicker`, `UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)` sarar ve bookmark'ı güvenle saklar.
- **Symlink ve Yol Sıçraması (Directory Traversal) Koruması:**
  - `values?.isSymbolicLink != true`: Sembolik bağlar (symlinks) kesinlikle atlanır.
  - `LibraryFileIdentity.relativePath`: `..` içeren dizin sıçrama yollarını derhal reddeder.
- **Fiziksel Disk Kimliği (Volume Identity):**
  - `volumeUUIDStringKey` + fiziksel inode (`systemFileNumber`) ile dosya kimliği bağlanır.
  - Aynı yola sonradan bağlanan farklı bir disk, eski disk olarak kabul edilmez ve yeniden bağlantı istenir.

---

## 3. iCloud ve Çevrimdışı İzolasyon
- **Sıfır Ağ Çıkışı (Zero Network Egress):**
  - `com.apple.security.network.client` yetkisi kaldırılmıştır. Kod içinde `URLSession` çağrısı **sıfırdır**.
- **iCloud Orijinalleri:**
  - `FolderSourceAdapter`: `isUbiquitousItem == true && ubiquitousItemDownloadingStatus == .notDownloaded` durumunda `allowNetwork` kapalıysa `UniversalScanError.networkRequired` döner.
  - `PhotoLibrarySourceAdapter`: `isNetworkAccessAllowed = allowNetwork` parametresiyle kullanıcı onayı olmadan hücresel veya WiFi indirmesi başlatılmaz.

---

## 4. WhatsApp ve Özel Uygulama Ayrımı (Kırmızı Çizgi 7)
- WhatsApp'ın özel uygulama veritabanına veya sohbetlerine erişim veya temizlik **kesinlikle yoktur**.
- `MetadataDoctor.swift`: Yalnızca kullanıcı tarafından galeriye kaydedilmiş dosya adlarındaki regex tarih formatlarını (ör. `WhatsApp Image 2024-01-01...`) ayrıştırmak için kullanılır.
