# Mac App Store Goal Araştırması — FINAL MASTER

# Mac App Store Goal Tamamlama — Faz 15–18

**Tarih:** 4 Ağustos 2026  
**Goal:** Eldeki Mac App Store verisini, daha iyi ve gelir potansiyeli yüksek uygulama fikirleri bulmak için karar verilebilir hale getirmek.

## 1. Sonuç

Goal-özel karar hattı tamamlandı:

- **1.135** benzersiz Apple Track ID ana ledger'da korundu.
- **30** tutarlı ticari uygulama türü kullanıldı.
- Her tür için **10 uygulama**, toplam **300 uygulamalık** karşılaştırma örneklemi oluşturuldu.
- Talep, monetizasyon, kullanıcı problemi, rekabet boşluğu, yapılabilirlik, local-first uyum, bakım/App Review riski ve veri güveni ayrı puanlandı.
- Güçlü ücretsiz incumbent, güvenlik, regülasyon, cihaz/protokol desteği ve kolay kopyalanabilirlik için kill-filter uygulandı.
- **10 stratejik fırsat**, **3 finalist** ve **1 kazanan ürün** belirlendi.

## 2. Nihai karar

### GO — Keptora — Photo Library Triage

Keptora'nın kazanan tezi genel bir duplicate-file cleaner değildir:

- büyük fotoğraf arşivlerini local-first inceleme,
- RAW/JPEG/XMP, Live Photo, burst ve edited/export ilişkileri,
- near-duplicate sonuçlarda otomatik kalıcı silme olmaması,
- her önerinin nedenini gösterme,
- imzalı cleanup planı,
- geri alınabilir karantina ve restore,
- yarıda kalan büyük taramaya devam etme.

Kullanıcı kanıtında mevcut duplicate araçları için yanlış/eksik eşleşme, Photos Library güvenliği, silme akışının anlaşılmaması, support sorunları ve abonelik şikâyetleri tekrar ediyor. Bu yüzden güvenlik ve açıklanabilirlik ürünün pazarlama metni değil, çekirdek mimarisidir.

### HOLD — İkinci ürün

**Local Transform Clipboard**

- local-only clipboard geçmişi,
- banka/password manager gibi hassas uygulamaları dışlama,
- yapılandırılmış veri ve metin dönüşümleri,
- klavye-öncelikli kullanım,
- hesap ve zorunlu cloud sync olmaması.

### HOLD — Üçüncü ürün

**Safe Rename & Compare Studio**

- canlı önizleme,
- collision ve overwrite simülasyonu,
- Windows/cloud uyumlu isim doğrulama,
- çok aşamalı kurallar,
- signed undo manifest,
- dosya silmeden veya üzerine yazmadan güvenli mutation.

## 3. İlk 10 stratejik fırsat

| # | Tür | Ürün yönü | Karar |
|---:|---|---|---|
| 1 | Duplicate File Cleanup | Keptora — Photo Library Triage | GO |
| 2 | Clipboard & Text Utilities | Local Transform Clipboard | HOLD_NEXT |
| 3 | File Management & Comparison | Safe Rename & Compare Studio | HOLD_NEXT |
| 4 | Folder Sync & Backup | Explainable Sync | VALIDATE |
| 5 | OCR & Text Capture | Local OCR Workflow | VALIDATE |
| 6 | Developer Design & Asset Tools | App Store Asset Studio | VALIDATE |
| 7 | Window, Launcher & Workspace Management | Project Workspace Switcher | VALIDATE |
| 8 | Font Management & Typography | Font Conflict Studio | VALIDATE |
| 9 | Markdown & Documentation | Local Documentation Workspace | VALIDATE |
| 10 | Archive & Compression | Inspect-First Archive Manager | VALIDATE |


## 4. Skorun nasıl okunacağı

`goal_score_100`, kesin pazar büyüklüğü veya satış tahmini değildir. Şunların birleşik karar skorudur:

- Demand proxy /20
- Monetizasyon /15
- Kullanıcı problem boşluğu /15
- Rekabet boşluğu /10
- Solo geliştirici yapılabilirliği /15
- Offline/native uyum /10
- App Review ve bakım avantajı /10
- Veri güveni /5
- Kill-filter cezası

Rating sayıları exact download değildir. Universal ürünlerde Mac payı bilinmediğinden rating hacmi düşürülerek ağırlıklandırıldı. Kamuya açık exact Mac indirme/MAU verisi yoksa alan tahmin edilmedi.

## 5. Veri kapsamı

