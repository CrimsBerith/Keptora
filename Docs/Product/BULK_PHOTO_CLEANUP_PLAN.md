# Keptora — 2.000–3.000 fotoğrafta kolay toplu temizlik planı

**Tarih:** 3 Ekim 2026. **İncelenen GitHub sürümü:** `d517fb8f969835c382797c4e9241ba3cf15c2bdc`, `feat/photo-cleaner-library`.

**Ana hedef:** Kullanıcı kaynaklarını tikler, bir kez tarar, bütün seçili fotoğrafları aynı arşivde görür, yan yana duran kopya/çok benzer kareleri karşılaştırır ve gereksiz olanları az adımla kaldırır. Teknik ayrıntıların öğrenilmesi gerekmez.

**Güncel kapsam kararı:** Kullanıcı WhatsApp'a özel çalışmayı iptal etti. Ayrı WhatsApp kaynağı, koleksiyonu, depolama/sohbet erişimi, ZIP içe aktarımı ve yedek/yerel depo araştırması geliştirme kapsamından çıkarıldı. Kaynaklar **Galeri/Fotoğraflar, Bulut klasörleri ve Dosyalar** olacak. Galeriye veya dosyalara kaydedilmiş fotoğraflar hangi uygulamadan geldiklerinden bağımsız normal taramada kalır. Önceki teslimdeki özel WhatsApp girişleri/rehberi de kaynak ve UI sadeleştirme aşamasında kaldırılacak; bu belge değişikliği uygulama kodundan kaldırıldıkları anlamına gelmez.

**Bu belgenin durumu:** Kaynak kodu incelenerek hazırlanmış yeni uygulama planıdır. Tikli tarama kapsamı, yeni kalite rozetleri ve yeni toplu karar akışı bu planın teslimiyle uygulanmış sayılmaz. Birleşik arşiv, mevcut kaynak rozetleri, ilk kurulum izinleri ve manuel kaldırma önceki teslimlerde kodlandı; native kabulü ayrıca gerekir.

**Çalışma sırası:** Kod, kaynak/analiz modelleri, UI, test verisi ve burada çalışabilen doğrulamalar önce tamamlanacak. Xcode derlemesi, Mac/iPhone çalıştırması ve gerçek cihaz kabulü en son kullanıcı tarafından yapılacak. Native erişimi kod geliştirmesine başlama önkoşulu yapan eski plan bölümlerinin yerine bu sıra geçer.

## 1. Mevcut durum ve gerçekten eksik olanlar

| Alan | Kodda mevcut | Yeni iş |
|---|---|---|
| Kaynaklar | Fotoğraflar ve çoklu izinli klasörler birlikte listeleniyor/taranıyor; bağlantılar saklanıyor. | Bağlı olmak ile bu taramada seçili olmak ayrılacak; tikler ve seçili öğe sayısı eklenecek. |
| Arşiv | Tüm öğeler, tarih/albüm filtreleri, serbest seçim, önizleme, kaynak rozetleri var. | Ana görünüm bütün öğeleri koruyarak ilgili kareleri yan yana yerleştirecek; tekrar eden kontroller sadeleşecek. |
| Kopya/benzer | Birebir ve benzer grupları ortak görünümde; SHA-256 ve medya ailesi koruması mevcut. | Birebir, çok benzer ve daha zayıf benzerlik açık ayrılacak; grup içi karar daha az dokunmayla verilecek. |
| Kalite | `VisualQualityEngine` netlik/pozlama/yüz sinyalleri hesaplıyor. `VisualSimilarityAnalyzer` raporları geçici olarak saklanacak kare seçimine katıyor. | Tek başına duran fotoğraflar dahil raporlar UI'a taşınacak; bulanıklık/düşük çözünürlük adayları açıklanacak. |
| Kalite doğruluğu | Kenar yoğunluğu ile netlik tahmini; ortalama parlaklık ile pozlama tahmini var. | Düşük detay, noise, portre arka planı ve sanatsal karanlık fotoğraf yanlış “kalitesiz” ilan edilmeyecek. |
| Önbellek | Mobil küçük resim önbelleği ve exact tarama checkpoint'i var. `MediaFingerprintDiskCache` dosyası mevcut. | Disk analizi önbelleği mevcut tarama akışında kullanılmıyor; revizyon güvenliği düzeltilip gerçekten bağlanacak. |
| Toplu karar | Filtre dışında kalan seçim, son inceleme, kaynak başına işlem ve kurtarma var. | Doğrulanmış fazladan kopyalar için toplu öneri; benzerlerde grup başına sakla/değiştir/diğerlerini seç akışı. |
| İzinler / akış sadeleştirme | Başlangıç Fotoğraflar izni ve klasör bağlantıları mevcut; önceki teslimde özel WhatsApp girişleri/rehberi eklendi. | Genel izin/klasör akışı korunacak; iptal edilen özel girişler kaldırılacak. |

