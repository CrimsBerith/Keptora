# Keptora — kolay kullanım ve güvenilir çalışma planı

**Tarih:** 4 Ekim 2026. **İncelenen sürüm:** `cc2b668b8576b4f806e08ecd8ce7f661802a296c`, `feat/photo-cleaner-library`.

**Hedef:** 2.000–3.000 fotoğrafı olan kullanıcı kaynaklarını bir kez bağlar; seçili kaynakları birlikte tarar; kopyaları, çok benzer kareleri ve incelemeye değer fotoğrafları kolayca ayırt eder; saklayacağı kareleri seçer ve kaldıracağı öğeleri tek incelemede onaylar. Bütün seçili ve listelenebilir öğeler arşivde kalır.

**Son kullanıcı kararı:** Karşılaştırma ekranı, swipe/sürükleyerek karar verme ve büyüteç düğmesi kaldırılmıştır. Galeride dokunarak seçim, **Bunu Sakla / Diğerlerini Seç** ve sabit geri alma çubuğu uygulanmıştır. Bu konuda aşağıdaki ilk plan yerine [güncel seçim teslimi](PHOTO_SELECTION_DELIVERY.md) esas alınır; ortak test sayısı 49'dur.

**Belgenin durumu:** Uygulama paketleri kodlandı; güncel sonuçlar, 48 portable test ve son Apple kabulü [teslim raporunda](BULK_CLEANUP_DELIVERY.md) kayıtlı. Aşağıdaki bulgular ilk incelemenin başlangıç durumudur. Gerçek fotoğraf kalibrasyonu ve cihaz performansı son kabulde ölçülür. [Kaynak seçimi teslimi](SOURCE_SELECTION_DELIVERY.md) tamamlanmış temel olarak korunur. [Toplu temizlik planı](BULK_PHOTO_CLEANUP_PLAN.md) ayrıntılı ürün kararlarını içerir; uygulama önceliği ve güncel eksikler için bu belge esas alınır.

**Çalışma sırası:** Ortak modeller, iPhone/Mac kodu, test senaryoları ve bu ortamda çalışabilen kontroller önce hazırlanır. Xcode derlemesi, Apple testlerini çalıştırma ve gerçek Mac/iPhone kabulü kullanıcı tarafından en son yapılır. Bu ortamın Linux olması geliştirmeye başlamak için engel değildir; Apple çalışma zamanı doğruluğu için son kabul gerekir.

## 1. Tamamlanan temel ve korunacak kararlar

| Alan | Kodda mevcut | Korunacak davranış |
|---|---|---|
| Kaynak seçimi | Ana tik, ayrı kaynak tikleri, kısmi durum, sayı/erişim, kalıcı seçim, seçili kaynaklarda tek tarama. | Kaynağın tikini çıkarmak bağlantıyı silmez; yeni bağlantı seçili başlar. |
| Ortak arşiv | Photos ve izinli dosya/bulut klasörleri aynı arşivde; serbest manuel seçim, kaynak rozetleri ve filtreler. | Kopya olmayan fotoğraflar da görünür ve seçilebilir. |
| Örtüşme | Aynı dosya yolu/PhotoKit kimliği tekilleştirilir; ayrı gerçek kopyalar korunur. | Toplam, örtüşen kaynak satırlarının adetlerini toplayarak hesaplanmaz. |
| Kopya/benzer | Birebir ve benzer grupları; çekim zamanı, konum ve burst bağlamı; medya ailesi için ayrı exact kanıtı. | Metadata görsel uyumsuzluğu eşleşmeye çeviremez; benzerlik birebir kopya diye sunulmaz. |
| Kaldırma/kurtarma | Son inceleme, kaynak başına hedef, revizyon kontrolü, kısmi işlem kaydı ve Geçmiş. | Sistem onayı ve mevcut kurtarma koşulları korunur. |
| Ana gezinme | iPhone'da Arşiv, Temizlik, Geçmiş; ayarlar ikincil alanda. | Yeni zorunlu sekmeler ekleyerek basit akış büyütülmez. |
| Görseller | Önceki 67 dosyalık yeniden üretim ve inceleme kaydı mevcut. | Mevcut varlıklar kullanılır; güncel native ekran kabulü ayrıca yapılır. |

