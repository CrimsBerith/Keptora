# Keptora — UI ve UX inceleme raporu

> 3 Ekim 2026 güncellemesi: kaynakların tek arşivde birleştirilmesi, ortak kopya/benzer sonuçları ve platform erişim sınırları için [Birleşik Arşiv UI/UX Raporu](UNIFIED_LIBRARY_UX_AUDIT.md).

**Tarih:** 3 Ekim 2026
**İncelenen sürüm:** `51442d562b91be83e3f7fce9cf8180c145cafe50`
**Kapsam:** Keptora macOS ve iPhone. Eris kapsam dışı.
**Yöntem:** SwiftUI kaynakları, seçim/temizleme/kurtarma davranışları, ortak tasarım sistemi, yerelleştirme kataloğu ve depodaki 12 ekran görüntüsü birlikte incelendi. Uygulama kaynaklarında değişiklik yapılmadı.

## 1. Ana değerlendirme

Keptora’nın güçlü tarafı, kullanıcıya güvenli ve yerel bir arşiv inceleme deneyimi sunmayı hedeflemesi. Klasör ile Fotoğraflar kaynaklarının ayrılması, birebir kopyaların doğrulanması, temizleme öncesi onay, Geçmiş üzerinden kurtarma, boş durum ekranları ve belirgin seçim göstergeleri iyi temeller oluşturuyor.

En büyük geliştirme alanı **güven vaadini gerçek işlem davranışıyla eşleştirmek**. “Korunan asıl kopya”, “her zaman geri alınabilir” ve “yer açma” söylemleri bazı akışlarda davranışı tam anlatmıyor. Bunları düzeltmeden yalnızca renk, animasyon ve kart tasarımını değiştirmek ürünün asıl sorununu çözmez.

İkinci büyük alan, fotoğrafların ve kullanıcının sıradaki kararının ekranın merkezine alınması. Mevcut ekranlarda marka başlıkları, kartlar, güven açıklamaları, seçim araçları ve teknik kontroller çoğu zaman fotoğrafın kendisiyle yarışıyor. Özellikle iPhone’da üst kontroller ile alt temizleme alanı birlikte kullanılabilir görüntü alanını daraltıyor.

Önerilen sıra: **güven ve kurtarma → seçim kapsamı ve geri bildirim → ekran hiyerarşisi → görsel sistem → dönüşüm ve ileri araçlar**.

## 2. Kanıt sınırları

- Bu ortam Linux. macOS/iOS uygulaması canlı çalıştırılmadı; dokunma davranışı, VoiceOver sırası, gerçek performans ve Dynamic Type taşmaları cihazda doğrulanmadı.
- Kodda doğrudan görülen davranışlar aşağıda “Kod” olarak işaretlendi. Bunlar çalışma zamanı kullanıcısı üzerinde yeniden üretilmiş test sonuçları değildir.
- Depodaki görüntüler mevcut kaynak koduyla aynı anda çekilmiş kabul edilmedi. Örneğin Mac görüntülerinde güncel kodda bulunan Akıllı Kategoriler rotası görünmüyor. Görüntü bulguları, incelenen görselin durumuna aittir.
- Bazı görüntüler gerçek içerik yerine boş veya hata durumlarını gösteriyor. Bu, üretimde bütün küçük resimlerin bozuk olduğunu kanıtlamaz; tanıtım görsellerinin ürün değerini göstermediğini kanıtlar.
- Kontrast hesapları tasarım tokenlarının düz renkleri için yapıldı. Material, gradient, fotoğraf, sistem modu ve alfa bileşiminden oluşan son piksel kontrastı ölçülmedi.

### Öncelik tanımları

| Seviye | Anlam |
|---|---|
| P0 | Veri güvenliği algısını veya kurtarma yolunu doğrudan etkileyen; yayın öncesi ele alınması gereken bulgu |
| P1 | Temel görevin anlaşılmasını, tamamlanmasını veya erişilebilirliğini belirgin etkileyen bulgu |
| P2 | Akıcılık, öğrenilebilirlik, görsel tutarlılık ve ürün değerini geliştiren bulgu |

Efor tahminleri görecelidir: S küçük metin/bileşen düzenlemesi; M bir ekran veya durum akışı; L birden fazla platform ve durum modeli. Bunlar takvim taahhüdü değildir.

## 3. Önceliklendirilmiş iş listesi

| ID | Bulgu | Öncelik | Platform | Efor |
|---|---|---|---|---|
| UX-01 | Korunan asıl kopya seçilebiliyor | P0 | iOS, Mac Fotoğraflar | M |
| UX-02 | Kurtarma kaydı onaysız silinebiliyor | P0 | iOS | M |
| UX-03 | Süresiz geri yükleme vaadi yanlış | P0 | Özellikle iOS | S–M |
| UX-04 | Karantina büyüklüğü ile boşalan alan ayrılmıyor | P1 | Ortak | M |
| UX-05 | Filtre değişince görünmeyen seçimler temizliğe dahil | P1 | iOS | M |
| UX-06 | İşlem sonrası hedef mesajı kaynakla uyuşmuyor | P1 | iOS | S |
| UX-07 | Temizleme sırasında belirgin işlem durumu yok | P1 | iOS | M |
| UX-08 | Kritik metinler Türkçe/İngilizce karışıyor | P1 | Ortak | M |
| UX-09 | Küçük resim başarısızlığı açıklanmıyor | P1 | Özellikle iOS | M |
| UX-10 | Benzerlik hatası boş sonuç gibi görünebiliyor | P1 | iOS | M |
| UX-11 | İnceleme araçları fotoğraf alanını daraltıyor | P1 | Ortak | M |
| UX-12 | Ana ekran, kullanıcının sıradaki adımını yeterince öne çıkarmıyor | P1 | Ortak | M |
| UX-13 | Dokunma hedeflerinin gerçek sınırları doğrulanmalı | P1 | iOS | S–M |
| UX-14 | Gradient üzerinde beyaz metin kontrastı riskli | P1 | Ortak | M |
| UX-15 | Dynamic Type ve dar pencere düzenleri eksik doğrulanmış | P1 | Ortak | M |
| UX-16 | Kota, toplu seçim sırasında beklenmedik paywall açabiliyor | P1 | iOS | M |
| UX-17 | Akıllı Kategoriler kaynak ve kapsam beklentisiyle uyuşmuyor | P1 | Mac | M–L |
| UX-18 | İzin uyarısı ilgisiz kaynakta da baskın | P2 | iOS | S |
| UX-19 | Teknik terimler ana karar akışında fazla görünür | P2 | Mac | M |
| UX-20 | Ücretsiz güvenlik ile Pro değer önerisi ayrışmalı | P2 | Ortak | M |
| UX-21 | Ayarlar simgesi hesap ekranını çağrıştırıyor | P2 | iOS | S |
| UX-22 | Tanıtım görselleri temel başarı durumlarını göstermiyor | P1 | Ortak | M |
| UX-23 | İlk kullanım, ilk başarılı taramaya daha doğrudan bağlanmalı | P2 | Ortak | M |
| UX-24 | Karşılaştırmada kimlik, büyütme ve erişilebilirlik daha açık olmalı | P2 | Ortak | M |

