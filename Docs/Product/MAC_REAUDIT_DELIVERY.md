# Mac yeniden denetimi — uygulama ve doğrulama teslimi

7 Ekim 2026 · `feat/photo-cleaner-library` · başlangıç revizyonu `7a19e1101b6f1bc676721c6d6260ead0318e97d7`.

[Başlangıç denetimindeki](MAC_PROFESSIONAL_REAUDIT.md) R01–R20 için kod değişiklikleri uygulandı. Bu, native derleme, gerçek cihaz ekranları veya gerçek arşiv performansının onaylandığı anlamına gelmez. Linux doğrulaması aşağıda ayrı; kullanıcı tarafından yapılacak Xcode/Mac/iPhone kabul adımları en sonda. Dal `main` ile birleştirilmez.

## Bulguların karşılığı

| ID | Uygulanan değişiklik | Doğrulama ve sınırı |
|---|---|---|
| R01 | Üç catch bloğunda hata alanı `self.error` ile açıkça hedefleniyor. | Swift parse geçti; Mac hedefinin tip kontrolü/derlemesi Xcode'da yapılmalı. |
| R02 | Dosya snapshot/cache anahtarına fiziksel kimlik ve nanosecond ctime revizyonu eklendi. Hash öncesi/sonrası doğrulama ve bilinen incelenmiş digest kontrolü var. Tokensız eski snapshot yeniden inceleme ister. | Gerçek dosyada aynı boyut/mtime ile atomik değişim, yerinde değişim, eski kayıt ve hash sırasında mutasyon ortak testleri geçti. |
| R03 | Varsayılan politika analizörün ölçülen kalite önerisini korur. Koruma ve açık saklama stratejileri önceliklidir; neden metni kullanılan politikaya uyar. | Ortak keeper/kalite/strateji testleri geçti. Gerçek görsel corpus doğruluğu native kabulde. |
| R04 | Sonuç tamamlanan, başarısız ve denenmeyen ID'leri ayırır. Son inceleme tamamlananları çıkarır; kalan öğeler açık yeniden inceleme olmadan tekrar kaldırılmaz. | Frozen review/kalan seçim testleri geçti. PhotoKit başarı + klasör hatası native kabulde. |
| R05 | Kalıcı kayıt-sağlığı uyarısı, kayıt hatasında karar/kaldırma engeli, retry ve okunamayan özgün kayıtları koruyarak onarma eklendi. Başarısız flush çıkışı iptal eder. | Ortak repository testleri geçti. Bozuk primary/backup ve yazma hatası için Mac model testleri eklendi; Xcode'da çalıştırılmalı. |
| R06 | Ana ve gelişmiş Mac motoru aynı kaynak/volume read/write sahibini kullanır. Quit yeni işleri engeller; iki motorun tarama ve onaylanmış taşıma işleri beklenir. | Ortak lease/çatışma/quit testleri geçti. Native iki-motor ve işlem sırasında quit kabulü gerekli. |
| R07 | Sağlıklı ve bozuk/unsafe kurtarma kayıtları ayrı döner; biri diğerini gizlemez. Tamamlanmış restore makbuzu sonraki düzenleme/rename nedeniyle bozulmaz. | Apple recovery testleri eklendi; Linux'ta çalıştırılmadı. Payload otomatik silinmez. |
| R08 | Her restore taşımasının hemen öncesinde taze hash/revizyon, sonrasında hedef hash kontrol edilir; ancak sonra makbuz kaydedilir. İptal/compensation kayıtla uzlaştırılır. | Geç mutasyon, hedef mutasyonu ve child-task iptali testleri eklendi; Apple dosya koordinasyonu Xcode'da doğrulanmalı. |
| R09 | Hard link fiziksel kimliği ile directory-entry seçim kimliği ayrıldı. Kendi taşıması sonrası sibling ctime değişimi, özgün digest korunarak uzlaştırılır. | Gerçek hard-link kimlik testi geçti. İki entry quarantine/restore Apple testi eklendi. |
| R10 | Sorunlu öğe filtresi, rozetler, Finder/erişim/tarama/cloud eylemleri, ayrı aşama hataları ve sunum sahibi eklendi. Issue/stage kimlikleri cache'de saklanır; tanılama redaction korunur. | Ortak filtre testleri geçti. Mac cache yeniden açılış ve redaction testleri Xcode'da çalıştırılmalı. |
| R11 | Koru tercihi manuel/toplu seçimi engeller; açık Korumayı Kaldır ve Seç eylemi vardır. | Mac koruma/undo testi eklendi; ortak öneri koruması testleri geçti. |
| R12 | Öneri adetleri seçili kaynakları sayar. Kategori açılışı arama/albüm/medya filtrelerini açıklayarak temizler; kaynak tikleri ve sepet korunur. | Kapsam/reset/sepet Mac model testi eklendi. |
| R13 | Kopya/benzer ilişkileri, saklama rozeti ve Koru/Sakla eylemleri zaman sıralamasında da korunur. | Projection üyelik/keeper Mac model testi eklendi. |
| R14 | Duraklatıldı metni öncelikli; Devam ve İptal galeri ve Öneriler'de var. Enumerasyon pause/cancel kontrolüne uyar; iptal işçi bitmeden idle sayılmaz. | Ortak pause/cancel testleri geçti; native enumerasyon/quit kabulü gerekli. |
| R15 | Muhtemel blur, düşük çözünürlük, karanlık, aşırı parlaklık ve sorunlu öğeler için adetli bağımsız filtreler eklendi. Kalite önerisi otomatik silme değildir. | Ortak kalite/filtre testleri geçti; gerçek portre/bokeh/gece corpus'u ile insan doğrulaması gerekli. |
| R16 | Arama, filtre, tarama ve kaynak özeti sabit üst kontrollere taşındı. Ayrıntılar tek Kaynaklar panelinde; filtreler tek tek kaldırılabilir; Cmd-F aramayı odaklar. | Swift parse geçti. 900×650 pencere, uzun TR/FR/DE metinler ve erişilebilirlik native görsel kabulde. |
| R17 | 50 adımlı seçim/karar Undo/Redo, native UndoManager ve grid Cmd-Z/Cmd-Shift-Z eklendi. Metin editörünün undo'su korunur; busy model çağrısı geçmişi tüketmez. | Ortak 3.000 işlem/bounded history testleri geçti. Mac model ve metin/grid UI testleri eklendi. |
| R18 | Toolbar ve Cmd-comma aynı native Ayarlar'ı açar. Pro sheet başlatan pencereye bağlıdır; Dock reopen ana pencere kimliğini hedefler. | Paywall host model testi ve yalnız Ayarlar açıkken Pro UI testi eklendi; Xcode'da çalıştırılmalı. |
| R19 | Kullanıcı durumu ve büyük analiz/cache ayrı yazılır. Kaynak içi 100 öğelik batch, cache'li galeri/albüm/issue projeksiyonu, 120 ms arama debounce ve metadata-first recovery refresh var. Pozisyon asenkron yükleme sonrası uygulanır. | Mac 3.000 öğe projection reuse/cache ayrımı testleri eklendi. Gerçek FPS/p95/RSS/enerji ölçülmedi. SwiftUI modelin tüm değişimlerini hâlâ gözler; daha fazla parçalama ölçüme göre yapılmalı. |
| R20 | Karar nedenleri, cleanup durumları ve interpolasyonlu grup metinleri uygulama diline bağlandı. Validator bilinen dinamik metin haritalarını da kontrol ediyor. | EN/TR/FR/DE 661 metin anahtarı ve format parametreleri geçti. Dört dil native model testi eklendi; ekranda plural/layout kabulü gerekli. |

