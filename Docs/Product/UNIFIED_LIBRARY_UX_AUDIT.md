# Birleşik fotoğraf arşivi — UI/UX taraması ve uygulama raporu

Tarih: 3 Ekim 2026. Kapsam: Keptora iPhone uygulaması, macOS arşivi, ortak kaynak/tarama/temizlik katmanı. Önceki görsel yenileme raporuna ek çalışmadır. Bu rapor kaynak kodu incelemesine ve burada çalışabilen testlere dayanır; Linux ortamında Xcode, gerçek iPhone ve macOS arayüzü çalıştırılamaz.

## Kullanıcının istediği akış

1. İlk kurulumda Fotoğraflar izni verilir. Dosyalar/iCloud Drive/diğer sağlayıcılardaki istenen klasörler bir kez bağlanır. Mac’te birden fazla klasör aynı seçim penceresinde eklenebilir.
2. Arşiv, bağlı ve erişilebilen kaynakların fotoğraf ve videolarını birlikte gösterir. WhatsApp’tan Fotoğraflar’a kaydedilen öğeler ikinci kez eklenmez; albüm üyeliği kaynak rozeti olarak kullanılır.
3. **Tüm Kaynakları Tara**, aynı taramada bu kaynakların hepsini karşılaştırır. **Bulut Asıllarını Dahil Et** indirmeli taramayı açık onayla başlatır. Bulutta olup okunamayan asıllar arşivden kaybolmaz.
4. **Tüm Öğeler** görünümü benzeri bulunmayanları da gösterir. **Kopyalar & Benzerler** görünümü birebir ve benzer fotoğraf/video gruplarını aynı akışta, farklı başlıklarla gösterir.
5. Fotoğraf üzerindeki rozet kaynak bilgisini verir: `WhatsApp · Fotoğraflar`, `Fotoğraflar / iCloud Fotoğrafları`, `Dosyalar · klasör`, tanınan sağlayıcılarda `Bulut Dosyaları · klasör`. Tutma önerisi gruplarda ayrıca görünür; kullanıcı bunu da elle seçebilir.
6. Kullanıcı istediği öğeleri seçer. Filtre değiştirmek seçimi silmez. Son inceleme kaynak başına öğe sayısını ve kaldırma hedefini gösterir. Fotoğraflar öğeleri Son Silinenler’e, dosyalar kendi kaynaklarının kurtarma klasörüne gider.

## Saptanan sorunlar ve yapılan değişiklikler

