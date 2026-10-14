# Keptora — UI/UX ana planı

**Tarih:** 13 Ekim 2026. **İncelenen sürüm:** `main` @ `656cb0b` (PR #19 sonrası).

**Hedef:** Fotoğraf kütüphanesi olan herkes, Keptora'yı açtıktan sonra bir dakika içinde ilk sonuçlarını görür, birkaç dokunuşla fazlalıkları seçer, neyin gideceğini tek ekranda görüp güvenle kaldırır ve gerekirse geri alır. Büyük yazı, karanlık mod, VoiceOver, dört dil ve büyük kütüphanelerde de aynı kolaylık geçerlidir.

**Bu belge neyi esas alır:** Norman ilkeleri, Nielsen'in 10 sezgisel kuralı, Shneiderman'ın 8 kuralı, Fitts/Hick/Doherty yasaları, Apple Human Interface Guidelines ve WCAG 2.2 AA. Her iş paketi hangi kurala dayandığını, neyi değiştireceğini ve nasıl kabul edileceğini yazar.

**İlişkili belgeler:** [Kolay kullanım ve güvenilirlik planı](USABILITY_AND_RELIABILITY_PLAN.md) (tamamlanmış temel), [UI/UX denetimi](UI_UX_AUDIT.md), [buton yerleşimi denetimi](BUTTON_LAYOUT_AUDIT.md).

## 1. Korunan ürün kararları

Bu kararlar plan boyunca değişmez:

- Karşılaştırma ekranı, kaydırarak karar verme (swipe) ve büyüteç butonu yoktur. Büyük görme yalnızca basılı tutma önizlemesi (iPhone) ve sağ tık / önizleme (Mac) ile yapılır.
- Seçim galeride dokunarak yapılır; **Bunu Sakla**, **Diğerlerini Seç**, **Fazla Kopyaları Seç** ve geri alma korunur.
- Hiçbir şey son inceleme ve onay olmadan kaldırılmaz. Photos öğeleri Son Silinenler'e, klasör dosyaları kurtarma klasörüne gider.
- Gezinme, kaldırma ve kurtarma ücretsizdir; Pro yalnızca 100 öğeden sonraki önerilen toplu seçimi açar.
- Uygulamada analitik ve ağ üzerinden veri toplama yoktur. Bu nedenle ölçümler testlerle ve kullanıcı görüşmeleriyle yapılır.
- Yeni zorunlu sekme eklenmez; iPhone'da Fotoğraflar, Öneriler, Geçmiş; Mac'te Fotoğraf Kütüphanesi ve Geçmiş kalır.

## 2. Başarı ölçütleri

| Ölçüt | Hedef | Nasıl ölçülür |
|---|---|---|
| İlk değere kadar süre | Yeni kurulumdan ilk sonuç kartına, 3.000 öğede 60 sn altı | `testFreshInstallWalkthrough` süre ölçümü + cihazda kronometre |
| İlk temizliğe dokunuş sayısı | Sonuç kartından kaldırma onayına en fazla 5 dokunuş | Walkthrough testinde sayım |
| İlk ekranda görünen fotoğraf | iPhone'da açılışta en az 2 tam satır fotoğraf | UI testinde ilk hücrenin `minY` değeri |
| Kontrast | Bütün metinlerde 4.5:1, büyük metin ve ikonlarda 3:1; açık ve karanlık modda | Renk tablosu testi + Xcode Accessibility Inspector |
| Dynamic Type | AX5 boyutunda kesilen veya üst üste binen metin yok | AX5 ile UI testleri ve ekran görüntüsü incelemesi |
| VoiceOver | Tarama, seçim, kaldırma ve geri yükleme yalnızca VoiceOver ile tamamlanır | Cihazda el ile test, kayıt |
| Akıcılık | 50.000 öğede kaydırırken kare düşmesi yok; seçim değişimi 100 ms altında | Instruments (SwiftUI, Time Profiler, Hangs) |
| Memnuniyet | 5 kişilik testte SUS ortalaması 80 ve üzeri | Kullanılabilirlik testi (bölüm 7) |

## 3. Mevcut durum denetimi

| Kural | Bulgu | Kanıt | Öncelik |
|---|---|---|---|
| Sade tasarım, Fitts | iPhone galerisinde fotoğraflar ekranın yaklaşık 720 pt / 874 pt noktasından sonra başlıyor; üstte sayaç, Bu Listeyi Seç, Kaynaklar, Kaynak Erişimi, tarama butonları, sonuç kartı, 4 bulgu butonu, ipucu, medya filtresi ve filtre çipleri var. | 13 Ekim walkthrough ekran görüntüleri | P0 |
| Hata önleme | **Bu Listeyi Seç (N)** en üstte, sayaç kadar belirgin; tek dokunuş binlerce öğeyi seçebilir. | `MobileArchiveView.swift`, `selectListButton` | P0 |
| Kontrast (WCAG 1.4.3) | Vurgu rengi sabit `#5747F5`. Karanlık modda `#1C1C1E` üzerinde 2.94:1, siyah üzerinde 3.63:1. | `MobileDesignSystem.swift:20`, `DesignTokens.swift:13` | P0 |
| Kontrast | Seçili bulgu ve filtre çiplerinde mor metin %12–16 mor zemin üzerinde 4.13–4.38:1 (küçük metin için yetersiz). | Aynı dosyalar | P0 |
| Kontrast | Turuncu/amber uyarı metni beyaz üzerinde 2.20–2.35:1; 6 yerde metin rengi olarak kullanılıyor. | `foregroundStyle(.orange / amber)` | P1 |
| Dynamic Type | 11 yerde sabit `font(.system(size:))`; bu metinler büyük yazı ayarıyla büyümüyor. | `MobileLibraryView`, `MobileHistoryView`, `MobileSettingsView`, `MainRootView`, `DesignTokens` | P1 |
| Performans | `visible` listesi her `body` değerlendirmesinde ~19 yerde yeniden filtrelenip sıralanıyor; tarama ilerlemesi her güncellemede bunu tetikliyor. | `MobileArchiveView.swift` | P1 |
| İlk değer süresi | Değer görülmeden önce 3 tanıtım sayfası + kaynak kurulumu (4 ekran). | `MobileOnboardingView`, `MobileSourceLibraryView` | P1 |
| Yıkıcı eylemden önce tam liste | Son incelemede seçili öğelerin listesi en altta; üstte özet, kaynak bazında kaldırma ve kurtarma detayları var. | `MobileSelectionReviewSheet` | P1 |
| Öneriler sekmesi | **Taramayı Başlat** en altta, yüzen tab bar'ın arkasında kalıyor. | Walkthrough 11 ekran görüntüsü | P1 |
| Mac'te eşitlik | iPhone'daki otomatik ilk tarama ve sonuç kartı Mac'te yok; önizleme yalnızca sağ tık menüsünde. Space ile Quick Look yok. | `MacArchiveView.swift` | P1 |
| Hata mesajı | Bütün hatalar "Something went wrong" başlığıyla geliyor; başlık sorunu söylemiyor. | `MobileRootView`, `MainRootView` | P2 |
| Bağlam içi yardım | Basılı tutma, koruma ve geri alma özellikleri yalnızca tek satırlık ipucuyla anlatılıyor; TipKit yok. | `import TipKit` yok | P2 |
| Reduce Motion | iPhone'da 6 animasyon noktası; hepsinin Reduce Motion'a uyduğu doğrulanmadı. | `withAnimation` kullanımları | P2 |
| Yerelleştirme | Almanca/Fransızca uzun metinler için kesilme testi yok (Türkçe AX testi var). | `KeptoraiOSUITests` | P2 |

Zaten iyi olan ve korunacaklar: son incelemede fiil ve sayı içeren kırmızı buton, seçim geri alma, bağlam içinde Photos izni, izin reddinde klasör seçeneği, kademeli sonuçlar, otomatik ilk tarama, sonuç kartı, 44 pt hedefler (test ediliyor), AX boyutunda dikey düzen, seçim haptiği, basılı tutma önizlemesi, dört dilde tutarlı metin, Mac'te ⌘, Ayarlar.

### 3.1 Ekran yoğunluğu ölçümü

`testScreenDensityInventory` testi, Türkçe arayüzde her ana ekranda görünen buton ve metinleri sayar ve listeler. Sayfa olarak açılan ekranlarda arkadaki kütüphane öğeleri de sayıma girer; aşağıdaki tabloda sayfanın kendi öğeleri ayrıca verilmiştir.

| Ekran | 13 Ekim başlangıç | Paket L/M sonrası |
|---|---|---|
| Arşiv (açılış) | 29 buton · 17 metin · 42 kelime | 22 buton · 16 metin · 40 kelime |
| Arşiv, 1 seçili | 32 buton · 20 metin · 48 kelime | 26 buton · 20 metin · 45 kelime |
| Kaynaklar sayfası (kendi öğeleri) | 6 buton · ~100 kelime | 7 buton (Ayrıntılar dahil) · ~48 kelime |
| Son inceleme (kendi öğeleri) | 4 buton · ~63 kelime | 6 buton (satır başına Seçimden Çıkar) · ~45 kelime |
| Öneriler | 10 buton · 29 kelime | 10 buton · 27 kelime |

## 4. Hedef kullanıcı akışı

1. **Açılış (1 ekran):** Tek bir karşılama ekranı: "Fotoğraflarınız cihazınızda kalır. Neyin gideceğine siz karar verirsiniz." ve **Başla**. Diğer tanıtım içeriği Ayarlar ▸ Keptora Nasıl Çalışır altına taşınır.
2. **Kaynak:** Photos izni bağlam içinde istenir. İzin verilirse doğrudan galeriye geçilir ve tarama başlar. Reddedilirse klasör seçme ve Ayarlar'ı aç yolu gösterilir.
3. **Galeri (ilk bakış):** Üstte tek satırlık durum şeridi (kaynak ve tarama durumu), altında yatay kaydırılan bulgu çipleri (Tümü, Birebir Kopyalar, Çok Benzer, İncelemeye Değer), hemen ardından fotoğraflar. Tarama sürerken ilerleme şeridin içinde görünür.
4. **Sonuç:** Tarama bitince şeritte "3 fazla kopya · 3,3 MB" sonucu ve tek dokunuşla ilgili görünüm açılır.
5. **Seçim:** **Fazla Kopyaları Seç** bulgunun hemen altında. Fotoğrafa dokunmak seçer, basılı tutmak büyütür. Alt çubuk seçimi, boyutu ve geri almayı gösterir.
6. **İnceleme:** Seçilen öğeler küçük resimlerle en üstte; tek tek çıkarılabilir. Kurtarma bilgisi kısa bir satır, ayrıntı açılır bölümde. **N Öğeyi Kaldır**.
7. **Sonuç:** "Temizlik tamamlandı" ekranında ne yapıldığı ve nasıl geri alınacağı; Geçmiş'e bağlantı.

Hedef: sonuç kartından kaldırma onayına 5 dokunuş (sonuç → Fazla Kopyaları Seç → İncele → Kaldır → sistem onayı).

## 5. İş paketleri

Büyüklükler: **S** birkaç saat, **M** bir gün, **L** birkaç gün.

### Paket L — Buton ve metin bütçesi (P0, M)

**Kural:** Sade tasarım, Hick yasası, bilişsel yük. Her ek buton ve cümle, diğerlerinin fark edilmesini zorlaştırır.

**Bütçe (iPhone, fotoğraf ızgarası dışında, gezinme ve tab bar hariç):**
- Ana ekranda en fazla 1 birincil buton ve en fazla 6 ikincil kontrol.
- Bir sayfada (sheet) 1 birincil buton, en fazla 3 ikincil buton.
- Yardımcı metin bölüm başına en fazla 1 cümle ve en fazla 12 kelime. Daha uzun açıklamalar **Ayrıntılar** altına gider.
- Aynı bilgi aynı ekranda iki kez yazılmaz.
- Tek seçenekli menü yapılmaz; o seçenek doğrudan veya basılı tutma menüsünde yer alır.
- Bir buton yalnızca bir şeyi değiştirebildiğinde görünür (ör. zaten saklanan fotoğrafta **Bunu Sakla** yok).

**Bu turda yapılanlar:**
- **Bu Listeyi Seç** yalnızca filtreli veya daraltılmış listede görünür; tüm arşivde tek dokunuşla toplu seçim yok.
- Her zaman açık duran **Kaynak erişimi** bölümü kaldırıldı; kaynaklarda sorun varsa tek satır uyarı ve **Kaynak Erişimini Yönet** butonu çıkar.
- iCloud orijinalleri için **Tarama Seçenekleri** menüsü yalnızca atlanan öğe varsa görünür (Mac ile aynı).
- **Bunu Sakla** önerilen veya seçilen saklanacak fotoğrafta gösterilmez.
- Tek seçenekli **Grup İşlemleri** menüsü kaldırıldı; **Grubu Koru** fotoğrafın basılı tutma menüsüne taşındı.
- Tarama sırasında her dosyanın adını yazan satır kaldırıldı (VoiceOver'da ilerleme değeri olarak duyulur).
- Kaynaklar sayfasındaki 4 açıklama paragrafı **Ayrıntılar** altına toplandı.
- Son incelemede tekrarlayan "Seçilen Öğeler" etiketi ve "Kaldırmadan önce gözden geçirin" cümlesi kaldırıldı; seçilen öğeler listesi kaynak ve kurtarma ayrıntılarının üstüne alındı; kaynak başına üç satır tek satıra indi.
- Öneriler'de tarama butonu yukarı alındı; tarama bittiyse **Yeniden Tara** ikincil stilde.
- İnceleme satırlarındaki küçük resimlerde gereksiz **Yeniden Dene** butonu kaldırıldı.

**Kalan:** Paket A ile galeri üst bölümünün tek satırlık duruma inmesi; Ayarlar ekranının (35 metin) sadeleştirilmesi.

**Kabul:** `testScreenDensityInventory` her ekranda bütçeyi aşmaz; aşarsa test başarısız olur (bütçe kontrolü Paket A ile teste eklenir).

### Paket M — Dil ve terim sözlüğü (P0, M)

**Kural:** Gerçek dünya dili, tutarlılık, bir kavram bir kelime.

**Ton:**
- Türkçe: kullanıcıya her yerde **siz** diye hitap edilir ("Seçin", "izin verdiğiniz"). Buton etiketleri kısa ve fiille biter ("Arşive Geç", "3 Öğeyi Kaldır").
- Fransızca: **vous** (tutarlı).
- Almanca: şu an karışık (~45 "du", ~70 "Sie"). Apple'ın güncel Almanca arayüzü "du" kullanır; tek forma geçiş anadili Almanca olan biri tarafından gözden geçirilerek ayrı turda yapılır.
- Teknik terim (SHA-256, hash, manifest, StoreKit, karantina) kullanıcı metninde geçmez; gerekiyorsa yalnızca destek ve App Review belgelerinde.

**Terim sözlüğü (Türkçe):**

| Kavram | Kullanılacak | Kullanılmayacak |
|---|---|---|
| Uygulamadaki tüm fotoğraf ve videolar (Library) | Arşiv | Kitaplık, Kütüphane, Galeri |
| Apple'ın Fotoğraflar uygulaması / kaynağı | Fotoğraflar | Apple Photos, Galeri |
| Fotoğraf veya video | öğe (sayılarda), fotoğraf (tek fotoğraf için) | varlık, medya dosyası |
| Exact copy | birebir kopya | tam kopya, aynı dosya |
| Keeper | saklanacak fotoğraf / Saklama önerisi | ana kopya, koruyucu |
| Kaldırılan klasör dosyalarının yeri | Kurtarma Klasörü | karantina, Recovery Bin, güvenli kutu |
| Orijinal dosya (iCloud) | orijinal | özgün, asıl |
| Removal | kaldırma | silme (Son Silinenler adı hariç) |

**Bu turda yapılanlar:**
- Sekme ve başlık "Fotoğraflar" yerine **Arşiv** (Almanca **Mediathek**); artık "Fotoğraflar" kaynağıyla aynı adı taşımıyor.
- 32 Türkçe metin düzeltildi: "sen" hitabı "siz"e çevrildi, "kitaplığınızda" → "arşivinizde", "özgün" → "orijinal".
- Kodda kullanılıp çeviri dosyasında olmayan 12 metin eklendi (Türkçe ekranda İngilizce kalan "Safety & Recovery", "Retry Loading Product", "How Keptora Works" ve satın alma mesajları).
- Kullanıcıya gösterilen "StoreKit product unavailable…" mesajı "Keptora Pro şu anda kullanılamıyor. İnternet bağlantınızı kontrol edip tekrar deneyin." oldu.
- "Medya boyutu; boşalan alan değildir" → "Yer hemen boşalmaz"; "SHA-256 ile bayt düzeyinde kanıt" → "Birebir kopyalar bayt bayt doğrulanır"; "Bir kategori aç; fotoğrafları ortak galeriden seç." → "Bir kategori açın ve fotoğrafları seçin."

**Kalan:** Almanca hitap birliği; tüm metinlerin sözlüğe göre tek tek gözden geçirilmesi (özellikle Mac ve hata mesajları); kodda kullanılmayan ~800 eski anahtarın temizliği (Paket K).

**Kabul:** Türkçe metinlerde "sen" hitabı, "kitaplık" ve "özgün" kalmaz; kodda kullanılan her metnin dört dilde çevirisi vardır (bir doğrulama betiği CI'a eklenir).

### Paket A — İlk bakışta fotoğraflar (P0, L)

**Kural:** Sade tasarım, Fitts, Hick, görsel hiyerarşi.

- Galeri üst bölümünü tek bir durum şeridine indir: kaynak adı ve sayısı, tarama durumu ve ilerleme, sonuç özeti. Kaynaklar ve Kaynak Erişimi bu şeride dokununca açılan bir sayfaya taşınır.
- Dört bulgu butonunu 2×2 ızgara yerine tek satır, yatay kaydırılan çipe çevir. Medya türü filtresini (Tümü/Fotoğraf/Video) ve Filtreler menüsünü aynı satırın sonuna al.
- **Taramayı Başlat / Tekrar Tara / Duraklat** durum şeridinin sağ tarafında küçük bir butona dönüşür; ilk kullanımda otomatik tarama zaten başlatır.
- "Fotoğrafa dokunarak seç" ipucu yalnızca ilk iki oturumda gösterilir (Paket I ile TipKit'e taşınır).
- Mac'te aynı ilke: araç çubuğu tek satır, bulgu seçici segmentli kontrol.

**Kabul:** iPhone 16 Pro'da, açılışta en az 2 tam satır fotoğraf görünür (ilk hücre `minY` ≤ 420 pt). AX5 boyutunda şerit dikey düzene geçer ve hiçbir metin kesilmez. Mevcut bütün UI testleri yeni kimliklerle geçer.

**Durum (14 Ekim):** Yapıldı. Üst bölüm tek bir durum kartına indi (kaynak ve öğe sayısı, sağda küçük tarama butonu, altında ilerleme veya "Fazla kopya: 3 · 3,3 MB" sonucu). Dört bulgu butonu, sayılarıyla tek satırlık yatay çiplere dönüştü (sayı yalnızca 0'dan büyükse görünür; VoiceOver tam adı okur). "Tüm Arşivi Göster" butonu kaldırıldı (aynı iş filtre çipinde). Seçili bulgu artık bir de filtre çipi olarak tekrar gösterilmiyor; "Bu Listeyi Seç" bulgu görünümlerinde gizli, çünkü orada saklanması önerilen fotoğrafları da seçerdi. Ölçüm: ilk fotoğraf ~720 pt yerine ~450 pt'de başlıyor; `testFirstScreenShowsPhotos` ilk fotoğrafın ekranın üst %55'inde başladığını doğruluyor. Hedeflenen 420 pt için medya filtresinin de bu satıra alınması gerekir; ileride değerlendirilecek.

### Paket B — Toplu seçimde hata önleme (P0, S)

**Kural:** Hata önleme, kullanıcı kontrolü.

- **Bu Listeyi Seç** ana alandan Filtreler menüsüne veya bölüm başlığına taşınır.
- Toplu seçim 50 öğeyi aşarsa sonuç kısa bir bildirimle gösterilir: "1.240 öğe seçildi · Geri Al".
- Gün ve Ay bölüm başlıklarındaki **Günü Seç / Ayı Seç** butonları ikincil stile geçer.

**Kabul:** Galeride ilk ekranda büyük bir toplu seçim butonu yoktur. 50'den fazla öğe seçildiğinde geri alma bildirimi görünür ve çalışır (UI testi).

### Paket C — Kontrast ve renk (P0, M)

**Kural:** WCAG 1.4.3, 1.4.11, 1.4.1.

- `accent` rengini açık ve karanlık mod için iki değerli dinamik renk yap. Karanlık modda koyu yüzeylerde 4.5:1 sağlayan daha açık bir mor seç (asset catalog'da `AccentColor` ile birlikte).
- Seçili çip metni için zemin opaklığını artır veya metni `label` rengi yap; seçili durum ayrıca onay ikonu ile gösterilsin (sadece renk olmasın).
- Uyarı metinlerinde turuncu/amber metin yerine birincil metin rengi + turuncu ikon kullan.
- Renk çiftlerinin kontrastını hesaplayan küçük bir birim testi ekle (açık ve karanlık mod).

**Kabul:** Renk testi bütün çiftlerde eşikleri geçer; Accessibility Inspector denetiminde kontrast uyarısı yoktur.

**Durum (13 Ekim):** Yapıldı (PR #22). Metin renkleri açık/karanlık için ayrı değerler aldı; beyaz yazılı butonlar sabit `accentFill` ve `dangerFill` kullanıyor; turuncu ve kırmızı sistem metin renkleri kaldırıldı. `ColorContrastTests` iki modda da 4.5:1 eşiğini doğruluyor.

### Paket D — Dynamic Type ve yazı (P1, S)

**Kural:** Erişilebilirlik, tipografi.

- 11 sabit `font(.system(size:))` kullanımını metin stillerine (`.caption`, `.headline` vb.) veya `@ScaledMetric`'e çevir.
- Dosya adlarında ortadan kesme (`truncationMode(.middle)`), sayaçlarda `monospacedDigit`.

**Kabul:** AX5 ve en küçük boyutta ekran görüntüleri incelenir; kesilme ve üst üste binme yoktur.

**Durum (13 Ekim):** Yapıldı. `testLargestTextSizeScreens` Türkçe AX5 ekran görüntüleri alır. Bulunan ve düzeltilenler: "Kaynaklar" satırı kelime ortasından bölünüyordu (AX boyutunda dikey düzen); seçim çubuğu ekranı kaplıyor ve buton metinleri kesiliyordu (AX boyutunda "Geri Al", "Temizle", "1 seçili" ve ayrıntı satırları gizli); Öneriler'de uzun başlık ve kategori adları bölünüyordu (tekrarlayan başlık kaldırıldı, AX boyutunda ikon gizli). Metnin yanındaki ikonlar metin stiliyle büyüyor; inceleme listesinde dosya adları ortadan kısaltılıyor. Sabit kutulardaki dekoratif ikonlar bilinçli olarak sabit bırakıldı.

### Paket E — Galeri performansı (P1, M)

**Kural:** Doherty eşiği, geri bildirim.

- `visible` listesini her `body` değerlendirmesinde yeniden hesaplamak yerine filtre, sıralama ve kaynak değiştiğinde güncellenen bir önbellekte tut (store'da veya küçük bir view model'de).
- Tarama ilerleme güncellemelerini galerinin geri kalanını yeniden çizmeyecek şekilde ayrı bir gözlemlenebilir nesneye taşı.
- `-keptoraThousandsStressUITesting` ile 10.000 ve 50.000 öğede Instruments ölçümü yap ve sonuçları bu belgeye ekle.

**Kabul:** 50.000 öğede kaydırmada takılma (hang) yok; seçim değişimi 100 ms altında; tarama sırasında galeri akıcı.

**Durum (14 Ekim):** İlk adım yapıldı. `GalleryPerformanceTests`, 50.000 öğede görünen listenin (kapsam, filtre, sıralama, gruplama) bir kez hesaplanmasını ölçüyor: simulator'de ~28 ms. Bu liste bir ekran güncellemesinde 6–8 kez hesaplanıyordu (her dokunuşta ~0,2–0,6 sn); artık güncelleme başına bir kez hesaplanıyor. UI testleriyle yapılan süre ölçümü XCTest'in kendi yükünü (~1,5 sn) ölçtüğü için kullanılmadı. Kalan: gerçek cihazda 10.000+ fotoğrafla Instruments kaydı ve tarama ilerlemesinin galeriyi yeniden çizmemesi.

### Paket F — Daha kısa ilk kullanım (P1, M)

**Kural:** İlk değer süresi, progressive disclosure.

- Üç tanıtım sayfasını tek karşılama ekranına indir; diğer içerik Ayarlar ▸ Keptora Nasıl Çalışır altında kalsın.
- Kaynak kurulum ekranında yalnızca Photos ve klasör seçimi; uzun açıklamalar açılır bölüme.
- Photos izni verildiyse kurulum ekranı kendiliğinden kapanıp galeriye geçebilir.

**Kabul:** Yeni kurulumda izin onayına kadar en fazla 2 ekran; `testFreshInstallWalkthrough` güncellenir ve geçer.

**Durum (13 Ekim):** Yapıldı. İlk açılışta tek karşılama ekranı (başlık, üç kısa satır, **Başla**); üç sayfalık tanıtım Ayarlar ▸ Keptora Nasıl Çalışır altında kaldı. Yeni kurulumda izin penceresine kadar 2 ekran; izin sonrası Arşiv tarama sonucuyla açılıyor. Kurulum ekranının izin sonrası kendiliğinden kapanması bilinçli olarak yapılmadı: kullanıcı klasör de eklemek isteyebilir.

### Paket G — Son inceleme ekranı (P1, S)

**Kural:** Yıkıcı eylemden önce tam liste, sade tasarım.

- Seçili öğeleri en üste, küçük resim ızgarası olarak koy; her birinde çıkarma düğmesi.
- Özet tek satır: "3 fotoğraf · 3,3 MB · Son Silinenler'e gider".
- Kaynak bazında kaldırma ve kurtarma ayrıntıları açılır bölüme.
- Kaldır butonu pasifken neden pasif olduğu butonun hemen üstünde yazmaya devam eder.

**Kabul:** Sheet açıldığında ilk görünür alanda en az bir seçili öğe görünür; mevcut inceleme testleri ek kaydırma olmadan geçer.

### Paket H — Mac'te eşitlik (P1, M)

**Kural:** Tutarlılık, platform kuralları.

- Kaynak kurulumu tamamlanınca ilk taramayı otomatik başlat.
- Tarama bitince sonuç özetini ve tek tıklamayla bulgu görünümünü göster (iPhone'daki sonuç kartının Mac karşılığı).
- Seçili fotoğrafta Space ile Quick Look tarzı önizleme; çift tıklama önizleme açsın.
- Menüye "Fazla Kopyaları Seç" ve "Seçimi İncele" komutları ve kısayolları eklensin.

**Kabul:** Mac UI testleri otomatik taramayı, sonuç özetini ve Space önizlemesini doğrular.

**Durum (14 Ekim):** Kısmen yapıldı. Kurulum bitince ilk tarama kendiliğinden başlıyor (`testFirstScanStartsAfterSetupOnlyWhenThereAreNoResults`); tarama bitince "Fazla kopya: 3 · 3,3 MB" bağlantısı kopyalara götürüyor; "Bu Listeyi Seç" yalnızca daraltılmış listede; seçili bulgu tekrar çip olarak gösterilmiyor; "Tarama Seçenekleri" yalnızca atlanan iCloud öğesi varsa görünüyor; kurulum sayfası açıklamaları "Ayrıntılar" altında; seçim boşken sıfır sayılar ve boyut yazılmıyor. **Space önizlemesi yapılmadı:** Mac'te Space bugün seçimi değiştiriyor ve ipucu metninde de böyle anlatılıyor; önizlemeye vermek kullanıcı alışkanlığını bozar. Önizleme sağ tık menüsünde kalıyor; ⌘Y kısayolu ayrı karar olarak bırakıldı.

### Paket I — Bağlam içi yardım (P2, S)

**Kural:** Yardım ve dokümantasyon, progressive disclosure.

- TipKit ile üç ipucu: ilk seçimde "Basılı tutarak büyüt", ilk grupta "Bunu Sakla", ilk geri alınabilir işlemde "Geri Al". Her ipucu bir kez gösterilir ve kapatılabilir.
- Öneriler sekmesinde tarama butonunu başlığın altına taşı (tab bar arkasında kalmasın).

**Kabul:** İpuçları ilk kullanımda görünür, kapatılınca bir daha çıkmaz; UI testlerinde ipuçları kapalı başlatılır.

**Durum (14 Ekim):** Yapıldı (yalnızca iPhone; TipKit macOS 14 ister, Mac uygulaması macOS 13'ü de destekliyor). Arşiv'deki kalıcı "Seçmek için dokunun, büyütmek için basılı tutun" satırı kapatılabilir bir ipucuna dönüştü. İlk seçimden sonra bu ipucu kalkıyor ve **Geri Al** butonunda balon ipucu çıkıyor; ekranda aynı anda tek ipucu oluyor. Planlanan üçüncü ipucu ("Bunu Sakla") ilk denemede iki ipucuyla fotoğrafları yine aşağı ittiği için çıkarıldı; buton ve "Saklama önerisi" rozeti zaten kendini anlatıyor. `testFirstUseTipsAppearOneAtATime` sırayı ve kalıcılığı doğruluyor; diğer UI testleri `-keptoraHideTips` ile ipuçsuz koşuyor.

### Paket J — Hata metinleri ve hareket (P2, S)

**Kural:** Hata mesajları, Reduce Motion.

- "Something went wrong" yerine soruna özel başlıklar: "Kütüphane yüklenemedi", "Kaldırma tamamlanamadı", "Dosyalar geri yüklenemedi". Her hatada bir aksiyon butonu (Tekrar Dene, Ayarlar'ı Aç, Kaynakları Aç).
- Bütün animasyonları Reduce Motion açıkken kapatan ortak bir yardımcıdan geçir.

**Kabul:** Hata metinleri dört dilde; Reduce Motion açıkken kayma animasyonu yoktur (el ile kontrol).

**Durum (14 Ekim):** Yapıldı. Hata uyarılarında genel başlık yerine mesajın ilk cümlesi başlık, kalanı açıklama oluyor (`AlertText.split`, iPhone ve Mac'te 6 uyarı, 4 birim testi). Mesajlar zaten dört dilde olduğundan başlık da dört dilde. iPhone ve Mac'teki bütün animasyonların Reduce Motion'a uyduğu doğrulandı; değişiklik gerekmedi. Ek olarak iPhone Ayarlar'da "Güvenlik ve Kurtarma" bölümü kaldırıldı (Keptora Nasıl Çalışır ile aynı bilgiyi tekrarlıyordu; Geçmiş zaten sekme), uzun iCloud cümlesi "iCloud orijinalleri: Yalnızca izin verirseniz" satırına indi.

### Paket K — Yerelleştirme kalitesi (P2, S)

**Kural:** Yerelleştirme, tutarlılık.

- Almanca ve Fransızca için galeri, inceleme ve ayarlar ekran görüntüsü testleri (Türkçe AX testine benzer).
- Kullanılmayan yaklaşık 800 çeviri anahtarının temizlenmesi (Xcode'da derleme sonrası `stale` işaretlenenler üzerinden).

**Kabul:** Dört dilde ekran görüntülerinde kesilme yok; `Localizable.xcstrings` içinde `stale` anahtar kalmaz.

**Durum (14 Ekim):** Yapıldı. Xcode'un derlemede çıkardığı metin listesi (`.stringsdata`) ile kaynak koddaki metinler birleştirilerek 1373 anahtardan kullanılmayan 929'u silindi (444 kaldı; dosya 856 KB → 306 KB). Ölçüm sırasında bulunanlar da düzeltildi: Mac ve iPhone paywall'ı kaldırılmış özellikleri ("Cleanup Plans", "Safety Plans") vaat ediyordu, artık Pro'nun gerçekten açtığı şeyi yazıyor ("Önerileri 100 öğe sınırı olmadan toplu seçin"); "1 Elemente entfernen", "Retirer 1 éléments", "Remove 1 Items" gibi tekil/çoğul hataları `L10n.plural` ve katalogdaki çoğul varyantlarıyla düzeldi (dört dilde birim testi); `testGermanAndFrenchScreens` ekran görüntülerinde kesilen Fransızca arama metni kısaltıldı ve "Saklama önerisi" rozetine iki satır verildi; iki indirme hatasının çevirisi eklendi. Ortak paketteki akıllı kategori, büyük video ve gizli belge motorları arayüzde kullanılmıyor; metinleri görünmediği için çevrilmedi, kodun silinmesi ayrı karar.

## 6. Sıra ve bağımlılıklar

1. **Dalga 1 (P0):** L, M, C, A ve B'nin ilk kısmı tamamlandı (PR #21–#25). Kalan: Almanca hitap birliği, Ayarlar ekranının sadeleştirilmesi.
2. **Dalga 2 (P1):** E (performans; A'dan sonra, yeni düzen üzerinde ölçülür) → G (inceleme) → F (ilk kullanım) → D (Dynamic Type) → H (Mac).
3. **Dalga 3 (P2):** I, J, K.
4. Her dalganın sonunda: bütün iPhone ve Mac testleri, walkthrough ekran görüntüleri, bu belgenin bölüm 3 tablosunun güncellenmesi.

## 7. Test ve doğrulama

**Otomatik (her PR'da CI):**
- Mevcut iPhone (47; walkthrough yalnızca yeni kurulumda çalışır) ve Mac (36) testleri.
- Yeni: ilk ekranda fotoğraf görünürlüğü, toplu seçim geri alma bildirimi, renk kontrast testi, Almanca/Fransızca ekran görüntüleri, Mac otomatik tarama ve önizleme.
- `testFreshInstallWalkthrough`: uygulama silinip çalıştırılır; süre ve dokunuş sayısı kaydedilir.

**Cihazda el ile (her dalga sonunda):**
- VoiceOver ile baştan sona: tarama, seçim, kaldırma, geri yükleme.
- Dynamic Type AX5, karanlık mod, Increase Contrast, Reduce Motion, Bold Text.
- Gerçek bir 10.000+ fotoğraflık kütüphane; Instruments kaydı.

**Kullanılabilirlik testi (Dalga 2 sonunda):**
- 5 katılımcı: 2 Türkçe, 1 Almanca veya Fransızca konuşan, 1 büyük yazı kullanan, 1 Mac kullanıcısı.
- Görevler: "Kopya fotoğrafları bul ve kaldır", "Yanlışlıkla seçtiğin bir fotoğrafı seçimden çıkar", "Bir klasörden kaldırdığın dosyayı geri getir", "Uygulama dilini değiştir".
- Ölçüm: görev başarısı, süre, hata sayısı, SUS. Gözlemler sesli düşünme yöntemiyle not edilir.
- Sonuçlar bu belgeye eklenir; SUS 80'in altındaysa ilgili akış yeniden ele alınır.

## 8. Kapsam dışı

- Karşılaştırma ekranı, swipe ile karar verme, büyüteç butonu (kullanıcı kararı).
- Hesap, bulut eşitleme, analitik.
- Otomatik kaldırma: hiçbir öneri kullanıcı onayı olmadan kaldırılmaz.

## 9. Riskler

- **Galeri üst bölümünün yeniden düzenlenmesi** birçok UI testinin öğe kimliklerini etkiler. Kimlikler korunur; değişen yerleşim için testler aynı PR'da güncellenir.
- **Vurgu renginin değişmesi** ekran görüntülerini ve App Store görsellerini etkiler. Yeni renkle ekran görüntüleri Dalga 1 sonunda yeniden alınır.
- **Tanıtımın kısalması** ilk kullanımda güven mesajını zayıflatabilir. Gizlilik cümlesi karşılama ekranında ve izin ekranında kalır.

## 10. Yayın öncesi kalan engeller (13 Ekim kontrolü)

Kodda ve repoda düzeltilebilenler düzeltildi. Aşağıdakiler bu repodan yapılamaz veya kullanıcı kararı gerektirir:

1. **Yayındaki web sayfaları eski.** `alfagolab.com/keptora/privacy` ve `/support` uygulamayı hâlâ yalnızca Mac için "Keptora: Duplicate Cleaner" olarak, karantina akışıyla anlatıyor; iPhone hiç geçmiyor. Güncel metinler [AppStore/PRIVACY_POLICY.md](../../AppStore/PRIVACY_POLICY.md) ve [AppStore/SUPPORT_PAGE.md](../../AppStore/SUPPORT_PAGE.md) içinde. Website reposu harici `DATA` diskinde; disk takılıyken güncellenip yayınlanmalı ([site eşleme notu](../../ALFAGOLAB_SITE_SYNC.md)).
2. **Gerçek App Store ekran görüntüleri yok.** `AppStore/Generated/Screenshots` içindeki 12 görsel tasarım önizlemesi ve kaldırılmış özellikleri (karşılaştırma ekranı, Safety Plan) gösteriyor; gönderilmemeli. Gereken: 6.9" iPhone ve Mac için, gerçek fotoğraflarla, dört dilde native ekran görüntüleri.
3. **Yasal alanlar:** gizlilik politikasında yürürlük tarihi, geliştiricinin yasal adı ve gerekiyorsa posta adresi.
4. **Almanca hitap birliği** (Paket M): anadili Almanca olan biri tarafından gözden geçirilmeli.
5. **Cihazda kontrol:** VoiceOver ile baştan sona, StoreKit sandbox satın alma ve geri yükleme, 10.000+ fotoğraflık gerçek kütüphanede akıcılık.