## 4. Güven, seçim ve kurtarma bulguları

### UX-01 — “Korunan asıl kopya” ile seçilebilir asıl kopya çelişiyor

**Kanıt: Kod.** [iOS seçim işlemi](../../KeptoraiOS/App/MobileKeptoraStore.swift) asıl kopyaya özel engel olmadan ID’yi seçim kümesine ekliyor. [Mac Fotoğraflar seçimi](../../Keptora/Features/Home/MacPhotosLibraryView.swift) de aynı davranışa sahip. [iOS onay metni](../../KeptoraiOS/UI/MobileReviewView.swift), bütün kopyalar ve asıl öğe seçildiğinde bunların silineceğini açıkça uyarıyor. Buna karşılık onboarding, asıl kopyanın her zaman korunduğunu söylüyor; kartlar kalkan ve “protected keeper” etiketi taşıyor.

**Kullanıcıya etkisi:** Kalkanı “seçilemez, dokunulmaz” olarak yorumlayan kullanıcı, küçük resme dokunarak korunduğunu düşündüğü öğeyi temizleme listesine alabilir. Son onaydaki uyarı, önceki güven mesajıyla çelişir.

**Öneri:** Varsayılan inceleme akışında her grupta en az bir öğe seçilemez olarak korunmalı. Kullanıcı asıl öğeyi değiştirmek istiyorsa ayrı bir “Bunu koru” eylemiyle yeni korunan öğeyi seçmeli; önceki öğenin koruması ancak yeni öğe belirlendikten sonra kalkmalı. Bütün kopyaları kaldırma ayrı bir ürün hedefiyse, güvenli kopya temizliği akışından açıkça ayrılmalı.

**Kabul ölçütü:** Hiçbir varsayılan seçim/toplu seçim/filtre geçişi gruptaki son kalan öğeyi temizleme listesine alamamalı. Onboarding, kart, onay ve işlem davranışı aynı koruma kuralını anlatmalı. Bu yalnızca yeni bir uyarı metniyle kapatılmamalı.

### UX-02 — Geçmiş satırını silmek, uygulama içi kurtarma erişimini kaldırabiliyor

**Kanıt: Kod.** [Geçmiş listesi](../../KeptoraiOS/UI/MobileHistoryView.swift) `onDelete` ile doğrudan [deleteHistory](../../KeptoraiOS/App/MobileKeptoraStore.swift) çağırıyor. İşlem kayıtları çıkarıp kalıcı geçmişi yazıyor; geri yüklenmemiş klasör kayıtlarına özel kontrol yok. [Restore](../../KeptoraiOS/App/MobileKeptoraStore.swift), ilgili geçmiş girdisinin `folderRecord` bilgisini kullanıyor.

**Kullanıcıya etkisi:** Bir kullanıcı geçmişi düzenlemek için satırı kaydırıp sildiğinde, dosyalar karantinada kalırken uygulamadaki “Dosyaları Geri Yükle” yolunu kaybedebilir. Bu bulgu dosyaların kalıcı silindiği anlamına gelmez; görünür kurtarma kaydının kaldırıldığı anlamına gelir.

**Öneri:** Geri yüklenmemiş klasör kayıtları silinememeli veya “Geçmişten gizle” işlemi kurtarma manifestini ayrı ve kalıcı bir kayıt deposunda korumalı. Aktif kurtarma kaydının kaldırılması gerekiyorsa somut sonuç açıklanmalı. Tercih edilen çözüm, kayıt gizleme ile kurtarma bilgisini silmeyi ayırmak.

**Kabul ölçütü:** Aktif karantina kaydı gizlense, uygulama kapansa ve yeniden açılsa bile dosyalar uygulama üzerinden kurtarılabilmeli. Satır kaldırıldıktan sonra geri alma sunulmalı; yalnızca Toast göstermek, manifest kayboluyorsa yeterli değildir.

### UX-03 — “Her zaman geri yüklenebilir” vaadi daraltılmalı

**Kanıt: Kod ve görüntü.** [MobileOnboardingView](../../KeptoraiOS/UI/MobileOnboardingView.swift), “restored at any time” diyor. [Onay mesajı](../../KeptoraiOS/UI/MobileReviewView.swift), aynı cümlede “at any time” ve “up to 30 days” ifadelerini kullanıyor. [Mac onboarding](../../Keptora/Features/Onboarding/OnboardingView.swift) “Undo anything, any time” diyor.

**Kullanıcıya etkisi:** Kullanıcı geri yükleme için süresiz zamanı olduğunu sanabilir. Fotoğraflar ve dosya karantinasının kurtarma koşulları da birbirine karışır.

**Önerilen metinler:**

- Fotoğraflar: “Seçilen öğeler Son Silinenler’e taşınır. Apple Fotoğraflar’da en fazla 30 gün içinde, kalıcı olarak silinmedikleri sürece geri yükleyebilirsiniz.”
- Dosyalar: “Seçilen dosyalar bu klasördeki Keptora kurtarma alanına taşınır. Dosyalar ve kurtarma kaydı mevcut kaldığı sürece Geçmiş’ten geri yükleyebilirsiniz.”
- Genel onboarding: “Temizlemeden önce planı inceleyin. Geri yükleme yolu ve koşulları seçtiğiniz kaynağa göre değişir.”

**Kabul ölçütü:** “Her zaman”, “her şeyi”, “süresiz” gibi mutlak vaatler kaldırılmalı. Fotoğraflar için geçmişte kalan süre ancak uygulamanın elindeki verilere göre tahmini olduğu belirtilerek gösterilmeli; dışarıdan yapılan kalıcı silme uygulama tarafından bilinmiyorsa “kesin kurtarılabilir” denmemeli.

### UX-04 — “Yer açma” ile “karantinaya taşıma” ayrılmalı

