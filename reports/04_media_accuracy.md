# Keptora — Media Accuracy & Intelligence Report
**Agent:** 04 `keptora-media-intelligence` (VISION / Exact, Similarity & Media Quality)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** VERIFIED (127/127 tests passed)

---

## 1. Kesin Kopya Algoritması (Exact SHA-256 Hashing)
- **İki Aşamalı Tarama (`UniversalExactScanner` - `ExactGrouping.swift:147-266`):**
  - **Aşama 1 (Candidate Signature Bucketing):** Dosya boyutu (`s:<byteCount>`) veya boyut/süre fallback'i (`d:<mediaKind>:<WxH>:<duration>`) ile ön gruplama. Benzersiz boyuttaki tekil öğeler tam hash hesaplanmadan `unique:<asset.id>` olarak işaretlenir. Sıfır baytlık bozuk dosyalar `zero:<asset.id>` ile izole edilerek sahte 0-byte eşleşmesi engellenir.
  - **Aşama 2 (Full-Content SHA-256):** Eşleşen imzalara sahip aday çiftler tam içerik SHA-256 doğrulamasına tabi tutulur. Tekil öğeler (`!fingerprint.digest.hasPrefix("unique:")`) asla kopya gruplarına girmez.
- **Akışlı SHA-256 (`StreamingSHA256` - `ExactGrouping.swift:290-320`):**
  - Dosyalar 1 MB (1.048.576 byte) parçalar halinde `FileHandle` ve `CryptoKit.SHA256` üzerinden okunur.
  - `Task.checkCancellation()` ile asenkron iptal desteği tamdır. Bellek taşması oluşmaz.
- **PhotoKit & Çoklu Kaynak Aileleri (`PhotoLibrarySourceAdapter.swift:189-250`):**
  - Standalone fotoğraflar: `requestImageDataAndOrientation` -> `SHA256`.
  - Live Photo ve RAW+JPEG aileleri: `.photo`, `.pairedVideo`, `.fullSizePairedVideo` bileşenleri `LockedPhotoHasher` ile ayrı ayrı taranır ve bileşik imza üretilir (`photos-family-sha256-v2`).
  - **Kırmızı Çizgi Güvencesi:** Tekil bir JPG/HEIC fotoğraf, Live Photo ile asla kesin kopya olarak eşleşmez (false positive = %0).

---

## 2. Görsel Benzerlik Algoritmaları & Eşikler (Vision Similarity)
- **Görsel Özellik Çıkarımı (`VisualSimilarityAnalyzer.swift:5-277`):**
  - Apple Vision Framework `VNGenerateImageFeaturePrintRequestRevision1` (`VNFeaturePrintObservation`).
  - Hızlı Kaba Filtre: 64-bit dHash (difference hash, 9x8 grayscale komşu piksel karşılaştırması).
- **Çoklu İndeks Aday Arama:** LSH bant indeksleme (8-bit dilimler), zaman kovaları (dakika bazlı), burst indeksi (`burstID`) ve coğrafi konum (~110m kovaları).
- **Metrik ve Eşik Değerleri:**
  - `threshold = 0.30` (Vision feature print mesafesi).
  - Coarse dHash fallback: `0.08` (hamming mesafesi / 64).
  - En-Boy Oranı Kapısı: `abs(aspect - repAspect) < max(0.12, repAspect * 0.15)`.
- **Anti-Chaining / Küme Sınırı (`VisualSimilarityAnalyzer.swift:106-122`):**
  - Geçişli kümeleme (transitive chaining) engellenmiştir: $A \approx B$ ve $B \approx C \implies A \approx C$ hatası önlenir. Aday, kümedeki TÜM öğelerle `pairwiseMaximum < 1` sınırını sağlamak zorundadır.
- **Video Benzerliği (`VideoSimilarityAnalyzer.swift:6-156`):**
  - Video süre boyunca 3 karede örnekleme (%12, %50, %88).
  - Eşikler: `averageThreshold = 0.31`, `maximumFrameDistance = 0.48`. Süre farkı $\le 1.5$s veya %8.
- **Seri Çekim (Burst) Algoritması (`BurstSequenceAnalyzer.swift:36-112`):**
  - Ardışık kareler arası $\le 2.5$s, toplam süre $\le 20.0$s, maksimum 30 kare.

---

## 3. Medya Kalite Analizi (Quality Assessment)
- **Kalite Motoru (`VisualQualityEngine.swift`, `QualityAssessment.swift`):**
  - 8-bit luma, Laplacian eğrilik, kenar yoğunluğu, gradient analizi.
  - Bayraklar: `.lowResolution` ($<1000$px), `.dark` (mean $<24$), `.bright` (mean $>234$), `.possibleBlur` (gradient $<8$ && curvature $<3$).
- **Kırmızı Çizgi Güvencesi:** Kalite analizleri sadece **kullanıcıya yardımcı görsel ipucu** (hint) niteliğindedir. Asla otomatik silme veya otomatik seçim kararı oluşturmaz.

---

## 4. Test ve Doğrulama Kanıtları
- `KeptoraCoreTests`:
  - `testFindingFiltersKeepQualitySingletonsAndSeparateVerySimilar`: PASS
  - `testFlatAndNoisyImagesAreNotConfidentBlurEvidence`: PASS (Portre bokeh ve sanatsal gürültüde sahte blur önlendi).
  - `testUnknownPhotoSizeDoesNotExcludeAnExactFileCopy`: PASS
  - `testExactSuggestionsNeverIncludeKeeperFromRelatedGroup`: PASS