| Öncelik | Sorun / kullanıcıya etkisi | Yapılan değişiklik | Doğrulama durumu |
|---|---|---|---|
| Kritik | Fotoğraflar ve klasör seçimi birbirinin yerine geçiyordu; arşivin bir bölümü kaybolmuş gibi görünüyordu. | İki platformda kalıcı, birden fazla kaynak bağlantısı ve ortak adaptör eklendi. | Ortak çekirdek testleri geçti; yerel platform testi CI’da tanımlı. |
| Kritik | Fotoğraflar’daki boyutu bilinmeyen öğe, dosya kopyasıyla farklı aday kovalarında elenebiliyordu. | Bilinmeyen boyutlar artık başka kaynaklarla eşleşmeyi engellemiyor. Birleşik tarama tüm öğeleri gerçek özetle ölçüyor. | Apple çekirdek regresyon testi eklendi; burada çalıştırılamadı. |
| Kritik | Fotoğraflar için kullanılan özet ön eki aynı dosyanın SHA-256 özetiyle uyuşmuyordu. | Tek bileşenli görüntü/video özeti dosyalarla aynı bayt temeline getirildi. | Kaynak incelemesi ve sözdizimi kontrolü; gerçek PhotoKit içe/dışa aktarımı native kabul adımı. |
| Kritik | Live Photo’nun yalnızca sabit karesi eşit olduğunda “birebir kopya” sayılma riski vardı. | Live Photo ve birden fazla kaynak içeren görüntülerde tüm kaynak bileşenleri ayrı özetlenir. Eksik hareketli bileşen eşleşmeyi engeller; aile özeti tek JPEG özetiyle eşit sayılmaz. | Aile/tek dosya ayrımı için Apple regresyon testi eklendi. |
| Kritik | Karma seçim tek aktif kaynağa göre silinebiliyor, yanlış kurtarma açıklaması gösterilebiliyordu. | Kaynak başına işlem grupları, klasör ön kontrolleri, Fotoğraflar’ın sistem onayı ve tamamlanan adımların ayrı geçmiş kaydı eklendi. | Mantık ve sözdizimi kontrol edildi; karma silme/izin iptali gerçek cihazda doğrulanmalı. |
| Yüksek | Kaynak hatası tüm arşivi gizleyebilir veya eksik tarama tamamlanmış sanılabilirdi. | Erişilebilen kaynaklar görünür kalır. Kaynak sayıları, sınırlı izin, kısmi okuma ve erişim hataları kapsam panelinde görünür. | Reddedilmiş, çevrimdışı, sınırlı ve kısmen okunabilen kaynak testleri geçti. |
| Yüksek | Örtüşen klasörler aynı fiziksel yolu iki öğe olarak gösteriyordu. | Normalleştirilmiş ve sembolik bağları çözümlenmiş referanslar tekilleştirildi. Ayrı dosya kopyaları ve Fotoğraflar’dan dışa aktarılan gerçek kopyalar tutulur. | Klasör/albüm örtüşmesi testi geçti. |
| Yüksek | Aynı dosyanın kimliği bağlı klasöre göre değişip seçim kaybolabiliyordu. | Dosya kimliği kaynak yerine normalleştirilmiş gerçek yoldan türetilir. Eski seçim kimlikleri taşınır; adaptör sırası kararlıdır. | Çekirdek kaynak kimliği testi geçti; yerel seçim taşıma kabul adımı eklendi. |
| Yüksek | Kullanıcının incelediği dosya sonradan değişirse yeni içerik kaldırılabilirdi. | Elle seçimde de değiştirilme tarihi/boyut ve PhotoKit revizyonu işlem öncesinde kontrol edilir. Önerilen temizlikte özet tekrar doğrulanır. | Gerçek geçici dosyanın sonradan değişmesi testi geçti. |
| Yüksek | Birebir ve benzer sonuçlar ayrı ekranlarda; tüm fotoğraflar başka akışta bulunuyordu. | Ana arşivde tüm öğeler ve ortak grup görünümü eklendi. Birebir grubun aynısını tekrar eden benzer grup gizlenir; başka fotoğrafa benzerlik ilişkisi korunur. | Ortak grup testi geçti; iPhone seçim/görünüm geçişi UI testi CI’ya eklendi. |
| Yüksek | Gruplu görünümde “bu görünümdekileri seç” arka plandaki ilgisiz fotoğrafları da seçebilirdi. | Seçim kapsamı görünen grup üyeleriyle sınırlandı. Gruplu görünümde arşiv sırasına göre sürükleme seçimi kapatıldı; dokunarak seçim korunur. | Kaynak incelemesi; native UI kabul adımı. |
| Yüksek | WhatsApp dosya adına bakılarak yanlış kaynak etiketi verilebilirdi. | Fotoğraflar için gerçek albüm üyeliği veya kullanıcının açık albüm eşlemesi kullanılır. Dosyalarda bağlı klasör adı gösterilir. | Kaynak rozeti testi geçti. |
| Yüksek | Bulut öğesi görünmeden veya izin olmadan indirme başlayabiliyordu. | Tanınan iCloud dosyalarında yerel erişim kontrolü, indirme onayı, süre sınırı ve iptal kontrolü eklendi. Izgara/meta veri okumaları bu kontrolü kullanır. | Sözdizimi kontrolü; iCloud ve üçüncü taraf sağlayıcılar gerçek cihaz kabul listesinde. |
| Orta | Varsayılan video benzerliği yalnızca ilk 1.500 videoyu kapsıyordu. | Sessiz video sayısı sınırı kaldırıldı. Görsel benzerlikte mevcut tüm-öğe davranışı korunur. | Kaynak ve sözdizimi kontrolü; büyük arşiv performansı native ölçülmeli. |
| Orta | Kaynak seçimi sayfası tarama ve sonuç ekranını tekrar ediyordu. | iPhone Kaynaklar sayfası bağlantı/izin işlemlerine indirildi. Ana tarama arşive taşındı. | Kaynak incelemesi; gerçek ekran görüntüsü CI adımı. |
| Orta | Üst üste kaynak/rehber/dosya seçici sunumları açılmayabiliyordu. | Dosya seçici, önceki sayfanın kapanma geri çağrısından sonra açılır. | Sözdizimi kontrolü; native belge seçici kabul adımı. |
| Orta | Mac’te “Kaynaklar & Analiz” ana arşivle aynı işi yapıyor gibi görünüyordu. | Arşiv ve Geçmiş ana gezinmede; klasör planı araçları ayrı, açıklayıcı adlarla araçlar bölümünde. Eski Fotoğraflar giriş düğmesi ortak arşive yönlendirilir. | Kaynak incelemesi; Mac native kabul adımı. |
| Orta | Mac filtre ve işlem düğmeleri tek satırda dar pencerede sıkışıyordu. | Filtreler ve tarama işlemleri iki satıra ayrıldı; kapsam paneli açılıp kapanır. | Native dar pencere doğrulaması gerekli. |
| Orta | Fotoğrafta kayıt yeri, tutulacak öneri ve kaynak geçişi anlaşılmıyordu. | Yüksek karşıtlıklı metin rozetleri, tutma önerisi ve seçim incelemesinde kaynak/hedef satırları eklendi. iPhone erişilebilirlik etiketi kaynağı da okur. | Kaynak incelemesi; VoiceOver/Dynamic Type native kontrol listesinde. |
| Orta | Sonuç için beklerken hangi aşamanın sürdüğü belli değildi. | Tarama/karşılaştırma ilerlemesi, çalışan aşama, iptal düğmesi ve grupların analiz boyunca değişebileceği açıklaması eklendi. PhotoKit tarama istekleri iptale bağlandı. | Sözdizimi kontrolü; indirme sırasında iptal native kabul adımı. |
| Orta | Filtrelerle boş kalan görünümden çıkış belirsizdi. | Filtre sıfırlama eklendi; görünüm dışında kalan seçimin sayısı korunur. | Mevcut seçim testleri geçti; UI testi CI’da. |
| Orta | Karma silme “alan boşaltma” veya yalnızca Fotoğraflar’dan silme sanılabilirdi. | Dosya kurtarma taşımasının alan boşaltmadığı, iCloud ve bağlı bulut klasörü değişikliklerinin eşitlenebileceği ve kısmi tamamlanmanın geçmişte görüneceği açıklanır. | Metin/katalog kontrolü. |
| Orta | Yeni terimler Türkçe arayüzde İngilizce kalabilirdi. | Yeni akışın metinlerine Türkçe, Fransızca ve Almanca karşılıklar eklendi; İngilizce kaynak metinler korundu. | Katalog ve biçim belirteci kontrolleri. |