**Kanıt: Kod.** [FolderQuarantineExecutor](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderQuarantineExecutor.swift) karantinayı seçilen kökün altında `.Keptora Quarantine` içine oluşturuyor ve dosyaları taşıyor. Bu işlem aynı kaynak/volume üzerinde dosya baytlarını ortadan kaldırmıyor. Ana ekranda “Make room”, “Potential recovery”, “Space” gibi ifadeler bulunuyor.

**Kullanıcıya etkisi:** 5 GB dosyayı karantinaya taşıdıktan sonra diskte 5 GB boşluk bekleyen kullanıcı, ürünün çalışmadığını düşünebilir. Fotoğraflar’daki Son Silinenler de anında kesin boşalan alan olarak sunulmamalı.

**Öneri:** Üç ayrı ölçüm kullanın: “İncelenen kopya boyutu”, “Kurtarma alanına taşınan boyut”, “Gerçekte boşalan alan”. Sonuncusu ölçülmediyse gösterilmemeli. Karantina sonrası “Arşivinizden ayrıldı; kurtarma alanında tutulduğu için disk alanı henüz boşalmadı” açıklaması verilmeli. Kalıcı kaldırma özellik olarak yoksa bir arayüz düğmesi varmış gibi tasarlanıp vaat edilmemeli.

**Kabul ölçütü:** Taşınan toplam bayt “boşalan alan” sayacına eklenmemeli. Gerçek cihazdaki önce/sonra depolama davranışı ayrı test edilmeli.

### UX-05 — Filtrelerin arkasında kalan seçimler işlem kapsamını belirsizleştiriyor

**Kanıt: Kod.** [Review görünümü](../../KeptoraiOS/UI/MobileReviewView.swift) grupları Fotoğraflar/Videolar filtresiyle ayırıyor. `selectedCount`, global `selectedAssetIDs` kümesinden geliyor. [selectedSafeAssets](../../KeptoraiOS/App/MobileKeptoraStore.swift) bütün exact gruplardan seçilenleri topluyor; [cleanupSelection](../../KeptoraiOS/App/MobileKeptoraStore.swift) bu global listeyi kullanıyor.

**Senaryo:** Fotoğraflar sekmesinde iki öğe seç → Videolar’a geç → bir video seç → temizlemeyi başlat. Kullanıcının gördüğü video listesi, temizlenen bütün listeyi temsil etmiyor.

**Öneri:** Global seçim isteniyorsa alt barda “3 seçildi · 2 fotoğraf, 1 video” gösterin. “Seçimi incele” ekranı, görünmeyen öğeleri de listelemeli. Eylem açıkça “Tüm seçimleri…” olmalı. Alternatif olarak seçimler medya türü başına ayrı tutulmalı. Filtre değişince sessizce temizlemek uygun çözüm değildir.

**Kabul ölçütü:** Her onayda tür, kaynak, adet ve toplam boyut aynı işlem anlık görüntüsünden üretilmeli. Kullanıcı bütün işlem kapsamını onaydan önce görebilmeli.

### UX-06 — Klasör temizliği sonrasında yanlış hedef anlatılıyor

**Kanıt: Kod.** [Başarı bildirimi](../../KeptoraiOS/UI/MobileReviewView.swift), kaynak ayrımı yapmadan “Selected items moved safely to Recently Deleted…” gösteriyor. [Store](../../KeptoraiOS/App/MobileKeptoraStore.swift) klasör kaynağında Keptora karantinasını kullanıyor.

**Öneri:** Sonuç metni işlemin kaynak ve gerçek sonucundan üretilsin: “2 dosya Keptora kurtarma alanına taşındı” veya “2 fotoğraf Son Silinenler’e taşındı”. Eylemler de “Dosyaları geri yükle” ile “Fotoğraflar’da kurtarma adımlarını gör” olarak ayrılsın.

**Kabul ölçütü:** Fotoğraflar ve Files başarı bildirimi, Geçmiş kaydı ve kurtarma eylemi aynı hedefi göstermeli.

### UX-07 — Temizleme sırasında kullanıcıya görünür işlem durumu eksik

**Kanıt: Kod.** Store [isCleaningUp](../../KeptoraiOS/App/MobileKeptoraStore.swift) ile tekrar işlemi engelliyor. MobileReviewView’de bu durumla bağlı görünür yükleme, seçim kilidi veya temizleme düğmesi devre dışı bırakma bulunmuyor. İç koruma tekrar işi engellese de kullanıcı ne olduğunu göremiyor.

**Öneri:** “Seçim doğrulanıyor”, “Dosyalar taşınıyor”, “Kayıt oluşturuluyor” gibi anlaşılır aşamalar gösterin. Görünen seçim ve işlem özeti sabitlensin. Aşamaya göre izin verilen vazgeçme davranışı açık olsun; güvenli iptal desteklenmeyen bir aşamada iptal düğmesi vaat etmeyin.

**Kabul ölçütü:** İşlem başlatıldıktan sonra tekrar dokunma belirsiz bir sessiz sonuç üretmemeli. Başarı, kısmi durum ve hata farklı anlatılmalı. VoiceOver işlem başlangıç ve sonucunu duyurmalı.

## 5. Dil, durumlar ve görsel güven

### UX-08 — Kritik akışlarda yerelleştirme boşlukları

**Kanıt: Kod, katalog ve görüntü.** Türkçe iPhone görüntülerinde İngilizce kalan “Move exact copies to Keptora Bin?”, “Move to Bin”, “Open Apple Photos” ve “Retry Loading Product” metinleri var. Bu anahtarlar ortak [Localizable.xcstrings](../../Keptora/Resources/Localizable.xcstrings) kataloğunda bulunmuyor. Geri yükleme vaadinin bazı tam cümleleri de eksik. Geçmişte “3 item”, “Keptora Safe Bin” görülüyor.

**Öneri:** Önce hata, silme/taşıma, kurtarma, ödeme ve izin metinlerini tamamlayın. Bir terim sözlüğü oluşturun: “Birebir kopyalar”, “Benzer öğeler”, “Korunan kopya”, “Temizleme planı”, “Kurtarma alanı”, “Son Silinenler”. “Güvenli Fotoğrafların Tümünü Seç” yerine “Kopyaları seç”; kapsam gerekiyorsa “Tüm gruplardaki kopyaları seç”. Fotoğrafın kendisini “güvenli” olarak sınıflandıran uzun ifadelerden kaçının.