Mevcut kalite motorunda ayrıca üç somut sorun var: göz noktalarının bulunması `eyesOpen` işaretine çevriliyor; bu gözlerin açık olduğunu kanıtlamaz. Genişlik/yükseklik ayrı ayrı 256'ya sınırlanırken bazı görüntüler esnetiliyor. Çok küçük/okunamayan görüntü düşük skorla dönüyor; bunun doğru durumu **değerlendirilemedi** olmalıdır. Bu sorunlar yeni kalite rozetleri gösterilmeden düzeltilecek.

## 2. Kullanıcının göreceği ana akış

1. **Kaynakları seç:** Tüm bağlı kaynaklar, Galeri/Fotoğraflar, Bulut klasörleri ve Dosyalar. Her satırda tik, erişim durumu ve mevcut öğe sayısı.
2. **Tek tarama:** Ana düğme **“Seçili kaynakları tara”**; yanında tekilleştirilmiş toplam, örneğin **“2.864 öğe”**. İzin/klasör bağlantısı yalnızca eksik kaynak için tamamlanır.
3. **Sonuçları gör:** Fotoğraflar uygulaması gibi yoğun ve kaydırılabilir grid. İlk fotoğraflar ve hazır bulgular tam analiz bitmeden görünür; neyin henüz değerlendirilmediği anlaşılır.
4. **Kolay karar ver:** Kopyalar ve çok benzer kareler ortak grup başlığı altında yan yana. Saklama önerisi ve kısa gerekçesi görünür. Kullanıcı öneriyi değiştirebilir.
5. **Seçimi incele ve kaldır:** Sabit alt çubukta adet ve **“Seçimi incele”**. Gerçek seçili fotoğraflar, kaynak ve kaldırma hedefi tek son incelemede gösterilir. Sonuç ve kurtarma yolu Geçmiş'te bulunur.

İlk kullanım hedefi, gerekli erişimler ve bağlantılar tamamlandıktan sonra **kaynakları seç → tara → öneriyi/seçimi incele → kaldır** akışıdır. Analiz beklemeden serbest manuel seçim mevcut kalır. Tarama, sonuçların görülmesini ve basit arşiv gezinmesini kilitlemez.

## 3. Tikli kaynak seçiminin davranışı

| Satır | Anlamı | Erişim eksikse |
|---|---|---|
| **Tüm bağlı kaynaklar** | Erişilebilir alt kaynakların tamamını seçer; bazıları seçiliyse kısmi durum gösterir. | İzin verilmemiş satır tiklenmiş/taranmış gibi görünmez. |
| **Galeri / Fotoğraflar** | İzinli PhotoKit arşivi; iCloud Fotoğrafları bu arşivin parçasıdır. | Fotoğraflar izni veya Ayarlar bağlantısı. |
| **Bulut klasörleri** | Kullanıcının bağladığı iCloud Drive ve diğer dosya sağlayıcı klasörleri. | **Klasör bağla**; bağlı olmayan tüm bulut hesabı taranmış sayılmaz. |
| **Dosyalar** | Bağlı yerel klasörler; kullanıcı isterse alt klasörleriyle birlikte. | Sistem klasör seçicisi. |

**Örtüşme kararı:** Tikler kullanıcının anlayabileceği tarama kategorileridir; fiziksel kaynak bağlantısını silmez. Bir bulut klasörü Dosyalar altında tekrar tarama kategorisi oluşturmaz. Bağlı klasörler örtüşürse öğe kapsamı gerçek dosya yolu/PhotoKit kimliği üzerinden birleşir. Ayrı kaydedilmiş gerçek dosya kopyaları ayrı öğe kalır. Fotoğraflar arşivindeki albümler kaynak değil filtre/bağlam bilgisidir; aynı PhotoKit kimliği birden fazla albümde bulunduğu için tekrar sayılmaz.

