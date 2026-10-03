# Keptora — Tam fotoğraf temizleme uygulaması için ürün ve UI/UX planı

**Tarih:** 3 Ekim 2026
**Kapsam:** Önce iPhone; ortak çekirdek üzerinden macOS uyarlaması.
**Girdiler:** [24 bulguluk UI/UX raporu](UI_UX_AUDIT.md), kullanıcının tüm arşivden serbest seçim/silme, mobil WhatsApp temizliği ve çekim bilgileriyle desteklenen benzerlik istekleri.
**Durum:** Bu belge ilk ürün planını ve sonraki teslim notlarını içerir. Birleşik arşiv, kaynak rozetleri, manuel temizlik, başlangıç izinleri ve görsel yenileme kodlandı; native kabulü ayrıca gerekir. Güncel geliştirme sırası: [2.000–3.000 fotoğrafta kolay toplu temizlik planı](BULK_PHOTO_CLEANUP_PLAN.md).

## 1. Yeni ürün hedefi

Keptora, kullanıcının erişim verdiği fotoğraf ve video arşivini rahatça gezdiği, istediği öğeleri seçtiği, karşılaştırdığı ve sistemin desteklediği yolla temizlediği bir uygulama olacak. Birebir kopya ve benzerlik analizi yardımcı özellikler olacak; manuel temizleme yapmak için analiz tamamlamak gerekmeyecek.

Başarı tanımı: Kullanıcı uygulamayı açıp erişilebilir arşivini görür, ay veya albüm üzerinden ilerler, birden çok öğeyi kolayca seçer, seçimini inceleyip kaldırır ve geri yükleme yolunu anlar. İstediğinde WhatsApp medyasını veya benzer çekimleri ayrı bir koleksiyonda inceler. Hiçbir öneri kullanıcı onayı olmadan silme başlatmaz.

## 2. Önceki raporla değişen kararlar

Önceki rapor mevcut “kopya inceleme” hedefi üzerinden değerlendirilmişti. Yeni talep bu sınırı genişletiyor; aşağıdaki kararlar önceki önerilerin ilgili kısımlarını güncelliyor:

| Konu | Yeni karar |
|---|---|
| Benzer fotoğraflar | Yalnızca karşılaştırma değil; kullanıcının açık seçimiyle temizlenebilir. Otomatik silme yapılmaz. |
| Bütün fotoğraflar | Kopya veya benzer gruba girmese de manuel seçilip kaldırılabilir. |
| Korunan kopya | Kopya asistanının toplu önerilerinde korunur. Manuel arşiv modunda kullanıcı bilinçli olarak bu öğeyi de seçebilir; “silinemez” izlenimi verilmez. |
| Grup içindeki bütün öğeler | Manuel seçimde yasaklanmaz. Bilinen bir grubun tamamı seçilmişse “Bu grubun tüm öğeleri kaldırılacak” açık gösterilir. Taranmamış arşiv için “son kopya” bilgisi uydurulmaz. |
| Favori/albümdeki öğeler | Önerilen toplu seçimlerden varsayılan dışlanabilir; manuel seçim kullanıcıya açık olmalı. Sistem gerçekten izin vermiyorsa sebep öğe bazında gösterilir. |
| Güven anlatısı | “Her zaman korunan orijinal” yerine “Toplu öneride korunan kopya”; “her zaman kurtarılabilir” yerine kaynağa bağlı süre ve koşullar. |
| SHA-256 | Birebir kopya iddiasında gerekli. Kullanıcının kendi fotoğrafını bilinçli kaldırması için kopya kanıtı aranmaz. |

Kurtarma kaydı güvenliği, seçim kapsamı, doğru alan ölçümü, yerelleştirme ve erişilebilirlik bulguları geçerliliğini koruyor. Yeni manuel mod, bu düzeltmeleri atlama gerekçesi değil.

## 3. Mobil WhatsApp temizliğinin kapsamı

### Yapılacak