Kaynaklar, telefon ve Mac'in uygulamaya sunduğu **izinli Fotoğraflar, Dosyalar ve bağlı bulut klasörleri**dir. iCloud Fotoğrafları Photos kaynağının içindedir; iCloud Drive dosya kaynağıdır. Harici disk/ağ konumları sistem tarafından sunuluyor ve kullanıcıca bağlanabiliyorsa dosya kapsamına girer. WhatsApp'a özel entegrasyon, sohbet/depo erişimi, ZIP içe alma ve özel kaynak rozeti kapsam dışıdır. Kaydedilmiş medya normal galeri/dosya öğesi olarak kalır.

## 2. Kodda doğrulanan eksikler

P0: yanlış sonuç/işlem algısı veya kararın kaybolması; yeni öneriler açılmadan düzeltilir. P1: ana temizleme görevini kolaylaştıran ve hızlandıran iş. P2: son görünüm, erişilebilirlik ve ürün metinleri.

| Öncelik | Bulgu / kanıt | Kullanıcıya etkisi | Gerekli değişiklik |
|---|---|---|---|
| P0 | `ExactGrouping.swift` erişim, kaynak yokluğu ve diğer okuma hatalarını `skippedNetwork` içinde topluyor. | Yerel bozuk/erişilemeyen dosya bulut indirme eksikliği gibi anlaşılabilir. | Aşama ve neden bazında erişim/indirme/bozuk/unsupported/iptal durumları. |
| P0 | `MobileKeptoraStore.startScan` exact aşamasından sonra, fotoğraf/video benzerliği bitmeden `.completed` yazıyor. | Ortak gruplar ekranı analiz sürerken “grup bulunamadı” izlenimi verebilir. | Oturum tamamlanması ile aşama tamamlanmasını ayır; kısmi sonucu açık göster. |
| P0 | Mobil arka plan durdurması yalnız `scanState.isScanning` için çalışıyor; Mac'te fotoğraf analiz hatası aynı `do` bloğundaki video aşamasını da atlatıyor. | Devam/iptal ve kısmi sonuç davranışı platformlar arasında tutarsız. | Ortak oturum durumu, bağımsız aşama hataları ve sonradan devam. |
| P0 | Katalog yenilemesi erişilemeyen kaynakta boş batch oluşturuyor; manuel seçim erişilen katalogla kesiştiriliyor. | Geçici izin/disk/ağ hatasında eski seçimler düşebilir; bu gerçek silinmeyle aynı değildir. | Erişilemeyen seçimleri bekleyen durumda koru; doğrulanmış kaldırılmış öğeleri ayrı uzlaştır. |
| P0 | `VisualQualityEngine` göz landmark'larının varlığından `eyesOpen`/“Best Expression” üretiyor; küçük/okunamayan görüntü düşük skor döndürüyor. | Kanıtlanmayan kalite gerekçesi saklama önerisine katılabilir. | İfade iddiasını kaldır; geçerli/değerlendirilemedi durumu ve gerekçe ekle. |
| P0 | Kalite/netlik motorları genişlik ve yüksekliği ayrı sınırlandırıyor; kenar yoğunluğu ve ortalama parlaklık esas sinyaller. | Oran bozulabilir; düşük detay, noise, bokeh veya gece çekimi yanlış yorumlanabilir. | Oran/orientasyon düzeltmesi; yeterli önizleme; temkinli, kalibre edilmiş netlik/pozlama sinyalleri. |
| P0 | Checkpoint `sameRevision`, tarih/boyut bilinmiyorsa güvenilir revizyon kanıtı olmadan aynı kabul edebiliyor. Disk cache zamanı tam saniyeye indiriyor; algoritma sürümü anahtarda yok. | Eski analiz ileride yanlışlıkla yeniden kullanılabilir. | Kaynak/medya/algoritma sürümü; yeterli revizyon kanıtı yoksa yeniden analiz. |
| P1 | Kalite raporları `VisualSimilarityAnalyzer` içindeki geçici sözlükte kalıyor; ana grid yalnız saklama önerisini gösteriyor. | Kullanıcı tekil bulanık/düşük çözünürlüklü fotoğrafı ve öneri gerekçesini göremiyor. | Kalıcı öğe bulguları ve bütün erişilebilir fotoğraflarda kalite değerlendirmesi. |
| P1 | Tek benzerlik sınıfı ve tek varsayılan eşik var; Vision ve hash mesafeleri aynı eşikle ele alınabiliyor. | Çok benzer ile daha zayıf benzerlik ayrılmıyor; farklı ölçülerde güven kalibrasyonu yok. | Ölçü/sürüm bazında eşik; çok benzer/benzer sınıfları; aday bulma doğruluğu testi. |
| P1 | Arşivin Tüm Öğeler görünümü tarihe göre; kopya/benzer görünümü ayrı. Örtüşen gruplarda aynı öğe yeniden görünebilir. | İlgili fotoğraflar ana gridde yan yana değil; toplam/seçim takibi zorlaşır. | Tekil ID'li akıllı düzen ve ilişki sınırlarını koruyan karşılaştırma blokları. |
| P1 | `isProtectedFromGlobalSelection` normal albüm üyeliğini de koruyor; keeper puanında albüm ve RAW formatı yüksek öncelikli. | Albümdeki çok sayıda sıradan kopya toplu öneriden düşebilir; format gerçek kalite sanılabilir. | Kullanıcının saklama kararı ile normal albüm/format bağlamını ayır. |
| P1 | Arşiv, exact ve benzer video için ayrı seçim kümeleri var; ana arşivde grup başına sakla/diğerlerini seç akışı yok. | Başka ekrandaki seçimlerin aynı işlem olup olmadığı anlaşılmayabilir. | Ortak seçim sepeti; ayrı niyet/kanıt bilgisi; tek son inceleme. |
| P1 | Disk fingerprint cache'i tarama için kullanılmıyor; cache temizleme ayarı mevcut. Tam hash, fotoğraf ve video aşamaları ardışık. | Tekrar tarama fazla iş yapıyor; ilk görsel sonuç büyük dosyaların okunmasını bekliyor. | Güvenli cache'i gerçekten bağla; ortak önizleme ve artımlı sonuç hattı. |
| P1 | `visible`, grup/album indeksleri ve sıralama tekrar hesaplanıyor; grup hücrelerinde `visible.contains` var. | Büyük arşivde gereksiz UI hesapları ve kaydırma maliyeti. | Önceden hesaplanan görünüm modeli, ID kümeleri, ölçülen thumbnail ön yükleme. |
| P2 | Ana arşivde açık kaynak paneli, yönetim/erişim alanı, ikinci bulut eylemi ve sonuç/medya kontrolleri birlikte yer alıyor. | Özellikle telefonda fotoğrafların alanı azalıyor; sıradaki eylem zayıflıyor. | Kurulum sonrası kısa kaynak özeti; bir ana tarama eylemi; sade filtreler. |
| P2 | Ayarlarda “benzer fotoğraflar temizlemeye asla girmez” metni var; manuel arşiv benzer dahil her öğeyi kaldırabiliyor. `String(localized:)`, `L10n` ve SwiftUI locale kullanımı karışık. | Metin gerçek davranışla veya uygulama içi seçilen dille uyuşmayabilir. | Akışa uygun kısa metinler; uygulama içi dil değişimi ve dört dil regresyonu. |