Kaynak rozeti gerçek Fotoğraflar/klasör bağlantısını gösterir. Dosya adı, albüm adı veya EXIF yokluğu gönderen uygulamanın kesin kanıtı diye sunulmaz. Genel albüm filtresi korunur; uygulama başına ayrı tarama koleksiyonu kurulmaz.

**Bulut kararı:** iCloud Fotoğrafları ayrı bir sürücü klasörü gibi gösterilmez. Galeri satırı iCloud Fotoğrafları'nı içerdiğini söyler; **Bulut klasörleri** iCloud Drive/diğer dosya sağlayıcılarını ifade eder. “Ağdan indirilmesi gerekiyor” ile “iCloud'da saklanıyor” aynı bilgi değildir; konum bilinmiyorsa kesin Bulut rozeti üretilmez.

Tarama kategorisini seçmek indirme onayı anlamına gelmez. Ağ gerektiren asıllar varsa ayrı **“Bulut asıllarını indirerek tamamla”** eylemi ve kapsamı görünür. İndirme reddedilse de katalogdaki fotoğraf kaybolmaz; exact/benzerlik/kalite aşamalarında okunamayan öğeler ayrı sayılır.

Seçimler bir sonraki açılış için saklanır. Tarama başladığında kapsam sabitlenir; tik değişikliği sonraki taramayı etkiler. Hiç kaynak seçilmediyse düğme pasif ve **“En az bir kaynak seç”** açıklaması görünür. Erişimi geri alınmış bir kaynakta açık durum gösterilir; kullanılabilir kaynakların tamamı engellenmez. Kaynak kapsamı değişince önceki analiz sonuçları yeni kapsamın sonucu gibi sunulmaz. Önceden yapılmış manuel seçim sessizce kaybolmaz; kapsam dışındaki seçim sayısı gösterilir.

## 4. Profesyonel rozetler ve kalite sınıfları

Kaynak rozetleri korunacak. **Kaynak** nerede bulunduğunu, **bulgu** neden incelenebileceğini anlatır; seçim tiki üçüncü, ayrı bir işarettir.

| Bulgu | Kullanıcı metni | Gerekli kanıt / davranış |
|---|---|---|
| Birebir kopya | **Birebir kopya** | Uyumlu algoritma ile doğrulanmış eşit içerik; Live Photo/medya ailesi korunur. Benzer thumbnail bu rozet için yetmez. |
| Güçlü görsel eşleşme | **Çok benzer** | Corpus ile kalibre edilmiş görsel eşleşme; zaman, konum ve burst destekleyici bağlam. Birebir kopya diye sunulmaz. |
| Daha zayıf görsel ilişki | **Benzer çekimler** | İkinci katman filtre/karşılaştırma; ilk toplu öneri daha güçlü eşleşmeleri öne çıkarır. |
| Netlik sorunu adayı | **Bulanıklık şüphesi** | Yeterli boyutta/kalitede önizleme, karşılaştırılabilir netlik sinyalleri ve uygun güven düzeyi. Tek başına az kenar içerme kesin bulanıklık değildir. |
| Yetersiz piksel boyutu | **Düşük çözünürlük** | Asıl medyanın bilinen boyutları; küçük thumbnail veya sıkıştırılmış dosya boyutu üzerinden karar verilmez. |
| Pozlama sorunu adayı | **Çok karanlık / Çok aydınlık** | Ortalama parlaklığa ek histogram/kırpılmış piksel oranı; kasıtlı gece/siluet fotoğrafında temkinli davranılır. |
| Grup içi iyi aday | **Saklama önerisi** | Bu grupta daha net / daha iyi pozlanmış / daha yüksek çözünürlüklü veya kullanıcının korumak istediği kare; gerekçesi açık. |
| Eksik değerlendirme | **Henüz incelenmedi / Değerlendirilemedi** | Önizleme, erişim, indirme veya işlem eksikliği; “kalitesiz” ve “sorun yok” sonuçlarına çevrilmez. |

