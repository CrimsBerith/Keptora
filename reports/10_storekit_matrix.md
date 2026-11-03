# Keptora — StoreKit 2 & Commerce Report
**Agent:** 10 `keptora-storekit` (COMMERCE / StoreKit 2 & Entitlements)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED PASS (Kırmızı Çizgi 8 Tam Uyumlu)

---

## 1. Ürün Yapılandırması ve İş Modeli
- **Ürün Kimliği:** `com.keptora.app.pro.lifetime` (Mac ve iOS için tekil birleşik Non-Consumable IAP).
- **Abonelik Yok:** Kesinlikle yinelenen abonelik eklenmemiştir; tek seferlik ömür boyu kilit açma modelidir.
- **Konfigürasyon Dosyası:** `Keptora/Resources/Keptora.storekit` (StoreKit v4.0).
- **Family Sharing:** `familyShareable: false` (Guideline 3.1.2 retlerini önlemek için devre dışı).

---

## 2. Kırmızı Çizgi 8: Ücretsiz Temel Haklar (Never Paywalled)
- **Asla Ödeme Duvarına Alınmayan Temel İşlevler:**
  - Tüm fotoğraf ve video arşivinde serbestçe gezinme, filtreleme ve sıralama.
  - Kesin kopya, benzerlik, video ve kalite taramalarını sınırsız çalıştırma.
  - Herhangi bir fotoğrafı/videoyu **manuel tekil olarak seçme**.
  - Manuel seçilen öğeleri Apple Photos onayıyla veya klasör karantinasıyla **ücretsiz temizleme**.
  - Karantinaya alınan dosyaları **ücretsiz ve sınırsız geri yükleme**.
- **Pro Kapsamı (`AccessPolicy.swift`):**
  - Ücretsiz sürüm, öneri tabanlı toplu seçimler (`Select Extra Copies`, `Select Others`) için ilk **100 öğeye** izin verir.
  - Lifetime Pro satın alımı bu 100 öğelik toplu öneri sınırını kaldırır.

---

## 3. StoreKit 2 Mimarisi ve Çevrimdışı Dayanıklılık
- **Atomik Kontrol:** `Transaction.currentEntitlements` üzerinden atomik kontrol edilir.
- **Arka Plan Dinleyicisi:** `Transaction.updates` ile arka planda tamamlanan işlemler anında yakalanır ve bitirilir (`finish()`).
- **Çevrimdışı Güven:** `refreshEntitlement()` ağ çağrısı yapmadan önce yerel makbuz önbelleğini okur. Pro kullanıcılar uçak modunda veya internet yokken Pro haklarını kaybetmez.
- **Satın Almaları Geri Yükle (Restore Purchases):** Hem macOS hem iOS Ayarlar ve Paywall ekranlarında mevcuttur.

---

## 4. Test Kanıtları (13/13 PASS)
- `StoreKitEntitlementTests.swift` (6 test PASS - 4.51s):
  - `testProductLoadingAndConfiguration`
  - `testSuccessfulPurchaseUnlocksLifetimeAccess`
  - `testRestorePurchasesWhenTransactionExists`
  - `testRestorePurchasesWhenNoTransactionExists`
  - `testCachedEntitlementPersistsAcrossRefreshes`
  - `testRetryRefreshClearsPriorStatusMessage`
- `AccessPolicyTests.swift` (7 test PASS):
  - `testFreePolicyAllowsFirstHundredUniqueReviews`
  - `testFreePolicyBlocksNewReviewAfterLimitButAllowsExistingAsset`
  - `testBatchReviewAuthorizationFailsAtomicallyWhenLimitIsTooSmall`
  - `testLifetimePolicyIsUnlimited`