## Platform erişim sınırları — ürünün doğru vaadi

**“Tüm telefonu otomatik tara” iOS’ta verilebilecek bir vaat değildir.** Keptora başka uygulamaların özel depolamasını, WhatsApp sohbet veritabanını, izin verilmemiş Fotoğraflar öğelerini veya Dosyalar’ın bütün sağlayıcı köklerini kendiliğinden açamaz. Bunun yerine **tüm bağlı ve izinli kaynakları tek taramada** işler. İlk erişim izinleri/klasör seçimleri zorunludur; sonraki taramalarda bunları tek tek seçmek gerekmez.

| Kaynak | iPhone | Mac | Arşiv/sonuçta açıklama |
|---|---|---|---|
| Galeri / Apple Fotoğraflar | PhotoKit izni; sınırlı izinde yalnızca izin verilen öğeler | Sistem Fotoğraflar kitaplığı için PhotoKit izni | Fotoğraflar kaynağı ve sınırlı izin açıklaması |
| iCloud Fotoğrafları | Aynı PhotoKit kitaplığı; ayrı kopya kaynak değildir | Aynı PhotoKit kitaplığı | Bulutta kalan öğe arşivde kalır; asıl indirme açık seçenek |
| WhatsApp’ın galeriye kaydettiği medya | Albüm üyeliği/kullanıcı albüm eşlemesiyle etiketlenir | Fotoğraflar kitaplığına kaydedilmiş öğeler aynı şekilde | WhatsApp rozeti; sohbet içindeki asılın ayrı olduğu belirtilir |
| WhatsApp özel sohbet depolaması | Uygulama korumalı alanı nedeniyle erişilemez | Keptora özel sohbet veritabanını taramaz | WhatsApp’ın kendi depolama yönetimine rehber |
| Yerel dosyalar / dışa aktarılan WhatsApp klasörü | Dosyalar seçicisiyle izin verilen klasörler | NSOpenPanel ile verilen klasörler | Dosyalar ve bağlı klasör adı |
| iCloud Drive / üçüncü taraf bulut dosyaları | Sağlayıcının izin verdiği seçilmiş klasörler | Finder’a bağlı, izin verilmiş klasörler | Tanınan bulut dosya kaynağı; erişim/indirme sınırları |
| Harici disk | Dosyalar’da sunulan ve izin verilen konumlar | Kullanıcı tarafından bağlanan disk/klasörler | Kopan/erişilemeyen kaynak uyarısı |

