# Keptora hazırlık düzeltmeleri — 18 Ekim 2026

Sonraki genişletilmiş denetim, yeni veri/işlem regresyonları ve build 185: [ikinci kalite raporu](PROFESSIONAL_QA_2026-10-18.md). Bu dosya 184 çalışmasının tarihsel kaydıdır.

Yerel aday: **1.0.0 (184)**. Önceki 183 hazırlıkları `d9fce0e` commitinde değiştirilmeden saklandı. Düzeltmeler `codex/keptora-readiness-fixes` dalında; `main` ve gönderilmiş mağaza build'i değiştirilmedi.

## Kapatılan bulgular

| Bulgu | Düzeltme ve kanıt |
|---|---|
| R01 — Mac mimarileri | XcodeGen ve üretilen proje tutarlı. Debug aktif mimariyi, Release arm64 ve x86_64'ü kullanıyor. Varsayılan Debug komutunda mimari override olmadan 32 test geçti; Release arşivi iki mimariyi içeriyor. |
| R02 — Optimize testler | `ReleaseTesting`, `-O` optimizasyonuyla ve `KEPTORA_TESTING` tanımıyla test yardımcılarını derliyor. Shipping `Release` bu tanımı içermiyor. Mac 32, iPhone 29 test geçti. Debug tanımı Release'e eklenmedi. |
| R03 — Yayın zinciri | Paket kapısı kaldırılmış Phase 5 dosyalarını çağırmıyor; güncel doğrulayıcıları ve gerçek ortak çekirdek testlerini çalıştırıyor. Python betikleri interpreter ile çağrılıyor. Yayın kapısı tekil çıktı klasörü kullanıyor; eski arşivleri silmiyor, simülatöre gerçek corpus hazırlıyor ve iki platformu yerel olarak export ediyor. Runner başlangıcı da timeout ile sınırlı; timeout başarısız sonuç ve log bırakıyor. |
| R04 — Kurtarma uyarısı | iPhone tam kurtarma kataloğunu alıp sorun listesini saklıyor. Geçmiş ekranında kayıt bulunmasa da uyarı ve yeniden deneme var. Yeni native test sağlıklı kayıt + bozuk manifesti gerçek geçici dosyalarda doğruluyor; onarım sonrası uyarı kalkıyor, sağlıklı kaydın dosyası korunuyor. |
| R05 — Canlı web | Pazarlama, gizlilik ve destek sayfaları Hostinger'da güncellendi. iPhone/Mac, sınırlı Fotoğraflar izni, iCloud, kurtarma ve satın alma kapsamı yer alıyor. Üç canlı URL HTTPS 200 verdi ve gövdeleri yayın dosyalarıyla SHA-256 düzeyinde eşleşti. |
| R06 — Yayın tercihi | Kullanıcının otomatik yayını koruma tercihi yerel metadata'ya işlendi. App Store Connect ayarı değiştirilmedi. |
| R07 — Kaynak kaydı | Başlangıçtaki 14 dosya değişikliği ve 9 ekran görüntüsü, önceki denetim raporuyla birlikte ayrı committe korundu. Yeni kaynak, yapılandırma ve web yayın dosyaları aynı yerel dalda sürümleniyor. Yeni GitHub CI koşusu henüz yok; yerel kanıtlar aşağıda. |

Ek düzeltmeler: küçük thumbnail'da kesilen önizleme hata metni yerine erişilebilir açıklamalı simge; normal testlerde otomatik mağaza ekranı yazdırmanın kapatılması; explicit-self uyarısının giderilmesi; TipKit ilk kullanım durumunun donation koleksiyonu yerine kalıcı boolean parametresiyle tutulması. [Apple TipKit parametre kuralları](https://developer.apple.com/documentation/tipkit/tip/rule) bu uygulama biçimini destekler.

## Doğrulama