Bu bulgular kaynak kodu incelemesidir. Geçici erişim/seçim kaybı, görüntü doğruluğu ve cihaz performansı native ortamda ayrıca yeniden üretilip ölçülecek.

## 3. Kullanıcının göreceği hedef akış

1. **İlk bağlantı:** Fotoğraflar erişimi ve gerekli klasörler. Açıklama kısa; erişim reddedilirse çalışan kaynaklarla devam veya sonra bağlama yolu açık.
2. **Kaynak özeti:** “3 kaynak · 2.864 öğe”. Açılınca mevcut ana/tekil tikler, sayı ve erişim. Bir kaynağın sayılamaması sıfır fotoğraf varmış gibi sunulmaz.
3. **Tek düğme:** “Seçili kaynakları tara”. Gerekli indirme varsa kaç öğenin eksik olduğu ve devam seçeneği gösterilir. Klasör sağlayıcısının kendi ağ davranışı için mutlak aktarım vaadi verilmez.
4. **Sonuç:** Tümü, Kopyalar, Çok benzer, İncelemeye değer. Varsayılan akıllı grid bütün öğeleri korur; tarihe göre alternatif vardır. Hazır sonuçlar görünürken kalan analiz devam eder.
5. **Karar:** Grup başlığı, kısa saklama gerekçesi, Bunu sakla / Diğerlerini seç / Grubu koru. Önizleme ve yakınlaştırmalı karşılaştırma aynı bağlamı korur.
6. **İnceleme:** Tek seçim çubuğu ve tek sepet. Adet, kaynak/hedef, görünüm dışında kalan veya erişimi bekleyen seçimler açık.
7. **Kaldırma ve sonuç:** Kullanıcının son onayı; kaynak başına başarı/hata; tamamlanan öğelerin seçimi temizlenir, kalan seçim korunur; Geçmiş'ten kurtarma yolu bulunur.

