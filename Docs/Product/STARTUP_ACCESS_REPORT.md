# Başlangıç izinleri ve WhatsApp medya erişimi

3 Ekim 2026. Keptora iPhone ve Mac uygulamaları. Kod uygulaması tamamlandı; native sistem pencereleri ve cihaz davranışları Apple CI/gerçek cihaz kabulüne bağlıdır.

## İlk açılış

Tanıtımın ardından **Arşivini bağla** ekranı açılır. Önce kaydedilmiş klasörler ve mevcut Fotoğraflar izni okunur. Fotoğraflar izni daha önce sorulmamışsa bu başlangıç ekranında sistemin okuma/yazma izni istenir. Kullanıcı reddederse Ayarlar bağlantısı, sınırlı erişim verirse kapsam açıklaması ve erişim yönetimi görünür. Cihaz kısıtlaması için yanlış bir “izin ver” düğmesi gösterilmez.

Kullanıcı izinsiz devam edebilir; kaynakları daha sonra ekleyebilir. Tamamlanan kurulum platform başına sürümlü bir tercihle saklanır ve her açılışta tekrar gösterilmez. Reddedilmiş, sınırlı, kısıtlanmış veya zaten verilmiş izin otomatik yeniden istenmez. iPhone’da **Arşiv → seçenekler → Kaynaklar**, Mac’te **Arşiv → Kaynaklar → İzinler ve WhatsApp rehberi** aynı erişim işlemlerini yeniden açar.

## Kaynak ve izin kapsamı

| Kaynak | Erişim yolu | Görünen kapsam |
|---|---|---|
| iPhone Fotoğraflar / iCloud Fotoğrafları | Başlangıçta PhotoKit okuma/yazma izni | Tam izinle erişilebilir arşiv; sınırlı izinle yalnızca seçilen öğeler |
| iPhone Dosyalar / iCloud Drive / diğer sağlayıcılar | Sistem Dosyalar seçicisinde kullanıcının klasör seçimi | Bağlı klasörler ve alt klasörlerde okunabilen fotoğraf/video dosyaları |
| Mac Fotoğraflar / iCloud Fotoğrafları | Başlangıçta PhotoKit izni; ret durumunda Sistem Ayarları | İzin verilen Fotoğraflar arşivi |
| Mac Resimler / İndirilenler / bulut klasörleri | Sistem klasör seçicisinde bir veya birden fazla klasör | Kullanıcı tarafından bağlanan klasörlerin ortak arşivi; güvenlik kapsamlı bağlantılar saklanır |
| WhatsApp’tan Fotoğraflar’a kaydedilen medya | Fotoğraflar izni | Albüm üyeliğiyle ilişkilendirilen kaydedilmiş kopyalar |
| Dışa aktarılmış WhatsApp sohbet medyası | Medyalı sohbet dışa aktarımı, ZIP açma, çıkan klasörü bağlama | Dışa aktarılmış fotoğraf ve videolar; mevcut medya önizleme/ayrıntı/seçim akışı kullanılır |
| WhatsApp’ın özel sohbet deposu / sohbet veritabanı / şifreli yedekleri | Keptora için desteklenen public erişim izni yok | Doğrudan okunmaz; WhatsApp açma ve kendi depolama yöneticisinin yolu gösterilir |

Kamera, mikrofon, kişiler, canlı konum ve Mac Tam Disk Erişimi istenmez. Çekim zamanı/konumu gibi mevcut medya bilgileri, zaten izin verilmiş dosyaların ve Fotoğraflar öğelerinin verilerinden okunur. Başka uygulamaların özel depoları veya bulut hesabındaki bütün dosyalar için genel bir erişim izni uydurulmaz.

## WhatsApp akışı

- **WhatsApp’ı aç** uygulamayı açar. Tam depolama ekranını açtığı iddia edilmez; kullanıcıya **Ayarlar → Depolama ve Veriler → Depolamayı Yönet** yolu gösterilir. Uygulama açılamazsa açıklayıcı mesaj görünür.
- iPhone rehberi: WhatsApp’ta sohbeti medyasıyla dışa aktar → Dosyalar’a kaydet → ZIP’i aç → çıkan klasörü Keptora’ya bağla.
- Mac rehberi: telefonda medyalı sohbet dışa aktarımı → Mac’e aktar → ZIP’i aç → klasörü bağla.
- Kaydedilmiş/dışa aktarılmış kopyaları kaldırmak, WhatsApp’taki asıl sohbet deposunda yer açmaz. Bu bilgi iki platformda da eylemin yanında görünür.

## UI/UX düzeltmeleri

- Fotoğraflar ve klasör erişimi tek başlangıç ekranında açıklanır; bağlı kaynakların sonraki taramalarda birlikte işlendiği belirtilir.
- iPhone’da klasör bağlı olsa da reddedilmiş Fotoğraflar izni gizlenmez; Fotoğraflar bağlantı rozeti aktif kaynağa değil gerçek bağlantıya dayanır.
- Başlangıçtaki klasör seçici kurulum ekranının içinde sunulur; kurulum ve seçici aynı kök modalı değiştirmez.
- Kaynaklar sayfasındaki ikinci Ayarlar düğmesi kaldırıldı; ana Arşiv seçenekleri Ayarlar’a erişimi korur ve üst üste modal sunumu önlenir.
- Fotoğraflar izin penceresi açıkken yeniden istek engellenir. iPhone’da büyük arşiv yüklenmesi, izin çözüldükten sonra “Arşive devam et” düğmesini kilitlemez.
- Mac’te başlangıç bağlantıları kökten yüklenir. Ayarlar’dan dönüldüğünde izin durumu yeniden okunur; Fotoğraflar erişimi kaldırılırsa izinli klasörler görünür kalır.
- Yeni 17 açıklama İngilizce, Türkçe, Fransızca ve Almanca eklendi. İki uygulamanın dört dildeki sistem Fotoğraflar izin açıklaması, tüm medya gösterimi/karşılaştırma/onaylı kaldırma davranışına uyarlandı.

## Doğrulama

| Kontrol | Sonuç |
|---|---|
| Ortak çekirdek / kaynak / seçim / izin politikası | Linux’ta 22 test geçti; ilk kurulum sırası ve tekrar izin istememe regresyonları dahil |
| Swift sözdizimi | 132 uygulama, paket ve test dosyası ayrıştırıldı |
| Xcode kaynak referansları | Eksik Swift referansı yok |
| Görseller / çeviri biçimleri | Dört yüksek çözünürlüklü illüstrasyon, 67 görselin mevcut inceleme manifesti ve Türkçe biçim belirteçleri geçti |
| Native başlangıç UI regresyonları | iPhone/Mac’te reddedilmiş izinle devam etme ve uygulama yeniden açıldığında kurulumun tekrarlanmaması testleri Apple CI’a eklendi; burada çalıştırılmadı |
| Native ekran kanıtı | UI testleri başlangıç ekranının ekran görüntüsünü xcresult’a ekler; bu ortamda alınmış native ekran görüntüsü yok |

Apple CI sonucu, ilk gerçek sistem izin penceresi, limited erişim seçicisi, iCloud/üçüncü taraf sağlayıcılar, WhatsApp dışa aktarımının cihazda bağlanması, büyük yazı ve VoiceOver kabulü tamamlanmadan “bütün cihaz davranışları doğrulandı” denmez.

[Birleşik arşiv raporu](UNIFIED_LIBRARY_UX_AUDIT.md), [teslim raporu](DELIVERY_REPORT.md), [Apple CI](../../.github/workflows/apple-validation.yml).
