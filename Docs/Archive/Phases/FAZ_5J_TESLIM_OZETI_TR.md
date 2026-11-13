# Keptora Faz 5J Teslim Özeti

## Eklenenler

- Benzer fotoğraflarda iki görseli aynı yakınlaştırma ve kaydırmayla yan yana karşılaştırma.
- Doğruluk öncelikli, dengeli ve keşif benzerlik profilleri.
- Profiller kayıtlı kalibrasyon sınırını yalnız daraltabilir; genişletemez.
- StoreKit 2 ömür boyu satın alma, entitlement kontrolü ve satın almayı geri yükleme akışı.
- İngilizce/Türkçe string catalog altyapısı.
- Görsel önizleme ve karşılaştırma alanları için erişilebilirlik etiketleri.
- Sürüm 0.9.0, build 90.
- Kod tabanında kalan PhotoKit kalıcı silme yöntemi tamamen kaldırıldı.
- Bundle ID, Team ID ve StoreKit product ID için güvenli yapılandırma scripti.
- Xcode test + archive için fail-closed release gate.

## Dürüst durum

Kaynak kod ve Linux üzerinde çalışabilen çekirdek testler doğrulandı. Ancak bu ortamda macOS SDK, AppKit/Vision/StoreKit runtime, code signing ve Xcode Archive çalıştırılamadı. Bu nedenle paket imzalı ve App Store'a hazır binary olarak tanımlanamaz. `RELEASE_BLOCKERS.md` içindeki Mac testleri tamamlanmalıdır.