Örnek: 12 çok benzer tatil karesinde kullanıcı önerilen kareyi büyütür, başka birini “Bunu sakla” ile değiştirir, “Diğerlerini seç” der. Son incelemede seçtiği 11 öğeyi görür. Aynı tarih veya konum tek başına 12 kareyi benzer grup yapmaz.

## 4. Bulgu, rozet ve saklama politikası

| Gösterim | Anlam | Seçim davranışı |
|---|---|---|
| Birebir kopya | Uyumlu gerçek içerik/medya ailesi kanıtı. | Korumasız fazladan kopyalar topluca önerilebilir; her grupta saklanan öğe kalır. |
| Çok benzer | Kalibre edilmiş güçlü görsel ilişki; zamanı/konumu destekleyici. | Kullanıcı saklama önerisini değerlendirir; grup içi seçim yapar. |
| Benzer çekimler | Daha zayıf görsel ilişki. | İkincil filtre/karşılaştırma; güçlü öneri gibi davranmaz. |
| Bulanıklık şüphesi | Geçerli önizleme ve uygun güvenle netlik sorunu adayı. | Otomatik kaldırma/seçim gerekçesi olmaz. |
| Düşük çözünürlük | Bilinen asıl piksel boyutu. | Thumbnail boyutu veya küçük dosya üzerinden karar verilmez. |
| Çok karanlık / Çok aydınlık | Pozlama sorunu adayı; histogram ve kırpılma desteği. | Gece/siluet/sanatsal ışık için temkinli; kullanıcı seçer. |
| Değerlendirilemedi | Önizleme, erişim, indirme veya destek sorunu. | Kalitesiz veya sorun yok diye gösterilmez; tekrar deneme nedeni görünür. |

“İncelemeye değer”, kalite sorun adaylarının ortak filtresidir. “Kalitesiz” estetik hükmü, keyfî kalite yüzdesi, “gözler açık/en iyi ifade” ve dosya formatından çıkarılan üstün kalite iddiası kullanılmaz.

Fotoğraf üstünde kısa kaynak rozeti; altta en önemli bulgu; seçim tiki ayrı köşede. Fazladan bulgular ayrıntıda. Kaynak rozeti gerçek kayıt yerini, bulgu ise inceleme nedenini anlatır; ağdan indirme ihtiyacı ayrı durumdur. Bilinmeyen sağlayıcı kesin bulut adıyla etiketlenmez. Simge/metin anlamı sadece renge bağlı kalmaz.

Saklama sırası kullanıcı niyeti ve açık koruma ile başlar. Favori, düzenlenmiş, gizli, paylaşımlı ve kullanıcıca korunan öğeler varsayılan toplu öneride korunur. Normal albüm üyeliği tek başına bütün kopyaları korumaz. RAW, çözünürlük ve boyut bağlamdır; netliği veya estetik üstünlüğü tek başına kanıtlamaz. Benzer grupta “bu grupta daha net” gibi gerekçe karşılaştırma kanıtına dayanır.

## 5. Uygulama paketleri ve tamamlanma ölçütleri

### Paket 1 — tarama ve seçim tutarlılığı (P0)