- Fotoğraflar’a kaydedilmiş WhatsApp medyası için albüm tabanlı koleksiyon; albüm mevcutsa üyelik bilgisi kullanılacak.
- Kullanıcının “bu albüm/koleksiyon WhatsApp medyam” diyerek kaynak seçebilmesi.
- WhatsApp’tan dışa aktarılmış veya Files üzerinden seçilmiş medyanın incelenmesi.
- Fotoğraf/video, tarih, boyut ve birebir/benzerlik filtreleri; çoklu seçim ve kaynağa uygun temizleme.
- Kaynak kanıtının açık gösterilmesi: “WhatsApp adlı albüm”, “Seçtiğiniz WhatsApp koleksiyonu”, “WhatsApp kaynaklı olabilir”.
- Uygulama içindeki özel medya için WhatsApp’ın kendi “Depolamayı Yönet” ekranına nasıl gidileceğini anlatan kısa rehber. Uygulama bu alana erişmiş gibi sayı üretmeyecek.

### Platform sınırı

iOS’ta Keptora, WhatsApp’ın özel uygulama alanındaki sohbet veritabanı veya medyasını doğrudan tarayıp silemez. Fotoğraflar’dan bir kaydı kaldırmak, WhatsApp sohbetindeki medyanın veya WhatsApp depolamasının da silindiği anlamına gelmez. Onay ve sonuç ekranı hangi kopyanın hangi kaynaktan kaldırıldığını söyleyecek.

WhatsApp albümü her cihazda bulunmayabilir; albüm adı kaynağın kesin kanıtı değildir. Dosya adı, düşük çözünürlük veya eksik EXIF de tek başına kesin kaynak kanıtı sayılmaz. Ürün metni bu belirsizliği saklamayacak.

**İlk sürüm kararı:** Albüm/kullanıcı seçimiyle açık kaynak koleksiyonu. Tahmine dayalı sınıflandırma daha sonra, yanlış atama oranı ölçüldükten sonra. Bulut sohbet erişimi, WhatsApp hesabı veya sohbet yetkilendirmesi istenmeyecek.

## 4. Yeni bilgi mimarisi

### iPhone

| Bölüm | İçerik | Ana eylem |
|---|---|---|
| Arşiv | Tüm erişilebilir fotoğraf/video, ay-gün, albümler, kaynak filtresi | Seç, önizle, kaldır |
| Temizlik | WhatsApp, birebir kopyalar, benzer çekimler, ekran görüntüleri, büyük videolar | Koleksiyonu incele |
| Geçmiş | İşlem sonucu, gerçek kaynak, kurtarma yolu ve durumu | Geri yükle / kurtarma adımlarını gör |
| Ayarlar | İzin, gizlilik, Pro, görüntüleme tercihleri | Dişli simgesiyle erişim |

Sekmelerin adı ve ikonları sabit olacak. Pro durumu Ayarlar’ı hesap ekranı gibi göstermeyecek. “Temizlik” ekranı kendi başına tarama bitmesini zorunlu kılmayacak; hazır koleksiyonlar kullanılabilecek, analiz isteyenler ilerleme gösterecek.

### macOS

Sidebar: **Arşiv → Temizlik koleksiyonları → Geçmiş**. Kopyalar/Benzerler/WhatsApp gibi koleksiyonlar Temizlik altında; Insights ve güvenlik teşhisi ikinci katmanda. Klasör ve Fotoğraflar ayrı pencerelerde farklı karar mantıkları taşımak yerine ortak arşiv/seçim deneyimine yaklaşacak. Kaynakların platform yetenekleri açıkça korunacak.

## 5. Tüm arşivden rahat seçim

### Arşiv ekranı

- İlk katalog, izin sonrasında hemen gösterilecek; hash/benzerlik analizini beklemeyecek.
- Sanallaştırılmış grid; Ay/Gün/Tüm öğeler görünümü; hızlı tarih atlama.
- Albüm, fotoğraf/video, tarih aralığı, favoriler, ekran görüntüsü, Live Photo, boyut ve kaynak filtreleri.
- Normal dokunma: tam ekran önizleme. “Seç” modunda dokunma: seçim. Uzun basmayla seçim moduna giriş mümkün.
- Grid üzerinde sürükleyerek aralık seçimi ve kenara yaklaşınca kontrollü otomatik kaydırma.
- Görünen gün/ay/filtre kapsamında “Tümünü seç”; kapsam adı ve adet daima açık.
- Filtre değişirken seçim korunursa “32 seçildi · 8’i mevcut filtrenin dışında” gösterilecek.
- Seçim listesini ayrı inceleme ekranında açma, öğe çıkarma ve seçim geri alma.
- Erişilebilirlik için gesture dışında seçim kutuları, “Günü seç”, “Seçimi temizle” gibi düğmeler.
- Gizli arşivler varsayılan görünümde açılmayacak; sistemin izin verdiği kapsamda açık kullanıcı tercihiyle ele alınacak.

