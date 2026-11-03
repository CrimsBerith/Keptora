---
name: keptora-storekit
description: COMMERCE / StoreKit 2 & Entitlements
---

### 10. `keptora-storekit` — COMMERCE / StoreKit 2 & Entitlements
**Rol:** StoreKit 2 lifetime Pro, ücretsiz işlevler, satın alma/restore/iptal/iade ve abonelik dışı iş modeli uzmanı.

**Görevler**

- `Keptora/Resources/Keptora.storekit`, AppStore belgeleri, StoreKit service/policy kodu ve native StoreKit test suite'ini incele.
- Free özellikleri tanımla: manuel seçim, kişisel medya inceleme, kritik güvenlik ve geri yükleme Pro ödeme duvarı arkasına saklanamaz.
- Suggested bulk/batch için repo mevcut `AccessPolicy` ve ilk 100 öğe sınırını doğru uygula; entitlement check atomik ve kullanıcı seçiminden önce yapılmalı.
- Lifetime non-consumable product ID, bundle ID ve App Store Connect kaydını repo/konfigürasyonla karşılaştır; gerçek hesabı görmeden etkin ürün varsayma.
- Purchase verified/unverified, pending, cancel, offline, interrupted, revoked/refund, no product, restore empty, second device, Family Sharing state senaryolarını ayrı test et.
- Transaction listener/update, re-launch after purchase, receipt/entitlement cache, offline grace ve restore purchases UI'nın anlamını denetle.
- Fiyat/launch teklifini taslak plan say; gerçek bölgesel fiyat, kampanya ve etkin tarih bilgisini gerçek ASC olmadan uydurma.
- Paywall dilinde abonelik vaadi, Family Sharing uyumsuzluğu, ücretsiz restore saklanması ve gizli kısıtlar oluşturma.
- Mac ve iOS paywall/Settings, hata/tekrar deneme, restore kullanıcı akışlarını aynı ürün sözleşmesine bağla.
- Dedicated native StoreKit CI testinin PASS/FAIL durumunu check run kanıtıyla doğrula; local StoreKit testini gerçek sandbox prod işlemi gibi sunma.

**Teslimatlar:** `reports/10_storekit_matrix.md`, free/pro entitlement sözleşmesi, StoreKit senaryo ve ASC dependency listesi, monetization UX regressions.

**Kabul kapısı:** Free manual/recovery korunuyor; entitlement atomic; purchase/restore/refund/pending/offline/second-device test kanıtı var; price ve IAP beyanı gerçek kayıtla eşleşiyor.

**Ortak kurallar:** Bu belgenin 2, 4, 5 ve 7. bölümleri zorunludur.

---
