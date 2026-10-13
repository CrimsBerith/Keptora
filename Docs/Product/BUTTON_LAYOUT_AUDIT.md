# iPhone ve Mac düğme yerleşimi denetimi

**Tarih:** 5 Ekim 2026. **Dal:** `feat/photo-cleaner-library`.

Denetimde eksikler bulundu ve düzeltildi. Ana Fotoğraflar → Kaynaklar → Tarama → Seçim → Son İnceleme → Geçmiş akışı ile karşılama, Pro ve ayarlar ekranlarının ilgili eylemleri incelendi. Bu belge kod yerleşimi denetimidir; gerçek cihazda görsel kabul değildir. Önceki [UI, UX ve dil teslimi](UI_UX_CLARITY_DELIVERY.md) üzerine kuruludur.

## Bulgular ve uygulanan değişiklikler

| Alan | Bulgu | Uygulanan çözüm |
|---|---|---|
| iPhone düğme hedefleri | Bazı metin düğmelerinde 44 puanlık çerçeve Button dışında kalıyordu. Ayrılan boşluk, gerçek dokunma alanını garanti etmiyordu. | Ortak ikincil düğme stilinde ölçü, iç boşluk ve `contentShape` doğrudan etikete uygulanır. Özel düğmelerin hedefi en az **44 × 44 pt**. |
| iPhone ana eylemleri | Tarama ve inceleme düğmeleri farklı ölçüler kullanıyordu; devre dışı görünüm bazı özel stillerde zayıftı. | Ana stil en az **52 pt** yüksekliktedir. Alt inceleme/kaldırma eylemleri tüm genişliği kullanır; devre dışı durumda dolgu ve gölge daha belirgin biçimde soluklaşır. Uzun metinler birden fazla satıra çıkabilir. |
| iPhone seçim çubuğu | Üç uzun eylem dar genişlikte birbirini sıkıştırıyor veya üç ayrı sıraya geçiyordu. | Geri al / seçimleri kaldır ikincil sıradadır. Adetli **Seçimi İncele** ayrı ve tam genişlikte son sıradadır. Erişilebilirlik yazı boyutlarında ikincil eylemler alt alta geçer. |
| iPhone filtre ve grup eylemleri | Grup, tarih başlığı ve tarama satırları uzun çevirilerde tek satıra zorlanıyordu. | Uygun genişlikte yatay, dar genişlikte dikey yerleşim. Düğme araları **12 pt**, dikey eylem araları **8 pt**. Bulgu ve etkin filtre düğmeleri arasında **8 pt**. |
| Fotoğraf altı eylemler | Saklama/ek bulgu düğmeleri fotoğraf kenarına bitişikti. | Fotoğraf ile alt eylemler arasında **6 pt**; bu eylemler en az 44 pt hedefli ve hücre genişliğindedir. Fotoğraf ızgarasının yoğun **4 pt** aralığı korunur. |
| Son inceleme — iki platform | Küçük resim, uzun dosya adı, kaynak ve çıkarma düğmesi aynı satırda sıkışıyordu. | Yatay/dikey uyarlanabilir satırlar; iPhone erişilebilirlik yazısında dikey yerleşim. Çıkarma eylemi kütüphaneyi silmediğini açıklayan erişilebilirlik ipucunu korur. Küçük resimler iPhone **60 pt**, Mac **76 pt**. |
| iPhone izin/kurtarma/Pro | Bazı izin, geri yükleme, atlama, yeniden deneme ve satın alımları geri yükleme düğmeleri küçük metin hedefleriydi. | Ortak hedef ölçülerine geçirildi. Yasal bağlantıların hedefi etikette 44 pt olarak belirlendi; uzun metinde alt alta geçerler. |
| Mac üst kontrolleri | Kütüphane başlığı, Fotoğraflar bağlantısı, klasör ve yenileme düğmeleri dar pencereye sığmayabiliyordu. | Uyarlanabilir başlık/eylem satırları ve büyük yerel kontroller. Yenileme simgesi **32 × 32 pt** iç hedef ve açık erişilebilirlik adı kullanır. |
| Mac görünür fotoğraf alanı | Üst kontroller ve açık erişim ayrıntıları galerinin yüksekliğini tüketebiliyordu. | Başlık, filtreler ve galeri aynı kaydırma alanında; seçim çubuğu altta sabit. Tarama ve liste/seçim kontrolleri ayrı uyarlanabilir satırlardır. Bulgu seçici sığmazsa yerel menüye geçer. |
| Mac kaynak seçimi | Kaynak adı, sayı ve durum tek satırdaydı; sabit yükseklikte iç kaydırma uzun metinleri kesebiliyordu. | Tam satır hedefi en az **44 pt**. Ad, sayı ve durum alt alta; kaynak listesinin sabit yüksekliği ve iç kaydırması kaldırıldı. Kaynak penceresi sabit 650 × 600 yerine esnek sınırlar kullanır: minimum **480 × 480**, ideal **650 × 600 pt**. |
| Mac alt eylemler | İnceleme ve Pro ekranında çok sayıda düğme/bağlantı tek sıraya sıkışıyordu. | Ana ve ikincil eylemler ayrıldı. Gerektiğinde alt alta geçer; yatay/dikey boşluklar **12/8 pt**. İncele/kaldır/devam düğmeleri etikette en az **32 pt** yükseklik, yerel büyük kontrol boyutu kullanır. Pro yasal bağlantıları ayrı sıradadır. |
| Mac geçmiş/ayarlar | Kurtarma ve ayar düğmesi çiftleri uzun metinle sıkışabiliyordu. | Uyarlanabilir satırlar ve büyük yerel kontroller. Klavye kısayolları ve sistem onay pencereleri korunur. |