### Önizleme

Fotoğraf/video oynatma, yakınlaştırma, önceki/sonraki, seçime ekleme/çıkarma. Tarih/saat, boyut, çözünürlük, kamera ve konum bilgisi ayrıntı panelinde. Bilgi yoksa “Çekim bilgisi yok”; tahmin gerçek veri gibi sunulmayacak.

### Temizleme onayı

“18 fotoğraf, 3 video · yaklaşık 420 MB · Apple Fotoğraflar”. Seçilen gerçek küçük resimler, varsa favori/ortak arşiv/korunan öneri uyarıları ve gerçek hedef. Fotoğraflar’da sistem onayı ve Son Silinenler yolu; Files’ta kurtarma alanına taşıma.

Manuel modda benzersiz veya favori fotoğrafın seçilmesi bir arıza sayılmayacak. Varsayılan akıllı toplu öneride bu öğeler dışlanacak; kullanıcı seçtiğinde kapsamı açık son inceleme yapılacak. Sistem desteklemeyen kaldırma işlemleri uygulama tarafından zorlanmayacak.

## 6. Benzer çekimler: görüntü + çekim zamanı + yer + fotoğraf bilgileri

### Kullanılacak sinyaller

| Sinyal | Kullanım | Eksik/yanlış olduğunda |
|---|---|---|
| Görsel özellik / perceptual hash | Gerçek görsel benzerlik, yeniden boyutlanmış veya sıkıştırılmış kopya adayları | Önizleme alınamayan öğe ayrı durum; sessizce analiz edilmiş sayılmaz |
| Çekim tarihi ve saati | Aynı çekim serisine/etkinliğe yakınlık | Dosya oluşturma veya alma tarihi, çekim tarihi diye etiketlenmez |
| Konum ve doğruluk | Yakın yerde çekilmiş karelere bağlam | GPS yokluğu “farklı yer” kabul edilmez |
| Burst / Live Photo ilişkisi | Birlikte incelenmesi gereken medya aileleri | Aile kimliği yoksa varsayılmaz |
| Kamera / lens / çözünürlük | Karşılaştırma açıklaması ve önerilen saklanacak kare | Büyük dosya veya yüksek çözünürlük tek başına iyi fotoğraf demek değildir |
| Netlik, pozlama, yüz kalitesi gibi yerel kalite sinyalleri | “Saklamanız önerilen” kareye destek | Kullanıcının estetik tercihi yerine karar vermez |
| Favori / düzenlenmiş / albüm ilişkisi | Öneride öncelik ve bağlamsal uyarı | Manuel silmeyi bütün albüm öğelerinde engellemez |

**Gruplama ilkesi:** Görsel benzerlik ana sinyal; zaman ve yer destekleyici sinyal. Aynı yerde aynı saatte çekilmiş iki farklı konu kopya sayılmayacak. Benzer görüntülerin metadata’sı farklı veya eksik diye adaylar bütünüyle elenmeyecek. Birebir, görsel benzer, aynı çekim serisi ve aynı etkinlik ilişkileri ayrı etiketlenecek.

Başlangıçta görsel aramaya ek olarak yakın zamanlı adaylar üretilecek; zaman/yer bağlamı sıralama ve açıklamada kullanılacak. Sabit ağırlık ve eşikler test verisiyle ayarlanacak; raporda keyfî “%95 aynı” skoru gerçek olasılık gibi gösterilmeyecek. Grup üyeleri arası tutarlılık kontrolü, farklı sahnelerin tek büyük gruba zincirleme birleşmesini engelleyecek.

**Örnek açıklama:** “Görsel olarak yakın · 12 saniye arayla çekilmiş · konumları yakın”. GPS yoksa yalnızca mevcut sinyaller gösterilecek. EXIF’te saat dilimi yoksa kesin sıralama iddiası yapılmayacak; orijinal tarih metni ve kaynağı saklanacak.

