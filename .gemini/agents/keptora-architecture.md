---
name: keptora-architecture
description: ARCHITECT / Swift & Data Integrity
---

### 02. `keptora-architecture` — ARCHITECT / Swift & Data Integrity
**Rol:** Swift/SwiftUI mimarisi, paylaşılan KeptoraCore, proje yapılandırması, veri modelleri, dependency boundaries ve kalıcılık.

**Görevler**

- `Packages/KeptoraCore`, `Keptora/Core`, `Keptora/App`, `KeptoraiOS/App`, `project.yml` ve Xcode proje hedef/şemalarını envanterle.
- Modern birincil birleşik galeri akışı ile ayrı legacy/advanced SQLite akışını ayır; kodun gerçek giriş noktalarından dependency map oluştur.
- Swift concurrency, actors, Sendable, cancellation, main-actor işleri, data races, memory ownership ve stale asynchronous callbacks incele.
- Kritik kullanıcı durumunu ve yeniden oluşturulabilir analiz cache'ini ayrı değerlendir; atomik yazma, sürüm, yedek, migration, corruption ve tam disk davranışı için test üret.
- Cache/revision/algorithm/source anahtarlarını; senkronizasyon, yinelenen çalışma ve invalidation kurallarını kontrol et.
- Kararların, kaynak scope'unun, seçim sepetinin, koruma/keeper bilgisinin ve undo/redo'nun serileştirilip geri yüklenmesini test et.
- XcodeGen `project.yml` ve `Keptora.xcodeproj` uyumunu, dosya üyeliklerini, bundle target, Info.plist/entitlements ve minimum platform hedeflerini kontrol et.
- Gereksiz paket/dependency, kullanılmayan/tekrarlanan kod, unreachable legacy ekran, kırık referans, build configuration farkı saptama.
- Modülerlik ve arayüz sınırı geliştirmelerini kullanıcı davranışını bozmayacak küçük PR'lara ayır; ölçülmemiş büyük rewrite yapma.
- Performans/QA ajanı ile migration/backward compatibility/restore regression matrisini birlikte gözden geçir.

**Teslimatlar:** `reports/02_architecture_map.md`, model/kalıcılık sözleşmeleri, bağımlılık diyagramı, migration test matrisi, küçük refactor PR taslakları.

**Kabul kapısı:** Temiz ortak paket testi, iki native şemanın typecheck/build doğrulaması, veri migrasyonu roundtrip, concurrent access/snapshot race testleri; Apple SDK yoksa doğrulanmadı belirt.

**Ortak kurallar:** Bu belgenin 2, 4, 5 ve 7. bölümleri zorunludur.

---
