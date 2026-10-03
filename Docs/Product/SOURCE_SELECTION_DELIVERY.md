# Seçili kaynaklarla tek tarama — arayüz teslimi

3 Ekim 2026 · `feat/photo-cleaner-library`

Kullanıcı Fotoğrafları ve klasörleri bir kez bağlar; ana arşivde hangi kaynakların görüneceğini ve birlikte taranacağını tiklerle seçer. Bağlantıyı kaldırmak ile taramadan çıkarmak ayrı işlemlerdir.

| Arayüz | Uygulanan davranış |
|---|---|
| Tüm bağlı kaynaklar | Ana tik tüm erişilebilir kaynakları seçer/çıkarır; kısmi seçimde eksi işareti gösterir. |
| Kaynak satırları | Fotoğraflar/iCloud Fotoğrafları ve bağlı dosya/bulut klasörlerinin kendi tikleri, öğe sayısı ve erişim durumu vardır. |
| Tek tarama | “Seçili kaynakları tara” yalnızca tikli kaynakları exact, fotoğraf benzerliği ve video benzerliği analizine gönderir. |
| Kaynak seçilmedi | Tarama kapanır, kaynak seçme açıklaması görünür. Kaynak hiç bağlanmadıysa bağlantı girişleri kullanılır. |
| Ortak arşiv | Seçili kaynakların öğeleri aynı gridde, mevcut kaynak rozetleriyle görünür. Kopya/benzer grupları seçili kapsamdan gelir. |
| Öğe sayısı | Aynı dosyanın örtüşen klasörlerdeki görünümleri ve tekrarlanan albüm görünümü bir sayılır; ayrı gerçek kopyalar korunur. Satır sayıları bu nedenle toplanarak arşiv toplamı bulunmaz. |
| Seçimi hatırlama | Kaynak tikleri iPhone/Mac için ayrı saklanır. Yeni bağlanan kaynak seçili başlar. |
| Silme için manuel seçim | Bir kaynağın tikini çıkarmak önceden seçilen fotoğrafları kaybetmez; görünüm dışında kalan seçim sayısı ve son inceleme korunur. |
| Kaynak değişikliği | Önceki analiz grupları ve iPhone tarama checkpoint'i geçersizleşir. Başka kapsamın sonucu yeni kapsamda sunulmaz. |
| İşlem sürerken | Kaynak değişimi yükleme, izin isteme, analiz ve kaldırma sırasında kapalıdır. |

Fotoğraflar/iCloud Fotoğrafları tek Photos kaynağıdır. Bulut sağlayıcıları sistemin Dosyalar/Finder üzerinden sunduğu izinli klasörlerle bağlanır. Kaynağın bağlı olması buluttaki bütün orijinallerin indirildiği anlamına gelmez; mevcut indirme onayı ve erişilemeyen öğe açıklamaları korunur.

WhatsApp'a özel kaynak, koleksiyon, rehber, dışa aktarım ve rozet kaldırıldı. Galeriye/dosyalara kaydedilmiş medya normal kapsamda kalır. UI metinleri İngilizce, Türkçe, Fransızca ve Almanca güncellendi.

## Doğrulama

- Linux'ta **29 ortak çekirdek testi geçti**. Seçilmeyen kaynağın hiç enumerate edilmemesi, tarama/checkpoint kimliğinin kapsama bağlanması, kısmi/boş seçim, sınırlı/reddedilmiş erişim, saklama ve yeni bağlantı davranışı test edildi.
- 3.000 öğelik sentetik senaryo: 1.500 Photos öğesi + 1.500 dosya + aynı dosyaların 500 iç klasör görünümü = 3.000 tekil öğe. Yalnız iç klasör seçildiğinde 500 öğe, doğru kaynak sahibi ve 2.500 görünüm dışı manuel seçim doğrulandı. Bu test gerçek cihaz hızını veya görsel analiz doğruluğunu ölçmez.
- Seçili kaynak yeniden tarandığında diğer kaynakların kataloğu, ölçülmüş boyutları ve manuel seçimleri korunur; gerçekten kaldırılmış öğeler katalogdan çıkarılır.
- 131 Swift dosyasının sözdizimi; Xcode kaynak referansları; görsel/asset bütünlüğü; Türkçe biçim yer tutucuları ve git whitespace kontrolü geçti. 67 görsel bu işte değiştirilmedi.
- Native Mac model testi ve iPhone kaynak tikleri/saklama/manuel seçim UI testi eklendi; Apple CI test listesi güncellendi. **Xcode derlemesi ve Apple testleri burada çalıştırılmadı.**

## Son cihaz kontrolü

1. iPhone ve Mac target'larını Xcode'da derleyin; hazırlanmış unit/UI testlerini çalıştırın.
2. Fotoğraflar + iki izinli klasör bağlayın. Birini çıkarın, yalnız seçili kaynakların göründüğünü/tarandığını; ana tikte kısmi durumu ve yeniden açılışta seçimin korunduğunu kontrol edin.
3. İç içe klasörleri aynı anda bağlayın; toplamın tekil, ayrı kopyaların görünür ve yalnız iç klasör seçildiğinde dosyaların erişilebilir olduğunu kontrol edin.
4. Bir fotoğrafı silmek için seçin, kaynağın tikini çıkarın; gizli seçim sayısını ve son incelemede fotoğrafın hâlâ bulunduğunu doğrulayın.
5. Sınırlı Photos, çevrimdışı bulut/harici disk, büyük yazı/VoiceOver, Mac'te dar pencere ve klavye kullanımını kontrol edin.

Kalite/bulanıklık rozetleri, yeni toplu karar akışı ve önbellek geliştirmeleri [aktif planda](BULK_PHOTO_CLEANUP_PLAN.md) sonraki işlerdir.