**Kabul ölçütü:** Türkçe kritik yolunda beklenmedik İngilizce olmamalı. Çoğul, sayı, tarih ve medya türü doğru olmalı. Metin uzunluğunu yalnızca küçültme veya üç noktayla çözmeyin.

### UX-09 — Küçük resim yoksa kullanıcı sebebini ve çözümünü göremiyor

**Kanıt: Kod ve görüntü.** [MobileAssetThumbnail](../../KeptoraiOS/UI/MobileAssetThumbnail.swift), yükleme bitince görüntü yoksa yalnızca fotoğraf/video simgesi gösteriyor. PhotoKit’te ağ kapalı. İncelenen iPhone exact ve comparison görsellerinde içerik yerine bu tür placeholder’lar var.

**Öneri:** Durumları ayırın: yükleniyor; yalnızca iCloud’da; erişim kaybedildi; dosya bulunamadı; önizleme üretilemedi. “Önizleme alınamadı · Tekrar dene” gösterin. iCloud gerekiyorsa kullanıcıya boyut/ağ açıklamasıyla açık indirme eylemi sunun. Önizleme sorunu kaynak dosyanın bozuk olduğunu tek başına iddia etmemeli.

**Kabul ölçütü:** Kullanıcı sebebi görmeden boş simge üzerinden görsel benzerlik kararı vermeye yönlendirilmemeli. Tanıtım çekimlerinde gerçek küçük resimlerin yüklenmiş olması kontrol edilmeli.

### UX-10 — Benzerlik hatası ile “benzer bulunamadı” durumu ayrılmalı

**Kanıt: Kod.** [Video benzerlik hatası](../../KeptoraiOS/App/MobileKeptoraStore.swift) konsola yazılıp grupları boşaltıyor. [Review boş durumu](../../KeptoraiOS/UI/MobileReviewView.swift), boş sonucu “No similar groups” şeklinde sunabiliyor. Bu görünüm hatalı analiz ile gerçekten sıfır sonucu ayıramaz.

**Öneri:** Her analiz için “başlatılmadı / sürüyor / tamamlandı / kısmen tamamlandı / başarısız / iptal edildi” durumu tutun. Birebir tarama başarılıysa sonucu koruyun; benzerlik hatasını ayrı bir kartta gösterin ve yalnızca bu aşamayı tekrar çalıştırın.

**Kabul ölçütü:** Yapay bir analiz hatası “0 benzer öğe bulundu” olarak gösterilmemeli. Kullanıcı hangi kısmın tamamlandığını anlamalı.

### UX-18 — İzin uyarısı seçili kaynakla orantılı gösterilmeli

**Kanıt: Kod ve görüntü.** [MobileLibraryView](../../KeptoraiOS/UI/MobileLibraryView.swift) Fotoğraflar izni reddedildiğinde, Files kaynağı seçiliyken de büyük uyarı kartını gösteriyor. İncelenen Library görüntüsünde Files bağlı olmasına rağmen kırmızı izin alanı önemli yer kaplıyor.

**Öneri:** Fotoğraflar seçildiğinde tam açıklama; Files seçiliyken Fotoğraflar satırında küçük “Erişim kapalı” durumu kullanın. Files taramasının bundan etkilenmediğini anlaşılır biçimde belirtin. İzin istenmesini kullanıcı seçimiyle ilişkilendirin.

**Kabul ölçütü:** Files seçen bir kullanıcı ilgisiz Fotoğraflar uyarısı nedeniyle görevini engellenmiş sanmamalı.

## 6. Ekran düzeni ve erişilebilirlik

### UX-11 — İnceleme alanı sadeleştirilmeli

**Kanıt: Kod ve görüntü.** Mac exact görüntüsünde üst araç çubuğunda, grup başlığında, kartlarda ve alt rafta benzer seçim/karar eylemleri tekrarlanıyor; bazı etiketler “Ad…” veya “Select All Safe C…” olarak kesiliyor. iPhone’da iki segmented kontrol, yatay seçim satırı ve büyük alt temizleme alanı fotoğraf alanını daraltıyor. [MobileReviewView](../../KeptoraiOS/UI/MobileReviewView.swift), [ReviewStudioView](../../Keptora/Features/ReviewStudio/ReviewStudioView.swift).

**Öneri:** Mac’te tek üst satır: kaynak, mod, grup ilerlemesi; ortada büyük fotoğraf alanı; altta tek karar/plan rafı. Kart üstünde yalnızca koruma ve seçim durumu; kart altındaki tekrar karar düğmeleri kaldırılabilir. Global seçim overflow menüsüne taşınmalı veya kapsamı açık tek eylem olmalı. iPhone’da medya filtresi daha kompakt, grup içi seçim kısa metinli, global seçim ayrı menüde olsun. Alt alan tek satır özet ve bir birincil eylemden oluşsun.

**Kabul ölçütü:** Kullanıcı aynı karar için dört ayrı kontrol öğrenmek zorunda kalmamalı. Temel etiketler kesilmeden görünmeli. Tam görsel görüntüleyici ile “seçme” eylemleri ayırt edilmeli.

### UX-12 — Ana ekran durum odaklı olmalı

**Kanıt: Kod ve görüntü.** [Mac Home](../../Keptora/Features/Home/HomeView.swift) ve [iOS Library](../../KeptoraiOS/UI/MobileLibraryView.swift) marka, kaynak, tarama, sonuç ve güven alanlarını sıralıyor. Mac görüntüsünde tamamlanmış tarama varken hem yeni tarama hem inceleme hem devam etme hem Pro çağrısı görünür. iPhone görselinde büyük hero ve kaynak kartları sonuç alanını aşağı itiyor.

**Önerilen hiyerarşi:**

| Durum | İlk görünmesi gereken içerik | Birincil eylem |
|---|---|---|
| İlk kullanım | Kaynak seçimi + kısa güven açıklaması | Fotoğraflar/Klasör seç |
| Kaynak bağlı | Seçilen kaynak ve kapsam | Taramayı başlat |
| Tarama sürüyor | Aşama ve ilerleme | Destekleniyorsa duraklat/iptal |
| Sonuç var | Grup sayısı, kopya boyutu ve kapsam | Kopyaları incele |
| Yarım inceleme | Son grup ve seçili öğeler | İncelemeye devam et |
| Temizleme tamamlandı | Gerçek hedef ve kurtarma yolu | Geçmişi aç |

Hero ilk kullanımda daha büyük olabilir; dönüş ziyaretinde küçülmeli. Fotoğraf arşivini tekrar kullanan kişi her seferinde pazarlama başlığı okumamalı.