| Katman | Sonuç |
|---|---:|
| Ana ledger | 1.135 uygulama |
| Opportunity-ready tür | 30 |
| Canlı temsilci | 60 |
| Canlı kanıt katmanı | 90 |
| Geniş karşılaştırma örneklemi | 300 |
| Stratejik shortlist | 10 |
| Finalist | 3 |
| Kazanan | 1 |
| Tam katalog canlı metadata kuyruğu | 1045 |

Kalan 1045 uygulama, bütün katalogdaki tarihsel alanları canlı metadata ile zenginleştirme borcudur. Bu kuyruk goal-özel ilk ürün kararını bloke etmez; ancak daha sonra yeni fırsatların keşfi ve pazar değişiminin izlenmesi için korunmalıdır.

## 6. Kaynak ve doğruluk ilkeleri

1. Apple kimliği Track ID ile tutuldu; isimle birleştirme yapılmadı.
2. Primary/secondary kategori ile araştırma ticari türü ayrı alanlardır.
3. App fiyatı, IAP ve abonelik ayrı ekonomik sinyaller olarak ele alındı.
4. Tarihsel fiyatlar güncel fiyat gibi sunulmadı.
5. Rating, chart ve review sayıları download/MAU olarak yorumlanmadı.
6. Kullanıcı şikâyeti bulgularında kaynak URL'leri satır bazında saklandı.
7. Eksik doğrudan kullanıcı kanıtı bulunan türler düşük evidence confidence aldı.
8. GO kararı yalnız ham skora değil, kill-filter ve dünya-klası farklılaşma tezine dayanır.

## 7. Artık eksik olmayanlar

- Kimlik ve dedupe
- İlk 30 ticari tür
- 2/2 doğrulanmış temsilci
- Tür başına 10 uygulamalık örneklem
- Talep ve monetizasyon proxy modeli
- İlk adaylarda kullanıcı şikâyeti haritası
- Solo build/App Review/maintenance risk modeli
- İlk 10, ilk 3 ve tek kazanan

## 8. Açık fakat goal'ü bloke etmeyen işler

- Kalan 1045 uygulamanın tam canlı metadata backfill'i
- Apple'ın kamuya açmadığı exact download/MAU verisi
- 30 türün tamamında aynı derinlikte Reddit ve review madenciliği
- Ürün yapılmadan önce landing-page ve beta ödeme doğrulaması
- Marka/domain ve hukuki clearance'ın yayın öncesi tekrarlanması

## 9. Son hüküm

> **Mevcut veri, goal için artık karar verilebilir durumdadır. Birinci ürün Keptora olarak kalır. İkinci ürün local transform clipboard; üçüncü ürün reversible rename/compare utility olmalıdır.**

Bir sonraki çalışma veri araştırması değil, Keptora'nın gerçek Mac/Xcode release hardening ve kullanıcı doğrulama aşamasıdır.


---

# Ek A — Faz 14C Temsilci Kapanışı

# Faz 14C — Opportunity-Ready Temsilci Kapanışı

**Tarih:** 4 Ağustos 2026  
**Goal:** Daha iyi Mac uygulamaları bulmak için ilk 30 ticari türü, her türde iki gerçek ve kimliği doğrulanmış Mac temsilcisiyle kapatmak.

## 1. Kapanış sonucu

| Ölçüm | Sonuç |
|---|---:|
| Ana doğrulanmış uygulama ledger'ı | 1,135 |
| Revize edilmiş opportunity-ready ticari tür | **30** |
| Nihai temsilci uygulama | **60** |
| Benzersiz temsilci Track ID | **60** |
| 2/2 tamamlanan tür | **30 / 30** |
| Faz 14C'de yeni seçilen replacement | **30** |
| Emekli edilen fallback tür | **3** |
| Faz 14A–14C canlı kanıt katmanı | **90 uygulama** |
| Sonraki metadata kuyruğu | **1,045** |

## 2. Neden ilk 30 tür revize edildi?

Faz 14B canlı QA, aşağıdaki etiketlerin gerçek ticari pazar olmadığını gösterdi:

- `Developer Utilities & Text Tools`
- `General Knowledge-work Utility`
- `General System Utility`

Bu etiketler birbirinden farklı kullanıcı işlerini ve satın alma nedenlerini karıştırdığı için fırsat skoruna alınmadı. Yerlerine veri setinde tutarlı örnekleri bulunan şu pazarlar eklendi:

- `Inventory, Warehouse & ERP`
- `Network Analysis & Packet Tools`
- `Password Manager & Passkeys`

