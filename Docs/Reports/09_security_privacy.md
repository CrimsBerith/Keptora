# Keptora — Security & Privacy Audit Report
**Agent:** 09 `keptora-privacy-security` (SHIELD / Security & Privacy)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED PASS (Sıfır Ağ Çağrısı, Tam İzolasyon)

---

## 1. Local-First ve Sıfır Ağ İletişimi (Zero Network)
- **Ağ Çerçeveleri Taraması:** `URLSession`, `Network.framework`, `CFNetwork`, ham soket çağrıları: **0 adet** (`Keptora/`, `KeptoraiOS/`, `Packages/KeptoraCore/`).
- **Üçüncü Parti SDK:** Firebase, Google Analytics, Facebook SDK, Crashlytics vb. hiçbir dış kütüphane **bulunmamaktadır**. %100 yerli Swift ve Apple sistem çatıları.
- **On-Device ML & Vision:** Apple Vision feature print, SHA-256 hesaplama ve CoreGraphics çizimleri tamamen cihaz üzerinde çalışır.
- **Ağ İstemci Yetkisinin İptali:** `Keptora/Resources/Keptora.entitlements` içinden `com.apple.security.network.client` **kaldırılmıştır**. macOS ikili dosyası işletim sistemi düzeyinde dışarıya soket açamaz.
- **Hardened Runtime:** Release yapılandırmasında `ENABLE_HARDENED_RUNTIME = YES` etkindir.

---

## 2. Gizlilik Manifesti (`PrivacyInfo.xcprivacy`) Uyumu
- `Packages/KeptoraCore/Sources/KeptoraCore/Resources/PrivacyInfo.xcprivacy`:
  - `NSPrivacyTracking`: `false`
  - `NSPrivacyTrackingDomains`: `[]`
  - `NSPrivacyCollectedDataTypes`: `[]` (Kullanıcıdan hiçbir veri toplanmaz).
  - `NSPrivacyAccessedAPITypes`:
    - `NSPrivacyAccessedAPICategoryFileTimestamp`: geçerli Apple gerekçeleri `3B52.1`, `C617.1`, `DDA9.1`
    - `NSPrivacyAccessedAPICategoryUserDefaults`: gerekçe `CA92.1`
- Belgelenmemiş veya izinsiz API (`systemUptime`, `volumeAvailableCapacity`, vb.): **0 eşleşme**.

---

## 3. Tehdit Modellemesi ve İzolasyon (STRIDE)
- **Path Traversal / Symlink Saldırıları:** Klasör kapsamları `security-scoped bookmark` ve `LibraryFileIdentity` ile sınırlandırılmıştır; symlink ile dışarı taşma engellenmiştir.
- **Bilgi Sızıntısı:** Tanılama (diagnostics) çıktısında dosya tam yolları, kullanıcı ev dizini adları, EXIF GPS ve hash değerleri maskelenir (`testUnifiedDiagnosticsRedactPathsNamesAndRawErrors` PASS).
- **Destructive Overwrite:** Orijinal konum doluysa geri yükleme güvenle durur (`testPartialRollbackPreservesRecoveryReceipt...` PASS).
- **Public URL'ler:** Yalnızca HTTPS ve geliştirici resmi alan adı: `https://alfagolab.com/keptora/privacy`, `https://alfagolab.com/keptora/support`.

