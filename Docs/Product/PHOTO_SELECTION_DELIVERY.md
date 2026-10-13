# Fotoğraf seçimi — sade galeri akışı

**Tarih:** 4 Ekim 2026. **Dal:** `feat/photo-cleaner-library`.

**5 Ekim güncellemesi:** Başlıklar, dil, açık düğmeler, etkin filtreler, kaynak/tarama ve son inceleme düzeni için [UI/UX anlaşılabilirlik teslimi](UI_UX_CLARITY_DELIVERY.md) güncel davranışı açıklar. Ortak test sayısı 54'tür; aşağıdaki sayılar önceki seçim tesliminin sonuçlarıdır.

Kullanıcının son tercihi bu belgedeki seçim akışıdır. Önceki plandaki ayrı karşılaştırma ekranı ve swipe/sürükleyerek karar verme önerileri yerine doğrudan galeri etkileşimi uygulanmıştır.

## Kullanıcının akışı

1. Seçili kaynakların fotoğraf ve videoları aynı galeride gösterilir. Kopyalar ve benzerler akıllı düzende yan yanadır; örtüşen gruplarda aynı fotoğrafın ikinci bir hücresi oluşturulmaz.
2. Fotoğrafa dokunmak/tıklamak seçimi değiştirir. Önce ayrı bir seçim moduna geçmek gerekmez. Seçili hücrede tik, karartma ve çerçeve vardır; kaynak/kalite rozetleri korunur.
3. Fotoğraf hücresindeki büyüteç düğmesi kullanıcının son tercihiyle kaldırılmıştır. Hücreye dokunmak/tıklamak doğrudan seçimi değiştirir; seçim için ayrı bir önizleme ekranına geçilmez. Kaynak ve kalite rozetleri daha fazla hücre genişliğini kullanır.
4. İlgili fotoğrafın altında **Bunu Sakla** bulunur. Fotoğrafın içinde olduğu bütün ilgili gruplara karar uygulanır ve fotoğraf seçimden çıkarılır. Grup altındaki **Diğerlerini Seç (adet)** yalnız mevcut görünümdeki uygun adayları işaretler; başka ilişkide saklanacak görünen fotoğraf da korunur. **Grubu Koru** ikincil menüdedir.
5. Alttaki sabit çubuk seçili adet, fotoğraf/video dağılımı, bilinen medya boyutu ve görünüm dışındaki seçimleri gösterir. Boyutu bilinmeyen öğeler açıkça belirtilir; medya boyutu boşalacak alan diye sunulmaz.
6. **Son Seçimi Geri Al**, **Seçimi Temizle** ve **Seçimi İncele** açık düğmelerdir. Seçim sıfıra inse bile geri alma düğmesi görünür kalır. Son inceleme mevcut güvenlik, sistem onayı ve kurtarma akışını kullanır.

iPhone'da dört bulgu filtresi iki sütunda aynı anda görünür. Normal galeriyi dikey kaydırmak seçim yapmaz. Tarih düzeninde gün/ay seçimi, görünür öğelerin tamamını seçme ve filtreler arasında seçimleri koruma devam eder.

## Son sadeleştirme

- **Kopyalar** görünümünde **Fazla Kopyaları Seç (adet)** doğrudan görünür. Medya türü, albüm, arama ve mevcut koleksiyon kapsamına bağlıdır; görünmeyen öğeleri yeni seçime eklemez. Önceden seçilmiş görünüm dışı öğeler sepette kalır.
- Grup düğmesinde yalnız yeni seçilecek adedin gösterilmesi, seçim tamamlanınca **Diğerleri Seçili** durumuna geçmesi ve uygun aday yoksa **Seçilecek Başka Öğe Yok** açıklaması uygulanmıştır. Etkisiz düğmeler devre dışıdır.
- Aynı saklama/koruma kararına tekrar basmak son anlamlı geri alma adımını silmez. Zaten seçilmiş adaylar tekrar inceleme yetkisi hesabına sokulmaz; ücretsiz inceleme sınırı değiştirilmemiştir.
- iPhone'da boş görünümün **Filtreleri Sıfırla** eylemi bulgu filtresini de **Tümü** yapar; tarih, sıralama ve koleksiyon kısıtlarını temizler. Mac'te boş filtre sonucu için aynı açık dönüş eylemi eklenmiştir. Seçim sepeti korunur.
- Bütün grupların uygun adayları aynı saklama/koruma dışlamasıyla tek geçişte hazırlanır. Her grup düğmesi için bütün grupların yeniden aranması önlenmiştir.

## Karar ve geri alma sınırları

- Tek adımlık geri alma seçilen kimlikleri ve saklama/koruma kararlarını birlikte geri yükler. Etkisiz toplu seçim/temizleme son geçerli adımı bozmaz.
- Geri alma mevcut, bekleyen veya eski kayıttan çözümlenemeyen kimliklerle sınırlıdır. Başarıyla kaldırılmış öğeleri tekrar sepete eklemez; kaldırmanın kurtarılması Geçmiş/sistemin kurtarma alanından yapılır.
- Grup karar düğmeleri analiz sürerken devre dışıdır; manuel fotoğraf seçimi devam edebilir. Kaldırma analiz bitene veya iptal edilene kadar bekler.
- Örtüşen grupların hücre ilişkileri blok başına bir kez indekslenir; her hücre için bütün ilişkiler yeniden aranmaz.
- iPhone temizlik sekmesinden eski ayrıntılı karşılaştırma bağlantısı çıkarıldı. Mac'in gelişmiş klasör incelemesindeki swipe düğmesi/ekran girişi ve karşılaştırma düzeni çıkarıldı; eski görüntüleyicinin karşılaştırma kontrolü kaldırıldı. Mac **İncelemeye Değer** kısayolu ortak galeri ve ortak seçim sepetini açar. Geçmiş/veri uyumluluğu için kullanılmayan eski bileşenler silinmedi.