**Kullanıcı kararı:** Önerilen saklanacak kare değiştirilebilir. Kullanıcı benzer gruptan bir, birkaç veya bütün öğeleri manuel seçebilir. Tamamı seçildiyse bu açıkça anlatılır; otomatik silme uygulanmaz.

## 7. WhatsApp ekranı

```text
WhatsApp medyası
Kaynak: Fotoğraflar’daki seçili albüm
Bu işlem WhatsApp sohbetlerindeki dosyaları kaldırmaz.

Fotoğraflar  |  Videolar
Son ay · Boyuta göre · Kopyalar · Benzerler

[Gerçek fotoğraf ve video grid’i]

24 seçildi · 190 MB medya boyutu
[Seçimi incele]

WhatsApp uygulamasındaki depolama için rehber →
```

WhatsApp albümü yoksa boş hata ekranı yerine “Albüm seç”, “Fotoğraflardan kendin seç”, “Files’tan dışa aktarılmış medya seç” yolları olacak. Koleksiyona kullanıcı ataması saklanacak; dışarıdan silinen/yeni eklenen öğeler PhotoKit değişiklikleriyle güncellenecek.

## 8. Görsel dönüşüm ve bütün görseller

Önceki turda 12 ekran görüntüsü görsel olarak incelendi. Bu turda **67 raster/vektör dosya** [görsel envanterine](VISUAL_INVENTORY.md) alındı. Bunların tamamı tek tek görsel kalite incelemesinden geçmiş sayılmaz. Dosyalar dışında SwiftUI ile çizilen logo, SF Symbols, gradient, kart ve durum bileşenleri de tasarım kapsamına girecek.

### Görsel yön

- Aurora renk kimliği korunacak; ana eylemlerde yüksek kontrastlı sade accent, dekorasyonda gradient.
- Fotoğraflar büyük ve net; hero alanları küçülecek; tekrar eden kart/kenarlık/gölge/ışık katmanları azaltılacak.
- Seçim, önerilen saklanacak kare, işlemde ve hata durumları tutarlı ikon + metinle gösterilecek.
- Tek tip spacing, tipografi, kart radius, modal, toolbar, seçili durum ve düğme sistemi.
- Açık/koyu mod, 44 pt dokunma hedefi, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast.

### Görsel ailelerine göre işler

| Görsel ailesi | Plan |
|---|---|
| Uygulama ikonu ve logo kaynakları | “Tam fotoğraf temizliği” konumlandırmasıyla değerlendirme; küçük boyut okunurluğu ve platform varyantları; gereksiz yeniden üretim yok |
| Onboarding privacy/proof/restore | Yeni manuel mod ve kaynağa bağlı kurtarma anlatısına uyarlama; süresiz kurtarma/daima korunan asıl öğe vaadi kaldırılır |
| Paywall hero | Daha kısa ve işlev odaklı görsel; fiyatı aşağı itmeyecek düzen; ücretsiz güvenlik ile Pro faydası ayrımı |
| Boş, izin ve hata durumları | Yeni WhatsApp/katalog/önizleme/analiz durumlarına uygun bileşen ve metin |
| Fotoğraf/video örnekleri | Gerçek, izinli örnek içerik; yeniden boyutlanmış kopya, burst, metadata’sız WhatsApp medyası ve benzersiz fotoğraflar |
| 12 mevcut tanıtım ekranı | Güncel başarı durumlarıyla yeniden çekim; boş önizleme, ürün hatası ve dil karışımı yok |
| Yeni özellik ekranları | Tüm arşiv seçimi, WhatsApp koleksiyonu, zaman/yer destekli benzerlik ve doğru sonuç/kurtarma ekranları |
| Test/fixture görselleri | Test amacına göre korunur; “bütün görseller değişsin” diye silinmez veya yeniden boyutlanmaz |

Bütün görseller kapsamda değerlendirilecek; hepsinin değiştirilmesi zorunlu olmayacak. Her dosya için “koru / düzenle / yeniden üret / kullanım dışı” kararı, kullanılma yeri ve gerekçesi envantere eklenecek. Fotoğraf küçük resimleri sabit tasarım görsellerinden ayrı, gerçek medya yükleme akışının parçası olacak.

## 9. Mevcut koddan yeniden kullanılacaklar ve değişmesi gerekenler

