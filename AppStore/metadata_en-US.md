# Keptora App Store Metadata Draft

**Snapshot date:** 4 August 2026  
**Status:** Content-complete draft; legal identity, URLs, identifiers, pricing tiers, and final screenshots remain release blockers.

## Shared app information

| Field | Draft |
|---|---|
| App name | `Keptora: Photo Triage` |
| Bundle display name | `Keptora` |
| Primary category | Photo & Video |
| Secondary category | Utilities — keep only if the shipping feature set justifies it |
| Download model | Free |
| In-App Purchase | One non-consumable lifetime unlock |
| Subscription | None |
| Family Sharing | Disabled for 1.0.0 |
| Expected age rating | 4+, subject to the current questionnaire |

The proposed name is 21 characters. Both localized subtitles are within the 30-character limit. Name, trademark, domain, and App Store reservation clearance are not complete.

## English (United States)

### Subtitle

`Clean safely. Keep memories.`

### Promotional text

Find exact photo and video copies, compare similar media, and reclaim space with explicit, protected cleanup on Mac and iPhone.

### Keywords

`duplicate,photo cleanup,similar photos,library,storage,organizer,offline,RAW,quarantine,restore`

### Description

Keptora helps you clean photo archives without trusting a black-box delete button.

**START WITH EXACT DUPLICATES**  
Scan a folder, external drive, or cloud folder mounted in Finder locally. Keptora groups files only after SHA-256 confirms byte-for-byte equality. It protects a keeper and explains why copies belong together.

**REVIEW SIMILAR MEDIA**
Compare similar photos without cleanup actions. Similar videos use duration, shape, and sampled frames; they are never auto-selected and require your explicit review before cleanup.

**REVIEW BEFORE ANY MOVE**  
Keptora builds a Safety Plan showing every proposed action, destination, and recoverability status. Approved copies move to a reversible quarantine on the same volume. Signed manifests and history make restoration auditable.

**UNDERSTAND PHOTO FAMILIES**  
RAW + JPEG, XMP sidecars, Live Photo components, bursts, and edited exports are treated as related assets instead of isolated files.

**PRIVATE BY DESIGN**  
No account. No ads. No analytics. No media upload. Your archive is processed on your supported Apple device.

**FREE TO START**  
Scan without a limit and review the first 100 unique recommendations. A one-time Keptora Pro purchase unlocks unlimited review and Safety Plans. No subscription.

Important: Keptora does not permanently delete files from Apple Photos. Similar-photo suggestions always require your review.

## Turkish

### Subtitle

`Güvenle temizle. Anıları koru`

### Promotional text

Birebir fotoğraf ve video kopyalarını bulun, benzer medyaları karşılaştırın ve Mac ile iPhone’da açık onaylı güvenli temizlik yapın.

### Keywords

`kopya,fotoğraf,temizleme,benzer,arşiv,depolama,düzenleme,çevrimdışı,karantina,geri yükleme`

### Description

Keptora, fotoğraf arşivinizi ne yaptığını açıklamayan tek tıklamalı bir silme aracına güvenmeden düzenlemenize yardımcı olur.

**ÖNCE TAM KOPYALAR**  
Bir klasörü veya harici diski tamamen yerel olarak tarayın. Keptora, dosyaları yalnızca SHA-256 ile birebir aynı oldukları doğrulandıktan sonra gruplar. Saklanacak ana kopyayı korur ve dosyaların neden aynı grupta olduğunu açıklar.

**BENZER MEDYALARI İNCELEYİN**
Benzer fotoğrafları temizleme eylemi olmadan karşılaştırın. Benzer videolar süre, görüntü oranı ve örnek karelerle önerilir; otomatik seçilmez ve temizlikten önce açıkça sizin incelemenizi gerektirir.

**HER HAREKETTEN ÖNCE İNCELEYİN**  
Keptora, önerilen her işlemi, hedef konumu ve geri alınabilirlik durumunu gösteren bir Güvenlik Planı oluşturur. Onaylanan kopyalar aynı disk üzerindeki geri alınabilir karantinaya taşınır. İmzalı manifestler ve geçmiş, geri yüklemeyi denetlenebilir kılar.

**FOTOĞRAF AİLELERİNİ ANLAYIN**  
RAW + JPEG, XMP sidecar dosyaları, Live Photo bileşenleri, burst çekimler ve düzenlenmiş dışa aktarımlar birbirinden kopuk dosyalar olarak değil, ilişkili varlıklar olarak ele alınır.

**GİZLİLİK ODAKLI**  
Hesap yok. Reklam yok. Analitik yok. Medya yükleme yok. Arşiviniz desteklenen Apple aygıtınızda işlenir.

**ÜCRETSİZ BAŞLAYIN**  
Sınırsız tarama yapın ve ilk 100 benzersiz öneriyi inceleyin. Tek seferlik Keptora Pro satın alımı sınırsız incelemeyi ve Güvenlik Planlarını açar. Abonelik yok.

Önemli: Keptora, Apple Photos içindeki dosyaları kalıcı olarak silmez. Benzer fotoğraf önerileri her zaman sizin incelemenizi gerektirir.

## Metadata entry checklist

- [ ] Reserve the final app name in App Store Connect.
- [ ] Complete trademark searches in the intended launch regions.
- [ ] Replace all placeholder URLs with public HTTPS pages.
- [ ] Confirm primary/secondary categories match the Xcode build and App Store Connect.
- [ ] Paste metadata from `app_store_metadata.json`, then run `Scripts/validate_app_store_metadata.py`.
- [ ] Re-check text after every localization edit; keywords are measured in UTF-8 bytes by the local validator.
- [ ] Do not add competitor trademarks, price claims, or unsupported feature promises.