- **1.1:** Oturum ve aşama durumlarını ayır: katalog, exact, fotoğraf benzerliği/kalite, video. Bekliyor/işleniyor/kısmi/tamamlandı/iptal/değerlendirilemedi durumları tanımla.
- **1.2:** Okuma hatalarını neden ve öğe kimliğiyle kaydet. Erişilemeyen kaynak, indeksleme eksikliği ve buluttan indirme eksikliği birbirinden ayrı olsun.
- **1.3:** Bekleyen erişim seçimlerini sakla. Tam ve başarılı kaynak sayımından sonra gerçekten kaldırılmış öğeleri uzlaştır; eksik sayımı kaldırılma kanıtı sayma.
- **1.4:** iPhone arka planında bütün aktif aşamaları uygun biçimde durdur/devam ettir. Mac'te bir aşamanın hatası diğer erişilebilir analizleri düşürmesin.
- **1.5:** Checkpoint yazımı/temizlemesini oturum sürümüyle sırala; kaynak/algoritma/medya revizyonu doğrulanmadan eski kanıtı kullanma. Dosya yazımının UI iş parçacığına maliyetini gider.
- **1.6:** Hatalı ifade/kalite kanıtını saklama sıralamasından çıkar; geçerli görüntü oranını ve eksik değerlendirme durumunu yeni rozetlerden önce düzelt.

**Çıkış:** İptal veya eksik analiz “her şey tamam” olmaz. Fotoğraf aşaması hata verse de video sonuçlarının durumu bellidir. Geçici disk/izin/ağ kaybında kullanıcı seçimi korunur. Belirsiz revizyonda önceki hash tekrar kullanılmaz.

### Paket 2 — ortak sonuç ve hızlı analiz hattı (P1)

- **2.1:** Öğe başına bulgu modeli ve oturum kapsamı kur: kanıt türü, durum/gerekçe, algoritma sürümü, medya revizyonu, ilgili grup ve kaynak kimliği. İsimler uygulamada seçilebilir; tek ortak politika kullanılır.
- **2.2:** Oranı/orientasyonu doğru ortak önizleme üret; kalite ve görsel benzerlik aynı görüntüden yararlansın. Bellekte bütün asılları biriktirme.
- **2.3:** Kataloğu ve hazır bulguları parça parça UI'a taşı; exact kanıtı tamamlanmayan aday exact etiketi almasın. Kullanıcının aktif grubunu sonuç akışı sırasında sabit tut.
- **2.4:** Güvenli revizyon ve algoritma anahtarlı cache'i gerçek hash/görsel/kalite akışına bağla. Bozuk cache, yer yokluğu ve bilinmeyen revizyon normal yeniden analize düşsün.
- **2.5:** Sınırlı decode/IO/analiz kuyruğu, iptal ve görünür öğeye öncelik ekle. PhotoKit thumbnail ön yüklemesini ve mevcut 64 MB mobil cache'i ölçerek ayarla.
- **2.6:** Görünümün kaynak/grup/filtre ID indekslerini önceden hesapla; tekrar sıralamayı ve iç içe üyelik aramalarını azalt.

**Çıkış:** Kullanıcı ilk fotoğrafları ve hazır bulguları tüm hash işlemi bitmeden görebilir. Değişmeyen güvenilir revizyon cache'den gelir; değişen veya belirsiz medya yeniden incelenir. Analiz sürerken grid gezilebilir ve manuel seçim korunur. Kaldırma başlamadan ilgili oturum durdurulur ve son inceleme sabitlenir.

### Paket 3 — doğru kalite ve çok benzer ayrımı (P1)

- **3.1:** Yeterli önizleme, ışık histogramı/kırpılma, ölçek ve yön bilgisi içeren kalite raporu üret. Tekil fotoğraflar da aynı kapsamda değerlendirilir.
- **3.2:** Düşük detay, noise, bokeh, gece ve siluet karşı örnekleriyle netlik/pozlama eşiklerini kalibre et. Emin olunmayan durumda rozet vermemeyi destekle.
- **3.3:** Vision mesafesi ve hash farkı için ayrı ölçü/sürüm ve eşikler kullan; doğrulanmamış ham mesafeyi kullanıcı yüzdesi yapma.
- **3.4:** JPEG yeniden sıkıştırma, ölçek değişimi ve metadata'sız kopyalar için aday bulma kapsamını ölç. Zaman/konum tek kanıt olmasın; metadata'sız benzerler kaybolmasın.
- **3.5:** Exact, çok benzer ve benzer ilişkilerini ayır; A≈B, B≈C diye A≈C hükmü verme. RAW/Live Photo/düzenlenmiş sürüm farkları korunur.
- **3.6:** Saklama önerisini kısa gerekçelerle öğe bulgularına bağla; kullanıcı tercihleri ve mevcut korumalar belirgin olsun.