**“Kalitesiz”** kesin ve estetik bir hüküm olduğu için ana rozet olmayacak. Filtrenin adı **“İncelemeye değer”**; içinde bulanıklık, düşük çözünürlük ve pozlama adayları kendi nedenleriyle yer alacak. RAW biçimi veya büyük dosya tek başına “iyi fotoğraf” kanıtı sayılmayacak. “En iyi ifade / gözler açık” rozeti, bunu gerçekten ölçen yöntem ve doğrulama olmadığı sürece gösterilmeyecek.

Küçük fotoğraf üzerinde üstte tek kısa kaynak rozeti (**Bulut / Dosyalar / Galeri**), altta en önemli tek bulgu gösterilir. Fazla bulgu ayrıntı panelinde açılır. Aynı fotoğraf hem kopya hem bulanık olabilir; veride iki bulgu tutulur fakat görsel beş rozetle kaplanmaz. Rozetler simge + kısa metin kullanır; anlam sadece renge dayanmaz. Silme rengi kalite tahminine verilmez. Kaynak ayrıntısında gerçek albüm/klasör ve varsa sağlayıcı açılır.

## 5. Bütün fotoğraflar ve yan yana karar ekranı

Varsayılan sonuç **Tüm öğeler — Akıllı düzen** olur. Tüm seçili ve listelenebilir fotoğraflar kalır; kopya veya kalite sorunu bulunmayanlar gizlenmez. **Tarihe göre** alternatif sıralamadır. Hızlı filtreler **Tümü · Kopyalar · Çok benzer · İncelemeye değer**; albüm/tarih/favori/medya türü gibi ek kontroller tek **Filtreler** alanında açılır.

Akıllı düzende önce doğrulanmış kopya grupları, sonra çok benzer gruplar, ardından incelemeye değer tekil öğeler ve diğer fotoğraflar gösterilir. Grup başlığı **“4 birebir kopya · 1 saklama önerisi”** veya **“5 çok benzer kare”** der. Saklama önerisi ilk sıradadır; grup sınırı görünür. Küçük iPhone'da okunabilir üç sütun, uygun genişlikte daha fazla sütun; büyük yazıda daha az sütun. Mac'te pencereye göre ölçeklenen aynı grup yapısı.

Bir öğe birden fazla ilişkiye sahipse ana grid'de aynı kimlik iki kez sayılmaz/gösterilmez. Ortak karşılaştırma bloğu exact alt kümelerini ve çok benzer ilişkisini ayrı işaretler; ilişkilerin transitif olması bütün bloğu “birebir/çok benzer” ilan ettirmez. Karmaşıklık ana görünümde tekrar eden kopya kartlarına dönüşmez. Grup filtresi açıldığında ilgili gerçek öğeler yan yana gösterilir. Analiz ilerlerken kullanıcının dokunduğu/seçtiği grup yerinden atlamaz ve önerisi sessizce değişmez.

Normal dokunma önizleme açar; **Seç** modunda dokunma seçimi değiştirir. Grup içinde **“Bunu sakla”**, **“Diğerlerini seç”**, **“Grubu koru”** bulunur. Yakınlaştırmalı karşılaştırma netlik farkını görmeyi sağlar. Hareket gerektirmeyen seçim düğmeleri ve VoiceOver açıklamaları korunur.

Kullanıcı grubun tamamını manuel seçebilir; son incelemede bunun bütün üyeleri kaldıracağı gösterilir. Aynı filtrede daha önce incelenmiş grup tekrar tekrar öne getirilmez. **“Sakla”** kararı kaydedilir, ilgili medya değişince eski değerlendirme tekrar kontrol edilir.

## 6. Hızlı toplu seçim ve kaldırma politikası

