# Keptora — iOS User Journey & Mobile Experience Report
**Agent:** 07 `keptora-iphone` (IPHONE STUDIO / Mobile Experience)  
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`  
**Durum:** PASS (Bir P1 Özellik Boşluğu ile Birlikte)

---

## 1. Zero-Jitter 1:1 Galeri Izgarası (Grid Architecture)
- **Kusursuz 1:1 Kare Geometri:** `KeptoraiOS/UI/MobileArchiveView.swift:831-870` içinde her hücre `.aspectRatio(1, contentMode: .fit)` ile sarılmıştır.
- **Yükseklik Asimetrisinin Ortadan Kaldırılması:** "Keep This" butonu (`archive.keep.\(asset.id)`) hücrenin altından alınarak thumbnail'ın **içine kayan kapsül rozet (.bottomLeading overlay)** olarak yerleştirilmiştir. Bu sayede 106pt vs 154pt yükseklik farkı ve kaymalar sıfırlanmıştır.
- **Sıfır Layout-Pass Gecikmesi:** Thumbnail ve hücre hiyerarşisinden gereksiz `GeometryReader`'lar temizlenmiştir.

---

## 2. Tekli Filtre Butonu ve Modal Sayfası (Single Filter Architecture)
- **Kontrol Sadeleştirmesi:** 9'dan fazla dağınık başlık kontrolü yerine tek bir **`LiquidGlassFilterButton`** (`MobileArchiveView.swift:51-107`) konulmuştur.
- **Modal İzolasyonu:** `MobileLibraryFilterSheet` (`MobileArchiveView.swift:111-262`) `.presentationDetents([.medium, .large])` ile açılır.
- **Sıfır Jank / Taslak Durum Makinesi:** Filtre sayfası `@State private var draft: MobileLibraryFilterCriteria` üzerinde çalışır. Kullanıcı tarih seçerken veya anahtarları değiştirirken 50.000 fotoğraflık arşiv üzerinde **0 yeniden filtreleme** yapılır; kullanıcı sayfayı kapattığında veya "Uygula" dediğinde tek bir atomik geçiş çalışır.
- **Aktif Filtre Rozetleri:** Yalnızca aktif filtre olduğunda tek satırda silinebilir rozetler (`archive.filter.remove.<id>`) gösterilir.

---

## 3. Dokunma, Hareketler ve Seçim Deneyimi (Gestures & Haptics)
- **Tek Dokunuş (Single Tap):** `store.toggleLibrarySelection(asset)` ile anında seçim yapar ve `.sensoryFeedback(.selection)` haptic titreşimi verir.
- **Uzun Basma (Context Menu):** "View Large", "Keep This", "Protect Photo", "Select / Deselect" seçenekleri sunar.
- **Tam Ekran Görünümü (`MobileFullAssetViewer`):**
  - Çift dokunma (Double Tap): 1.0x ile 2.5x yakınlaştırma arasında geçiş yapar.
  - Sıkıştırma Hareketi (Pinch-to-zoom): 1.0x ile 4.0x arasında yayınlanıp sınırda yaylanır (spring snap-back).
  - Kaydırma (Pan Gesture): Yakınlaştırıldığında ($>1.05\times$) görsel içinde kaydırma sağlar.
- **Güvenli Alanlar (Safe Area Insets):** Alt seçim çubuğu (`selectionBar`) ve inceleme eylemleri `.safeAreaInset(edge: .bottom)` ve `ultraThinMaterial` kullanır.

---

## 4. Tespit Edilen Kritik Bulgular
- **UX-01 (P1 - Özellik Paritesi Eksikliği):**
  - Geçmiş `5641a610` commit'inde ("Remove Swipe and other unreachable UI code") `MobileSplitComparisonView.swift` silinmiştir.
  - İnceleme akışı `MobileSelectionReviewSheet` içine toparlanmış olsa da, **iOS tarafında iki benzer fotoğrafı yan yana koyup inceleme ekranı eksiktir** (macOS'ta `SideBySideCompareView` varken iOS'ta bulunmamaktadır).
  - **Öneri:** `SideBySideCompareView`'ın iOS dikey/yatay ekranına uyarlanmış bir `MobileSplitComparisonView` sayfası olarak yeniden kazandırılması.
- **UX-04 (P2 - VoiceOver Çift Atlaması):**
  - `MobileArchiveView:831-869` içinde thumbnail butonu ile "Keep This" butonu iki ayrı erişilebilirlik öğesidir. VoiceOver ile gezinirken her hücrede 2 swipe gerektirmektedir. `.accessibilityElement(children: .combine)` ile tek öğe yapılıp keeper işlemi özel eylem olarak sunulmalıdır.

