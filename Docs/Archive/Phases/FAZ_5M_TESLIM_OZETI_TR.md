# Keptora Faz 5M Teslim Özeti

**Sürüm:** 0.9.3  
**Build:** 120  
**Platform:** macOS 13+ / SwiftUI / AppKit / SQLite / StoreKit 2

## Bu fazda eklenenler

- Kaynak kimliğine bağlı yerel inceleme checkpoint'i
- Home ve Review Insights üzerinden kaldığın yere dönme
- Uygulama pasif olduğunda otomatik checkpoint
- `⌘[` / `⌘]` ile exact grup değiştirme
- `⌥←` / `⌥→` ile grup içinde fotoğraf odağı değiştirme
- `⌘1`, `⌘2`, `⌘3` ile koru, plana ekle ve atla kararları
- `⇧⌘P` ve `⇧⌘S` ile SHA-256 exact-only toplu kararlar
- Gerçek tarayıcıyı kullanan, cihaz üzerinde üretilen özel örnek fotoğraf arşivi
- Karar sayısı, tamamlanan grup, yerel inceleme hızı ve planlanan alan için telemetry'siz metrikler
- App Review için deterministik demo rehberi ve 20 senaryolu test matrisi

## Korunan güvenlik kuralları

- Benzer fotoğraflar otomatik Safety Plan oluşturamaz.
- Toplu işlem yalnız byte-identical SHA-256 gruplarında çalışır.
- Keeper hiçbir batch operasyona dahil edilmez.
- Ücretsiz 100 karar sınırı persistence öncesinde atomik kontrol edilir.
- Restore, Pro hakkı olmasa da erişilebilir kalır.
- Kalıcı silme, Finder Trash ve Apple Photos delete API'si yoktur.
- Checkpoint ve kalite metrikleri yalnız cihazda kalır.

## Bu ortamda geçen doğrulamalar

- 61 Swift kaynak/test dosyasının parser kontrolü
- Xcode kaynak referans kontrolü
- Info.plist, entitlements, privacy manifest ve JSON resource kontrolleri
- SQLite schema v4 ve source isolation smoke testi
- RAW/JPEG/XMP, Live Photo, burst, edited/export family graph smoke testi
- Recovery ve changed-prefix restart testi
- Similarity candidate/calibration/safety smoke testi
- Review checkpoint Codable ve metrik smoke testi
- Saklanan 100K similarity benchmark doğrulaması
- Kalıcı silme API taraması
- 155 localization anahtarı
- 22 kaynaklı rakip kaydı

## Açık gerçek release kapıları

Xcode compile/link, XCTest/UI test, analyzer, code signing, Release Archive, StoreKit sandbox, VoiceOver, Full Keyboard Access, gerçek 10K/50K/100K arşiv benchmark'ı, final screenshot ve App Store Connect submission bu ortamda yapılmadı.