| Alan | Mevcut durum | Planlanan değişiklik |
|---|---|---|
| `UniversalMediaAsset` | Tarih, çözünürlük, favori vb. var; ortak konum/ayrıntılı kaynak bilgisi yok | Konum, metadata kaynağı/güveni, albüm üyeliği ve ilişkili medya kimlikleri |
| `PhotoMetadataExtractor` | EXIF, GPS, kamera, çekim tarihi çıkarıyor | PhotoKit metadata’sıyla ortak model; saat dilimi, veri kaynağı ve eksik durumlar |
| `PhotoLibrarySourceAdapter` | Tüm erişilebilir öğeleri alabiliyor; albüm bilgisini çoğunlukla boolean tutuyor | Albüm kimliği/adı/üyeliği; değişiklik gözlemi; katalog/thumbnail önbelleği |
| `deleteSelectedAssets` | Favori/gizli/düzenlenmiş/ortak/album öğelerinde uygulama seviyesinde genel engel | Akıllı öneri politikası ile açık manuel silme politikası ayrılır; gerçek sistem kısıtları korunur |
| `MobileKeptoraStore` | Seçim ve temizleme exact/similar-video gruplarına bağlı | Arşiv tabanlı ortak SelectionSession ve manuel işlem planı |
| `VisualSimilarityAnalyzer` | Görsel özellik ve hash; tarih saklanacak aday sıralamasında; varsayılan 5.000 öğe sınırı | Metadata destekli aday/grup açıklamaları, artımlı analiz, kapsam ve atlanan öğe raporu |
| `FolderQuarantineExecutor` | Dosyaları kök altına taşır; digest parametresi kullanır | Manuel işlemde kopya iddiasından bağımsız dosya anlık görüntüsü/taşıma doğrulaması; manifest korunur |
| Mobile/macOS Review | Tekrarlı, farklı kapsamlı eylemler | Ortak seçili öğe özeti, kaynak bazlı onay, işlem aşamaları |
| History | Aktif kayıt silinebiliyor | Kalıcı kurtarma manifesti; gizleme ile silme ayrımı |

Seçim modelleri baştan birleştirilmeden yalnızca “bütün fotoğraflar” grid’i eklemek mevcut global seçim ve grup bağımlılığını büyütür. Manuel seçim ilk geliştirme dilimi olacak.

## 10. Ortak işlem modeli

Her işlem kullanıcı niyetini kaydedecek:

- `exactDuplicateCleanup`: birebir kopya doğrulaması; önerilen toplu seçimde bir öğe korunur.
- `similarityAssistedCleanup`: görsel/metadata destekli öneri; kullanıcı seçimi zorunlu.
- `manualLibraryCleanup`: bütün arşiv veya koleksiyon üzerinden açık seçim; exact grup üyeliği aranmaz.

İşlem planı kaynak, seçili ID’ler, tür/adet, bilinen boyut, seçimin son hali ve kurtarma yolunu içerir. Onaydan sonra bu kapsam sabitlenir. PhotoKit ID’lerinin hâlâ erişilebilir olması ve dosya kaynağında güvenli taşıma koşulları doğrulanır. Metadata bilgisi, kopya kanıtı ve kullanıcının manuel seçimi farklı kanıt türleridir.

**Sonuç ölçümleri:** “Kaldırılan/taşınan öğe”, “işlenen medya boyutu”, “kurtarma alanında tutulan boyut”. “Gerçek boşalan alan” yalnızca ölçüm destekliyorsa ayrı gösterilir. Files’a taşıma veya Fotoğraflar Son Silinenler işlemi doğrudan boş alan garantisi değildir.

## 11. Geliştirme aşamaları ve tamamlanma kapıları

