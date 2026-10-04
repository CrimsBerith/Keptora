# Fotoğraf seçimi — sade galeri akışı

**Tarih:** 4 Ekim 2026. **Dal:** `feat/photo-cleaner-library`.

Kullanıcının son tercihi bu belgedeki seçim akışıdır. Önceki plandaki ayrı karşılaştırma ekranı ve swipe/sürükleyerek karar verme önerileri yerine doğrudan galeri etkileşimi uygulanmıştır.

## Kullanıcının akışı

1. Seçili kaynakların fotoğraf ve videoları aynı galeride gösterilir. Kopyalar ve benzerler akıllı düzende yan yanadır; örtüşen gruplarda aynı fotoğrafın ikinci bir hücresi oluşturulmaz.
2. Fotoğrafa dokunmak/tıklamak seçimi değiştirir. Önce ayrı bir seçim moduna geçmek gerekmez. Seçili hücrede tik, karartma ve çerçeve vardır; kaynak/kalite rozetleri korunur.
3. Büyüteç ayrı, erişilebilir bir düğmedir. Tek öğenin önizlemesini açar; iPhone önizlemesinde sonraki/önceki grup gezintisi veya karşılaştırma yoktur. Görüntüyü büyütme ve büyütülmüş görüntüyü taşıma, seçim kararını değiştirmez.
4. İlgili fotoğrafın altında **Bunu Sakla** bulunur. Fotoğrafın içinde olduğu bütün ilgili gruplara karar uygulanır ve fotoğraf seçimden çıkarılır. Grup altındaki **Diğerlerini Seç** yalnız güvenli adayları işaretler; başka ilişkide saklanacak görünen fotoğraf da korunur. **Grubu Koru** ikincil menüdedir.
5. Alttaki sabit çubuk seçili adet, fotoğraf/video dağılımı, bilinen medya boyutu ve görünüm dışındaki seçimleri gösterir. Boyutu bilinmeyen öğeler açıkça belirtilir; medya boyutu boşalacak alan diye sunulmaz.
6. **Son Seçimi Geri Al**, **Seçimi Temizle** ve **Seçimi İncele** açık düğmelerdir. Seçim sıfıra inse bile geri alma düğmesi görünür kalır. Son inceleme mevcut güvenlik, sistem onayı ve kurtarma akışını kullanır.

iPhone'da dört bulgu filtresi iki sütunda aynı anda görünür. Normal galeriyi dikey kaydırmak seçim yapmaz. Tarih düzeninde gün/ay seçimi, görünür öğelerin tamamını seçme ve filtreler arasında seçimleri koruma devam eder.

## Karar ve geri alma sınırları

- Tek adımlık geri alma seçilen kimlikleri ve saklama/koruma kararlarını birlikte geri yükler. Etkisiz toplu seçim/temizleme son geçerli adımı bozmaz.
- Geri alma mevcut, bekleyen veya eski kayıttan çözümlenemeyen kimliklerle sınırlıdır. Başarıyla kaldırılmış öğeleri tekrar sepete eklemez; kaldırmanın kurtarılması Geçmiş/sistemin kurtarma alanından yapılır.
- Grup karar düğmeleri analiz sürerken devre dışıdır; manuel fotoğraf seçimi devam edebilir. Kaldırma analiz bitene veya iptal edilene kadar bekler.
- Örtüşen grupların hücre ilişkileri blok başına bir kez indekslenir; her hücre için bütün ilişkiler yeniden aranmaz.
- iPhone temizlik sekmesinden eski ayrıntılı karşılaştırma bağlantısı çıkarıldı. Mac'in gelişmiş klasör incelemesindeki swipe düğmesi/ekran girişi ve karşılaştırma düzeni çıkarıldı; eski görüntüleyicinin karşılaştırma kontrolü kaldırıldı. Mac **İncelemeye Değer** kısayolu ortak galeri ve ortak seçim sepetini açar. Geçmiş/veri uyumluluğu için kullanılmayan eski bileşenler silinmedi.

## Doğrulama

- Ortak paket: **49 taşınabilir test**; yeni test, grup seçiminin örtüşen ilişkideki saklanacak kareyi işaretlememesini doğrular.
- iPhone için dört, Mac için iki yeni yerel karar/geri alma testi hazırlandı. Son öğeyi seçimden çıkarma, koruma ve saklamayı birlikte geri alma, örtüşen gruplar, bekleyen seçim ve kaldırılan kimliğin yeniden seçilmemesi kapsanır.
- iPhone UI testleri dokunarak seçim, bağımsız önizleme, galeri içinde saklama/toplu seçim ve son incelemeyi iptal etme akışına uyarlandı. Yeni temel senaryolar Apple CI listesine eklendi. Ekran görüntüleri test sonuç paketine eklenir.
- Yeni/güncellenen **11 seçim metni EN/TR/FR/DE** olarak hazırlandı. **137 uygulama/paket/test Swift dosyasının sözdizimi**, proje referansları ve yerelleştirme kontrolleri geçti. Mevcut **67 görselin** hash/boyut/fixture kontrolleri geçti.

Bu ortam Linux'tur. Xcode tip kontrolü/derleme, yerel unit/UI testleri, gerçek iPhone/Mac etkileşimi ve güncel ekranların görsel kabulü burada yapılmış sayılmaz. Kullanıcı en son büyük yazı/VoiceOver, dar Mac penceresi, 2.000–3.000 fotoğraf, grup kararları, filtre dışı seçim ve geri alma senaryolarını cihazda doğrular. Mevcut 67 görsel bu değişiklikte yeniden üretilmemiştir.
