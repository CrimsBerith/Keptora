# Daha anlaşılır fotoğraf temizleme — UI, UX ve dil teslimi

**Tarih:** 5 Ekim 2026. **Dal:** `feat/photo-cleaner-library`.

Sonraki çalışma: [iPhone/Mac düğme yerleşimi denetimi ve düzeltmeleri](BUTTON_LAYOUT_AUDIT.md). Gerçek dokunma alanları, ana/ikincil eylem sıraları ve dar ekran yerleşimleri bu ek teslimde ele alındı.

Derin sistem/Mac incelemesi: [Profesyonel Mac uygulaması mimari denetimi](MAC_ARCHITECTURE_AUDIT.md). Bu rapor iki ürün akışının bağlantı boşluklarını, Apple derleme engelini ve henüz tamamlanmamış Mac kabul gereksinimlerini kanıtlarıyla listeler.

Bu çalışma, kullanıcının kaynak → tarama → galeri → seçim → son inceleme → geçmiş akışını sadeleştirme planını uygular. Önceki [fotoğraf seçimi teslimi](PHOTO_SELECTION_DELIVERY.md) üzerine kuruludur. Doğrudan dokunarak seçim, ortak galeri/sepet, kaynak rozetleri ve tek adımlık geri alma korunur; karşılaştırma, swipe ile seçim ve büyüteç akışı eklenmez.

## Kullanıcının göreceği değişiklikler

| Alan | Yeni davranış |
|---|---|
| Ana gezinme | iPhone: **Fotoğraflar · Öneriler · Geçmiş**. Mac ana gezinmesinde aynı isimler; klasör planları ve istatistikler açılır **Gelişmiş Araçlar** altında. Gelişmiş ekrana başka bir girişten gidilirse bölüm açılır. |
| Sayılar | Galeri toplamı **Bu listede: … öğe**; sepet adedi **Seçili öğeler: …** olarak ayrı gösterilir. Grup başlığı mevcut filtredeki öğe sayısını gösterir. Örtüşen grupların sayıları toplanarak toplam diye sunulmaz. |
| Seçim düğmeleri | **Bu Listeyi Seç (adet)**, **Tüm Seçimleri Kaldır**, **Seçimi İncele (adet)** açık metinlidir. iPhone toplu seçim düğmesi başlık alanında dar genişlikte alt satıra geçer. Mac seçim çubuğu seçim/geri alma gerektiğinde görünür. |
| Kaynaklar | Ana ekranda seçili kaynak isimleri ve adedi vardır. Kaynak ekranında farklı öğe toplamı; tik kaldırmanın bağlantıyı silmediği açıklaması. Kaynak seçilmediyse veya erişim sorunu varsa doğrudan kaynak yönetimine götüren eylem gösterilir. |
| Tarama | Her iki platformda ana ad **Taramayı Başlat**. Tarama sürerken duraklatma görünür, iptal seçenekler menüsündedir; duraklatılınca ana eylem **Devam Et** olur. Hazır sonuçların seçilebildiği, duraklama ve tam sonuç açıkça anlatılır. Bulut asıllarının indirme/tarama seçeneği ayrı onayla çalışır. |
| Etkin filtreler | Bulgu, medya, albüm ve arama tek tek kaldırılabilir. iPhone'da favori, tarih, sıralama ve koleksiyon da görünür. Koleksiyonun kaldırılması diğer filtreleri ve sepeti sıfırlamaz. Bütün filtreleri sıfırlama seçeneği devam eder. |
| Saklama/kalite | **Saklama önerisi**, **Senin seçimin** ve **Korunuyor** farklı anlamlarda gösterilir. Kullanıcı kararı örtüşen grupta önerinin önüne geçer; eski medya revizyonu güncel kullanıcı kararı olarak etiketlenmez. Birden fazla bulgunun ek olanları menüden okunur. |
| Son inceleme | **… Öğeyi Kaldır** düğmesinde adet bulunur. **Seçimden Çıkar** metinlidir. Hedef, iCloud eşitlemesi ve dosya kurtarma/alan koşulları görünür; uzun açıklama **Kurtarma Ayrıntıları** bölümündedir. Analiz sırasında kapalı kaldırma düğmesinin nedeni açıklanır. |
| Sonuç/geçmiş | Kaynaklar arasında işlem yarıda kalırsa gerçekten taşınan ve taşınmayan adetler açıklanır; tamamlanan kaynaklar Geçmiş'te kurtarılabilir. Dosya geçmişi son incelemeyle aynı **Kurtarma Klasörü** adını kullanır. iPhone kurtarma eylemlerinde 44 noktalık hedef korunur. |

Saklama rozeti kararları blok başına hazırlanır; her küçük fotoğraf için grup revizyonunun tekrar hesaplanması önlenmiştir. Son incelemenin sabit öğe/revizyon kontrolü ve kaldırılan kimliklerin seçimden çıkarılması korunur. Fotoğraflar sistemin Son Silinenler alanına, dosyalar aynı depolamadaki kurtarma klasörüne taşınır; dosya boyutu boşalmış alan diye gösterilmez.

## Dil ve doğrulama

- **109 metin anahtarı** EN/TR/FR/DE olarak eklendi veya tamamlandı. Ana Fotoğraflar, Kaynaklar, Öneriler, Son İnceleme ve Geçmiş görünümlerindeki sabit metin taramasında TR/FR/DE eksiği kalmadı; arama, ilerleme ve onay pencereleri de kapsandı. Dinamik klasör/album/dosya adları özgün kalır; bu kontrol bütün eski/gelişmiş ekranların yerelleştirme kabulü anlamına gelmez.
- **54 taşınabilir ortak paket testi geçti.** Saklama kararının revizyon değişince geçersizleşmesi testi genişletildi; örtüşen grupta kullanıcı rozetinin sıra bağımsız önceliği için yeni test eklendi.
- **137 uygulama/paket/test Swift dosyası** sözdizimi kontrolünden geçti. Proje referansları, görsel referansları, dört dilde biçim argümanları ve değişikliklerin boşluk kontrolü geçti.
- iPhone/Mac gezinme ve son inceleme UI testleri yeni metinlere/sabit kimliklere uyarlandı. Bir filtreyi kaldırırken diğer filtreyi ve seçimi koruma senaryosu iPhone Apple CI listesine eklendi.
- Bu ortam Linux'tur. Apple tip kontrolü/derleme ve native unit/UI testleri burada çalıştırılmadı. Görsel dosyalar değiştirilmedi; güncel native ekranlar görsel olarak onaylanmış sayılmaz.

## Kullanıcının son cihaz kabulü

İlk kullanımda kaynak seçimi ve izin reddi; kısmi Fotoğraflar erişimi; dar Mac penceresi; büyük yazı/VoiceOver; 2.000–3.000 öğede gezinme ve seçim; duraklatma/devam/iptal; bir filtreyi ve koleksiyonu tek başına kaldırma; filtre dışı seçim; kullanıcı saklama rozeti; adetli son onay; karışık kaynakta kısmi işlem ve Geçmiş'ten kurtarma kontrol edilir. Fotoğrafların doğru gruplanması ve kalite ipuçlarının gerçek fotoğraflardaki doğruluğu ayrıca cihazda değerlendirilir.