| Kontrol | Sonuç |
|---|---|
| Güncel paket kapısı | Geçti. 126 ortak çekirdek testi başarılı; isteğe bağlı büyük benchmark bu turda atlandı. |
| Mac Debug | 32/32 geçti; özel mimari seçenekleri yok. |
| Mac ReleaseTesting | 32/32 geçti; StoreKitTest satın alma ve restore dahil. |
| iPhone ReleaseTesting | 29/29 geçti; bozuk kurtarma kaydı regresyonu dahil. |
| Mac UI | 3/3 geçti: Ayarlar/Pro, kaldırma/geri alma/restore, dolu hedefte üzerine yazmama. |
| iPhone UI | 3/3 geçti: ilk kullanım ipuçları, standart/büyük yazıda seçim ve son inceleme hedefleri, Ayarlar → Pro → kapatma. |
| Yeni simülatör kurulumu | Hazırlık betiği ReleaseTesting/build 184 ile çalıştı. CLI izin komutu tek başına yeterli olmadı; ilk native medya testi bu yüzden durdu. Yayın kapısındaki gerçek Fotoğraflar UI izin adımı çalıştırıldı ve ardından birim testleri tekrar doğrulandı. |
| Shipping Release Analyze | İki platform geçti. Swift 6 kaynak uyarıları giderildi; yalnız kullanılmayan AppIntents metadata çıkarma uyarısı kaldı. |
| Build 184 arşivleri | İki platformda imzalı `ARCHIVE SUCCEEDED`; Info.plist build numaraları 184. |
| App Store yöntemiyle yerel export | Mac `.pkg` ve iPhone `.ipa` oluştu. Mac paket imzası kontrol edildi; IPA'nın build 184 ve tracking/collected-data içermeyen privacy manifesti doğrulandı. |
| Yapılandırma | XcodeGen tekrar üretimi deterministik. Debug/Release/ReleaseTesting etkin ayarları ayrı kaydedildi. Shell sözdizimi ve `git diff --check` temiz. |
| Timeout yardımcısı | Süre aşımında 124, özgün süreç hatasında 7 döndüğü ve logu koruduğu gerçek alt süreçlerle doğrulandı. |

Tam yayın betiği bu turda tek komut olarak baştan sona çalıştırılmadı; tabloda belirtilen bileşenler ayrı çalıştırıldı. Tam betiğin daha geniş UI seçkisindeki bütün testler geçti diye sayılmadı. Yerel StoreKitTest gerçek App Store sandbox/üretim satışı değildir.

## Çıktılar

- Paketler: `Build/ReleaseCandidates/1.0.0-184/Keptora-macOS.pkg` ve `Keptora-iPhone.ipa`.
- Paket boyutu ve SHA-256: aynı klasörde `packages.json`; kaynak commit bağlantısı `provenance.json`.
- Kalıcı yerel kanıtlar: `ValidationArtifacts/Mac/Fixes-20261018/` (loglar, test sonuçları, build ayarları, web eşleşmesi).
- Orijinal çalışma yedeği ve geçici derlemeler: `/tmp/keptora-fixes-20261018/`.
- Web üretimi: `Scripts/build_keptora_web.py`; yayın: `AppStore/Web/publish/keptora/`; önceki canlı sayfalar: `AppStore/Web/previous/`.

Canlı sayfalar: [ürün](https://alfagolab.com/keptora/), [gizlilik](https://alfagolab.com/keptora/privacy/), [destek](https://alfagolab.com/keptora/support/). Mevcut ortak tasarım dosyaları ve diğer ürünlerin sayfaları değiştirilmedi.

## Dağıtım sınırı

Build 184 App Store Connect veya TestFlight'a yüklenmedi; mevcut 183 başvurusu geri çekilmedi. GitHub'a push yapılmadı. Otomatik yayın tercihi korundu.

Fiziksel iPhone son cihaz kontrolünde offline. Gerçek cihazda silme/Recently Deleted kurtarması, iCloud/sınırlı erişim ve gerçek sandbox satın alma/restore kabulü bu turda tamamlanmadı. Desteklenen en düşük işletim sistemleri ve fiziksel Intel Mac kabulü de ayrı kalıyor. Kod ve yerel dağıtım paketlerinin hazır olması bu kabul alanlarını veya Apple onayını tamamlanmış yapmaz.