**Çıkış:** Net düşük detaylı görüntü otomatik bulanık olmaz. Okunamayan dosya kalite kusuru sayılmaz. Yalnız aynı saatte/konumda çekilmiş farklı sahneler gruplanmaz. Çok benzer sınıfı için gerçek ve dönüştürülmüş örneklerde yanlış eşleşme/kaçırma oranı kaydedilir.

### Paket 4 — ana karar arayüzü ve toplu seçim (P1)

- **4.1:** Akıllı düzeni bütün öğeler içinde uygula: exact grupları, çok benzer blokları, incelemeye değer tekiller ve diğerleri. Tarih görünümü korunur; her ID ana gridde bir kez yer alır.
- **4.2:** Dört kısa filtre ve grup adetleri ekle. Kategori adetleri aynı öğede birden fazla bulgu bulunabildiğini gizlice toplamamalı; seçili adet her zaman tekildir.
- **4.3:** Bunu sakla / Diğerlerini seç / Grubu koru işlemleri ve zoom ile karşılaştırma ekle. Kararlar revizyonla saklansın; öneri sessizce kullanıcının kararını değiştirmesin.
- **4.4:** Ortak seçim sepeti oluştur; manuel/suggested niyeti ve kaynak/kanıt korunarak tek son incelemeye bağla. Görünüm dışındaki seçim ve erişimi bekleyen seçim ayrı açık sayılsın.
- **4.5:** “Önerilen kopyaları seç” sadece doğrulanmış korumasız fazlalıkları seçsin. Benzer veya kalite adayları tüm arşivde kendiliğinden seçilmesin. Geri alma ve seçimi temizleme korunur.
- **4.6:** Son incelemeyi kısa özet + öğeler + kaynak/hedef olarak sadeleştir; karma kaynak hata/iptalinde yalnız tamamlanan öğelerin seçimini çıkar. Bütün grup manuel seçilmişse uyarı açık olsun.

**Çıkış:** Kullanıcı 12 yakın çekimde saklanacak kareyi seçip kalanları tek grup eylemiyle incelemeye alır. 3.000 öğelik arşivde filtre/kaynak değişimi seçimleri kaybetmez. Yeni gelen bulgu aktif grubu veya kaydırma konumunu atlatmaz. Toplu exact önerisi her grupta en az bir saklanan üye bırakır.

### Paket 5 — iPhone/Mac kolaylığı, metinler ve son görsel düzen (P1/P2)

- **5.1:** Kurulum sonrası kaynak panelini kısa özete daralt; tikleri tek açılır kaynak alanında tut. Temizlik sekmesinde aynı tarama mantığı ve kapsam kullanılsın; ayrı bir sonuç/seçim evreni kurulmasın.
- **5.2:** iPhone'da fotoğrafın alanını büyüt; uygun üç sütun, büyük yazıda daha az sütun; erişilebilir 44 pt eylemler. Tarih/albüm/favori/medya türü gelişmiş filtre alanında kalsın.
- **5.3:** Mac'te dar pencere, çok kaynaklı arşiv, klavye/shift ile seçim ve grup karşılaştırması. Mevcut Cmd+A/Cmd+Z işlevlerinin kapsamı korunur ve açıklanır.
- **5.4:** Kopya, benzer, saklama önerisi ve kurtarma metinlerini gerçek davranışla eşleştir. Teknik hash/quarantine ayrıntılarını kullanıcı kararını desteklediği ikincil alana taşı.
- **5.5:** EN/TR/FR/DE ve uygulama içi dil değişimini doğrula; sayı, tarih, kaynak adı, format metni ve hata açıklamaları aynı dili izlesin. Mevcut 100 ücretsiz inceleme sınırının hangi eylemleri kapsadığı tutarlı anlatılsın; fiyat/limit değişikliği bu planın işi değildir.
- **5.6:** Açık/koyu görünüm, kontrast, rozet okunabilirliği ve desteklenen SF Symbol adları için native senaryolar hazırla. Güncel ekran görüntülerini son native sürümden üret; önceki tasarım önizlemelerini cihaz kanıtı sayma.
- **5.7:** Kaldırma sonucunda gerçek hedef ve alan açma yolu göster: Photos için Son Silinenler, dosyalar için Kurtarma. Kurtarmaya taşınan medya boyutunu boşalan alan diye sunma. Dosya Kurtarma alanını kalıcı boşaltma eklenirse kullanıcıca başlatılan, ayrı inceleme/onaylı işlem olarak tasarla; otomatik boşaltma yapma.

