# Keptora uygulama teslimi

2026-10-03. Çalışma yalnızca Keptora deposunda yapıldı.

## Kullanıcıya görünen değişiklikler

- iPhone’daki Arşiv, kopya analizini beklemeden tüm erişilebilir fotoğraf ve videoları listeler. Normal dokunma önizleme, seçim modunda dokunma seçimdir. Basılı tutup sürükleme, görünür kapsamı/günü/ayı seçme, seçim geri alma ve ayrı son inceleme vardır.
- Albüm, fotoğraf/video, favori, arama, tarih aralığı, gün/ay gruplaması ve boyut sıralaması eklendi. Filtre dışında kalan seçim sayısı görünür; kaynak başına seçim kaydedilir. Kaynak değiştirme, eski asenkron sonuçların yeni arşivi ezmesini engeller.
- Benzersiz, favori, düzenlenmiş veya albümdeki öğeler manuel seçilebilir. Akıllı toplu öneri kişisel öğeleri ve saklanacak kopyayı korur. Manuel seçim Pro gerektirmez.
- Temizlik sekmesi WhatsApp albümleri, ekran görüntüleri, boyuta göre videolar, Live Photos ve kopya/benzerlik incelemesine erişim sağlar. WhatsApp albümleri kullanıcı tarafından atanabilir ve saklanır. Fotoğraflar’daki koleksiyon üyeliği değişince koleksiyon güncellenir. WhatsApp sohbet depolaması, iOS uygulama sınırı nedeniyle WhatsApp’ın kendi rehberiyle yönetilir.
- Benzerlik, görsel özellik ve hash adaylarına güvenilir çekim zamanı, yakın konum ve burst bağlamı ekler. Metadata görsel uyumsuzluğu kopya yapmaz. Grup üyeleri arasında görsel uyum kontrol edilir, eksik önizlemeler sayılır. Eski 5.000 görsel sınırı kaldırıldı.
- Önizlemede yakınlaştırma, önceki/sonraki öğe, seçim, video oynatma ve açık tercihle iCloud indirme vardır. Ayrıntılarda mevcut çekim tarihi, GPS, kamera/lens, ISO, diyafram ve enstantane gösterilir. Saat dilimi olmayan EXIF metni olduğu gibi gösterilir. Dosya oluşturma tarihi çekim tarihi diye etiketlenmez.
- Silme öncesi seçilen gerçek öğeler, kaynak, fotoğraf/video sayısı, bilinen medya boyutu ve kişisel öğe uyarısı gösterilir. Fotoğraflar sistem onayıyla Son Silinenler’e gider; süre en fazla 30 gündür ve daha önce kalıcı silinebilir. iCloud değişiklikleri diğer cihazlara eşitlenir.
- Klasör temizliği alan boşalttığını iddia etmez. Dosyalar aynı depolamadaki kurtarma klasörüne taşınır. Hash, kaynak sınırı, çakışma, işlem öncesi/sonrası içerik ve geri yükleme kontrol edilir. Atomic recovery.json taşımadan önce diske yazılır; tercihler kaybolsa bile yeniden bulunur. Kesilmiş geri yükleme devam edebilir; dolu hedefin üstüne yazılmaz. Aktif iPhone kurtarma kayıtları silinemez.
- macOS’a ortak medya modeli üzerinden Arşiv, albüm/WhatsApp filtreleri, manuel seçim, önizleme, benzerlik ve kurtarma geçmişi eklendi. Mevcut doğrulanmış klasör planları gelişmiş inceleme akışında korunur; geçmiş iki tür işlemi gösterir.
- Dört kaliteli PNG illüstrasyon iPhone/macOS onboarding ve Pro ekranlarına bağlandı. Kart katmanları sadeleşti, ana eylem rengi düzleştirildi, dokunma hedefleri ve Reduce Motion davranışları iyileşti. Türkçe ürün metinleri eklendi; yeni Temizlik sekmesi desteklenen dört dilde çevrildi.

## Doğrulama