## Son inceleme ve dar ekran düzeni

- iPhone ve Mac seçim çubuğunda özet ve eylemler ayrı satırlara alındı. Düğmeler genişlik yetmediğinde dikey yerleşir; uzun çeviriler ve büyük yazı için özetin eylemlerle aynı yatay alanı paylaşması önlendi.
- Mac son incelemesi küçük fotoğraf önizlemeleri, kaynak ve çekim tarihiyle gösterilir. Uzun kurtarma/kaynak açıklamaları aynı kaydırılabilir listenin bölümlerindedir; listeyi ekran dışına itmez. İnceleme penceresinin asgari genişliği 640'tan 500 noktaya indirildi.
- İki platformda seçimden çıkarma, öğenin kitaplıkta kalacağını açıklayan metin ve VoiceOver ipucuyla gösterilir. Sabit alt alanda güncel adet ve **Son Çıkarmayı Geri Al** vardır. Liste boşalınca açık boş durum gösterilir, kaldırma kapanır, son çıkarılan fotoğraf aynı ekranda geri alınabilir.
- `FrozenSelectionReview`, incelemeyi yalnız açılışta yakalar. Son çıkarılan öğeyi eski sırası ve aynı dosya/fotoğraf revizyonuyla geri koyar. Sonradan gelen katalog kayıtları otomatik olarak silme planına alınmaz. Erişilemeyen öğeler açık eylemle çıkarıldığında bu öğeler inceleme geri almasıyla dönmez.
- Bütün kopyaların seçili olduğu uyarısı incelemedeki sabit öğelere dayanır. Mac'te seçim inceleme sonrasında değişirse sessizce durmak yerine yeniden inceleme gerektiği açıklanır. Mevcut kimlik ve revizyon doğrulamaları devam eder.
- Ek doğrulama: **53 ortak paket testi geçti**; dört yeni test boş listeyi geri alma, son anlamlı çıkarma, sıralama, eski revizyonun korunması ve erişilemeyen öğeyi geri getirmeme davranışını kapsar. **137 Swift dosyası** sözdizimi kontrolünden geçti; proje referansları, görsel referansları ve dört dilde metin biçimleri doğrulandı.
- Yeni iPhone son inceleme/boş liste/geri alma UI senaryosu Apple CI listesine eklendi. Mac için değişmiş seçim ve geri yüklenen eski revizyonu kaldırmadan reddetme testi hazırlandı. Bu Apple testleri Linux ortamında çalıştırılmadı. Dört yeni inceleme metni EN/TR/FR/DE olarak eklendi; görsel dosyalar değiştirilmedi.

## Doğrulama

- Ortak paket: **53 taşınabilir test**; grup seçiminin örtüşen ilişkideki saklanacak kareyi işaretlememesi ve sabit son inceleme/geri alma politikası doğrulanır.
- iPhone için altı, Mac için beş yeni yerel karar/geri alma/güvenlik testi hazırlandı. Son öğeyi seçimden çıkarma, koruma ve saklamayı birlikte geri alma, örtüşen gruplar, bekleyen seçim, kaldırılan kimliğin yeniden seçilmemesi, tekrarlanan karar, görünüm kapsamı ve değişmiş son incelemenin reddi kapsanır.
- iPhone UI testleri dokunarak seçim, büyüteç düğmesinin bulunmaması, geri alma, galeri içinde saklama/toplu seçim ve son incelemeyi iptal etme akışına uyarlandı. Yeni temel senaryolar Apple CI listesine eklendi. Ekran görüntüleri test sonuç paketine eklenir.
- Yeni/güncellenen **11 seçim metni EN/TR/FR/DE** olarak hazırlandı. **137 uygulama/paket/test Swift dosyasının sözdizimi**, proje referansları ve yerelleştirme kontrolleri geçti. Mevcut **67 görselin** hash/boyut/fixture kontrolleri geçti.
- Son sadeleştirmede **6 ek durum/adet metni** dört dilde eklendi. Ortak aday politikası kontrolleri genişletildi; **49 taşınabilir test tekrar geçti**. Filtreli toplu kopya seçimi ve geri alma için yeni iPhone UI senaryosu Apple CI listesine alındı; Apple testleri burada çalıştırılmadı.

Bu ortam Linux'tur. Xcode tip kontrolü/derleme, yerel unit/UI testleri, gerçek iPhone/Mac etkileşimi ve güncel ekranların görsel kabulü burada yapılmış sayılmaz. Kullanıcı en son büyük yazı/VoiceOver, dar Mac penceresi, 2.000–3.000 fotoğraf, grup kararları, filtre dışı seçim ve geri alma senaryolarını cihazda doğrular. Mevcut 67 görsel bu değişiklikte yeniden üretilmemiştir.