**Kabul ölçütü:** Ana ekranda bir belirgin birincil eylem olmalı. Sonuç/yarım inceleme hazırken küçük ekranda gereksiz kaydırma yapmadan erişilebilmeli.

### UX-13 — iPhone dokunma hedefleri ve yanlış eylem riski

**Kanıt: Kod; cihazda doğrulanmalı.** Grup ileri/geri kontrollerinde 30×30 çerçeveler var. [Kart seçim/inceleme kontrolleri](../../KeptoraiOS/UI/MobileReviewView.swift) 36×36 çerçeve, pozitif ve negatif padding kullanıyor. Bu yüzden son hit alanının yalnızca kaynak boyutundan kesin ölçüleceği varsayılmamalı.

**Öneri:** iPhone’da etkileşim alanlarını açıkça en az 44×44 pt yapın; simge daha küçük kalabilir. Önizleme açma ve seçme hedefleri birbirine girmesin. Küçük resmin tamamına dokununca seçim değiştiği için, kullanıcıların alışılmış “fotoğrafa dokun → büyüt” beklentisini test edin. Tercih: fotoğrafı dokunarak açmak, seçim kutusuyla seçmek.

**Kabul ölçütü:** Hit-test sınırları cihazda ölçülmeli. Tek elle kullanımda yanlış seçim ve yanlış görüntüleyici açma oranı izlenmeli; her kontrol VoiceOver ile ayrı ulaşılabilir olmalı.

### UX-14 — Marka gradient’i ile eylem rengi ayrılmalı

**Kanıt: Hesap ve kod.** [MobilePrimaryButtonStyle](../../KeptoraiOS/UI/MobileDesignSystem.swift) beyaz metni cyan→accent→violet→coral gradient üzerine koyuyor. Düz tokenlar için beyaz kontrastı: cyan **2,65:1**, accent **5,79:1**, coral **2,94:1**, mint **3,21:1**. Bunlar tüm düğmenin gerçek piksel kontrastı değildir; açık uçların riskini gösterir. Normal metin için 4,5:1, büyük metin için 3:1 hedefi kullanılmalı.

**Öneri:** Gradient’i logo, hero ve dekoratif alanlarda koruyun. Birincil eylemlerde yeterince koyu, tek bir accent zemin kullanın veya metnin altındaki gradient bölümünü koyulaştırın. Tehlike eylemi, başarı ve seçim renkleri tutarlı olsun. Kartlarda renkli kenarlık + glow + gölge + material birleşimini azaltın.

**Kabul ölçütü:** Açık/koyu mod, Increase Contrast ve Reduce Transparency ile gerçek render ölçülmeli. Seçim yalnızca renkle anlatılmamalı; işaret ve metin de bulunmalı.

### UX-15 — Büyük yazı ve dar pencere düzenleri

**Kanıt: Kod; cihazda doğrulanmalı.** iPhone hero [26 pt sabit yazı](../../KeptoraiOS/UI/MobileLibraryView.swift) ve iki satır sınırı kullanıyor. Metrik başlıklarında tek satır sınırları var. Mac [onboarding](../../Keptora/Features/Onboarding/OnboardingView.swift) 720×620; [SafetyPlan](../../Keptora/Features/SafetyPlan/SafetyPlanSheet.swift) 760×560 minimum boyut kullanıyor; planın üstünde beş metrik yan yana duruyor. Öte yandan `ViewThatFits`, semantik fontlar ve bazı `@ScaledMetric` kullanımları olumlu.

**Öneri:** Kritik yazıları semantik fonta bağlayın; erişilebilirlik yazı boyutlarında satır sayısı ve grid değişsin. Metrikler iki sütundan tek sütuna geçebilsin. Onboarding içeriği scroll edilebilir olsun. Dar Mac penceresinde araç çubukları eylem önceliğine göre yeniden yerleşsin; kritik düğme etiketleri kesilmesin.

**Kabul ölçütü:** En küçük desteklenen iPhone, yatay kullanım, en büyük erişilebilirlik yazı boyutları, 1280×800 Mac ekran ve dar pencere test edilmeli. Bir kontrolün küçültülmüş yazıyla “sığması” yeterli sayılmamalı.

## 7. Ürün akışı, öğrenilebilirlik ve ödeme

### UX-16 — Kota, seçimden önce anlaşılmalı

**Kanıt: Kod.** [authorizeReview](../../KeptoraiOS/App/MobileKeptoraStore.swift), daha önce görülmeyen ID’lerin tamamı kota içine sığmıyorsa bütün işlemi reddediyor. [Toplu seçim](../../KeptoraiOS/UI/MobileReviewView.swift) false sonucunda paywall açıyor. Örneğin kalan 100 hakkı olan kullanıcı 120 kopya seçmek istediğinde neden seçim oluşmadığı görünür şekilde açıklanmıyor. Yeni seçim ID’leri kalıcı inceleme sayacına ekleniyor; kullanıcı açısından “inceleme hakkı”nın hangi eylemde harcandığı açıklanmalı.

**Öneri:** Toplu eylem öncesi “120 kopya · 100 ücretsiz inceleme hakkınız kaldı” bilgisi verin. Ürün kuralı uygunsa “100 kopyayı seç” ve “Pro ile tümünü seç” seçenekleri sunun. Kota tüketiminin bir öğe başına mı, karar başına mı olduğu açık anlatılsın. Kullanıcı yaptığı seçimleri ve kurtarma erişimini paywall nedeniyle kaybetmemeli.

**Kabul ölçütü:** Kota sınırında seçim davranışı öngörülebilir olmalı. Paywall kapatılınca kullanıcı bulunduğu grup ve önceki seçimlerle devam edebilmeli.

### UX-17 — Akıllı Kategoriler vaat ettiği kapsamı göstermeli

**Kanıt: Kod.** [SmartBucketsView](../../Keptora/Features/PhotoViewer/SmartBucketsView.swift), Fotoğraflar veya klasör taramasıyla ekran görüntüleri, belgeler, büyük videolar ve burst’lerin sınıflanacağını söylüyor. [startSwipeCulling](../../Keptora/Features/PhotoViewer/SmartBucketsView.swift) ise `model.duplicateGroups` içindeki korunan olmayan öğeleri dolaşıyor. Fotoğraflar ayrı `MacPhotosLibraryModel` akışında. Bu ekrandan bütün bağımsız büyük videoların veya bütün Fotoğraflar arşivinin incelenebileceği beklentisi mevcut kapsamdan geniş.