- **“Önerilen kopyaları seç”** sadece doğrulanmış birebir gruplardaki fazladan ve korumasız öğeleri seçer. Her grupta saklanan aday kalır; kaç adayın koruma nedeniyle atlandığı anlaşılır.
- **Çok benzer** gruplarda önce kullanıcı saklanacak kareyi görür/seçer; ardından **“Diğerlerini seç”** kullanır. Bütün arşivdeki benzerler tek dokunmayla kendiliğinden silinmez.
- **Bulanıklık/pozlama** tahminleri otomatik seçime dönüşmez. Kullanıcı bu filtrede görünenleri açıkça seçebilir; seçim kapsamı ve adet bellidir.
- Favori, kullanıcıca “Sakla” işaretli, düzenlenmiş, gizli ve paylaşımlı öğeler varsayılan toplu öneride korunur; mevcut sistem yetkileri/kısıtları ayrıca geçerlidir. Manuel seçim mevcut serbestliğini korur.
- Sıradan albüm üyeliği ile kişisel koruma ayrılacak. Bir öğenin sırf normal bir albümde diye toplu temizlikten tamamen dışlanması kolay temizliği engeller. Normal albüm üyeliği bağlam/uyarı bilgisidir; açıkça korunan albümler farklı ele alınır. Bu mevcut `isProtectedFromGlobalSelection` davranışında bilinçli bir politika değişikliğidir ve regresyonla doğrulanır.
- Seçim birden fazla filtre/grupta aynı ID'yi bir kez içerir. Filtre değişiminde seçim korunur; gizli seçim sayısı ve **“Seçimi geri al”** görünür. Kaydırma jesti başka grubun üyelerini seçmez.
- Son inceleme seçilen gerçek öğeleri, adetleri ve kaynak başına hedefleri gösterir. Onay sırasında kapsam sabitlenir; işlem başlamadan revizyon/erişim tekrar kontrol edilir. Kaynak başına hata/kısmi tamamlanma Geçmiş'e doğru yazılır.

Fotoğraflar'da sistem onayı ve Son Silinenler, dosyalarda mevcut kurtarma klasörü davranışı korunur. Kurtarma alanına taşıma veya Son Silinenler'e gönderme **“şu kadar alan kesin boşaldı”** diye sunulmaz. İşlem yalnızca seçilen gerçek öğeleri ve gösterilen kayıt yerlerini etkiler.

## 7. 2.000–3.000 fotoğraf için performans tasarımı

**Önce katalog ve küçük resimler, sonra artımlı bulgular.** Mevcut iPhone akışı exact taramayı bitirip görsel benzerliğe geçtiğinden, kalite ve çok benzer sonuçları bütün büyük dosyaların hash'ini bekleyebilir. Ortak tarama koordinatörü aşamaları bağımsız ilerletir; toplam kapsam ile exact/görsel/kalite tamamlanma sayıları ayrı tutulur. Henüz doğrulanmamış eşleşme exact rozeti alamaz.

| İş | Uygulama kararı | Doğrulama |
|---|---|---|
| Aynı resmi tekrar açma | Boyutu/oranı/orientasyonu doğru ortak önizleme; kalite + perceptual hash + Vision aynı görüntüden yararlanır. | Decode sayacı; değişmemiş öğede gereksiz yeni analiz sayısı. |
| Yeniden tarama | Mevcut disk önbelleğini exact ve görsel/kalite akışına bağla. Anahtarda algoritma/revizyon, içerik sürümü ve gerekli medya ailesi bilgisi. | Değişmeyenler cache hit; değişenler yeniden hesaplanır. Eksik/güvenilmez revizyonda eski kanıt tekrar kullanılmaz. |
| Önbellek güvenliği | Mevcut tam saniyeye yuvarlanan değiştirme zamanı düzeltilecek; bilinmeyen tarih/boyut ve algoritma değişimi açık ele alınacak. | Aynı saniyede değiştirilmiş dosya, PhotoKit düzenlemesi, bozuk kayıt, farklı algoritma testleri. |
| Büyük bellek | Sınırlı iş kuyruğu; küçük analiz görüntüleri; bütün asılları RAM'e alma yok. Mobil mevcut thumbnail cache'i korunur/ölçülür. | Kuyruk/bellek ölçümü; uzun kaydırmada limit dışı birikme yok. |
| Pahalı yüz işlemleri | Her fotoğrafta yüz + göz noktası işi yapmak yerine gerekli karşılaştırmalara sınırla. Doğrulanmamış ifade rozetini kaldır. | Kalite sonucu bu işlem olmadan çalışır; yanlış ifade iddiası üretilmez. |
| Kopya doğrulama | SHA-256/aile kanıtını koru; değişmeyen güvenilir revizyonda yeniden kullan. Boyutu bilinmeyen PhotoKit öğelerini dosya eşleşmesinden eleme. | Mevcut kaynaklar arası ve Live Photo regresyonları korunur. |
| Benzer aday arama | Hash/zaman/burst/konum indeksleri korunur; aday ölçümü ve grup içi tutarlılık sürer. FeaturePrint ve hash mesafeleri farklı ölçüler olarak kalibre edilir. | Aynı yer/saatte farklı sahneler birleşmez; metadata'sız benzerler kaybolmaz; keyfî yüzde yok. |
| UI maliyeti | ID/grup indeksleri ve önceden hesaplanan görünüm modeli. İç içe `visible.contains` ve her hücrede tam sıralama azaltılır. | 3.000 öğelik fixture'da hesaplama/sıralama sayacı ve kararlı seçim. |
| İptal/devam | Aşama ve tarama kapsamına bağlı checkpoint; iPhone arka planında uygun durdurma, sonra devam. | İptal sahte tamamlandı sonucu üretmez; değişmiş tik/algoritma eski checkpoint'i kullanmaz. |