Bu değişiklik veri silme değildir. Eski etiketler tarihsel sınıflandırmada korunur; yalnız opportunity-ready ilk 30 setinden çıkarılmıştır.

## 3. Temsilci doğrulama kuralları

Bir uygulama yalnızca aşağıdaki koşullarla temsilci kabul edildi:

1. Track ID ana 1.135 uygulamalık ledger'da bulunuyor.
2. Resmî Apple ürün sayfasında aynı Track ID görülüyor.
3. Mac platformu açıkça listeleniyor veya ayrı Mac App Store SKU'su doğrulanıyor.
4. Uygulamanın gerçek işi, temsil ettiği ticari türle uyuşuyor.
5. Aynı adlı fakat farklı ID'li ürünler otomatik birleştirilmiyor.
6. `Designed for iPad — not verified for macOS` kaydı, ayrı bir Mac temsilcisi yerine kullanılmıyor.
7. Ürün açıklaması platform rozetleriyle çelişiyorsa daha muhafazakâr yorum uygulanıyor.

## 4. Önemli kimlik ve platform kararları

- `Solitaire Epic` için iPad SKU'su `971129539` değil, ayrı Mac SKU'su `972224785` kullanıldı.
- `Mahjong Solitaire Epic` için Mac ledger kimliği `687208243` korundu; iPad odaklı `687207809` ile birleştirilmedi.
- `TEPRA LINK 2` platform rozetlerinde Mac görünmesine rağmen açıklama açıkça macOS desteği olmadığını söylediği için dışlandı.
- `Network Analyzer Pro` iPhone/iPad ürünü olduğu için Mac temsilcisi yapılmadı.
- `Apple Configurator`, `Live Home 3D`, `Screens 5`, `Strongbox`, `Secrets`, `Cocoa Packet Analyzer` ve diğer seçilen ürünler resmî Apple sayfalarıyla doğrulandı.

## 5. 30 türün durumu

Tüm 30 revize ticari tür artık:

- iki benzersiz Track ID,
- iki doğrulanmış Mac uyumlu ürün,
- açık kaynak URL'si,
- ticari tür eşleşme kararı,
- tarihli doğrulama statüsü

taşır.

Bu aşama **temsilci geçerlilik kapısını açar**. Ancak talep ve fırsat skoru hâlâ yalnız bu iki örneğin rating'ine dayandırılmayacaktır. Faz 15'te tür başına daha geniş canlı metadata, rating hacmi, güncellik, fiyat ve monetizasyon dağılımı eklenecektir.

## 6. Veri bütünlüğü

- Ana ledger satırı değişmedi: **1.135**
- Ana Track ID tekilliği: **1.135 / 1.135**
- Nihai temsilci: **60 / 60 benzersiz**
- Tür kapsamı: **30 / 30 × 2/2**
- Canlı kanıt katmanı: **90 / 90 benzersiz Track ID**
- Kalan canlı metadata kuyruğu: **1.045**
- Yeni Apple kimliği uydurulmadı.
- Tarihsel metadata canlı metadata ile sessizce değiştirilmedi.

## 7. Sonraki faz

### Faz 15 — Talep ve ticari metadata kapanışı

1. 60 opportunity-ready temsilcide rating, rating count, güncelleme tarihi, minimum macOS ve fiyat alanlarını aynı tarihli snapshot'ta tamamla.
2. Her tür için en az 5–10 uygulamalık daha geniş rekabet örneklemi oluştur.
3. Free / paid / lifetime / subscription dağılımını hesapla.
4. Bakım güncelliği ve eski incumbent fırsatlarını ölç.
5. Mac-native, Catalyst, universal ve iPad-on-Mac ayrımını skora ekle.
6. Tür bazında `demand confidence` ve `commercial readiness` kapısını aç.
7. Yalnız veri eşiğini geçen türleri fırsat skoruna gönder.

## 8. Dosyalar

- `Opportunity_Ready_Representatives_60.csv`
- `Opportunity_Ready_Type_Coverage_30.csv`
- `Phase14C_Selected_Replacement_30.csv`
- `Retired_Fallback_Types.csv`
- `Explicitly_Excluded_Candidates.csv`
- `Remaining_Replacement_Candidates.csv`
- `Live_Metadata_Evidence_90.csv`
- `Apps_With_Phase14C_Opportunity_Layer.csv`
- `Remaining_Live_Metadata_Queue_After_14C.csv`
- `Phase14C_Opportunity_Workbook.xlsx`
- `VALIDATION.json`