**Öneri:** Şimdiki davranış korunacaksa başlık “Kopyalar içindeki kategoriler” olmalı; kaynak ve kapsam görünmeli. Fotoğraflar/benzersiz büyük medya desteği ürün hedefiyse önce ortak veri ve karar akışı tasarlanmalı; yalnızca kart eklemek yeterli değil. Kategori sayılarıyla “temizlenebilir kopya” sayıları ayrılmalı.

**Kabul ölçütü:** Yalnızca benzersiz büyük videolar içeren arşiv, kopya arşivi ve Fotoğraflar taraması ayrı test edilmeli. Ekran neyi saydığını ve neyi inceleyebildiğini doğru söylemeli.

### UX-19 — Teknik terimler ikinci katmana taşınmalı

**Kanıt: Kod ve görüntü.** Mac ekranlarında “Review Floor”, “Reconcile”, “Evidence”, “SHA-256”, “signed manifest”, “lineage” gibi kavramlar birincil yüzeylerde. [SafetyPlan](../../Keptora/Features/SafetyPlan/SafetyPlanSheet.swift) zaten Advanced Details kullanıyor; bu iyi yaklaşım genişletilebilir.

**Öneri:** Birincil dil kullanıcı sonucunu anlatsın: “Birebir doğrulandı”, “Dosya değişmiş; yeniden kontrol gerekli”, “Güvenlik ayrıntıları”, “Kurtarma durumunu kontrol et”. SHA-256 ve plan lineage ayrıntıları açılabilir alanlarda kalsın. Queue/Evidence, ayrı açık/kapalı paneller olarak anlaşılır başlıklara sahip olsun.

**Kabul ölçütü:** Yeni kullanıcı teknik yardım almadan kaynak seçme, kopya inceleme, plan onayı ve kurtarma görevlerini tamamlayabilmeli. Teknik kanıtlar erişilebilir kalmalı.

### UX-20 — Pro ekranı avantajı ve ücretsiz sınırı net anlatmalı

**Kanıt: Kod ve görüntü.** [MobilePaywall](../../KeptoraiOS/UI/MobilePaywallView.swift), gizlilik ve geri alınabilir temizlik gibi güven vaatlerini ücretli özellik listesinde sunuyor. “Tek satın alma; abonelik yok” güçlü ve açık bir mesaj. Ancak ücretsiz kullanıcının hangi güvenlik garantilerine sahip olduğu yeterince ayrışmıyor. iPhone görselinde hero ve uzun özellik listesi fiyat/işlem alanını aşağı itiyor; ürün yüklenemiyor durumunda da aynı satış düzeni devam ediyor.

**Öneri:** “Ücretsiz: 100 inceleme; aynı güvenlik ve gizlilik” ile “Pro: sınırsız inceleme…” ayrımı yapın; gerçek lisans kuralına göre düzenleyin. Hero küçülsün, fiyat ve ana fayda erken görünsün. Yükleniyor, bağlantı/ürün kullanılamıyor, bekleyen satın alma, kullanıcı iptali ve satın alındı durumları farklılaşsın. Mevcut restore/retry/close/status desteği korunmalı.

**Kabul ölçütü:** Kullanıcı ne satın aldığını, ücretsiz sınırı ve güvenli kurtarmanın koşullarını anlayabilmeli. Fiyat alınamadığında tahmini fiyat gösterilmemeli. StoreKit yapılandırma tavsiyeleri üretim kullanıcısına yönelik hata metni olmamalı; geliştirici teşhisine ayrılmalı.

### UX-21 — Ayarlar için hesap simgesi yanlış çağrışım yapıyor

**Kanıt: Kod ve görüntü.** [Library toolbar](../../KeptoraiOS/UI/MobileLibraryView.swift), ayarları kişi simgesiyle açıyor; Pro olunca mühür simgesine dönüşüyor. Ürün hesap gerektirmediğini vurguluyor.

**Öneri:** Ayarlarda tutarlı dişli simgesi; Pro durumu ayarlar ekranı içinde ayrı badge. Bir kontrolün anlamı satın alma durumuna göre değişmemeli.

**Kabul ölçütü:** Kullanıcı bu düğmenin hesap açma/giriş yerine ayarlar olduğunu ilk bakışta anlayabilmeli.

### UX-23 — İlk kullanım, ilk başarılı göreve bağlanmalı

**Kanıt: Kod.** Her iki onboarding üç sayfa güven anlatısı kullanıyor. Mac tamamlanınca doğrudan klasör seçiciyi açıyor; iOS ise ana ekrana dönüyor. Mac’in Fotoğraflar seçmek isteyen kullanıcısı klasör akışına yöneliyor.

**Öneri:** İlk sayfa kısa değer önerisi; ikinci adım kaynak seçimi; izin yalnızca ilgili seçimden sonra; tarama öncesi “Bu adım dosyaları değiştirmez” açıklaması. Ayrıntılı güven açıklamaları erişilebilir kalsın. İlk görev tamamlandıktan sonra inceleme ekranındaki korunan/seçilen kopya işaretlerine kısa bağlamsal yardım eklenebilir.

**Kabul ölçütü:** Kaynak seçimi kullanıcıya ait olmalı. İlk kullanımdan ilk başarılı sonuca geçen süre ve izin reddi sonrası devam edebilme ölçülmeli.

### UX-24 — Karşılaştırma, karar vermeyi kolaylaştırmalı

**Kanıt: Kod ve görüntü.** iPhone comparison görüntüsü iki boş siyah alan gösteriyor. [SplitComparison](../../KeptoraiOS/UI/MobileSplitComparisonView.swift) senkron zoom/pan ve VoiceOver ayarlanabilir bölücü içeriyor; 44 pt bölücü hedefi olumlu. Reset, koşulsuz `withAnimation` kullanıyor; Reduce Motion davranışı bu ekranda ayrıca ele alınmalı.

**Öneri:** A/B dosya adı, çözünürlük, çekim zamanı ve zoom düzeyi gösterin. Yan yana ve sürgülü karşılaştırmanın amacını kısa açıklayın. Çift dokunmayla büyütme, görünür +/− düğmeleri ve reset erişilebilir olsun. Benzer fotoğraflarda inceleme-only politikasını koruyun; sırf daha akıcı deneyim için temizleme yetkisi eklemeyin. Önizleme alınamıyorsa bu açıkça anlatılmalı.