| Aşama | Teslimat | Tamamlanma ölçütü |
|---|---|---|
| 0 — Uyumluluk ve tasarım | macOS/Xcode çalışma ortamı, PhotoKit/WhatsApp sınırları, güncel ekran durumu, tüm görsel kullanım eşlemesi, akış prototipi | Gerçek iPhone’da izin, katalog ve sistem silme onayı; kaynakların yetenekleri belgeli |
| 1 — Güven ve ortak seçim | Kurtarma manifesti, doğru süre/hedef metni, ortak seçim planı, işlem geri bildirimi | Aktif geçmiş kaydı kaybolmaz; filtre dışı seçim görünür; işlem kapsamı sabit |
| 2 — Tüm arşivden manuel temizlik | Katalog grid’i, önizleme, tarih/albüm filtreleri, çoklu seçim, onay, sonuç | Analiz yapmadan benzersiz fotoğraf ve video seçilip kaldırılabilir |
| 3 — Mobil WhatsApp koleksiyonu | Albüm/kullanıcı seçimi, Files kaynakları, filtreler, rehber | WhatsApp albümlü/albümsüz ve sınırlı izinli cihazlarda doğru kaynak gösterimi; sohbet depolaması hakkında yanlış vaat yok |
| 4 — Metadata destekli benzerlik | Ortak metadata, zaman/konum destekli gruplar, açıklama ve önerilen saklanacak kare | Eksik metadata’da çalışır; aynı zaman/yer ama farklı görseller yanlış kopya diye sunulmaz; kullanıcı serbest seçim yapar |
| 5 — Görsel sistem ve Mac eşitleme | Tasarım bileşenleri, mobil/macOS yerleşimleri, görsel dosya kararları, yerelleştirme | Erişilebilirlik matrisi; tutarlı seçim/onay/sonuç; kritik metin taşması ve dil karışımı yok |
| 6 — Yayın hazırlığı | Gerçek cihaz testleri, büyük arşiv, yeni tanıtım çekimleri, StoreKit akışı | Beklenen başarı durumunda çekimler; kurtarma ve izin testleri geçti; ölçüm raporu hazır |

Görsel prototip ve ortak bileşen tanımı 0. aşamada başlar, 2–4. aşamalara uygulanır. 5. aşama görsel çalışmanın ilk kez başlaması değil, bütün platformlarda tamamlanması ve kontrolüdür. WhatsApp ve gelişmiş benzerlik, manuel temizliğin yayına hazır olmasını gereksiz yere bekletmez; her dilim ayrı doğrulanabilir.

### Önerilen ilk geliştirme dilimi

**iPhone: bütün Fotoğraflar arşivini göster → seçim modu → seçimi incele → sistem onayıyla kaldır → doğru sonuç/kurtarma rehberi.** Aynı dilimde tarih grupları, filtre dışı seçim sayısı, favori uyarısı, hata/işlem durumu ve sade görsel bileşenler bulunmalı. Önce bütün ürüne yayılmış dekoratif değişiklik yapmak yerine bu tam akış doğrulanacak.

## 12. Gerçek cihaz test planı

### Temel senaryolar

1. Hiç kopyası olmayan 20 fotoğraf: analiz çalıştırmadan üç fotoğraf seç ve kaldır.
2. Fotoğraf/video filtreleri arasında seçim koruma; görünmeyen seçimleri onayda görebilme.
3. Favori, albümdeki, düzenlenmiş ve önerilen saklanacak fotoğraflar: akıllı toplu öneri ve manuel seçim farklı davranır.
4. Bilinen bir grubun tamamını manuel seçme: açık kapsam uyarısı ve sistem onayı; kopya temizliği modu ile karışmaz.
5. Sınırlı Fotoğraflar izni, izin reddi/geri verilmesi, dışarıdan silinen öğe, iCloud-only fotoğraf.
6. WhatsApp albümü var/yok/yeniden adlandırılmış; farklı kaynaklı fotoğraf albüme eklenmiş; EXIF’siz ve yeniden sıkıştırılmış medya.
7. Aynı saniye/konumda farklı konular; farklı tarihlerde aynı görsel; EXIF saat dilimi eksik; GPS yok; burst/Live Photo.
8. Benzer fotoğraftan manuel kaldırma; öneriyi değiştirme; yanlış öneride bütün öğeleri koruma.
9. Files karantina → kapat/aç → geri yükle; geçmişi gizleme sonrası da kurtarma erişimi.
10. İşlem sürerken çift dokunma, uygulamanın arka plana geçmesi, disk/provider hatası, sistem silme onayını iptal.
11. En küçük desteklenen iPhone, büyük yazı, VoiceOver, açık/koyu mod ve hareket azaltma.
12. 5.000 / 20.000 / 50.000 öğelik test arşivleri: gezinme, bellek, analiz kapsamı, değişiklik sonrası artımlı yenileme. Bunlar performans test hedefleridir; önceden verilmiş destek garantisi değildir.