Fotoğraf kalitesi bütün erişilebilir görüntülerde değerlendirilir; tekil fotoğraf olması eleme nedeni değildir. Videolar mevcut görünüm/temizlik kapsamını korur, fakat fotoğraf bulanıklık metriği bir video karesinden bütün videoya uygulanmaz. Video analizi kendi aşaması ve kapsamıyla gösterilir.

Ölçülecekler: ilk grid'in görünme süresi, ilk incelenebilir grubun süresi, tam yerel analiz, ikinci tarama, ana iş parçacığı takılması, peak bellek, decode/karşılaştırma sayısı, iptal gecikmesi. **“3.000 fotoğrafı X saniyede bitirir”** vaadi ölçüm yapılmadan verilmeyecek; bulut indirme süresi ayrı raporlanacak.

## 8. Burada uygulanacak geliştirme sırası

| Sıra | Teslimat | Başlıca kod alanları | Tamamlanma ölçütü |
|---|---|---|---|
| **1 — Tarama kapsamı** | Bağlantı/kategori/tik ayrımı; tümünü/kısmi seç; tekil adet; sabit kapsam; iptal edilen özel kaynak girişlerinin kaldırılması; bulut açıklamaları. | [LibraryWorkflow.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryWorkflow.swift), [LibraryModels.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/LibraryModels.swift), [MobileKeptoraStore.swift](../../KeptoraiOS/App/MobileKeptoraStore.swift), [MobileLibraryView.swift](../../KeptoraiOS/UI/MobileLibraryView.swift), [MacArchiveView.swift](../../Keptora/Features/Home/MacArchiveView.swift) | Tiklenmeyen kategori işlenmez; örtüşen fiziksel referans bir kez; ayrı gerçek kopya korunur; izin eksikliği açık. |
| **2 — Kalite kanıtı** | Bulgu/veri modeli, geçerli/değerlendirilemedi durumu, oran/orientasyon düzeltmesi, temkinli netlik/pozlama, açıklama. | [VisualQualityEngine.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/VisualQualityEngine.swift), [ImageSharpnessEvaluator.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/ImageSharpnessEvaluator.swift), ortak Foundation modelleri | Tekil fotoğrafta da sonuç; okuma hatası kalite kusuru olmaz; unsupported göz/ifade etiketi yok; UI bilinmeyenle düşük kaliteyi ayırır. |
| **3 — Artımlı ortak analiz** | Tek önizleme hattı, bulguları UI'a veren analiz sonucu, ayrı stage coverage, güvenilir cache, çok benzer ayrımı. | [VisualSimilarityAnalyzer.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/VisualSimilarityAnalyzer.swift), [ExactGrouping.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/ExactGrouping.swift), [MediaFingerprintDiskCache.swift](../../Packages/KeptoraCore/Sources/KeptoraCore/MediaFingerprintDiskCache.swift), iki platformun store/model'i | İlk sonuçlar tam hash bitişine bağlı değil; exact kanıtı korunur; algoritma/medya değişince eski bulgu yenilenir. |
| **4 — Ana karar arayüzü** | Akıllı/tarih grid'i, küçük kaynak/bulgu rozetleri, yan yana bloklar, saklama gerekçesi, sade filtreler. | [MobileArchiveView.swift](../../KeptoraiOS/UI/MobileArchiveView.swift), [MobileAssetThumbnail.swift](../../KeptoraiOS/UI/MobileAssetThumbnail.swift), [MacArchiveView.swift](../../Keptora/Features/Home/MacArchiveView.swift), ortak review modeli | Tüm seçili öğeler görünür; aynı ID iki kez sayılmaz; seçim tiki kaynak rozetiyle karışmaz; kullanıcı dokunduğu grup atlamaz. |
| **5 — Toplu karar** | Doğrulanmış kopyaları öner, grupta sakla/diğerlerini seç, koruma ayrımı, seçim geri alma, son inceleme. | Ortak keeper/seçim politikası; mevcut iPhone/Mac kaldırma ve Geçmiş akışları | Her toplu exact grubunda saklanan aday; favori/sakla korunur; sıradan albüm üyeliği bütün temizliği engellemez; manuel seçim özgürlüğü sürer. |
| **6 — Teslim hazırlığı** | Dört dil, erişilebilirlik kodu, gerçek test corpus senaryoları, benchmark komutları, güncel rapor ve native kabul listesi. | [Localizable.xcstrings](../../Keptora/Resources/Localizable.xcstrings), ortak testler, Scripts, mevcut iPhone/Mac UI testleri | Burada çalışabilen anlamlı testler, proje referansları, veri/çeviri/görsel kontrolleri geçti; native çalıştırılmadı durumları açık. |
| **7 — Kullanıcının son kabulü** | Xcode build/test; Mac/iPhone gerçek kullanım, iCloud/provider ve kaldırma/kurtarma; ölçümler ve ekran kabulü. | Kullanıcının Apple ortamı; mevcut Apple CI ve hazırlanmış kontrol listesi | Cihaz davranışı ve hız ölçüldü; kritik hata varsa ilgili düzeltme yapıldı; ardından yayın kararı. |