| Kontrol | Bu ortamın sonucu |
|---|---|
| Swift ortak katalog/seçim/metadata politikası testleri | 11 test, 0 hata; gerçek paylaşılan kaynak kodu derlendi |
| Swift sözdizimi | 132 uygulama/test/paket dosyasında temiz |
| Xcode kaynak referansları | Eksik referans yok; iki yeni ekran dosyası hedeflerine bağlı |
| PNG çözünürlük/SHA-256 ve asset referansları | Geçti: dört 1536×1024 PNG ve tüm asset referansları |
| Türkçe format yer tutucuları | Geçti |
| iOS/macOS native derleme, PhotoKit, Vision ve UI testleri | Linux’ta çalıştırılamadı; Apple CI eklendi, sonucu ayrıca değerlendirilir |
| Apple kurtarma testleri | Manifest yeniden keşfi, yarım geri yükleme ve değişmiş dosya için eklendi; Linux’ta çalıştırılmadı |
| Yeni gerçek ekran çekimleri | Apple CI, simülatöre gerçek medya dosyaları aktarır ve xcresult ekran eklerini saklar; bu ortamda çekilmedi |

Linux hedefi yalnızca Foundation modellerini derler. Apple framework’leri sahte implementasyonlarla değiştirilmez. Native doğrulama geçmeden yayın sürümü hazır kabul edilmez.

## Yayın öncesi kalan kabul işleri

Apple CI derleme/test sonuçları, gerçek cihazda silme/geri yükleme, iCloud/limited erişim, VoiceOver, büyük yazı ve açık/koyu tema görsel kabulü gerekir. Yeni App Store ekran görüntüleri bu kabulden sonra seçilmelidir; eski 12 ekran yeni ürün için onaylı değildir. Fotoğraflar boyutu public API ile katalogda bilinmeyebilir; ölçülen değerler ve bilinmeyen boyutlar ayrı sunulur. Yeni ayrıntılı ürün metinleri İngilizce/Türkçe tamamlandı; Almanca/Fransızca yeni uzun metinlerin çeviri kabulü sonraki dil kontrolündedir. Büyük gerçek arşivde süre/bellek ölçümü ve analiz eşiklerinin corpus ile kalibrasyonu yapılmadı.

[Önceki UI/UX raporu](UI_UX_AUDIT.md), [ürün planı](PHOTO_CLEANER_PLAN.md), [görsel kararları](VISUAL_INVENTORY.md), [yeni görseller](ARTWORK.md) ve [Apple CI](../../.github/workflows/apple-validation.yml).

## 67 görsel yenilemesi

34 ikon/logo, 8 illüstrasyon, 13 test girdisi ve 12 tasarım önizlemesi yeniden üretildi. 66 görüntülenebilir çıktı tek tek açıldı; kasıtlı bozuk JPEG negatif test olarak doğrulandı. [Yeni inceleme raporu](VISUAL_REGENERATION_REVIEW.md) ve [galeri](VISUAL_GALLERY.html). 12 ekran native çekim değildir ve App Store için onaylanmadı.


## 3 Ekim 2026 — Tek arşiv ve kaynaklar arası tarama güncellemesi

Yeni birleşik akış, iPhone ve Mac’te Fotoğraflar ile birden fazla izinli klasörü birlikte gösterip tarar; farklı kaynaklardaki kopyaları karşılaştırır. Birebir/benzer grupları ana arşivde birlikte sunulur, kayıt kaynağı ve tutma önerisi etiketlenir. Karma seçim kaynak başına kaldırma ve ayrı kurtarma geçmişi kullanır. Tüm bağlı kaynaklar işlenir; bütün telefonun özel uygulama depolamasına erişim vaadi verilmez.

Bu güncellemenin doğrulama durumu ve kalan native kabul adımları [Birleşik Arşiv UI/UX Raporu](UNIFIED_LIBRARY_UX_AUDIT.md) içinde kayıtlıdır. 67 görselin yeniden üretim durumu önceki raporda geçerlidir; burada yeni native ekran görüntüsü onaylanmış sayılmaz.