**Çıkış:** Ana ekranda bir sonraki eylem ve fotoğraflar öne çıkar. Sembol/renk/metin aynı anlamı taşır. Kullanıcı uygulama içi dil değiştirince karma dil görmez. Kaldırmanın sonucu, eşitleme etkisi ve gerçekten nasıl alan açılacağı anlaşılır.

### Paket 6 — burada teslim hazırlığı, ardından kullanıcının son native kabulü

- Ortak Foundation politikalarını portable teste aç; örnekten beklenen grup/bulgu/seçim sonuçlarını önceden yaz.
- Apple görüntü/Vision, SourceAdapter, iptal/devam ve UI testlerini hazırlayıp mevcut Apple CI'a ekle. Burada koşulamayan testleri çalıştırılmış gibi kaydetme.
- Ürün kodu değişikliklerinde ilgili test, proje referansı, sözdizimi, çeviri ve görsel bütünlüğü kontrollerini çalıştır; her paket küçük incelenebilir commit'lerle aynı dalda ilerlesin.
- Kullanıcı en sonda Xcode derlemesi, gerçek Mac/iPhone, iCloud/sağlayıcı, sistem kaldırma onayı, kurtarma, büyük yazı/VoiceOver, pil/bellek ve hız kontrollerini yapar. Bulunan hata ilgili pakette düzeltilir; tekrar ölçülür.

## 6. Sıra, bağımlılıklar ve iş büyüklüğü

| Sıra | Paket | Bağımlılık | Büyüklük | Teslimde görülecek sonuç |
|---|---|---|---|---|
| 1 | Tarama/seçim tutarlılığı | Mevcut kaynak tikleri | Orta | Doğru aşama/eksik erişim durumu, korunmuş seçim ve güvenilir checkpoint. |
| 2 | Ortak sonuç/önizleme/cache | 1; kalite sürüm sözleşmesi | Büyük | İlk hazır sonuçlar daha erken; tekrar iş azalır. |
| 3 | Kalite/çok benzer kanıtı | 1–2 | Büyük | Gerekçeli bulgular; bağımsız eşikler ve ölçülmüş yanlış eşleşmeler. |
| 4 | Akıllı grid/toplu karar | 2–3; UI ilk olarak fixture ile geliştirilebilir | Büyük | Kopyalar/çok benzerler yan yana; grup kararı ve tek sepet. |
| 5 | Platform/metin/görsel düzen | 4; küçük metin/daraltma iyileştirmeleri 1 ile başlayabilir | Orta | Az kontrol, okunabilir fotoğraf ve tutarlı dil/işlem metinleri. |
| 6 | Teslim testleri | Her pakete eşlik eder | Sürekli | Burada çalışabilen kontroller + hazırlanmış Apple testleri. |
| Son | Kullanıcının native kabulü | Paketler tamam | Apple ortamında ölçülür | Cihaz davranışı ve gerçek performans kanıtı. |

Büyüklük göreli kapsamdır; ölçülmüş takvim tahmini değildir. Her paket bitince raporda kodlandı/portable doğrulandı/native hazırlanmış/native çalıştırıldı durumları ayrı tutulur.

## 7. Test verisi ve ölçüm planı