## Bu ortamda geçen kontroller

- `swift test --package-path Packages/KeptoraCore`: **82 test, 0 hata**; önceki 69 teste 13 regresyon testi eklendi. Apple-only recovery/PhotoKit/AVFoundation/Vision testleri bu sayıya dahil değildir.
- **141 Swift dosyası** parse kontrolü: 0 sözdizimi hatası. Parse, Apple SDK tip kontrolü yerine geçmez.
- `Scripts/validate_mac_localization.py`: **661** sabit/haritalı anahtar EN/TR/FR/DE.
- `Scripts/validate_project_references.py`: Swift kaynakları Xcode projesinde mevcut.
- `Scripts/validate_photo_cleaner_assets.py`: yüksek çözünürlük, asset referansları ve format parametreleri geçti.
- `Scripts/validate_regenerated_visuals.py`: mevcut **67** yolun hash/boyut/corpus/ZIP sözleşmesi geçti. Bu görevde yeniden görsel üretilmedi. Manifest **54 asset, 12 tasarım önizlemesi, 1 kasıtlı bozuk test dosyası** içerir; 12 önizleme native App Store ekran görüntüsü değildir.
- `Scripts/validate_review_session_core_linux.sh`: checkpoint encode/decode ve sayısal ilerleme smoke testi geçti. Script ortak paket bağımlılığını derleyip bağlar; Linux metin uyumluluk yardımcısı Apple yerelleştirmesi testi sayılmaz.
- `git diff --check`: geçti.