**Kabul ölçütü:** Kullanıcı hangi görüntünün hangisi olduğunu kaybetmemeli. Gesture olmadan temel karşılaştırma mümkün olmalı. Reduce Motion ve VoiceOver kontrolü cihazda yapılmalı.

## 8. Ekran görüntüsü ve tanıtım kalitesi

### UX-22 — Mevcut görseller yayın öncesi yeniden çekilmeli

**Kanıt: Görüntü, kesin.** İncelenen 12 görselin şu örnekleri isimlerinin vadettiği başarı durumunu göstermiyor:

| Görsel | Gözlenen durum | Yeni çekimde gösterilecek durum |
|---|---|---|
| [Mac Similar Comparison](../../AppStore/Generated/Screenshots/Mac/03_Keptora_Similar_Comparison.png) | Benzer analiz yapılmamış, 0 grup | Gerçek iki görselle karşılaştırma |
| [Mac Safety Plan](../../AppStore/Generated/Screenshots/Mac/04_Keptora_Safety_Plan.png) | Toplu seçim onayı | Açık temizleme planı, korunacak ve taşınacak özet |
| [Mac History Restore](../../AppStore/Generated/Screenshots/Mac/05_Keptora_History_Restore.png) | Boş geçmiş | Tamamlanmış işlem, kurtarma önizlemesi |
| [Mac Privacy Pro](../../AppStore/Generated/Screenshots/Mac/06_Keptora_Privacy_Pro.png) | StoreKit ürünü kullanılamıyor | Doğru fiyat/ürün veya temiz gizlilik ekranı |
| [iPhone Exact Review](../../AppStore/Generated/Screenshots/iOS/02_iPhone_Exact_Review.png) | Küçük resimler yerine placeholder | Gerçek fotoğraf, korunan kopya, seçim ve kısa özet |
| [iPhone Similar Comparison](../../AppStore/Generated/Screenshots/iOS/03_iPhone_Similar_Comparison.png) | İki boş önizleme | Gerçek detay karşılaştırması |
| [iPhone Cleanup Confirm](../../AppStore/Generated/Screenshots/iOS/04_iPhone_Cleanup_Confirm.png) | Türkçe/İngilizce karışık onay | Tam Türkçe, kaynağa uygun hedef ve kurtarma koşulu |
| [iPhone Paywall](../../AppStore/Generated/Screenshots/iOS/06_iPhone_Paywall.png) | Ürün kullanılamıyor, İngilizce retry | Çalışan ürün/fiyat ve tam yerelleştirme |

**Öneri:** Çekim öncesi otomasyon, dosyanın oluşmasına ek olarak seçilen durumun koşullarını kontrol etmeli: grup sayısı > 0; önizleme hazır; gerçek plan açık; history boş değil; ürün/fiyat alınmış; doğru locale. Fixture dosyaları çekim sırasında erişilebilir ve yüklenmiş olmalı. Çekimler güncel commit ile etiketlenmeli.

**Kabul ölçütü:** Her görsel adı ve açıklaması gösterdiği ekranla eşleşmeli. Hata/boş durumlar QA amacıyla saklanabilir; ana tanıtım setine başarı ekranı yerine konmamalı.

## 9. Önerilen ekran taslakları

### iPhone Arşiv

```text
Arşiv                                     Ayarlar

Seçili kaynak: Fotoğraflar
2.450 öğeye erişim · Erişimi yönet

12 kopya grubu bulundu
34 kopya · 480 MB kopya boyutu
[Kopyaları incele]

Benzer fotoğraflar       8 grup →
Benzer videolar          2 grup →

Kaynağı değiştir / Yeniden tara
Verileriniz cihazınızda işlenir
```

Bu düzen tarama tamamlanmış duruma aittir. İlk açılışta sonuç kartı yerine kaynak seçimi; tarama sürerken aynı yerde ilerleme görünür. 480 MB değeri doğrudan “boşalan alan” olarak etiketlenmez.

### iPhone İnceleme

```text
İnceleme                               Seçim menüsü
Birebir kopyalar | Benzerler
Fotoğraflar · Grup 3 / 12

[ Büyük korunan görsel ] [ Büyük kopya görsel ]
Korunan kopya            Seçim kutusu

Bu gruptaki kopyaları seç
← Önceki grup                         Sonraki grup →

3 seçildi · 2 fotoğraf, 1 video · 24 MB
[Seçimi ve hedefi incele]
```

Korunan öğeyi değiştirmek ayrı bir eylem. Önizleme dokunuşu görüntüleyiciyi açar; seçim kutusu temizleme listesini değiştirir. Global seçim, grup seçimiyle aynı ad altında sunulmaz.

### macOS İnceleme

```text
Klasör adı | Birebir / Benzer | Grup 3 / 12 | Filtre
----------------------------------------------------
Grup listesi |       Büyük karşılaştırma alanı
             |       Korunan / Seçilen bilgisi
             |       Dosya ayrıntıları açılabilir
----------------------------------------------------
Önceki | Koru | Plana ekle | Atla | Sonraki
5 öğe · 80 MB kopya boyutu        [Planı incele]
```

Güvenlik ayrıntıları ve teknik kanıtlar yan panelde. Üst toolbar, kart ve alt rafta aynı eylem tekrar edilmez. Kaynak olarak Fotoğraflar kullanıldığında hedef ve kurtarma açıklaması buna göre değişir.

## 10. Metin örnekleri

| Mevcut / belirsiz ifade | Önerilen ifade |
|---|---|
| Güvenli Fotoğrafların Tümünü Seç | Tüm gruplardaki kopyaları seç |
| Asıl kopya / Protected keeper | Korunan kopya |
| Her zaman geri yüklenebilir | Kaynağa uygun süre ve koşul cümlesi |
| Zero KB planned | Henüz seçim yapılmadı |
| Reconcile | Kurtarma durumunu kontrol et |
| Evidence | Güvenlik ayrıntıları |
| Start Read-Only Scan | Kopyaları bul — alt açıklama: Bu adım dosyaları değiştirmez |
| Product unavailable | Satın alma bilgisi şu anda yüklenemiyor |
| Retry Loading Product | Tekrar dene |
| Keptora Safe Bin | Keptora kurtarma alanı |
| Potential Recovery / Space | Kopya boyutu veya taşınacak dosya boyutu |
| Cleanup Completed | Gerçek sonuca göre: 3 dosya kurtarma alanına taşındı |

