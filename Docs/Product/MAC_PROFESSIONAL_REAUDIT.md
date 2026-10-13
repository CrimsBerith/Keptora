# Profesyonel Mac uygulaması — güncel sistem ve UI/UX denetimi

6 Ekim 2026. İncelenen kod: **7a19e1101b6f1bc676721c6d6260ead0318e97d7**, feat/photo-cleaner-library.

**7 Ekim uygulama durumu:** Bu belge başlangıç denetimini ve o revizyona ait kanıtları korur. R01–R20 için kod değişiklikleri, doğrulama ve kalan native kabul adımları [teslim raporunda](MAC_REAUDIT_DELIVERY.md) açıklanır. Aşağıdaki eski satır numaraları başlangıç revizyonuna aittir.

Güncel kodda **20 eksik veya iyileştirme noktası**: **1 P0, 7 P1, 12 P2**. P0 derleme engeli; P1 güvenilirlik/işlem doğruluğu; P2 kullanım, bakım veya performans mimarisi önceliğidir. P2 maddeleri aynı ağırlıkta ürün hataları değildir; aşağıda doğrudan kod davranışı ile önerilen iyileştirmeler açıklanır.

Bu incelemede uygulama kodu değiştirilmedi. Önceki [21 bulgunun teslimi](MAC_ARCHITECTURE_DELIVERY.md) ve [güncel mimari](CURRENT_LIBRARY_ARCHITECTURE.md) başlangıç olarak kullanıldı. Ana galeri, kaynak tikleri, ortak seçim sepeti, kullanıcı saklama kararı ve kurtarma korunmalı. WhatsApp, karşılaştırma, swipe seçimi veya büyüteç bu önerilerin parçası değildir.

## Kanıtın kapsamı