PhotoKit’te burst alt öğeleri ve API’nin erişime izin verdiği gizli öğeler için fetch seçenekleri açıldı. Kilitli/sistemce gizlenen veya paylaşım/kurum politikasıyla kısıtlanan içerik için tam erişim garanti edilmez. iCloud etiketinin kitaplık kaynağını anlattığı, her öğenin o anda indirilmiş olup olmadığını kanıtlamadığı unutulmamalıdır. Birden fazla kökteki aynı dosya yolu tekilleştirilir; başka sağlayıcıların farklı kimlikle sunduğu aynı uzaktaki nesnenin tek nesne olduğu kesin olarak bilinemeyebilir.

Üçüncü taraf sağlayıcılar dosya açılışında kendi ayarlarına göre ağ erişimi başlatabilir. Keptora’nın açık indirme kontrolü PhotoKit ve kamuya açık iCloud dosya durumları için uygulanır; tüm sağlayıcıların aktarım davranışı için mutlak bir “hiç ağ kullanılmaz” vaadi verilmez.

## Teknik karşılıklar

- `LibraryWorkflow.swift`: ortak kaynak adaptörü, kapsam raporu, kararlı tekilleştirme, karma grup modeli, kaynak etiketi, işlem öncesi revizyon kontrolü.
- `MobileKeptoraStore.swift`: çoklu klasör kapsamı/bookmark saklama, ortak tarama, seçim taşıma, kaynak bazında temizleme ve kısmi tamamlanma kaydı.
- `MobileArchiveView.swift`, `MobileLibraryView.swift`: arşivde tek tarama, ortak grup görünümü, kaynak yönetimi, kaynak/hedef incelemesi ve dosya seçici sunum sırası.
- `MacArchiveView.swift`: Mac için aynı bağlantı/arşiv/tarama/temizlik davranışı; çoklu klasör seçimi ve kalıcı bookmark’lar.
- `ExactGrouping.swift`, `PhotoLibrarySourceAdapter.swift`, `FolderSourceAdapter.swift`, `VideoSimilarityAnalyzer.swift`: kaynaklar arası özet tutarlılığı, güvenli aile eşleşmesi, bilinmeyen boyutların elenmemesi, iCloud erişimi ve tüm videolar.
- `SidebarRoute.swift`, `MainRootView.swift`, `HomeView.swift`: birleşik arşivi birincil akış yapma ve gelişmiş klasör araçlarını açıklayıcı adlarla sunma.