Toplam **40 katalog girdisi** eklendi/tamamlandı. Önceki katalog sırası ve diğer çevirilerin içeriği korunur.

## Hazırlanan native testler

[Apple workflow](../../.github/workflows/apple-validation.yml), ortak Apple paketini, Mac/iPhone birim testlerini ve ürün UI testlerini çalıştıracak şekilde güncellendi. Bu turda 6 Apple recovery testi, 8 Mac model testi ve 2 Mac UI testi eklendi; mevcut Undo/Redo ve metin-editör testleri genişletildi. Linux'ta native testler çalıştırılmadı.

Önceki [Actions çalışması](https://github.com/CrimsBerith/Keptora/actions/runs/37395882608) hesap ödeme/harcama limiti nedeniyle job başlamadan engellendi. Güncel push sonrası durum teslim mesajında ayrıca belirtilir; workflow hazırlığı başarılı native sonuç yerine gösterilmez.

7 Ekim'de Apple runner başladı. İlk [çalışma](https://github.com/CrimsBerith/Keptora/actions/runs/37611135154) ortak Apple kodunu derledi; recovery testleri Mac yol alias'larının (`/var` / `/private/var`) ve artık mevcut olmayan özgün dosya yolunun tutarsız ele alındığını gösterdi. Kaynak sınırı/relative path kontrolü mevcut üst dizini çözerek eksik yol bileşenlerini ekler; taşınmış kökün dangling alias'ını da ele alır ve kaynak dışına giden symlink'i reddeder. Quarantine hedefi de aynı kaynak sınırına bağlandı. Gerçek dizin/symlink/eksik dosya/rebase regresyon testi 82 ortak teste dahildir. Native düzeltme sonrası sonuç teslimde ayrıca güncellenir.

## Kullanıcının Xcode/Mac/iPhone kabul sırası

1. **Derleme:** Mac Debug/Release, Apple core, Mac birim/UI testleri; ardından iPhone hedefi/simülatörü. Minimum macOS, güncel macOS, App Sandbox ve imzalı archive ayrıca kontrol edilmeli.
2. **Kullanım:** 900×650 ve geniş pencerede buton/aralıklar, dört dil, VoiceOver/yüksek kontrast; Cmd-A/F/Z/Shift-Z, arama metni undo/redo, filtreler, 50 adımlı sepet, koruma kaldırma, kategori geçişi ve soğuk açılış scroll/focus.
3. **Güvenilirlik:** Aynı volume'da iki motor; harici disk çıkarma/rename; sleep/quit; hash sırasında/restore öncesi/sonrası değişen dosya; occupied original; hard link; bozuk manifest; primary+backup bozukluğu; disk-full; kısmi Photos/klasör sonucu ve kalanları yeniden inceleme.
4. **Gerçek kaynaklar:** Photos/iCloud Photos izinleri ve limited erişim; bağlanan yerel/iCloud Drive/provider klasörleri; cloud indirme consent/cancel. Uygulama yalnız OS'nin izin verdiği kaynakları tarar; WhatsApp özel verisi kapsam dışıdır.
5. **Performans/doğruluk:** İnsan etiketli 2.000/3.000 HEIC/JPEG/RAW/video arşivinde ilk fotoğraf/ilk öneri, cold/warm startup, search/selection p95, scroll, peak RSS ve enerji; yanlış blur/benzer önerileri ayrıca sayılmalı. `KEPTORA_BENCHMARK_ITEMS=2000` ve `3000` ile `NativeAnalysisBenchmarkTests` çalıştırılabilir; sentetik corpus gerçek arşiv ölçümü yerine geçmez.
6. **Ayarlar/StoreKit:** Ana pencere kapalıyken Cmd-comma/Pro ve Dock reopen; sandbox purchase, restore, offline/refund.

Otomatik purge/kalıcı silme eklenmedi. Klasör quarantine aynı storage'da geri alınabilir taşıma yapar ve tek başına disk alanı boşaltmaz; arayüz bu ayrımı korur. [Güncel mimari](CURRENT_LIBRARY_ARCHITECTURE.md) işlem ve kayıt sahipliğini açıklar.