- Mac uygulaması, SwiftUI/AppKit kabuğu, ortak analiz/metadata politikaları, güvenli kaldırma ve restore yolları, kayıt repository'si, ayarlar, gelişmiş araçlar ve native test seçimi incelendi.
- Catch kapsam hatası Swift 5 dil modunda küçük bir örnekte derleyici ile doğrulandı: immutable error ve String → Error tip hataları.
- **Gerçek geçici dosyalarla ortak üretim kodu çalıştırıldı:** farklı kimlik/içerik, aynı boyut/tarih ile değiştirilmiş dosya revizyon doğrulamasını geçti. Hard link için iki referansın aynı ID'yi taşıdığı ve referans dedup'ının ikisini de tuttuğu doğrulandı. Bu fixture metadata sözleşmesini sınar; JPEG decode veya native kaldırma testi değildir.
- Kalan Apple davranışları kod yollarından çıkarılmıştır. Bu ortamda Apple SDK ve canlı Mac arayüzü yok; burada yeni başarılı Mac derlemesi, UI testi, disk taşıma veya Instruments sonucu iddia edilmez.
- Önceki **69 ortak test** Mac uygulama hedefini derlemez. [Linux paket seçimi](../../Packages/KeptoraCore/Package.swift#L7) MacArchiveModel ve Apple adaptörlerini kapsamaz. 141 dosyanın parse kontrolü isim/tip çözümlemesi yapmaz.
- Önceki [GitHub çalıştırması](https://github.com/CrimsBerith/Keptora/actions/runs/37395882608) ödeme/harcama limiti nedeniyle başlamadı. Bu, kodun native testleri geçtiği veya native testte aşağıdaki hataların zaten gözlendiği anlamına gelmez.

## Öncelik tablosu

| ID | Öncelik | Eksik | Kullanıcıya etkisi |
|---|---|---|---|
| R01 | P0 | Üç catch bloğunda yanlış error alanına atama | Mac derlemesi engellenir. |
| R02 | P1 | İncelenen dosya kimliği kaldırma öncesinde doğrulanmıyor | Aynı boyut/tarihle başka içerik geldiğinde eski fotoğrafın snapshot'ı kabul edilebilir. |
| R03 | P1 | Ölçülen kaliteye göre saklama tercihi yeniden hesaplanarak kayboluyor | Netlik/pozlama yerine daha büyük metadata tercih edilebilir; neden metni kullanılan gerekçeyi doğru anlatmayabilir. |
| R04 | P1 | Kısmi kaldırmadan sonra son inceleme listesi güncellenmiyor | Tamamlanmış öğeler listede kalır; kalanları yeniden deneme seçim eşitliği kontrolüne takılır. |
| R05 | P1 | Kayıt hatasında sınırlı çalışma ve değişiklik politikası yok | Kaydedilemeyen oturumda seçim/klasör kaldırma sürer; çalışma kararları yeniden açılışta korunmayabilir. |
| R06 | P1 | Ana ve gelişmiş motor arasında ortak işlem/quit kapısı yok | Aynı klasörde eş zamanlı işlemler açılabilir; quit yalnız ana akışın işlemini bekler. |
| R07 | P1 | Kurtarma uzlaştırması bozuk/final kayıtları yeterince ayırmıyor | Bozuk manifest sessizce atlanabilir; tamamlanmış restore sonrası normal dosya değişimi yanlış sorun sayılabilir. |
| R08 | P1 | Restore taşımasında son hash doğrulaması yok | Uzun toplu hazırlıktan sonra değişen içerik, geri yüklenmiş olarak işaretlenebilir. |
| R09 | P2 | Hard link referansı ve öğe ID'si sözleşmesi uyuşmuyor | İki yol tek seçim ID'siyle kalır; galeri/grup ve kaldırma adetleri tutarsızlaşabilir. |
| R10 | P2 | Analiz hataları öğeye bağlı eylemlere dönüşmüyor | Kullanıcı hangi fotoğrafın sorunlu olduğunu ve neyi yeniden deneyeceğini bulmakta zorlanır. |
| R11 | P2 | Koru etiketi ile manuel/toplu seçim davranışı farklı | Kilitli görünen fotoğraf tekrar seçilip kaldırma listesine girebilir. |
| R12 | P2 | Öneri adedi ile korunmuş galeri filtreleri uyuşmuyor | Adetli kategoriye tıklamak boş veya eksik liste açabilir. |
| R13 | P2 | Zaman sıralamasında kopya/benzer ve saklama bağlamı kayboluyor | Aynı fotoğrafın ilişki bilgisi görünüm seçimine bağlı olur. |
| R14 | P2 | Duraklatılmış taramanın metni/iptal eylemi eksik | Ekran hâlâ taranıyor der; iptal etmek için önce devam gerekir. |
| R15 | P2 | Bulanık/düşük çözünürlük gibi tek bulgu filtreleri yok | Kalite sorunu arayan kullanıcı benzerlerle karışık inceleme listesini taramak zorunda kalır. |
| R16 | P2 | Arama, filtre ve tarama kontrolleri uzun listeyle kayıyor | Büyük arşivde sık kullanılan kontrollere dönmek ek gezinme gerektirir. |
| R17 | P2 | Sistem Undo bağlantısı tek adımlı; Redo yok | Art arda seçim düzeltmelerinde standart Mac düzenleme beklentisi karşılanmaz. |
| R18 | P2 | Ayarlar ve satın alma sunumu pencere bağlamını paylaşmıyor | Native Ayarlar'daki Pro eylemi başka pencerenin sheet'ine bağlı kalır. |
| R19 | P2 | Artımlı durum/galeri/performance sınırları eksik | Küçük değişikliklerde bütün snapshot ve kurtarma içeriği yeniden işlenir; büyük arşiv davranışı ölçülmeli. |
| R20 | P2 | Dinamik gelişmiş ekran açıklamalarında İngilizce metin kalıyor | Sabit literal çeviri kontrolü geçse de dil tutarlılığı tamamlanmış olmaz. |

## P0 ve P1 — kod düzeltmesi gerekenler

### R01 — Catch bloklarında property gölgelenmesi

**Kanıt:** [MacArchiveModel:312](../../Keptora/Features/Home/MacArchiveModel.swift#L312), [337](../../Keptora/Features/Home/MacArchiveModel.swift#L337), [422](../../Keptora/Features/Home/MacArchiveModel.swift#L422).

Catch içindeki yalın error, modelin String? alanını değil Swift'in implicit, değişmez Error değerini ifade eder. error = error.localizedDescription bu nedenle derlenmez. 337. satırda persistenceError = error da Error → String? uyumsuzluğu taşır. 312 DEBUG içindedir; diğer ikisi Release yolunda da vardır.

**Gerekli değişiklik:** self.error veya ayrı caughtError/message isimleri. **Kabul:** Apple ortak paket + Mac/iPhone hedefleri; Mac Debug ve Release tip kontrolü. Parse/lokalizasyon kontrolü native derlemenin yerine konulmamalı.

### R02 — İncelenen dosya revizyonu içeriğe/kimliğe yeterince bağlı değil

**Kanıt:** [LibraryRevisionValidator:26](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryWorkflow.swift#L26), [dosya kimliği:57](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L57), [preflight:252](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L252).

Asset ID volume/inode tabanlıdır; validator yalnız modificationDate ve fileSize karşılaştırır. Eski fotoğrafın yoluna farklı dosya aynı tarih/boyutla taşındığında ID değişmesine rağmen validator kabul etti. Preflight yeni içeriği hash'ler; taşımanın bu yeni hash'e uyması tek başına kullanıcının gördüğü eski içeriği bağlamaz. Mevcut taşıma hash korumaları gerçektir, fakat bu pencereyi kapatmaz.

**Gerekli değişiklik:** İncelenen kimlik/revizyon/generation ve varsa incelenen analiz fingerprint'ini işlemin tüm aşamalarına bağlamak. Değişmiş öğe için yeniden inceleme gerekir. **Kabul:** Aynı boyut/tarihle atomic replacement; yerinde içerik değişimi; hash sırasında değişim. Platform dışında atomik kilit garantisi verilmemeli.

### R03 — Kaliteye dayalı saklama önerisi koordinatörde kayboluyor

**Kanıt:** [analizör kalite sıralaması:150](../../Packages/KeptoraCore/Sources/KeptoraCore/VisualSimilarityAnalyzer.swift#L150), [configuredSimilar:140](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryAnalysisCoordinator.swift#L140), [LibraryConfiguration.keeperID:35](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L35), [neden metni:211](../../Packages/KeptoraCore/Sources/KeptoraCore/AnalysisModels.swift#L211).

Analizör, kullanıcı koruma bayraklarından sonra composite netlik/pozlama puanını kullanır. Koordinatör dönen keeperID'yi LibraryConfiguration.keeperID ile yeniden belirler; bu fonksiyona QualityAssessment haritası verilmez. Varsayılan preserve tercihi ölçülen netliği kullanmadan metadata ile saklanacak fotoğrafı değiştirebilir. Buna rağmen kalite ölçülmüşse gerekçe Detail and Resolution olabilir.

**Gerekli değişiklik:** Tek saklama politikası, ölçüm güvenini ve gerçek seçim gerekçesini birlikte döndürmeli; favori/düzenleme ve kullanıcının tercihi önceliğini korumalı. **Kabul:** Daha net küçük fotoğraf ile daha büyük bulanık fotoğraf; favori, manuel saklama ve explicit largest/newest tercihleri ayrı doğrulanmalı.

### R04 — Kısmi kaldırma son incelemede yeniden deneme döngüsünü bozuyor

**Kanıt:** [completedIDs uzlaştırması:604](../../Keptora/Features/Home/MacArchiveModel.swift#L604), [kısmi sonuç:639](../../Keptora/Features/Home/MacArchiveModel.swift#L639), [frozen review:654](../../Keptora/Features/Home/MacArchiveView.swift#L654), [seçim eşitliği:583](../../Keptora/Features/Home/MacArchiveModel.swift#L583).

Örneğin Photos kaldırması başarılı, klasör kaldırması başarısız olursa tamamlanan ID'ler gerçek sepetten çıkarılır; removeSelection false döndürür ve sheet kapanmaz. FrozenSelectionReview yalnız ilk açılışta yakalanmıştır. İkinci onay hâlâ bütün eski ID'leri yollar; güncel sepetle eşleşmez. Çok öğeli işte tamamlananları tek tek ayıklamak kullanıcı işi olmamalı.

**Gerekli değişiklik:** Bool yerine öğe/source bazlı işlem sonucu; tamamlananları tekrar seçemeyen, kalanları açık yeniden inceleme eylemine taşıyan durum. **Kabul:** Photos başarı + ikinci klasör hatası; iki klasörden yalnız birinin başarısı; sonrasında doğru kalan listeyle güvenli retry.

### R05 — Kayıt hatası sonrasında çalışma politikası açık değil

**Kanıt:** [repository okuma hatası:337](../../Keptora/Features/Home/MacArchiveModel.swift#L337), [kaldırma guard'ı:581](../../Keptora/Features/Home/MacArchiveModel.swift#L581), [save/quit:688](../../Keptora/Features/Home/MacArchiveModel.swift#L688).

Bozuk kayıt persistenceError oluşturur ve otomatik kayıt durur; seçim/kaynak/klasör kaldırma guard'ları bu durumu dikkate almaz. Photos adımı saveStateNow kullandığı için durabilirken yalnız klasör kaldırması manifest üzerinden ilerleyebilir. Kullanıcı alert'i kapatınca kalıcı uyarı yoktur. repositoryLoaded false ise quit flush başarılı sayılır. Klasör manifestinin bağımsız kurtarma sağlaması korunur; burada sorun kullanıcı oturumunun ve kararlarının kaydedilememesidir.

**Gerekli değişiklik:** Görünür kayıt sağlığı; bozulmada inceleme/kurtarma erişimi ile yeni değişikliklerin politikasını açıkça ayırmak; onarım/retry sonucu doğrulanmadan kaydedilmiş gibi devam etmemek. **Kabul:** Corrupt primary+backup, disk-full, sonradan yazılabilir disk, alert kapatma ve quit; mevcut okunamayan dosyalar korunmalı.

### R06 — İki akış ortak kaynak işlemi/quit politikası kullanmıyor

**Kanıt:** [AppModel.canStartScan:89](../../Keptora/App/AppModel.swift#L89), [legacy commit:806](../../Keptora/App/AppModel.swift#L806), [legacy restore:895](../../Keptora/App/AppModel.swift#L895), [ana kaldırma:581](../../Keptora/Features/Home/MacArchiveModel.swift#L581), [quit:36](../../Keptora/App/KeptoraApp.swift#L36).

Ana akışın busy/loading/analyzing kapısı ile AppModel'in isCommittingCleanup/restoringPlanID/scanProgress kapısı birbirini bilmez. Aynı kaynak iki akışa bağlanabilir. AppDelegate quit'te advanced checkpoint alır fakat yalnız archive.prepareForTermination işlemini bekler. Native komutların ana oturuma bağlanmış olması bu ortak kaynak sahipliği sorununu tek başına çözmez.

**Gerekli değişiklik:** Her iki motorun kullandığı source/volume bazlı işlem sahibi; quit bütün etkin yazıcıları beklemeli. Gelişmiş motorun tümünü yeniden yazmak gerekmez. **Kabul:** Aynı klasörde iki akıştan tarama/kaldırma/restore; legacy işlem sırasında quit; farklı kaynakta paralel salt-okuma çalışması.

### R07 — Kurtarma uzlaştırmasında sessiz atlama ve final durum ayrımı

**Kanıt:** [recoveryRecords:102](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderQuarantineExecutor.swift#L102), [durum uzlaştırması:107](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderQuarantineExecutor.swift#L107), [geçmiş sunumu:747](../../Keptora/Features/Home/MacArchiveView.swift#L747).

Okunamayan/bozuk recovery.json try? + continue ile sessizce atlanır. Kurtarma dosyaları diskte durabilirken yeni oturum kaydı görmez. Tek bir rebasing hatası da bütün recoveryRecords çağrısını kesebilir. Ayrıca tamamlanmış restore kayıtları her yenilemede özgün dosya üzerinden yeniden hash'lenir; kullanıcının sonradan düzenlediği/taşıdığı dosya interrupted sayılır, ancak restoredAt korunur. Geçmiş Restored ile Needs attention bilgisini aynı kayıtta üretebilir.

**Gerekli değişiklik:** Geçerli kayıt, bozuk kayıt ve tamamlanmış tarihsel makbuz ayrı ele alınmalı. Bozuk klasör bir hata kaydı ve Finder eylemiyle görünür olmalı; bir kaydın hatası diğerlerini gizlememeli. **Kabul:** Bozuk JSON, eksik manifest, yanlış kaynak, restore sonrası normal düzenleme/rename; hiçbir payload otomatik silinmemeli.

### R08 — Restore sonrası doğrulama ve makbuz sırası

**Kanıt:** [toplu restore preflight:133](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderQuarantineExecutor.swift#L133), [taşıma ve restored kaydı:155](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderQuarantineExecutor.swift#L155). Kaldırma yolunda ise taşıma sonrası hash kontrolü vardır.

Restore bütün dosyaları başlangıçta hash'ler, sonra sırayla taşır. Her taşımanın hemen öncesinde ve hedefte sonrasında digest tekrar doğrulanmaz. Uzun restore sırasında son sıradaki kurtarma dosyası değişirse güncel içerik denetlenmeden restored durumuna yazılabilir. Sonraki refresh doğrulaması, başarılı makbuzun öncesindeki doğrulamanın yerine geçmez.

**Gerekli değişiklik:** Geç doğrulama, hedefte hash ve yalnız bundan sonra durable completed kaydı; kısmi/rollback sonuçları doğru işaretlenmeli. **Kabul:** Preflight sonrasında dosya mutasyonu, taşıma sırasında içerik değişimi, yarıda quit ve occupied original; üzerine yazma yasağı korunmalı.

## P2 — kullanıcı akışı ve bakım iyileştirmeleri

### R09 — Hard link kimliği

**Kanıt:** [kimlik:60](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L60), [asset ID:77](../../Packages/KeptoraCore/Sources/KeptoraCore/FolderSourceAdapter.swift#L77), [referans dedup:199](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryWorkflow.swift#L199), [adet guard'ı:591](../../Keptora/Features/Home/MacArchiveModel.swift#L591).

Gerçek hard link örneğinde iki farklı yolun ID'si aynı çıktı; uniqueReferences iki yolu da tuttu. SwiftUI ForEach/sepet ID'ye, dedup yola bağlıdır. Seçilen snapshot adedi expectedIDs adedini aşabilir; ilgili guard hata açıklaması da üretmez. Fiziksel içerik kimliği ile kaldırılacak directory entry kimliği ayrılmalı veya alias yollar tek öğenin altında açıkça temsil edilmeli. Hard link ile normal bağımsız byte-identical kopya ayrı test edilmeli.

### R10 — Hatalar işlem yapılabilir olmalı

**Kanıt:** [sadece neden adetleri:325](../../Keptora/Features/Home/MacArchiveView.swift#L325), [tek String hata:90](../../Keptora/Features/Home/MacArchiveModel.swift#L90), [aşama hatası:553](../../Keptora/Features/Home/MacArchiveModel.swift#L553).

AnalysisIssue öğe/source ID'si taşır; arayüz bunları yalnız adet olarak gösterir. Üç aşamanın hataları aynı String alanına yazılır. Sorunlu Öğeleri Göster, bu öğeleri yeniden dene, erişimi düzelt ve dosyayı Finder'da göster eylemleri gerekli. Typed issue/operation bağlamı kullanılmalı; aynı hatanın kök alert, sheet ve geçmişte sunumu bir sunum sahibiyle yönetilmeli. Tanılama dışa aktarımındaki mevcut redaction korunmalı.

### R11 — Koru sözü davranışla örtüşmeli

**Kanıt:** [manuel seçim:215](../../Keptora/Features/Home/MacArchiveModel.swift#L215), [toplu liste seçimi:564](../../Keptora/Features/Home/MacArchiveView.swift#L564), [Protected hücresi:506](../../Keptora/Features/Home/MacArchiveView.swift#L506), [öneri koruması:234](../../Packages/KeptoraCore/Sources/KeptoraCore/AnalysisModels.swift#L234).

Koruma öneri seçiminden hariç tutar; manuel seçim ve Select This List bunu aşabilir. Son inceleme kişisel Photos bayraklarını uyarır fakat uygulamanın protectedIDs tercihini ayrı uyarmıyor. Kullanıcı isterse tüm öğeleri seçebilmelidir; ancak Koru bir kilit olarak sunuluyorsa açık korumayı kaldırma/istisna eylemi gerekir. Alternatif ürün sözleşmesi Önerilerden Hariç Tut şeklinde açıklanmalı.

### R12 — Öneri adedi ile açılan kapsam

**Kanıt:** [kategori adedi/eylemi:802](../../Keptora/Features/Home/MacArchiveView.swift#L802), [birleşen filtreler:183](../../Keptora/Features/Home/MacArchiveView.swift#L183).

Öneriler toplam kategori adedini sayar, açarken yalnız finding'i değiştirir. Önceden seçilmiş video/albüm/dosya adı filtresi korunur; 100 kopya yazan kategori boş açılabilir. Korunan bağlam ile kategori açma sözleşmesi açık olmalı: adet güncel kapsamı anlatmalı veya Tüm Kategoriyi Aç eylemi filtrelerin etkisini anlaşılır biçimde kaldırmalı. Sepet korunmalı.

### R13 — Görünüm değiştirmek ilişki bilgisini kaldırmamalı

**Kanıt:** [smart grid:345](../../Keptora/Features/Home/MacArchiveView.swift#L345), [timeline hücresi:363](../../Keptora/Features/Home/MacArchiveView.swift#L363), [hücre varsayılan groups:477](../../Keptora/Features/Home/MacArchiveView.swift#L477).

Keep Related Shots Together kapalıyken archiveCell(item) çağrısına ilişki/keeper bilgisi verilmez. Kopya/çok benzer bağlamı, saklama etiketi ve Keep This eylemi bu görünümde kaybolur. Sıralama ilişki üyeliğinden ayrılmalı; kompakt rozetler ve saklama bilgisi her iki düzende aynı kalmalı.

### R14 — Paused durumu ve iptal erişimi

**Kanıt:** [metin branch'i:540](../../Keptora/Features/Home/MacArchiveView.swift#L540), [scan controls:569](../../Keptora/Features/Home/MacArchiveView.swift#L569), [pause:566](../../Keptora/Features/Home/MacArchiveModel.swift#L566).

Çalışan pause analiz görevi analyzing=true olarak kalır. Metin önce analyzing kontrol ettiği için taranıyor açıklamasını gösterir. Paused branch yalnız Resume sunar; Cancel menüsü kaybolur. Açık paused göstergesi, son tamamlanan ilerleme, her durumda iptal ve Öneriler ekranından uygun devam eylemi gerekli. Katalog enumerasyonu sırasında pause davranışı da kabul testine girmeli.

### R15 — Kalite bulgusuna doğrudan filtre

**Kanıt:** [dört genel kategori:148](../../Packages/KeptoraCore/Sources/KeptoraCore/AnalysisModels.swift#L148), [review birleşimi:159](../../Packages/KeptoraCore/Sources/KeptoraCore/AnalysisModels.swift#L159), [kalite finding'leri:6](../../Packages/KeptoraCore/Sources/KeptoraCore/QualityAssessment.swift#L6).

Worth Reviewing sıradan benzerleri ve bütün kalite sorunlarını birleştirir. 3.000 fotoğrafta yalnız muhtemelen bulanıkları veya düşük çözünürlüklüleri görmek mümkün değildir. Ortak sepeti koruyan, adetli ve bir tıkla kaldırılabilen alt filtreler eklenmeli. Kalite bulguları otomatik silme hükmüne dönüştürülmemeli; bir fotoğraf birden çok bulguya sahip olabilir.

### R16 — Büyük galeride kontrol erişimi

**Kanıt:** [scroll içerik sahibi:194](../../Keptora/Features/Home/MacArchiveView.swift#L194), [filtreler:300](../../Keptora/Features/Home/MacArchiveView.swift#L300), [arama:561](../../Keptora/Features/Home/MacArchiveView.swift#L561).

Arama, filtre, kaynak/tarama kontrolleri galeri ScrollView'inin içindedir; alt kısımda yalnız seçim sepeti sabittir. Uzun listede arama veya pause için başa dönmek gerekir. Kompakt sabit üst toolbar, görünür kapsam/adet, aramaya standart klavye odağı ve ayrıntılar için tek Kaynaklar paneli önerilir. Dar pencere ve uzun dil metinlerinde mevcut ViewThatFits koruması devam etmeli.

### R17 — Undo/Redo ve klavye doğrulaması

**Kanıt:** [native undo kaydı:225](../../Keptora/Features/Home/MacArchiveModel.swift#L225), [tek memento:224](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L224), [native test:114](../../KeptoraUITests/KeptoraUITests.swift#L114).

Her seçim eski undo action'larını kaldırır; undo mevcut durumu redo için kaydetmez. Basitlik için tek adım bilinçli olabilir, fakat profesyonel Mac'te standart çok adımlı Undo/Redo daha öngörülebilirdir. Modelle özel Undo düğmesi aynı sözleşmeyi kullanmalı. SearchDoesNotLoseSelectionOrHijackTextUndo testi Cmd-A ve gezinmeyi sınar, Cmd-Z/Redo içermez. Metin, grid ve son inceleme odakları ayrı test edilmeli.

### R18 — Native Settings, Pro ve pencere sahipliği

**Kanıt:** [native Settings scene:107](../../Keptora/App/KeptoraApp.swift#L107), [toolbar inline Settings:285](../../Keptora/App/MainRootView.swift#L285), [Pro eylemi:130](../../Keptora/Features/Settings/SettingsView.swift#L130), [ana root paywall sheet:100](../../Keptora/App/MainRootView.swift#L100).

Toolbar Ayarlar sayfasını ana pencerede değiştirir; Cmd-comma ayrı Settings scene açar. Pro sheet yalnız MainRootView'de sunulur. Native Ayarlar'dan açılan Pro bu pencereye bağlı değildir; ana pencere kapalıysa sunumun kullanıcının önünde oluşma garantisi yoktur. Tek standart Ayarlar giriş davranışı ve eylemi başlatan pencereye bağlı satın alma/hata sunumu gerekli. Dock reopen/fallback, yalnız Settings açıkken de test edilmeli.

### R19 — Büyük arşivde artımlı çalışma ve gözlem sınırları

**Kanıt:** [tam durum snapshot'ı:681](../../Keptora/Features/Home/MacArchiveModel.swift#L681), [debounce:688](../../Keptora/Features/Home/MacArchiveModel.swift#L688), [tam backup/write:122](../../Packages/KeptoraCore/Sources/KeptoraCore/LibrarySessionInfrastructure.swift#L122), [refresh recovery hash:474](../../Keptora/Features/Home/MacArchiveModel.swift#L474), [ilk kaynak batch:183](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryWorkflow.swift#L183), [tekrarlanan visible projeksiyonu:183](../../Keptora/Features/Home/MacArchiveView.swift#L183).

Context/seçim değişimi bütün asset/grup/checkpoint/geçmiş snapshot'ının kayıt kuyruğuna gitmesine neden olur. Kaynak batch'i ancak tüm ilgili kaynak enumerate edilince gelir. Refresh kurtarma içeriklerini tekrar hash'ler. Visible/smart block projeksiyonları aynı render'da birden fazla yerde hesaplanır; scopedAssets/reviewGroups önbellekleri zaten vardır.

Öneri: stabil analiz snapshot'ı ile sık değişen context/karar yazımını ayırmak; kaynak içi batch; önbellekli görünüm projeksiyonu ve dar observation; kurtarmayı parçalı arka plan uzlaştırması. Restore öncesi taze doğrulama korunmalı. Scroll/odak restore'u ilk onAppear'a bağlıdır; soğuk açılışta asenkron kayıt/katalog yüklendikten sonra yeniden uygulanması da test edilmeli.

Bu kod örüntüleri **ölçülmüş FPS veya bellek arızası değildir**. 2.000/3.000 gerçek HEIC/JPEG/RAW/video ile ilk görünen fotoğraf, ilk öneri, arama/selection p95, peak RSS, cold/warm startup, iptal, JSON yazımı ve History açılışı ayrı ölçülmeli.

### R20 — Dinamik metinler sabit anahtar kontrolünden kaçıyor

**Kanıt:** [reasonLabel:141](../../Keptora/Core/Models/ReviewModels.swift#L141), [görünen evidence.reasonLabel:1146](../../Keptora/Features/ReviewStudio/ReviewStudioView.swift#L1146), [localization taramasının kapsamı:12](../../Scripts/validate_mac_localization.py#L12).

Gelişmiş incelemede yedi sabit reasonLabel İngilizce String olarak döner; örnekler Protected canonical keeper, Keeper selected by user ve Batch-added exact extras. Bunların TR/FR/DE anahtarları da katalogda yoktur. Bu ekran erişilebilir; uyumluluk için saklanan ulaşılamayan ekranla karıştırılmamalı. Sabit view literal kontrolünün 550 anahtarda geçmesi bu dinamik değerleri kapsamaz. Typed reason → yerelleştirilmiş anlaşılır metin; plural/interpolasyon ve sistem/app dil seçimi native ekran testleriyle tamamlanmalı.

## Uygulama hatası diye sayılmayan ürün kararları

- **Kurtarma alanını kalıcı temizleme:** Boyut ve Finder eylemi mevcut; uygulama içi açık kalıcı temizleme/saklama yönetimi yok. Dosyaları aynı volume'da taşımak alan boşaltmaz. Depolama temizleme hedefleniyorsa ayrı bir açık kullanıcı eylemi, kapsam incelemesi ve doğru byte hesabı gerekir. Otomatik purge önerilmez.
- **Fotoğraf ailelerinin kapsamı:** Aynı basename RAW/JPEG/MOV/XMP/AAE uyarısı mevcut. Farklı isimli gerçek çekim ailelerinin tam metadata eşleştirmesi ayrı kapsamdır; temel koruma yokmuş gibi tekrar bulgu sayılmaz.
- **Dosya sağlayıcısı politikası:** iCloud/Photos ile üçüncü taraf File Provider aynı yerellik sinyalini vermeyebilir. Arayüz sağlayıcının indirme davranışını açıklıyor; tüm cloud depolarının sessizce/dışarıdan taranabildiği söylenmemeli. WhatsApp özel verilerine erişim istenmiyor.

## Yayın kabulü: kod denetiminden sonra gerekli kanıt

| Kabul | Gerekli kanıt |
|---|---|
| Native derleme | Mac Debug/Release, ortak Apple paket ve iPhone hedefi; minimum desteklenen macOS ile güncel macOS; App Sandbox. |
| Gerçek arşiv doğruluğu | İnsan etiketli kopya/çok benzer/blur corpus'u; portre/bokeh/gece/belge; yanlış saklama/yanlış öneri oranları. |
| Gerçek 2.000/3.000 öğe | Gallery scrolling/arama p95, bellek, ilk sonuç, startup, pause/cancel, enerji; cloud/harici disk. Sentetik 320×240 JPEG benchmark bunların yerine geçmez. |
| Yaşam döngüsü ve recovery | İki motor, kaynak çıkarma/rename, uyku/quit, dosya mutasyonu, kısmi işlem, bozuk manifest, disk-full; makbuz + gerçek disk içeriği. |
| Native UI/erişilebilirlik | Ok/Shift/Space, Cmd-A/Z/Redo, metin odakları, Cmd-comma, yalnız Ayarlar açıkken Pro, VoiceOver, yüksek kontrast, dar pencere ve dört dil. |
| Dağıtım/StoreKit | İmzalı archive, ürün/sandbox satış ve restore/refund/offline senaryoları, privacy raporu. Yapılandırılmış bundle/team/URL'ler placeholder sayılmamalı; Docs/RELEASE_BLOCKERS.md içindeki 181 sürümü güncel 182 proje ayarlarının kanıtı değildir. |

## Önerilen uygulama sırası

1. R01'i düzelt; native build kapısını aç ve Apple derleme kanıtı al.
2. R02, R08, R07: incelenen kimlik, restore son doğrulaması ve kayıt uzlaştırması.
3. R03, R04, R05, R06: doğru saklama gerekçesi, kısmi işlem sonucu, kayıt sağlığı ve ortak işlem sahibi.
4. R09–R18, R20: tek galeri/sepeti koruyarak seçim, hata, filtre, dil ve Mac pencere/klavye davranışını tamamla.
5. R19 ve kabul matrisi: öncelikle 2.000/3.000 gerçek öğede ölç; sonuçlara göre artımlı veri ve observation sınırlarını iyileştir.

Hedef, mevcut SwiftUI/AppKit/PhotoKit/Vision yapısı üzerinde açık işlem durumları, source bazlı ortak sahiplik, doğru keeper gerekçesi ve tutarlı native sunumdur. SwiftUI'yi veya tüm uygulamayı yeniden yazmak bu bulguların çözümü için zorunlu değildir.