| Senaryo | Kabul ölçütü |
|---|---|
| 2.000 ve 3.000 öğelik karma arşiv | Tam/kısmi/boş kaynak seçiminde beklenen tekil toplam, grup ve seçim; sessiz üst sınır yok. |
| Photos + dosyadaki aynı gerçek JPEG; yeniden sıkıştırılmış JPEG | Uyumlu birebir kanıtta exact; yeniden sıkıştırılan dosya ancak görsel benzerlik sınıfında. |
| Örtüşen kökler/albümler | Tekil ID; ayrı gerçek kopya görünür; yalnız iç kök seçilince doğru erişim/sahip. |
| Live Photo hareket bileşeni farklı; düzenlenmiş/RAW sürüm | Aile/sürüm farkı exact kanıtıyla kaybolmaz; korunması gereken bileşen yanlış kaldırılmaz. |
| Net düz yüzey, bulanık dönüşüm, noise, bokeh, gece/siluet, düşük çözünürlük | Beklenen geçerli/şüpheli/değerlendirilemedi durumları; tek estetik skora bağlanmaz. |
| Metadata yok veya aynı konum/saatte farklı sahne | Metadata'sız yakın görüntüler aranır; farklı sahne konum/saatle zorla eşleşmez. |
| Geçici disk/izin/ağ kaybı; gerçek dosya silinmesi | Bekleyen seçim korunur; başarılı tam sayımda gerçek kaldırılma uzlaştırılır. |
| Aynı saniyede değişiklik, bilinmeyen revizyon, algoritma değişimi, bozuk cache | Eski kanıt kullanılmaz; yeniden analiz; UI'da yanlış hazır/kopya durumu yok. |
| İptal/arka plan/aşama hatası | Kısmi durum doğru; devam eden başka aşamaya uygun davranış; iptal başarı diye kaydolmaz. |
| Karma kaynak kaldırma iptali/kısmi başarısı ve kurtarma çakışması | Tamamlananlar Geçmiş'te; kalanlar seçili; var olan dosyaya üstten yazma yok. |
| Büyük yazı, VoiceOver, dar Mac penceresi, uygulama içi dil değişimi | Ana eylemler, adet/hedef ve seçim okunur; dört dil tutarlı. |

Sentetik görüntü dönüşümleri sistematik regresyon içindir. Kalite/çok benzer eşikleri ayrıca farklı fotoğraf türlerinden izinli ve etiketli gerçek bir doğrulama kümesinde kalibre edilir. Kullanıcının özel fotoğraf yüklemesi geliştirme önkoşulu değildir.

Ölçümler: ilk kullanılabilir grid, ilk incelenebilir grup, tam yerel analiz, değişmeyen tekrar analiz, değişen öğe tekrar analizi, p50/p95 kaydırma/etkileşim gecikmesi, peak bellek, decode/hash/Vision sayısı, cache hit, iptal gecikmesi ve pil/ısı. Bulut indirmesi ayrı ölçülür. Exact yanlış pozitifler, çok benzer kaçırma/yanlış eşleşme ve kalite false positive türlere göre raporlanır.

İlk ölçüm referans cihazı, arşiv türünü ve erişim durumunu kaydeder; süre/bellek hedefleri bu referans üzerinden konur. “3.000 fotoğraf X saniyede” veya “anında tekrar tarama” vaadi ölçüm olmadan verilmez. Doğrulanmış exact toplu öneride bilinen yanlış eşleşme yayın engelidir; tahmini bulgular için hata türleri ve emin olunmayan durumlar ayrı ele alınır.

## 8. Teslim ve yayın kabulü

Mevcut temel için önceki teslimde 29 portable çekirdek testi, 131 Swift dosyası sözdizimi ve proje/görsel kontrolleri geçti. Bu, yeni kalite sınıflarının, güncel native arayüzün veya 3.000 gerçek fotoğrafta hızın doğrulandığı anlamına gelmez. Sonraki uygulama teslimi davranışı değiştirdi; yeni doğrulama ve kalan native kabul için [teslim raporuna](BULK_CLEANUP_DELIVERY.md) bakın.

Kabul: kullanıcı kaynaklarını bağlayıp tek tarama yapabilir; bütün seçili listelenebilir öğeler görünür; exact/çok benzer/kalite şüphesi ayrılır; ilgili kareler yan yana ve gerekçeleri kısa; seçimler filtre/geçici erişim değişiminde kaybolmaz; toplu öneri korunan öğeleri ve en az bir keeper'ı bırakır; kullanıcı hangi kayıt yerinden ne kaldıracağını ve kurtarma/alan açma yolunu anlar. Native derleme, kaldırma davranışı ve ölçülmüş performans son kabulde tamamlanır.

[Kaynak seçimi teslimi](SOURCE_SELECTION_DELIVERY.md) · [Ayrıntılı toplu temizleme kararları](BULK_PHOTO_CLEANUP_PLAN.md) · [İlk UI/UX incelemesi](UI_UX_AUDIT.md) · [Görsel inceleme kaydı](VISUAL_REGENERATION_REVIEW.md)
