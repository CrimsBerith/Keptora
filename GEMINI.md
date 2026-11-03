# Keptora — Gemini Orchestration Rules

## 1. Global Invariants (Kırmızı Çizgiler)
1. Kullanıcıdan açık son işlem onayı olmadan medya kaldırma/taşıma yok; otomatik benzerlik/kalite skoruna göre silme yok.
2. Manuel medya seçimiyle önerili/bulk temizlik aynı şey değildir. Manuel seçilen benzersiz/favori medya da açık kapsam ve sistem koşullarıyla kaldırılabilir; öneri yolundaki koruma/keeper kurallarını tüm manuel seçimlere yanlışlıkla zorla uygulama.
3. Kesin kopya iddiası tam içerik hash kanıtıyla desteklenir; benzer görünüm veya aynı dosya adı yeterli değildir.
4. Photos kaldırması Apple'ın sistem onayıyla Recently Deleted akışını takip eder; Files/klasör işleri aynı depolamada recovery alanına taşınır. Files recovery hareketi boş alan açmayı garanti etmez.
5. Restore route ve manifest asla sessizce kaybolamaz; orijinale üzerine yazma, double-copy veya missing-copy belirsizliğinde otomatik kalıcı müdahale yok.
6. Cihazdaki kullanıcı fotoğraf/video/EXIF/GPS/path ve kaynak kimliği gizli kalır; privacy ve no-upload beyanları her release'te kod/SDK/evidence ile doğrulanır.
7. PhotoKit yalnız yetkili içerik; iCloud download açık politika/izin; symlink, path ve source-volume kimliği kontrolü; WhatsApp özel uygulama verisine erişim vaadi yok.
8. Manuel seçim, güvenlik/geri yükleme gibi temel haklar ödeme duvarına alınmaz; lifetime Pro entitlement atomik kontrol edilir. Yeni abonelik ekleme.
9. Release öncesi gerçek macOS/iOS native test, gerçek izin/cihaz QA, performance corpus, StoreKit sandbox ve Apple App Review belge kanıtı gereklidir. Yalnız Python/Swift parse PASS = native READY değildir.
10. Private arşivde otomatik destructive test yok; sentetik/geçerli izinli corpus kullan; değişiklik/yayın/ürün satın alma/gizli servis erişimi için gereken insan onaylarını atlama.

## 2. Command Rules
- Always prefix shell commands with `rtk` (e.g. `rtk git status`, `rtk swift test`).
- Keep communication terse, compact, and direct like smart caveman.
- 12 specialist subagents defined in `.gemini/agents/`.