Önerilen yeni ortak modeller: kaynak seçimini ifade eden `ScanScopeSnapshot`, öğe başına çoklu ve gerekçeli bulgu için `AssetFindings`, güven/durum/algoritma içeren kalite değerlendirmesi, exact/çok benzer ilişki kanıtı ve kararlı grid blokları. Bunlar önerilen isimlerdir; bu plan commit'inde yeni uygulama modeli eklenmiş değildir. Apple görüntü erişimi ile saf sayısal politika ayrılarak burada çalışabilen ortak test kapsamı artırılır. Aynı kalite matematiği ikinci bir Python/Swift uygulamasıyla çelişecek biçimde çoğaltılmaz.

Her aşama küçük, incelenebilir commit'lerle mevcut dalda ilerler. UI ve algoritmalar iki platformda ortak politika kullanır; native testi beklemek iPhone/Mac kodunu yazmayı durdurmaz. Native framework derlemesi/sistem davranışı burada geçmiş gibi raporlanmaz.

## 9. Anlamlı testler ve kabul ölçütleri

### Burada hazırlanacak/çalıştırılabilecek testler

| Senaryo | Beklenti |
|---|---|
| Galeri + birden fazla albüm + örtüşen yerel/bulut klasörleri | Kapsam/toplam ID'ler tekil; aynı içeriğin iki gerçek kopyası kalır. Tik kapalı kategori analiz dışıdır. |
| Kaynak tikleri boş/kısmi; izin reddi/sınırlı erişim | Yanlış tam kapsam sonucu yok; kullanılabilir seçili kaynaklar işler. |
| Aynı görsel, farklı kayıt yeri/metadata | Exact kanıt eşitse tek kopya grubunda; boyutu bilinmeyen öğe eşleşmeden düşmez. |
| Live Photo + yalnız sabit JPEG; düzenlenmiş görüntü | Aile/versiyon farkı yok sayılarak exact etiketi verilmez. |
| Aynı zaman/yer ama farklı konu; yeniden sıkıştırılmış benzer | Metadata görsel uyumsuzluğu geçerli eşleşmeye çeviremez; JPEG boyutu farklı diye gerçek benzerlik kaybolmaz. |
| Bulanık dönüşüm, net düz/az detaylı yüzey, portre bokeh, noise, gece/siluet, küçük önizleme | Tahmin durumları ve gerekçeler doğru; eksik/şüpheli kanıt otomatik seçime dönüşmez. |
| Favori/düzenlenmiş/kullanıcıca sakla; sıradan albüm | Koruma ile koleksiyon üyeliği ayrılır; toplu öneri ve manuel seçim farklı niyeti korur. |
| Aynı ID birden fazla bulgu/grupta | Bir kez sayılır/seçilir; grup ilişkisi kaybolmaz; kategori toplamları aynı öğeyi gizlice toplamaz. |
| Yeniden tarama, aynı saniyede değiştirilmiş dosya, algoritma/kapsam değişimi | Cache/checkpoint doğru yenilenir; eski kanıt yeni sürümün kanıtı sayılmaz. |
| 2.000 ve 3.000 öğelik deterministic karma corpus | Beklenen kapsam/gruplar/seçim, iptal ve tekrar tarama doğrulanır; algoritma ve bellek maliyeti kaydedilir. |

