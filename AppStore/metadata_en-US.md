# Keptora App Store Metadata Draft

**Snapshot date:** 13 October 2026  
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

Find exact copies, similar shots, screenshots and large videos. Choose what goes, review it, and recover it if you change your mind. On iPhone and Mac.

### Keywords

`duplicate,photo cleaner,similar photos,storage,screenshots,large videos,blurry,live photos,restore`

### Description

Keptora helps you clear out your photo library without a risky one-tap delete. Every photo stays in view, you decide what goes, and you can review everything before it is removed.

**SEE EVERYTHING, CHOOSE ANYTHING**  
Browse Apple Photos or a folder you choose. Filter by photos or videos, album, favorites or date, sort by size, and group by day or month. Select with a tap or click, open a larger preview, and undo any selection step.

**EXACT COPIES, PROVEN**  
Keptora groups copies only after SHA-256 confirms they are byte-for-byte identical. Select Extra Copies keeps one photo in every group and leaves protected items alone.

**SIMILAR SHOTS TOGETHER**  
Very similar and similar photos are grouped using the image itself plus capture time, location and bursts. Keptora suggests which one to keep; you choose.

**QUICK WINS**  
Open Screenshots, Videos by Size, Live Photos and photos worth reviewing - blurry, dark, overexposed or low resolution - in one tap.

**REVIEW, THEN REMOVE**  
The final review lists every item, its source and how to recover it. Photos items go to Recently Deleted after Apple's confirmation. Folder files move to a recovery folder and can be restored from History.

**PRIVATE BY DESIGN**  
No account. No ads. No analytics. No uploads. Analysis runs on your iPhone or Mac, and iCloud originals are downloaded only if you ask.

**FREE TO START**  
Browsing, scanning, manual selection, removal and recovery are free. Suggested batch selection is free for your first 100 items; a one-time Keptora Pro purchase removes the limit on iPhone and Mac. No subscription.

## Turkish

### Subtitle

`Güvenle temizle. Anıları koru`

### Promotional text

Birebir kopyaları, benzer çekimleri, ekran görüntülerini ve büyük videoları bulun. Neyin gideceğini seçin, inceleyin, fikrinizi değiştirirseniz geri alın.

### Keywords

`kopya,fotoğraf temizle,benzer,depolama,ekran görüntüsü,video,bulanık,geri yükle`

### Description

Keptora, tek dokunuşla riskli silme yapmadan fotoğraf arşivinizi temizlemenize yardım eder. Her fotoğraf gözünüzün önünde kalır, neyin gideceğine siz karar verirsiniz ve kaldırmadan önce hepsini incelersiniz.

**HER ŞEYİ GÖRÜN, İSTEDİĞİNİZİ SEÇİN**  
Apple Fotoğraflar'ı veya seçtiğiniz bir klasörü inceleyin. Fotoğraf ya da videoya, albüme, favorilere veya tarihe göre filtreleyin; boyuta göre sıralayın, güne veya aya göre gruplayın. Dokunarak veya tıklayarak seçin, büyük önizleme açın ve her seçim adımını geri alın.

**KANITLANMIŞ BİREBİR KOPYALAR**  
Keptora kopyaları yalnızca SHA-256 bayt bayt aynı olduklarını doğruladıktan sonra gruplar. Fazla Kopyaları Seç her grupta bir fotoğrafı saklar ve korunan öğelere dokunmaz.

**BENZER ÇEKİMLER BİR ARADA**  
Çok benzer ve benzer fotoğraflar görüntünün kendisi, çekim zamanı, konum ve seri çekimlere göre gruplanır. Keptora hangisini saklayacağınızı önerir; karar sizindir.

**HIZLI KAZANÇLAR**  
Ekran görüntülerini, boyuta göre videoları, Live Photo'ları ve incelemeye değer fotoğrafları (bulanık, karanlık, aşırı parlak veya düşük çözünürlüklü) tek dokunuşla açın.

**ÖNCE İNCELE, SONRA KALDIR**  
Son inceleme her öğeyi, kaynağını ve nasıl geri alınacağını gösterir. Fotoğraflar öğeleri Apple onayıyla Son Silinenler'e gider. Klasör dosyaları kurtarma klasörüne taşınır ve Geçmiş'ten geri yüklenebilir.

**GİZLİLİK ODAKLI**  
Hesap, reklam, analitik veya yükleme yoktur. Analiz iPhone veya Mac'inizde yapılır; iCloud orijinalleri yalnızca siz isterseniz indirilir.

**ÜCRETSİZ BAŞLAYIN**  
Gezinme, tarama, elle seçim, kaldırma ve kurtarma ücretsizdir. Önerilen toplu seçim ilk 100 öğe için ücretsizdir; tek seferlik Keptora Pro satın alımı sınırı iPhone ve Mac'te kaldırır. Abonelik yoktur.

## Metadata entry checklist

- [ ] Reserve the final app name in App Store Connect.
- [ ] Complete trademark searches in the intended launch regions.
- [ ] Replace all placeholder URLs with public HTTPS pages.
- [ ] Confirm primary/secondary categories match the Xcode build and App Store Connect.
- [ ] Paste metadata from `app_store_metadata.json`, then run `Scripts/validate_app_store_metadata.py`.
- [ ] Re-check text after every localization edit; keywords are measured in UTF-8 bytes by the local validator.
- [ ] Do not add competitor trademarks, price claims, or unsupported feature promises.