### Benzerlik ölçümü

Etiketli test gruplarıyla yanlış gruplama, kaçırılan benzer kare, metadata eksikliği ve yeniden sıkıştırılmış WhatsApp medyası ayrı ölçülecek. Varsayılan görsel eşikler ile metadata destekli yöntem aynı veri üzerinde karşılaştırılacak. “Yüksek doğruluk” iddiası ölçüm sonucu olmadan ürün metnine eklenmeyecek.

### UX ölçümü

İlk seçim ve ilk başarılı temizliğe kadar geçen süre; görev tamamlama; yanlış seçme/yanlış önizleme; filtre dışı seçim farkındalığı; kurtarma yolunu bulma; WhatsApp’ta hangi depolamanın etkilendiğini doğru anlatabilme. İlk prototipten sonra hedefler belirlenip mevcut sürümle karşılaştırılacak.

## 13. Lisans ve gizlilik kararları

Temel arşiv görüntüleme, manuel seçim deneyimi, güvenlik açıklaması ve kurtarma erişimi güvenilir kalacak. Paywall seçimi kaybetmeyecek; kota bir öğeyi görmekle mi işlemle mi harcanıyor açık olacak. Gelişmiş benzerlik veya sınırsız toplu işlem gibi Pro sınırları gerçek ürün kararıyla tanımlanacak; bu planda fiyat ve yeni limit uydurulmuyor.

Konum ve fotoğraf özellikleri mümkün olduğunca cihazda işlenecek. Mevcut fotoğraflardaki GPS bilgisini okumak için gereksiz canlı konum izni istenmeyecek. Harita veya yer adı sağlayıcısı eklenirse ağ/gizlilik ihtiyacı ayrıca değerlendirilecek; ilk sürüm “yakın konum” açıklamasıyla çalışabilir. Sohbet içeriği ve kişi kimliği analizi kapsam dışı.

## 14. Teslim edilecek çıktılar

- Mobil kaynak/izin, tüm arşiv, seçim, WhatsApp, benzerlik, onay, sonuç ve kurtarma ekranlarının prototipleri.
- Mac için karşılık gelen ortak akış ve klavye etkileşimleri.
- Görsel envanterindeki her dosya için karar ve gerekçe; tasarım tokenları/bileşenleri.
- Ortak metadata, seçim ve işlem modeli; artımlı katalog ve analiz.
- Türkçe/İngilizce tam kritik yol metinleri.
- Gerçek cihaz doğrulaması, benzerlik ve büyük arşiv ölçümleri.
- Başarı durumları doğrulanmış güncel App Store görselleri.

**Güncel uygulama sırası:** Kullanıcının son talebiyle kaynak tikleri, kalite bulguları, toplu karar UI'ı, önbellek ve ortak testler önce burada kodlanacak. macOS/Xcode ve gerçek iPhone erişimi son native derleme/kabul aşaması için gerekir; kod geliştirmesine başlama engeli değildir. Linux'taki ortak testler native UI/PhotoKit davranışını kanıtlamaz. Güncel kapsam ve kabul ölçütleri [toplu temizlik planında](BULK_PHOTO_CLEANUP_PLAN.md) yer alır.


## 3 Ekim 2026 — Birleşik kaynak akışı

Fotoğraflar ve çoklu izinli klasörler tek arşiv/taramada birleştirildi. Ana arşivde tüm öğeler, ortak birebir/benzer grupları, kaynak rozeti ve kaynak başına işlem hedefi yer alır. Mac klasör bağlantıları ve iPhone Dosyalar bağlantıları kalıcı bookmark ile saklanır. iOS’un özel WhatsApp/izin verilmemiş dosya erişimi kısıtları kaldırılmış değildir. Ayrıntılı bulgular, uygulama karşılıkları ve gerçek cihaz kabul listesi: [Birleşik Arşiv UI/UX Raporu](UNIFIED_LIBRARY_UX_AUDIT.md).

Sonraki teslim kapısı: Apple CI derleme/test sonucu, gerçek iCloud/üçüncü taraf sağlayıcı, karma silme/geri alma ve büyük arşiv performans doğrulaması. Linux testlerini geçmiş olmak bu native doğrulamaların yerine geçmez.