Mevcut 22 portable çekirdek testinin kapsamı korunacak ve yeni politikalarla genişletilecek. Apple görüntü/Vision testleri burada yazılabilir; gerçekten çalıştırılmaları son native aşamada yapılır. 2.000–3.000 öğelik sentetik corpus ölçek testidir; gerçek insan fotoğraflarında kalite doğruluğunu tek başına kanıtlamaz. Var olan görseller/test kaynakları kullanılabilir; özel fotoğraf yükleme şartı yoktur.

### Kullanıcının en son Apple ortamında doğrulayacağı kısa liste

1. İki target Xcode'da derlenir; hazırlanmış unit/UI testleri çalışır.
2. iPhone'da tam/sınırlı/reddedilmiş Fotoğraflar erişimi; Dosyalar ve bulut klasörü bağlanır. Farklı uygulamalardan galeriye/dosyalara kaydedilmiş fotoğraflar normal kapsamda görünür.
3. 2.000–3.000 gerçek karışık fotoğrafta kaynaklar tiklenir; tek tarama; tüm seçili öğeler görünür; exact/çok benzer kareler yan yana ve gerekçeler anlaşılır.
4. Net, bulanık, düşük detaylı, bokeh'li, karanlık ve küçük çözünürlüklü örneklerde yanlış rozetler sayılır. Kalite tahminleri yayın eşiği için etiketli, farklı türlerde gerçek bir doğrulama kümesiyle kalibre edilir.
5. Doğrulanmış kopyalardan toplu seçim, saklama önerisini değiştirme, grup koruma, filtre dışı seçim ve son inceleme denenir. Kullanıcı hangi öğeleri kaldıracağını teknik açıklama okumadan anlayabilir.
6. Fotoğraflar sistem onayını iptal etme, karma kaynakta işlem hatası, Geçmiş/kurtarma ve iCloud eşitleme davranışı denenir.
7. Aynı arşivde ilk grid/ilk grup/tam yerel tarama/tekrar tarama/bellek ölçülür. Bulut ağı etkisi ayrı tutulur. Mac'te dar pencere ve klavye; iPhone'da büyük yazı, VoiceOver ve açık/koyu görünüm kontrol edilir.

**Çıkış kapısı:** Bütün seçili erişilebilir öğeler görünür veya neden erişilemediği bellidir; kesin kopya ile tahmini kalite karışmaz; toplu öneride yanlış exact seçimi ve korunan öğe kaybı yoktur; kullanıcı benzer kareleri hızlı karşılaştırır; kaldırma hedefi açıktır. Ölçülmemiş hız/doğruluk ve çalıştırılmamış native kontroller tamamlandı diye işaretlenmez.

## 10. Kapsamı sade tutan kararlar

Kaynak rozetleri kalır. Yeni logo veya mevcut 67 görselin yeniden üretimi gerekmez; güncel görsel çalışma yeniden kullanılacak. Bu aşamada OCR, kişi tanıma, sohbet mesajı okuma, bulut hesabı entegrasyonu, yeni paywall/fiyat ve yeni hesap açma akışı eklenmez. Bunlar kullanıcının fotoğraf temizleme kararını yavaşlatır ve ana hedef için gerekli değildir.

WhatsApp'a özel entegrasyon, kaynak/rozet, dışa aktarım içe alma, yedek okuma ve yerel özel depo araştırması kapsam dışıdır. İzinli galeri/dosya medyası hangi uygulamadan geldiğine bakılmadan normal kapsamda işlenir. Başka uygulamaların özel depolarına genel erişim vaadi verilmez.

[Önceki ürün planı](PHOTO_CLEANER_PLAN.md) · [Birleşik arşiv raporu](UNIFIED_LIBRARY_UX_AUDIT.md) · [Başlangıç izinleri](STARTUP_ACCESS_REPORT.md) · [Görsel inceleme](VISUAL_REGENERATION_REVIEW.md)