“Korunan kopya”, matematiksel olarak ilk/orijinal dosyanın hangisi olduğunu iddia etmeden uygulamanın koruma tercihini anlatır. Birebir içerik eşitliği, dosyanın kullanıcı açısından asıl sürüm olduğunu tek başına kanıtlamaz.

## 11. Uygulama planı

### Aşama A — Güven ve kurtarma

UX-01, 02, 03, 05, 06, 07. Koruma kuralını davranışa bağla; geri yükleme kayıtlarını güvenceye al; kaynak bazlı onay ve başarı mesajlarını düzelt; işlem özetini sabitle. Önce bunlar tamamlanmalı.

### Aşama B — Temel görevin anlaşılması

UX-04, 08, 09, 10, 16, 17. Doğru depolama dili, eksiksiz kritik yerelleştirme, önizleme durumları, analiz hata ayrımı, kota açıklaması ve kategori kapsamı.

### Aşama C — Görsel sadeleştirme

UX-11, 12, 13, 14, 15, 18, 19, 21, 24. Fotoğrafa daha fazla alan, tek karar rafı, daha az dekorasyon, tutarlı eylem renkleri, erişilebilir hedef ve boyutlar. Marka gradient’i korunabilir; her kartın ana özelliği olmak zorunda değil.

### Aşama D — İlk kullanım ve tanıtım

UX-20, 22, 23. Onboarding’i ilk sonuca bağla, ücretsiz/Pro ayrımını açıklaştır, tanıtım çekimlerini doğrulanmış başarı durumlarıyla yenile. Hata akışları ayrı QA seti olarak tutulmalı.

## 12. Mac/iPhone doğrulama planı

### Görev temelli kullanılabilirlik çalışması

İlk turda 5–8 temsilî kullanıcı yeterli bir başlangıçtır; bu sayı istatistiksel başarı kanıtı değildir. Mac ve iPhone görevleri ayrı değerlendirilir. Aynı sürümle şu görevler verilmelidir:

1. İlk açılışta bir kaynak seç ve ilk sonucu al.
2. İki kopya içinden hangisinin korunacağını açıkla ve diğerini seç.
3. Fotoğraflardan videolara geç; hangi öğelerin seçili kaldığını söyle.
4. Temizleme öncesi dosyaların nereye gideceğini ve disk alanının ne zaman boşalacağını açıkla.
5. Bir dosyayı karantinaya taşı, uygulamayı kapat/aç, sonra geri yükle.
6. Geçmiş kaydını kaldırmayı dene; kurtarmaya etkisini açıkla.
7. Fotoğraflar erişimi reddedilmişken Files üzerinden devam et.
8. Küçük resim/iCloud/analiz hatasında doğru çözüm yolunu bul.
9. Kota sınırında toplu seçim yap; hangi ücretli avantajın gerektiğini açıkla.

Ölçümler: yardım almadan görev tamamlama, ilk doğru eyleme kadar geçen süre, yanlış seçim, kapsamı yanlış açıklama, gereksiz geri dönüş, kurtarma yolunu bulamama, paywall sonrası göreve devam edebilme. Başarı hedefleri ölçüm öncesinde belirlenmeli; bu raporda mevcut başarı yüzdesi ölçülmüş değildir.

### Erişilebilirlik matrisi

- iPhone: en küçük desteklenen ekran, yatay kullanım, standart ve en büyük erişilebilirlik yazı boyutu.
- macOS: dar pencere ve 1280×800 ekran; yalnızca klavye ile bütün temel akış.
- Her platform: açık/koyu mod, VoiceOver, Reduce Motion, Increase Contrast, Reduce Transparency.
- Türkçe ve İngilizce; diğer desteklenen dillerde en uzun kritik metinler.
- Gerçek görüntüler, iCloud-only öğeler, izin reddi, kayıp dosya, yavaş sağlayıcı, başarısız StoreKit yükleme.

### Yayın öncesi zorunlu kabul senaryoları

| Senaryo | Beklenen sonuç |
|---|---|
| Korunan öğeye dokunma | Varsayılan akışta temizleme listesine giremez |
| Tüm kopyaları toplu seçme | Her grupta korunacak öğe kalır |
| Filtre değiştirme | Global seçim kapsamı görünür kalır |
| Geçmişte aktif kayıt silme/gizleme | Kurtarma yeteneği kaybolmaz |
| Files temizleme başarısı | Keptora kurtarma alanı anlatılır |
| Photos temizleme başarısı | Son Silinenler ve süre koşulu anlatılır |
| Karantinaya taşıma | Taşınan baytlar gerçek boş alan gibi raporlanmaz |
| Benzerlik analizi hatası | Başarısız durum; sıfır sonuç gibi sunulmaz |
| Küçük resim yüklenememe | Sebep veya açık hata + uygun çözüm eylemi |
| İşlem sürerken tekrar dokunma | İşlem durumu görünür, kapsam değişmez |
| Türkçe kritik yol | İngilizceye düşen kritik metin yok |
| Tanıtım görseli çekimi | Beklenen ekran/durum ve önizleme hazır |

## 13. İncelemede korunması önerilen iyi kararlar

- Birebir kopya ile görsel benzerlik ayrı kavramlar. Benzer fotoğrafların temizleme yetkisine otomatik geçmemesi korunmalı.
- Klasör taraması salt okunur adım olarak ayrılıyor; plan onayı olmadan taşıma yapılmaması güçlü yaklaşım.
- Mac yeniden tarama öncesinde tamamlanmamış kararları sıfırlayacağını açıklıyor.
- Bazı ekranlarda `ViewThatFits`, `@ScaledMetric`, erişilebilirlik etiketleri ve Reduce Motion kontrolü var. Yeni tasarım bunları kaybetmemeli.
- Split karşılaştırmada ayarlanabilir VoiceOver bölücüsü ve geniş etkileşim alanı bulunuyor.
- Satın alma ekranlarında restore, retry, kapatma ve sonuç mesajı desteği mevcut. Problem bu mekanizmaların yokluğu değil; hiyerarşi, yerelleştirme ve kullanıcıya dönük hata dili.
- Akıllı kategori toplamları, aynı kopyayı farklı kategorilerde tekrar saymamak için exact bucket üzerinden hesaplanıyor. Yeniden tasarım bu tekilleştirmeyi korumalı.

**Önerilen ilk teslimat:** Korunan kopya kuralı, kurtarma kayıt güvenliği, doğru hedef/süre metinleri ve açık seçim özeti. Ardından ana ekran ile inceleme ekranını fotoğraf ve tek bir sonraki eylem etrafında sadeleştiren tasarım çalışması.