Ölçüler, özel eylem etiketlerinin kodda tanımlanan alt sınırlarıdır. Sistem araç çubuğu, sekme, seçici, menü içeriği ve onay pencereleri platformun yerel kontrol davranışını kullanır. Bu kontrol, bütün gelişmiş/eski ekranların her düğmesinin cihazda ölçüldüğü anlamına gelmez.

## Doğrulama

- **137 Swift dosyası** sözdizimi kontrolünden geçti. Bu kontrol Apple SDK tip kontrolü veya derleme değildir.
- Xcode proje kaynak referansları, görsel referansları, EN/TR/FR/DE biçim argümanları ve değişikliklerin boşluk kontrolü geçti. Ana akış sabit metin taramasında eksik çeviri bulunmadı.
- iPhone `testSelectionActionsHaveAccessibleTargetsAndDoNotOverlap` hazırlandı ve Apple CI test listesine eklendi. Standart İngilizce ve erişilebilirlik boyutunda Türkçe ile tarama, sepet ve son inceleme eylemlerinin gerçek XCUI çerçevesini, dokunulabilirliğini, ekranda kalmasını ve sepet düğmelerinin çakışmamasını denetler. Her iki durumda ekran görüntüsü kaydeder.
- Mac başlangıç testi, devam düğmesinin dokunulabilirliğini, en az 32 pt yüksekliğini ve pencere içinde kalmasını denetleyecek şekilde genişletildi.
- **Native testler burada çalıştırılmadı.** Bu ortam Linux'tur. Ortak seçim/kaldırma mantığı değiştirilmedi; önceki 54 taşınabilir testin sonucu bu çalışmanın Apple derleme sonucu olarak sunulmaz. Görsel dosyalar yeniden üretilmedi.

## Son cihaz kontrolü

| Cihaz / durum | Kabul ölçütü |
|---|---|
| Küçük iPhone, dikey/yatay, klavye açık/kapalı | Liste kaydırılabilir; inceleme eylemi erişilebilir; sekme çubuğu ve alt güvenli alanla çakışma yok. |
| Büyük yazı ve VoiceOver | Türkçe/Almanca/Fransızca uzun düğmeler okunur; odak sırası mantıklı; görünür eylem alanının tamamı çalışır. En büyük erişilebilirlik boyutları ayrıca denenir. |
| iPhone grup ve son inceleme | Saklama/diğerlerini seç eylemleri yanlışlıkla fotoğraf seçmez. Çıkarma eylemi yalnızca sepetten çıkarır; geri alma çalışır. |
| Dar Mac penceresi ve küçük ekran | Başlık ve eylemler sığar veya alt alta geçer. Üst kontroller kaydırılabilir; galeri/seçim çubuğu erişilebilir kalır. |
| Mac kaynak/son inceleme pencereleri | Çok kaynak ve uzun klasör/dosya adlarıyla içerik kesilmez; sabit alt eylemler görünür; Tab, Return ve Escape beklenen şekilde çalışır. |
| Açık/koyu görünüm, 2.000–3.000 öğe | Devre dışı eylem durumu anlaşılır; rozet ve seçim belirgindir; hızlı kaydırma/seçimde yerleşim kararlı kalır. |

Cihaz testleri kullanıcının istediği son aşamadır. Native Apple CI sonucu ve gerçek ekran kabulü görülmeden tüm iPhone/Mac yerleşimlerinin görsel olarak onaylandığı söylenemez.