## Doğrulama ve henüz kanıtlanmamış noktalar

Yerel doğrulama: 20 taşınabilir çekirdek testi geçti; 131 Swift dosyasının sözdizimi kontrolü geçti; proje referansları, 4 yüksek çözünürlüklü uygulama görseli, Türkçe biçim belirteçleri ve önceki 67 görselin tüm hash/boyut/fixture/ZIP kontrolleri geçti. Apple framework’lerinin gerçek tip kontrolü ve uygulama derlemesi burada yapılamaz. `.github/workflows/apple-validation.yml` tam Apple çekirdeği/macOS birim testlerini, iPhone derlemesini, gerçek JPEG’lerle hazırlanan simülatörde ortak taramayı ve görünüm değiştirirken seçimin korunmasını çalıştıracak şekilde güncellendi. Eklenen 3 Apple çekirdek regresyon testi ve 2 iPhone UI testi burada geçmiş sayılmaz; GitHub çalışma sonucu ayrıca incelenmelidir.

Gerçek cihaz/Mac kabul adımları:

1. Fotoğraflar + iki yerel klasör + bağlı bulut klasörü ekle; tek düğmeyle tarayıp tüm öğeleri aynı arşivde gör.
2. Bir JPEG’i Fotoğraflar’a ve bağlı klasöre aynı baytlarla koy; tek birebir grupta iki kaynak rozeti gör. Düzenlenmiş dışa aktarımı benzer olarak, birebir diye sunmadan kontrol et.
3. Aynı sabit kareye fakat farklı hareketli videoya sahip iki Live Photo kullan; birebir kopya grubuna girmediklerini doğrula.
4. İç içe klasörleri bağla; aynı yola iki hücre oluşmasın. Uygulamayı kapat/aç; bağlantı ve seçim korunsun.
5. Kaynağı çıkar, PhotoKit iznini daralt/iptal et ve bir alt klasörü okunamaz yap; erişilebilen kaynaklar kalırken kapsam uyarısını gör.
6. En az 1.501 video içeren arşivde karşılaştırmanın sessizce kesilmediğini doğrula; gerçek bellek, pil ve süreyi ölç. Tüm-öğe özetleme eski tekil dosya kısa yolundan daha fazla iş yapar.
7. Ortak grup görünümünde tüm görünenleri seç; ilgisiz tekil fotoğraflar seçilmesin. Tüm Öğeler’e dönünce seçim korunsun.
8. WhatsApp albümünü elle eşle; rozeti kontrol et. Fotoğraflar’da silmenin sohbet içindeki asılı sildiği izlenimi oluşmasın.
9. iCloud asılı yerelde değilken ızgara/detay aç; onay verilmeden indirilmesin. İndirmeli taramayı açıp iptal et. Üçüncü taraf sağlayıcı davranışını ayrıca izle.
10. Fotoğraflar + iki klasörden karma seçim yap. Sistem Fotoğraflar onayını iptal edince dosya hareketi başlamasın. Bir klasör adımı sonradan başarısız olursa tamamlanan adımlar Geçmiş’te, kalanlar seçili kalsın.
11. Seçilen dosyayı incelemeden sonra değiştir; işlem dursun. Geçmişten dosyayı eski yerine geri al; var olan başka bir dosyanın üzerine yazılmasın.
12. iPhone SE/Pro Max, yatay görünüm, en büyük yazı boyutu ve VoiceOver; Mac dar pencere/klavye gezinmesi: kaynak rozetleri, seçili sayı, işlem hedefleri ve iptal düğmesi erişilebilir olsun.

Önceki 67 görsel bu değişiklikte yeniden üretilmedi; mevcut yenilenmiş varlıklar korunur. Önceki tasarım önizlemeleri yeni birleşik akışın native ekran kanıtı değildir. Güncel ekran kanıtı simülatör test eklerinden ve gerçek Mac ekran doğrulamasından alınmalıdır.
