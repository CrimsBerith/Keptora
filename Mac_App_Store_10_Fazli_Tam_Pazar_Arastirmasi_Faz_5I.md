# Mac App Store — 10 Fazlı Tam Pazar Araştırması

**Dosya durumu:** Faz 5I/10 — on-device perceptual similarity, kalibrasyon altyapısı ve 100K aday benchmark’ı tamamlandı  
**Referans tarihi:** 2 Ağustos 2026  
**Ana hedef:** Mac App Store’da kamuya açık olarak bulunabilen uygulamaları tekilleştirerek; kategori, alt kategori, niş, mikro-niş, fiyat ve para kazanma modeliyle tek bir master Markdown dosyasında toplamak.

> [!IMPORTANT]
> Apple, Mac App Store’un indirilebilir ve herkesçe erişilebilir tek parça “tüm uygulamalar” dökümünü sunmuyor. Bu nedenle mutlak %100 eksiksizlik bağımsız olarak kanıtlanamaz. Araştırmanın hedefi; Apple’ın kamuya açık kategori sayfaları, listeleri, arama API’si, ürün sayfaları ve erişim mümkünse Enterprise Partner Feed kullanılarak **kamuya açık biçimde indekslenebilen uygulamaların tamamına yaklaşmak** ve eksikliği bir kapsam defteriyle ölçmektir.

## 1. Araştırma kapsamı ve ana kararlar

- **Ana platform:** macOS / Mac App Store.
- **Dahil:** Mac’e özel uygulamalar, Universal Purchase uygulamaları, Mac App Store’da Mac için sunulan Catalyst uygulamaları ve mağazada Mac uyumluluğu bulunan uygulamalar.
- **Ayrı işaretlenecek:** “Mac native”, “Mac Catalyst”, “Designed for iPad/iPhone on Apple silicon”, “Universal”.
- **Ana storefront:** ABD; geniş ürün kapsamı ve USD karşılaştırması için.
- **Zorunlu fiyat storefront’u:** Türkiye; kullanıcının yerel satın alma fiyatını göstermek için.
- **Karşılaştırma storefront’ları:** Birleşik Krallık, Almanya, Kanada, Avustralya ve Japonya; sonraki fazlarda genişletilecek.
- **Tekilleştirme anahtarı:** Öncelik `trackId/adamId`; ikinci anahtar `bundleId`; isim tek başına anahtar olmayacak.
- **Fiyat anlık görüntüdür:** Her fiyatın para birimi, ülke vitrini ve gözlem tarihi yazılacak.
- **Uygulama fiyatı ile uygulama içi ödeme ayrı tutulacak:** “Ücretsiz” görünen bir uygulama abonelikli olabilir.

## 2. Neden tek sorguyla bütün mağaza çekilemez?

Apple Search API `macSoftware` varlığını destekler; ancak bir sorgu en fazla 200 sonuç döndürür ve dokümantasyonda yaklaşık 20 çağrı/dakika sınırı belirtilir. Sonuçlar bir arama terimine bağlıdır; boş sorguyla bütün katalog verilmez. Bu yüzden top chart + kategori + anahtar kelime matrisi + bölgesel vitrin + ürün sayfası doğrulaması birlikte kullanılacaktır.

## 3. 10 fazlı çalışma planı

| Faz | İş | Durum | Teslim |
|---:|---|---|---|
| 1 | Kapsam, resmî kategori haritası, veri şeması ve doğruluk kuralları | Tamamlandı | Bu dosya |
| 2 | Mac App Store kategori sayfaları, Top Free/Top Paid ve Discover seed taraması | **Top Charts tamamlandı — 20/20 kategori / 999 kayıt; Discover taraması bekliyor** | İlk uygulama envanteri |
| 3 | Uzun kuyruk keşfi: niş, A–Z/0–9 ve çoklu storefront taraması | **Devam ediyor — Faz 3A–3J: 739 doğrulanmış chart-dışı kayıt** | Top listelerde görünmeyen uygulamalar |
| 4 | Storefront genişletme: US, TR, GB, DE, CA, AU, JP ve diğer bölgesel vitrinler | **Top 5 kapsamı tamamlandı — 20 kategori / 200 pozisyon** | Bölgesel bulunabilirlik ve fiyat farkları |
| 5 | Kazanan ürünün marka, 30+ rakip, teknik spike, bilgi mimarisi, premium UI ve geliştirme backlog’u | **Tamamlandı — Faz 5I perceptual similarity + 100K candidate benchmark** | Cullora 0.8.0 Xcode projesi, schema v4, review-only Vision pipeline ve reversible exact cleanup |
| 6 | Alt kategori, niş ve mikro-niş sınıflandırması; çakışan kategorilerin çözümü | Bekliyor | Tutarlı pazar taksonomisi |
| 7 | Talep ve rekabet sinyalleri: sıralama, puan, yorum sayısı, güncellik, fiyat ve yoğunluk | Bekliyor | Kategori/niş pazar ölçümleri |
| 8 | Para kazanma analizi: ücretsiz, ücretli, freemium, abonelik, lifetime ve hibrit model | Bekliyor | Fiyat ve monetizasyon haritası |
| 9 | Tekilleştirme, kaldırılmış uygulama kontrolü, fiyat tarihçesi ve kapsam doygunluğu | Bekliyor | QA edilmiş nihai veri seti |
| 10 | Tek master .md: tüm uygulamalar, kategori/niş tabloları, fırsat skorları ve ürün önerileri | Bekliyor | Nihai Mac App Store pazar dosyası |

## 4. “Bütün uygulamalara yaklaşma” ölçütü

Araştırma yalnızca uygulama sayısı vermeyecek; kapsama ne kadar yaklaşıldığını da gösterecek:

1. Her kaynak ve storefront için bulunan benzersiz `trackId` sayısı tutulacak.
2. Her yeni tarama turunda yeni bulunan uygulama sayısı kaydedilecek.
3. Üç ardışık genişletilmiş taramada yeni uygulama oranı çok düşük seviyeye indiğinde ilgili kategori “doygun” işaretlenecek.
4. Top listeler, arama sonuçları ve kategori sayfalarının kesişim oranı izlenecek.
5. Ürün sayfası erişilemeyen, kaldırılan veya bölgesel olarak kapalı uygulamalar ayrı statü alacak.
6. Son dosyada her kategori için `yüksek / orta / düşük kapsam güveni` yazacak.

## 5. Uygulama başına tutulacak master veri şeması

| Alan grubu | Tutulacak bilgiler |
|---|---|
| Kimlik | `trackId/adamId`, `bundleId`, uygulama adı, geliştirici/satıcı |
| Bağlantı | App Store ürün sayfası ve geliştirici sitesi |
| Platform türü | Mac native / Catalyst / Universal / iPad-on-Mac |
| Storefront | US, TR, GB, DE vb. ve gözlem zamanı |
| Kategori | Birincil kategori, ikincil kategori, Games alt kategorileri |
| Pazar sınıflandırması | Araştırma alt kategorisi, niş, mikro-niş, kullanım işi |
| Etiket fiyatı | Sayısal fiyat, gösterilen fiyat, para birimi, ücretsiz/ücretli |
| IAP | IAP var/yok, tüketilebilir/tüketilemez, görünen paketler ve fiyatlar |
| Abonelik | Aylık, yıllık, haftalık, ekip/aile planı ve ücretsiz deneme |
| Lifetime | Tek seferlik kalıcı açma veya ayrı ücretli sürüm |
| Monetizasyon modeli | Free, paid, freemium, subscription, lifetime, hybrid, ads, enterprise |
| Sürüm | Mevcut sürüm, ilk yayın tarihi, son güncelleme tarihi |
| Uyumluluk | Minimum macOS, Apple silicon/Intel bilgisi bulunabildiği ölçüde |
| Kalite sinyalleri | Puan, puan sayısı, yazılı yorum sayısı, yaş derecesi |
| Ürün kapsamı | Dil, dosya boyutu, Family Sharing, offline/cloud/AI bağımlılığı |
| Gizlilik | Gizlilik etiketi özetleri ve hesap gereksinimi |
| Pazar notları | Ana özellik, hedef kullanıcı, rakipler, farklılaşma |
| Fırsat sinyalleri | Talep, rekabet, fiyat gücü, güncellik, şikâyet boşluğu |
| Veri kalitesi | Kaynak, son doğrulama, güven seviyesi, çelişki notu |

### Önerilen tek uygulama satırı

```text
APP-000001 | trackId | bundleId | Uygulama | Geliştirici | Platform türü | Storefront |
Birincil kategori | İkincil kategori | Resmî oyun alt kategorisi | Araştırma alt kategorisi |
Niş | Mikro-niş | Etiket fiyatı | Para birimi | IAP | Aylık | Yıllık | Lifetime |
Monetizasyon | Puan | Puan sayısı | Son güncelleme | Minimum macOS | Diller |
Offline | AI/Cloud | Ürün URL | Gözlem tarihi | Durum | Güven | Not
```

## 6. Fiyat ve “ne para?” normalizasyonu

Her uygulama için aşağıdaki fiyatlar birbirinden ayrılacak:

- **Download price:** App Store’daki indirme fiyatı.
- **Unlock price:** Uygulamanın tam sürümünü açan tek seferlik IAP.
- **Lifetime price:** Kalıcı lisans; varsa.
- **Subscription:** Haftalık, aylık, yıllık ve ekip fiyatları.
- **Consumable IAP:** Kredi, jeton, içerik paketi gibi tekrar satın alınabilir ürün.
- **External/enterprise price:** Ürün sayfasında açıkça belirtilen harici lisans veya kurumsal plan; App Store fiyatından ayrı.
- **Trial:** Deneme süresi ve deneme sonrası fiyat.

### Monetizasyon kodları

| Kod | Model | Açıklama |
|---|---|---|
| FREE | Tamamen ücretsiz | Ücretli açma veya abonelik gözlenmedi |
| PAID | Peşin ücretli | İndirme öncesi tek fiyat |
| FREEMIUM | Ücretsiz + IAP | Temel sürüm ücretsiz, özellik/içerik ücretli |
| SUB | Abonelik | Ana gelir tekrar eden ödeme |
| LIFE | Lifetime | Kalıcı tek seferlik açma |
| HYBRID | Hibrit | Abonelik + lifetime veya paid + IAP |
| ADS | Reklam | Reklam destekli veya reklam kaldırma IAP’si |
| ENT | Kurumsal | Koltuk, ekip veya özel sözleşme |
| UNKNOWN | Belirsiz | Ürün sayfası yeterli bilgi vermiyor |

## 7. Resmî Mac App Store kategorileri

Apple, uygulamalara bir birincil ve isteğe bağlı bir ikincil kategori verir. **Games dışındaki aşağıdaki “alt kategori/niş”ler Apple’ın resmî alt kategorileri değildir; pazar analizini ayrıntılandırmak için bu araştırmada oluşturulan sınıflandırmadır.** Games için Apple’ın resmî alt kategorileri ayrıca belirtilmiştir.

Toplam resmî üst kategori: **26**

### 1. Books

**Araştırma alt kategorileri ve nişleri:**
- eBook/EPUB readers
- PDF reading and annotation
- digital libraries and catalogues
- comic and manga readers
- interactive books
- children’s storybooks
- academic reading
- book discovery and reading lists
- speed reading
- quote and excerpt managers
- book collection management
- self-publishing companions

### 2. Business

**Araştırma alt kategorileri ve nişleri:**
- CRM and sales management
- invoicing and billing
- accounting and bookkeeping
- inventory and warehouse management
- point of sale
- project and work management
- team collaboration
- video meetings and VoIP
- remote desktop and support
- document management and scanning
- ERP and operations
- HR and recruiting
- shift and workforce management
- time tracking and timesheets
- customer success/support tooling
- field service management
- legal practice management
- real-estate business tools
- restaurant and retail back office
- business dashboards and reporting

### 3. Developer Tools

**Araştırma alt kategorileri ve nişleri:**
- IDEs and code editors
- Git clients
- terminal and SSH clients
- API clients
- database clients
- Docker and container tools
- Kubernetes tools
- cloud administration
- network debugging and proxy tools
- log viewers
- crash and performance tools
- JSON/XML/YAML tools
- regex tools
- diff and merge tools
- code snippets
- package and dependency tools
- documentation generators
- localization tools
- app icon and asset generators
- simulator/device utilities
- CI/CD clients
- website development
- no-code and low-code tools
- AI coding assistants
- security testing tools
- developer menu-bar utilities

### 4. Education

**Araştırma alt kategorileri ve nişleri:**
- language learning
- exam and certification prep
- flashcards and spaced repetition
- math learning
- science learning
- coding education
- typing tutors
- music education
- art and design education
- geography and history
- astronomy
- school portals and LMS clients
- classroom management
- teacher lesson-planning tools
- special education and accessibility learning
- early learning
- professional skills training
- pet training
- craft and hobby learning

### 5. Entertainment

**Araştırma alt kategorileri ve nişleri:**
- video streaming
- media centers and players
- podcast entertainment
- internet radio entertainment
- live event and ticketing
- fan communities and companions
- voice changers and soundboards
- meme and GIF creation
- wallpapers and screensavers
- interactive art and visual toys
- virtual pets
- celebrity and fandom content
- TV second-screen companions
- karaoke entertainment
- casual creative experiences

### 6. Finance

**Araştırma alt kategorileri ve nişleri:**
- personal budgeting
- expense tracking
- banking clients
- investment and portfolio tracking
- stock market tools
- trading journals
- crypto portfolio and wallets
- tax preparation
- bill reminders
- debt payoff
- loan and mortgage calculators
- insurance management
- currency conversion
- small-business finance
- cash-flow forecasting
- financial calculators
- net-worth tracking
- receipt and expense inboxes
- subscription expense tracking
- financial news terminals

### 7. Food & Drink

**Araştırma alt kategorileri ve nişleri:**
- recipe managers
- meal planning
- grocery lists
- pantry and food inventory
- cooking timers
- baking tools
- nutrition and ingredient reference
- food-allergy and dietary tools
- restaurant discovery and reviews
- menu planning
- wine and beverage reference
- coffee brewing tools
- cocktail and drink recipes
- restaurant operations companions
- food journaling
- international cuisine guides

### 8. Games

**Apple’ın resmî Games alt kategorileri:** Action, Adventure, Board, Card, Casino, Casual, Family, Music, Puzzle, Racing, Role Playing, Simulation, Sports, Strategy, Trivia, Word.

**Araştırmada ayrıca izlenecek nişler:**
- indie premium games
- free-to-play games
- multiplayer games
- idle/incremental games
- cozy games
- educational games
- retro and arcade games
- game companions and launchers

### 9. Graphics & Design

**Araştırma alt kategorileri ve nişleri:**
- raster image editing
- vector design
- drawing and illustration
- 3D modelling
- CAD
- desktop publishing
- UI/UX design
- prototyping
- diagramming
- animation and motion graphics
- font management and creation
- icon design
- color tools
- asset management
- mockup generation
- presentation graphics
- generative AI design
- image upscaling and restoration
- pattern and texture design
- architecture and interior visualization
- print and prepress tools

### 10. Health & Fitness

**Araştırma alt kategorileri ve nişleri:**
- workout planning
- strength training
- running and cycling tracking
- yoga and pilates
- meditation and mindfulness
- breathing exercises
- sleep tracking and sleep sounds
- posture and ergonomics
- break and eye-rest reminders
- hydration tracking
- nutrition and calorie tracking
- weight management
- habit-based wellness
- women’s health and cycle tracking
- pregnancy companions
- health dashboards
- stress management
- recovery and mobility
- sports conditioning
- Apple Health viewers

### 11. Lifestyle

**Araştırma alt kategorileri ve nişleri:**
- home inventory
- home improvement
- interior design
- gardening and plant care
- pet care
- parenting
- family organization
- fashion and wardrobe
- wedding planning
- hobby tracking
- collecting and cataloguing
- genealogy
- journaling and life logging
- personal goals
- astrology and spiritual lifestyle
- relationship tools
- home automation companions
- vehicle ownership logs
- minimalism and decluttering
- personal safety and preparedness

### 12. Magazines & Newspapers

**Araştırma alt kategorileri ve nişleri:**
- newspaper editions
- magazine editions
- digital periodicals
- trade publications
- academic periodicals
- local news editions
- issue-based readers
- subscription publication hubs
- interactive print companions
- archive readers

### 13. Medical

**Araştırma alt kategorileri ve nişleri:**
- medical reference
- anatomy and physiology
- drug and medication reference
- clinical calculators
- medical education
- patient record management
- EHR/EMR clients
- DICOM and medical imaging
- telemedicine clients
- dental tools
- veterinary medicine
- laboratory reference
- medical research tools
- symptom and condition reference
- medical device companions
- practice management
- nursing tools
- pharmacy tools
- mental-health professional tools

### 14. Music

**Araştırma alt kategorileri ve nişleri:**
- digital audio workstations
- audio recording and editing
- MIDI tools
- virtual instruments and synthesizers
- music notation
- guitar tabs and chords
- tuners and metronomes
- DJ tools
- sample and loop managers
- mixing and mastering
- podcast production
- radio and music streaming
- music discovery
- lyrics and songwriting
- ear training
- karaoke
- concert and setlist tools
- audio routing
- music library management
- music practice tracking

### 15. Navigation

**Araştırma alt kategorileri ve nişleri:**
- road maps and driving
- public transit
- walking navigation
- cycling routes
- hiking and topographic maps
- marine navigation and tides
- aviation navigation
- GPS utilities
- traffic monitoring
- EV charging maps
- fuel finders
- geocaching
- offline maps
- route planning
- fleet navigation
- location coordinate tools
- camping and outdoor navigation

### 16. News

**Araştırma alt kategorileri ve nişleri:**
- RSS readers
- news aggregators
- read-later services
- general news
- local news
- technology news
- business and finance news
- political news
- science news
- entertainment news
- sports news
- broadcast news clients
- newsletters and digest readers
- fact-checking and media-bias tools
- press monitoring
- newsroom tools

### 17. Photo & Video

**Araştırma alt kategorileri ve nişleri:**
- photo editing
- RAW processing
- photo library management
- photo organization
- video editing
- screen recording
- webcam tools
- camera capture
- video transcoding
- compression and optimization
- subtitle tools
- slideshow creation
- GIF and short-video creation
- animation
- AI photo enhancement
- AI video enhancement
- background removal
- color grading
- video asset management
- streaming production
- photo printing and layout
- metadata and EXIF tools

### 18. Productivity

**Araştırma alt kategorileri ve nişleri:**
- task and to-do management
- notes and knowledge bases
- calendar management
- email clients
- document editors
- PDF tools
- clipboard managers
- window management
- app launchers
- automation and macros
- time tracking
- focus timers and blockers
- mind mapping
- whiteboards
- OCR and scanning
- translation
- password managers
- cloud storage and sync
- file organization
- meeting notes and transcription
- text expansion
- workflow dashboards
- personal CRM
- bookmark and read-it-later
- AI productivity assistants

### 19. Reference

**Araştırma alt kategorileri ve nişleri:**
- dictionaries and thesauruses
- encyclopedias
- translation reference
- legal reference
- religious reference
- standards and codes
- technical manuals
- nature and species identification
- astronomy reference
- maps and atlases
- quotations
- history reference
- politics reference
- genealogy reference
- how-to libraries
- academic reference
- units and scientific constants
- language grammar reference
- collectibles reference

### 20. Safari Extensions

**Araştırma alt kategorileri ve nişleri:**
- ad blockers
- privacy and tracker blocking
- password managers
- coupon and shopping helpers
- read-later and bookmarking
- tab/session management
- developer tools
- translation
- screenshot and capture
- accessibility helpers
- social media utilities
- content filters
- video controls
- search enhancements
- form filling
- link management
- reader-mode enhancements
- security warnings

### 21. Shopping

**Araştırma alt kategorileri ve nişleri:**
- retailer storefronts
- marketplaces
- price comparison
- price tracking
- coupons and deals
- grocery shopping
- fashion shopping
- resale and second-hand
- collectibles marketplaces
- gift lists and registries
- package tracking
- shopping list managers
- product review tools
- auction clients
- B2B procurement
- local shopping discovery
- loyalty and rewards

### 22. Social Networking

**Araştırma alt kategorileri ve nişleri:**
- messaging clients
- community networks
- forum and Reddit-style clients
- creator communities
- professional networking
- dating and relationship networks
- photo/video social clients
- microblogging
- decentralized and federated social
- interest-based communities
- voice and video chat
- live-streaming communities
- social media management
- multi-account clients
- family and private networks

### 23. Sports

**Araştırma alt kategorileri ve nişleri:**
- live scores
- team and league apps
- fantasy sports
- sports news
- coaching and tactics
- training analysis
- golf tools
- football/soccer tools
- basketball tools
- baseball tools
- tennis tools
- motorsport tools
- cycling tools
- running tools
- outdoor sports
- esports
- sports video analysis
- race timing
- sports statistics
- regulated betting information

### 24. Travel

**Araştırma alt kategorileri ve nişleri:**
- flight tracking
- hotel and accommodation booking
- flight booking
- itinerary planning
- city guides
- road-trip planning
- public transport
- travel rewards
- time-zone tools
- packing lists
- travel journals
- camping and RV travel
- digital nomad tools
- visa and entry reference
- travel translation
- currency tools
- airport guides
- rental-car tools
- cruise and maritime travel
- local experience discovery

### 25. Utilities

**Araştırma alt kategorileri ve nişleri:**
- system monitoring
- disk cleanup and storage analysis
- backup and restore
- file compression and archives
- antivirus and malware protection
- VPN and network privacy
- menu-bar utilities
- window management
- clipboard utilities
- keyboard and mouse tools
- network diagnostics
- screen capture
- file transfer
- batch rename
- file conversion
- virtualization
- remote control
- battery management
- display and brightness tools
- audio routing and volume tools
- printer and scanner tools
- data recovery
- duplicate file finders
- uninstallers
- download managers
- file search
- USB/device utilities
- automation helpers
- security and encryption

### 26. Weather

**Araştırma alt kategorileri ve nişleri:**
- general forecasts
- menu-bar weather
- radar
- severe weather alerts
- marine weather
- aviation weather
- agricultural weather
- air quality
- pollen and allergy forecasts
- tide and surf forecasts
- snow and ski weather
- astronomy and stargazing weather
- historical climate data
- weather stations
- weather widgets
- professional meteorology

## 8. Kategori çakışmalarını çözme kuralları

- PDF düzenleyici: ana iş belge üretkenliği ise **Productivity**; kurumsal doküman akışı ise **Business**.
- Fotoğraf düzenleyici: üretim aracıysa **Photo & Video**; illüstrasyon/tasarım odaklıysa **Graphics & Design**.
- Kod odaklı metin editörü: **Developer Tools**; genel yazı/not editörü: **Productivity**.
- Bütçe uygulaması: kişisel kullanımda **Finance**; işletme muhasebesinde Finance + Business ikincil etiketi.
- Meditasyon uygulaması: **Health & Fitness**; genel yaşam/ritüel günlüğü: **Lifestyle** veya Reference ikincil etiketi.
- RSS okuyucu: güncel içerik tüketimi ana işse **News**; okuma arşivi ve odak akışıysa Productivity ikincil nişi.
- Ekran kaydı: içerik üretimi ana işse **Photo & Video**; teknik yakalama/yardım aracıysa **Utilities**.
- Sistem temizleyici, menü çubuğu aracı, clipboard ve window manager: **Utilities** ana; Productivity ikincil nişi.
- Uygulama kendi App Store kategorisini yanlış seçmiş görünse bile resmî kategori değiştirilmez; araştırma alt kategorisi gerçek kullanım işine göre ayrıca atanır.

## 9. Faz 2’de başlanacak uygulama envanteri formatı

| ID | Uygulama | Geliştirici | Platform | Birincil kategori | Alt kategori | Niş | US fiyat | TR fiyat | IAP/Abonelik | Puan | Son güncelleme | Kaynak tarihi |
|---|---|---|---|---|---|---|---:|---:|---|---:|---|---|
| APP-000001 | _Faz 2’de doldurulacak_ |  |  |  |  |  |  |  |  |  |  |  |

## 10. Kalite güven seviyeleri

| Seviye | Anlam |
|---|---|
| A | Ürün sayfası + Apple API/Chart verisi birbiriyle uyumlu ve yakın tarihte doğrulandı |
| B | Tek resmî Apple kaynağıyla doğrulandı; bazı ticari ayrıntılar eksik |
| C | Arama sonucu veya bölgesel sayfa bulundu; ürün sayfası ayrıntıları tam doğrulanamadı |
| D | Uygulama kaldırılmış, erişilemez veya bilgiler çelişkili |

## 11. Araştırmada özellikle üretilecek sonuçlar

- Her kategori ve nişte kaç benzersiz uygulama bulunduğu.
- Ücretsiz/ücretli/freemium/abonelik/lifetime oranı.
- Medyan ve dağılım olarak fiyat; yalnızca veri yeterliyse.
- Puan ve yorum yoğunluğu ile rekabet seviyesi.
- Son 12/24 ayda güncellenmiş uygulama oranı.
- Yüksek talep + düşük kaliteli rekabet görülen nişler.
- Offline çalışabilen ve bağımsız geliştirici için uygulanabilir fırsatlar.
- Abonelik yorgunluğu bulunan, tek seferlik fiyatla ayrışabilecek alanlar.
- Mac’e özgü avantaj sunmayan kötü Catalyst/iPad portlarının bulunduğu boşluklar.
- Kullanıcının hedefi için “yapılabilirlik × gelir × talep × rekabet” puanlı uygulama fikirleri.

## 12. Kaynaklar

Kaynaklar 1 Ağustos 2026 tarihinde kontrol edilmiştir.

- [Apple — Categories and Discoverability](https://developer.apple.com/app-store/categories/) — Mac App Store’da birincil/ikincil kategori mantığı ve kategori tanımları.
- [Apple — List App Categories (App Store Connect API)](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appcategories) — MAC_OS filtresiyle resmî kategori ve alt kategori hiyerarşisi.
- [Apple — iTunes Search API: Constructing Searches](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html) — macSoftware entity, 200 sonuç sınırı ve yaklaşık 20 çağrı/dakika limiti.
- [Apple — App Pricing and Availability](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability/) — Fiyat, bölgesel bulunabilirlik, gelir ve eğitim indirimi alanları.
- [Apple — Set a Price for an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/) — IAP fiyat noktaları ve yüksek fiyat seviyeleri.
- [Apple — App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/) — Uygun geliştiriciler için %15 komisyon ve 1 milyon USD eşik bilgisi.
- [Apple Services Performance Partners — RSS Generator](https://performance-partners.apple.com/tools) — Top apps listeleri için Apple RSS üreticisi.
- [Apple Services Performance Partners — Enterprise Partner Feed](https://performance-partners.apple.com/epf) — Erişim sağlanırsa toplu katalog ve application_price gibi alanlar.
- [Apple — Freemium Games](https://developer.apple.com/app-store/freemium-games/) — Games için resmî 16 alt kategori listesi.

## 13. Faz 1 tamamlanma kontrolü

- [x] Araştırmanın dürüst kapsam tanımı
- [x] 10 fazlı plan
- [x] Resmî Mac kategori mantığı
- [x] 26 üst kategori
- [x] Games için 16 resmî alt kategori
- [x] Diğer kategoriler için araştırma alt kategori ve niş sözlüğü
- [x] Uygulama başına fiyat/IAP/abonelik/lifetime şeması
- [x] Tekilleştirme ve veri güven kuralları
- [x] Faz 2 uygulama envanteri tablo formatı
- [ ] Uygulama satırlarının toplu eklenmesi — Faz 2’den itibaren

---

**Sürüm:** 1.0 — Faz 1/10  
**Son güncelleme:** 1 Ağustos 2026

# Faz 2A — ABD Mac Top Charts İlk Uygulama Envanteri

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kapsam:** 399 chart sıralama kaydı, 397 isim-bazlı benzersiz kayıt, 8 kategori, 16 ücretsiz/ücretli liste.

> [!NOTE]
> Bu bölüm uygulama ürün sayfası envanteri değil, **chart placement** envanteridir. Aynı isim farklı uygulama kimliklerini temsil edebilir veya aynı uygulama birden fazla listede bulunabilir. Kesin tekilleştirme `trackId/adamId` ile Faz 3–5 sırasında yapılacaktır.

> [!WARNING]
> `Top Free`, yalnızca indirme fiyatının ücretsiz olduğunu; abonelik veya IAP bulunmadığını göstermez. `Top Paid` ise ücretli indirmeyi gösterir, fakat kesin USD/TRY fiyatı bu fazda doğrulanmamıştır.

## Faz 2A özeti

| Kategori | Free kayıt | Paid kayıt | Toplam |
|---|---:|---:|---:|
| Business | 25 | 25 | 50 |
| Developer Tools | 25 | 25 | 50 |
| Games | 25 | 25 | 50 |
| Graphics & Design | 25 | 25 | 50 |
| Health & Fitness | 25 | 25 | 50 |
| Productivity | 25 | 25 | 50 |
| Utilities | 25 | 25 | 50 |
| Weather | 25 | 24 | 49 |
| **Toplam** | **200** | **199** | **399** |

## İlk pazar sinyalleri

- **Utilities:** VPN, reklam engelleme, arşiv, depolama ve masaüstü özelleştirme kümeleri yoğun.
- **Productivity:** Office istemcileri ve web-servis wrapper’ları ücretsiz listede; yerel Mac araçları, yazma ve pencere yönetimi ücretli listede daha görünür.
- **Developer Tools:** Apple geliştirme zinciri ücretsiz tarafta; veri editörleri, terminal, Markdown ve özel dosya araçları ücretli tarafta yoğun.
- **Graphics & Design:** Cricut, ev/CAD, çizim, görsel düzenleme ve widget tasarımı ayrı güçlü kümeler oluşturuyor.
- **Health & Fitness:** Uyku/ses, günlük, ergonomi ve alışkanlık uygulamaları Mac’e özgü masa başı kullanım senaryolarıyla öne çıkıyor.
- **Business:** Ücretsiz listede yazıcı uygulamaları ve web/AI wrapper’ları; ücretli listede dosya dönüştürme ve uzak masaüstü araçları dikkat çekiyor.
- **Weather:** Ücretli listede profesyonel radar, havacılık ve denizcilik; ücretsiz listede widget ve genel tahmin ürünleri daha yoğun.
- **Games:** Ücretsiz tarafta portlar ve free-to-play oyunlar; ücretli tarafta premium PC/console portları ve klasik simülasyon/strateji oyunları bulunuyor.

## En sık görülen araştırma nişleri

| Niş | Chart kaydı |
|---|---:|
| Other / manual review | 48 |
| Sleep, meditation & relaxation | 13 |
| General forecast | 12 |
| VPN & network privacy | 12 |
| Documents & file conversion | 11 |
| Drawing & painting | 11 |
| Workout & training | 10 |
| Radar & severe weather | 9 |
| Printing & scanning | 7 |
| Menu bar & widgets | 7 |
| Moon & solar tracking | 7 |
| Browser extensions & blockers | 7 |
| Home, CAD & spatial design | 7 |
| Team collaboration | 6 |
| Weather wallpaper & desktop | 6 |
| Apple development | 6 |
| Image editing | 6 |
| Graphic layout & publishing | 6 |
| System & network administration | 5 |
| Office suite | 5 |
| Browser productivity | 5 |
| Markdown & documentation | 5 |
| Structured data editors | 5 |
| Cricut & cutting design | 5 |
| Health data & monitoring | 5 |

## Uygulama envanteri

| Kategori | Liste | Sıra | Uygulama | Araştırma nişi | Fiyat durumu |
|---|---|---:|---|---|---|
| Business | Free | 1 | Open Link for Chrome & Firefox | Browser workflow | Free download; IAP/subscription unknown |
| Business | Free | 2 | Windows App | Remote desktop & virtualization | Free download; IAP/subscription unknown |
| Business | Free | 3 | Slack for Desktop | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 4 | PDFgear: PDF Editor & Reader | Documents & file conversion | Free download; IAP/subscription unknown |
| Business | Free | 5 | Okta Verify | Enterprise security & access | Free download; IAP/subscription unknown |
| Business | Free | 6 | Opus Chat-AI Chatbot Assistant | Other / manual review | Free download; IAP/subscription unknown |
| Business | Free | 7 | HP Smart Printer App & Scanner | Printing & scanning | Free download; IAP/subscription unknown |
| Business | Free | 8 | Parallels Desktop | Remote desktop & virtualization | Free download; IAP/subscription unknown |
| Business | Free | 9 | iPrint for Epson Printer | Printing & scanning | Free download; IAP/subscription unknown |
| Business | Free | 10 | HP Printer App for Desktop | Printing & scanning | Free download; IAP/subscription unknown |
| Business | Free | 11 | VooV Meeting | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 12 | Todo List & Task for Notion | Other / manual review | Free download; IAP/subscription unknown |
| Business | Free | 13 | Easy Access for Google Drive | Other / manual review | Free download; IAP/subscription unknown |
| Business | Free | 14 | WeCom-Business IM & Work Tools | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 15 | 钉钉 - AI时代的工作方式 | Other / manual review | Free download; IAP/subscription unknown |
| Business | Free | 16 | Lark: Team Collaboration | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 17 | Document Writer Word Processor | Documents & file conversion | Free download; IAP/subscription unknown |
| Business | Free | 18 | Citrix Secure Access | Enterprise security & access | Free download; IAP/subscription unknown |
| Business | Free | 19 | Printer App Smart Print Scan | Printing & scanning | Free download; IAP/subscription unknown |
| Business | Free | 20 | Trello | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 21 | Printer App: Smart Printer | Printing & scanning | Free download; IAP/subscription unknown |
| Business | Free | 22 | QuickBooks Desktop | Business operations & finance | Free download; IAP/subscription unknown |
| Business | Free | 23 | Browser App for All Browser | Browser workflow | Free download; IAP/subscription unknown |
| Business | Free | 24 | Whiteboard: just draw together | Team collaboration | Free download; IAP/subscription unknown |
| Business | Free | 25 | ClashX Pro - Dashboard manager | Network administration | Free download; IAP/subscription unknown |
| Business | Paid | 1 | UTM Virtual Machines | Remote desktop & virtualization | Paid download; exact price pending |
| Business | Paid | 2 | Jump Desktop (RDP, VNC, Fluid) | Remote desktop & virtualization | Paid download; exact price pending |
| Business | Paid | 3 | Sync Folders Pro | Other / manual review | Paid download; exact price pending |
| Business | Paid | 4 | Antivirus Zap - Virus Scanner | Printing & scanning | Paid download; exact price pending |
| Business | Paid | 5 | Virtual Teleprompter Pro | Presentation tools | Paid download; exact price pending |
| Business | Paid | 6 | APK Installer Pro | Other / manual review | Paid download; exact price pending |
| Business | Paid | 7 | Simplefax | Other / manual review | Paid download; exact price pending |
| Business | Paid | 8 | MSG Viewer for Outlook Pro | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 9 | iPrint Smart Printer App Pro | Printing & scanning | Paid download; exact price pending |
| Business | Paid | 10 | Living_Psychrometrics | Other / manual review | Paid download; exact price pending |
| Business | Paid | 11 | HTML Email Signature - Mail | Other / manual review | Paid download; exact price pending |
| Business | Paid | 12 | DICOM File Viewer | Other / manual review | Paid download; exact price pending |
| Business | Paid | 13 | Export Calendars Pro: iCal,CSV | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 14 | Msg Viewer Pro | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 15 | PUB Editor & Converter for MS Publisher | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 16 | Mocha TN3270 | Other / manual review | Paid download; exact price pending |
| Business | Paid | 17 | WPD Reader : for WordPerfect | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 18 | Docs² \| for Microsoft Office | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 19 | TapeCalc 2 | Business operations & finance | Paid download; exact price pending |
| Business | Paid | 20 | Document Converter | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 21 | Duplicate Manager Pro | Other / manual review | Paid download; exact price pending |
| Business | Paid | 22 | Downgrade for Premiere Project | Other / manual review | Paid download; exact price pending |
| Business | Paid | 23 | Get contact Backup: vCard, CSV | Documents & file conversion | Paid download; exact price pending |
| Business | Paid | 24 | Hair Stylist Appointments | Business operations & finance | Paid download; exact price pending |
| Business | Paid | 25 | MSG to PDF Converter Pro－Batch | Documents & file conversion | Paid download; exact price pending |
| Developer Tools | Free | 1 | Xcode | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 2 | TestFlight | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 3 | Apple Developer | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 4 | Transporter | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 5 | Termius: SSH Client & Terminal | Terminal & SSH | Free download; IAP/subscription unknown |
| Developer Tools | Free | 6 | BBEdit | Code editors | Free download; IAP/subscription unknown |
| Developer Tools | Free | 7 | Userscripts | Web development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 8 | Clone in VS Code | Code editors | Free download; IAP/subscription unknown |
| Developer Tools | Free | 9 | NearbiJSX | AI/web prototype tooling | Free download; IAP/subscription unknown |
| Developer Tools | Free | 10 | Sequel Ace | Database tools | Free download; IAP/subscription unknown |
| Developer Tools | Free | 11 | Transmit 5 | Other / manual review | Free download; IAP/subscription unknown |
| Developer Tools | Free | 12 | Py Editor for Python | Code editors | Free download; IAP/subscription unknown |
| Developer Tools | Free | 13 | MD-Viewer | Markdown & documentation | Free download; IAP/subscription unknown |
| Developer Tools | Free | 14 | Free MP4 Converter | Other / manual review | Free download; IAP/subscription unknown |
| Developer Tools | Free | 15 | ColorSlurp | Design assets for developers | Free download; IAP/subscription unknown |
| Developer Tools | Free | 16 | QuickMD | Markdown & documentation | Free download; IAP/subscription unknown |
| Developer Tools | Free | 17 | DevCleaner for Xcode | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 18 | Free Ruler | Design assets for developers | Free download; IAP/subscription unknown |
| Developer Tools | Free | 19 | Vesta Player | AI/web prototype tooling | Free download; IAP/subscription unknown |
| Developer Tools | Free | 20 | System Color Picker | Design assets for developers | Free download; IAP/subscription unknown |
| Developer Tools | Free | 21 | STEP File Viewer | CAD file inspection | Free download; IAP/subscription unknown |
| Developer Tools | Free | 22 | TurboWarp | Other / manual review | Free download; IAP/subscription unknown |
| Developer Tools | Free | 23 | RocketSim for Xcode Simulator | Apple development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 24 | Cookie-Editor | Web development | Free download; IAP/subscription unknown |
| Developer Tools | Free | 25 | Enchanted Developers Only | AI/web prototype tooling | Free download; IAP/subscription unknown |
| Developer Tools | Paid | 1 | RegEx+ | Regex tools | Paid download; exact price pending |
| Developer Tools | Paid | 2 | Monodraw | ASCII diagrams | Paid download; exact price pending |
| Developer Tools | Paid | 3 | TerminalWidget | Terminal & SSH | Paid download; exact price pending |
| Developer Tools | Paid | 4 | Virtual Location | Testing & network utilities | Paid download; exact price pending |
| Developer Tools | Paid | 5 | App Explorer: Homebrew Catalog | Package discovery | Paid download; exact price pending |
| Developer Tools | Paid | 6 | QL Markdown by XN | Markdown & documentation | Paid download; exact price pending |
| Developer Tools | Paid | 7 | MDB ACCDB Viewer | Database tools | Paid download; exact price pending |
| Developer Tools | Paid | 8 | Global Store Go | Other / manual review | Paid download; exact price pending |
| Developer Tools | Paid | 9 | HextEdit: Hex Editor & Viewer | Hex & binary tools | Paid download; exact price pending |
| Developer Tools | Paid | 10 | JSON XML Two Way Converter | Structured data editors | Paid download; exact price pending |
| Developer Tools | Paid | 11 | Native SQLite Manager | Database tools | Paid download; exact price pending |
| Developer Tools | Paid | 12 | Textastic | Code editors | Paid download; exact price pending |
| Developer Tools | Paid | 13 | Markdown2PDF: Convert Markdown | Markdown & documentation | Paid download; exact price pending |
| Developer Tools | Paid | 14 | Easy CSV Editor | Structured data editors | Paid download; exact price pending |
| Developer Tools | Paid | 15 | Upgrade to Marked 3 | Markdown & documentation | Paid download; exact price pending |
| Developer Tools | Paid | 16 | JSON Editor | Structured data editors | Paid download; exact price pending |
| Developer Tools | Paid | 17 | PLIST Editor | Structured data editors | Paid download; exact price pending |
| Developer Tools | Paid | 18 | WiFiSpoof 4 | Testing & network utilities | Paid download; exact price pending |
| Developer Tools | Paid | 19 | App Icon Extractor | Design assets for developers | Paid download; exact price pending |
| Developer Tools | Paid | 20 | My Styles: Custom Website Look | Web development | Paid download; exact price pending |
| Developer Tools | Paid | 21 | Termix Pro: SSH & SFTP Client | Terminal & SSH | Paid download; exact price pending |
| Developer Tools | Paid | 22 | Peek — A Quick Look Extension | Other / manual review | Paid download; exact price pending |
| Developer Tools | Paid | 23 | Delimited RFC 4180 Editor | Structured data editors | Paid download; exact price pending |
| Developer Tools | Paid | 24 | Another Desktop Manager For Redis | Database tools | Paid download; exact price pending |
| Developer Tools | Paid | 25 | RocketCake Professional | Web development | Paid download; exact price pending |
| Games | Free | 1 | Steam Link | Game streaming | Free download; IAP/subscription unknown |
| Games | Free | 2 | Asphalt Legends: Racing Game | Racing | Free download; IAP/subscription unknown |
| Games | Free | 3 | Asphalt 8: Airborne | Racing | Free download; IAP/subscription unknown |
| Games | Free | 4 | Solitaire Epic | Card | Free download; IAP/subscription unknown |
| Games | Free | 5 | Code of War・Online FPS Shooter | Action / FPS | Free download; IAP/subscription unknown |
| Games | Free | 6 | MultiCraft — Build and Mine! | Sandbox / Survival | Free download; IAP/subscription unknown |
| Games | Free | 7 | Resident Evil 4 | Action / Horror | Free download; IAP/subscription unknown |
| Games | Free | 8 | Among Us! | Social deduction | Free download; IAP/subscription unknown |
| Games | Free | 9 | Township | Simulation | Free download; IAP/subscription unknown |
| Games | Free | 10 | Rolling Ball Adventure: 3D Run | Casual / Platformer | Free download; IAP/subscription unknown |
| Games | Free | 11 | Mind The Door | Puzzle | Free download; IAP/subscription unknown |
| Games | Free | 12 | RetroArch | Emulation | Free download; IAP/subscription unknown |
| Games | Free | 13 | Wuthering Waves - To Xuanfang | Action RPG | Free download; IAP/subscription unknown |
| Games | Free | 14 | Block Blast : New Puzzle Games | Puzzle | Free download; IAP/subscription unknown |
| Games | Free | 15 | Colors by Number® – No.Draw® | Game / Genre verification pending | Free download; IAP/subscription unknown |
| Games | Free | 16 | DREDGE | Adventure | Free download; IAP/subscription unknown |
| Games | Free | 17 | NTE: Neverness to Everness | Role Playing | Free download; IAP/subscription unknown |
| Games | Free | 18 | POOLS™ | Game / Genre verification pending | Free download; IAP/subscription unknown |
| Games | Free | 19 | Mahjong Solitaire Epic | Board / Puzzle | Free download; IAP/subscription unknown |
| Games | Free | 20 | CATO: Buttered Cat | Puzzle platformer | Free download; IAP/subscription unknown |
| Games | Free | 21 | Sudoku+ | Puzzle | Free download; IAP/subscription unknown |
| Games | Free | 22 | Truck Simulator - Semi Driving | Simulation | Free download; IAP/subscription unknown |
| Games | Free | 23 | RESIDENT EVIL 2 | Action / Horror | Free download; IAP/subscription unknown |
| Games | Free | 24 | UNO!™ | Game / Genre verification pending | Free download; IAP/subscription unknown |
| Games | Free | 25 | Solitaireﾠ | Card | Free download; IAP/subscription unknown |
| Games | Paid | 1 | Palworld | Adventure / Survival | Paid download; exact price pending |
| Games | Paid | 2 | Geometry Dash | Casual / Rhythm platformer | Paid download; exact price pending |
| Games | Paid | 3 | Control Ultimate Edition | Action / Adventure | Paid download; exact price pending |
| Games | Paid | 4 | The Sims™ 2: Super Collection | Game / Genre verification pending | Paid download; exact price pending |
| Games | Paid | 5 | Road to Empress | Adventure | Paid download; exact price pending |
| Games | Paid | 6 | The Jackbox Party Pack 3 | Party / Trivia | Paid download; exact price pending |
| Games | Paid | 7 | Quiplash | Party / Trivia | Paid download; exact price pending |
| Games | Paid | 8 | inZOI | Simulation | Paid download; exact price pending |
| Games | Paid | 9 | Plague Inc: Evolved | Strategy | Paid download; exact price pending |
| Games | Paid | 10 | Incredibox | Music | Paid download; exact price pending |
| Games | Paid | 11 | Is This Seat Taken? | Puzzle | Paid download; exact price pending |
| Games | Paid | 12 | Cyberpunk 2077: Ultimate | Action RPG | Paid download; exact price pending |
| Games | Paid | 13 | SimCity™ 4 Deluxe Edition | Game / Genre verification pending | Paid download; exact price pending |
| Games | Paid | 14 | Farming Simulator 25 | Simulation | Paid download; exact price pending |
| Games | Paid | 15 | Stray | Adventure | Paid download; exact price pending |
| Games | Paid | 16 | MONOPOLY: The Board Game | Board | Paid download; exact price pending |
| Games | Paid | 17 | Old Man's Journey | Adventure | Paid download; exact price pending |
| Games | Paid | 18 | Purple Place - Classic Games | Casual / Family | Paid download; exact price pending |
| Games | Paid | 19 | 60 Seconds! Reatomized | Adventure / Survival | Paid download; exact price pending |
| Games | Paid | 20 | Myst III: Exile | Adventure / Puzzle | Paid download; exact price pending |
| Games | Paid | 21 | Civilization® V | Strategy | Paid download; exact price pending |
| Games | Paid | 22 | Thank Goodness You're Here!! | Comedy platformer | Paid download; exact price pending |
| Games | Paid | 23 | Disney Dreamlight Valley. | Life simulation | Paid download; exact price pending |
| Games | Paid | 24 | Papa's Paleteria To Go! | Time management | Paid download; exact price pending |
| Games | Paid | 25 | Aurora Hills: Chapter 2 HD | Adventure / Puzzle | Paid download; exact price pending |
| Graphics & Design | Free | 1 | Pixelmator Pro: Edit Images | Image editing | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 2 | Designs for Cricut Maker | Cricut & cutting design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 3 | Design Space For Cricut Studio | Cricut & cutting design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 4 | ibisPaint - Your Art Studio | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 5 | Sweet Home 3D | Home, CAD & spatial design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 6 | Cover Design | Graphic layout & publishing | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 7 | Home Planner: Room Design 3D | Home, CAD & spatial design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 8 | Paint S | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 9 | InFold: Reels & Story Maker | Other / manual review | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 10 | Linearity Curve: Graphic Art | Vector design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 11 | Tayasui Sketches | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 12 | Design Studio : Craft Space | Cricut & cutting design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 13 | Cricut Design Studio & Fonts | Cricut & cutting design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 14 | Design Studio for: Craft Space | Cricut & cutting design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 15 | ScreenKit - App Icons & Widget | Widgets & visual customization | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 16 | MCPaint | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 17 | Clockology Watch Faces | Widgets & visual customization | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 18 | Live Home 3D: House Design | Home, CAD & spatial design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 19 | Sketch | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 20 | Colorful Widget- Widget&Themes | Widgets & visual customization | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 21 | Mockup - UI/UX Design | UI/UX design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 22 | Paint X - Paint, Draw and Edit | Drawing & painting | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 23 | Widgy Widgets: Home/Lock/Watch | Home, CAD & spatial design | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 24 | Graphic Designer: Logo Maker | Graphic layout & publishing | Free download; IAP/subscription unknown |
| Graphics & Design | Free | 25 | CorelDRAW | Vector design | Free download; IAP/subscription unknown |
| Graphics & Design | Paid | 1 | Pixelmator Pro | Image editing | Paid download; exact price pending |
| Graphics & Design | Paid | 2 | Callipeg Studio: 2D Animation | 2D animation | Paid download; exact price pending |
| Graphics & Design | Paid | 3 | Sketchbook Pro | Drawing & painting | Paid download; exact price pending |
| Graphics & Design | Paid | 4 | Logoist 6 – Graphic Design | Graphic layout & publishing | Paid download; exact price pending |
| Graphics & Design | Paid | 5 | Krita | Drawing & painting | Paid download; exact price pending |
| Graphics & Design | Paid | 6 | TechSmith Snagit 2024 | Other / manual review | Paid download; exact price pending |
| Graphics & Design | Paid | 7 | Acorn 8 | Image editing | Paid download; exact price pending |
| Graphics & Design | Paid | 8 | RailModeller Pro | Home, CAD & spatial design | Paid download; exact price pending |
| Graphics & Design | Paid | 9 | Formline - Precision Drawing | Home, CAD & spatial design | Paid download; exact price pending |
| Graphics & Design | Paid | 10 | GraphicConverter 12 | Image editing | Paid download; exact price pending |
| Graphics & Design | Paid | 11 | Artstudio Pro - Desktop | Drawing & painting | Paid download; exact price pending |
| Graphics & Design | Paid | 12 | Entity Pro | Other / manual review | Paid download; exact price pending |
| Graphics & Design | Paid | 13 | Heightmap: Depth Map Maker | 3D/laser depth maps | Paid download; exact price pending |
| Graphics & Design | Paid | 14 | Seahorse Image Editor | Image editing | Paid download; exact price pending |
| Graphics & Design | Paid | 15 | Swift Publisher 5 | Graphic layout & publishing | Paid download; exact price pending |
| Graphics & Design | Paid | 16 | SKP Simple Viewer | Home, CAD & spatial design | Paid download; exact price pending |
| Graphics & Design | Paid | 17 | Templates for Creator Studio | Graphic layout & publishing | Paid download; exact price pending |
| Graphics & Design | Paid | 18 | CD DVD Cover Pro - Disc Label | Graphic layout & publishing | Paid download; exact price pending |
| Graphics & Design | Paid | 19 | Paint Pad | Drawing & painting | Paid download; exact price pending |
| Graphics & Design | Paid | 20 | Sacred Geometry Maker | Other / manual review | Paid download; exact price pending |
| Graphics & Design | Paid | 21 | Visuals - Be Inspired | Moodboards & references | Paid download; exact price pending |
| Graphics & Design | Paid | 22 | PixelStyle Photo Editor | Image editing | Paid download; exact price pending |
| Graphics & Design | Paid | 23 | Waterlogue Pro | Artistic photo effects | Paid download; exact price pending |
| Graphics & Design | Paid | 24 | Reference Board | Moodboards & references | Paid download; exact price pending |
| Graphics & Design | Paid | 25 | ArtRage Vitae | Drawing & painting | Paid download; exact price pending |
| Health & Fitness | Free | 1 | Portal - Escape Into Nature | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 2 | Diarly: Diary, Private Journal | Journal & mental wellness | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 3 | SmartGym: Gym & Home Workouts | Workout & training | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 4 | Endel: Focus & Sleep Sounds | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 5 | stoic. journal & mental health | Journal & mental wellness | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 6 | MyWhoosh: Indoor Cycling App | Workout & training | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 7 | Blankie | Other / manual review | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 8 | Habitify: Habit Tracker | Habit building | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 9 | White Noise: Sound Machine | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 10 | LookAway - Break Reminder | Breaks, posture & ergonomics | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 11 | Calm | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 12 | Nutrition Tracker: Foodnoms | Nutrition | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 13 | Flow Cycle & Period Tracker | Cycle tracking | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 14 | Calorie Counter Diet Tracker | Nutrition | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 15 | White Noise Lite | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 16 | Health Auto Export - JSON+CSV | Health data & monitoring | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 17 | Tacx Training™ | Workout & training | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 18 | Wakeout! Break the Sit Habit | Habit building | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 19 | NYC ACCESS HRA | Health data & monitoring | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 20 | Easlo Journal | Journal & mental wellness | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 21 | Yoga \| Down Dog | Workout & training | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 22 | Relax Melodies: Sleep Sounds | Sleep, meditation & relaxation | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 23 | Yoga Studio: Stretch on the Go | Workout & training | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 24 | O2Insight pro | Health data & monitoring | Free download; IAP/subscription unknown |
| Health & Fitness | Free | 25 | Time Out - Break Reminders | Breaks, posture & ergonomics | Free download; IAP/subscription unknown |
| Health & Fitness | Paid | 1 | Streaks | Habit building | Paid download; exact price pending |
| Health & Fitness | Paid | 2 | Calm and Confident | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 3 | White Noise | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 4 | SymptomLog: Symptom Journal | Journal & mental wellness | Paid download; exact price pending |
| Health & Fitness | Paid | 5 | Noizio — Calm, Meditate, Sleep | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 6 | rubiTrack 6 | Activity analytics | Paid download; exact price pending |
| Health & Fitness | Paid | 7 | GlucoseDesk | Health data & monitoring | Paid download; exact price pending |
| Health & Fitness | Paid | 8 | Seconds Pro Interval Timer | Workout & training | Paid download; exact price pending |
| Health & Fitness | Paid | 9 | Pocket Yoga | Workout & training | Paid download; exact price pending |
| Health & Fitness | Paid | 10 | Dorso - Posture Monitor | Breaks, posture & ergonomics | Paid download; exact price pending |
| Health & Fitness | Paid | 11 | O2 Buddy: Blood Oxygen SpO2 | Health data & monitoring | Paid download; exact price pending |
| Health & Fitness | Paid | 12 | Simply Being - Meditation | Other / manual review | Paid download; exact price pending |
| Health & Fitness | Paid | 13 | Perfect Diet Tracker | Nutrition | Paid download; exact price pending |
| Health & Fitness | Paid | 14 | Relax Melodies Premium | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 15 | Nutrition Menu - Calorie Tracker | Nutrition | Paid download; exact price pending |
| Health & Fitness | Paid | 16 | Brainwave Studio | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 17 | Chill | Other / manual review | Paid download; exact price pending |
| Health & Fitness | Paid | 18 | Menstrual Period Tracker Plus | Cycle tracking | Paid download; exact price pending |
| Health & Fitness | Paid | 19 | Healthier: Break Reminder | Breaks, posture & ergonomics | Paid download; exact price pending |
| Health & Fitness | Paid | 20 | Workout Timer: tabata training | Workout & training | Paid download; exact price pending |
| Health & Fitness | Paid | 21 | Relax and Rest Guided Meditations | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 22 | 7 Minute Workout | Workout & training | Paid download; exact price pending |
| Health & Fitness | Paid | 23 | Music Healing | Sleep, meditation & relaxation | Paid download; exact price pending |
| Health & Fitness | Paid | 24 | Screen Lights | Other / manual review | Paid download; exact price pending |
| Health & Fitness | Paid | 25 | Tai Chi Step by Step | Workout & training | Paid download; exact price pending |
| Productivity | Free | 1 | Microsoft Word | Office suite | Free download; IAP/subscription unknown |
| Productivity | Free | 2 | Microsoft Excel | Office suite | Free download; IAP/subscription unknown |
| Productivity | Free | 3 | Microsoft Outlook | Email | Free download; IAP/subscription unknown |
| Productivity | Free | 4 | Microsoft 365 | Office suite | Free download; IAP/subscription unknown |
| Productivity | Free | 5 | Microsoft PowerPoint | Office suite | Free download; IAP/subscription unknown |
| Productivity | Free | 6 | WidgetWall | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 7 | HP: Print and Support | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 8 | Apps for Google App | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 9 | Mail for Gmail | Email | Free download; IAP/subscription unknown |
| Productivity | Free | 10 | OneDrive | Cloud & file transfer | Free download; IAP/subscription unknown |
| Productivity | Free | 11 | Join for Zoom Meetings | Meeting workflow | Free download; IAP/subscription unknown |
| Productivity | Free | 12 | Microsoft Copilot | AI assistant & writing | Free download; IAP/subscription unknown |
| Productivity | Free | 13 | Grammarly: AI Writing App | AI assistant & writing | Free download; IAP/subscription unknown |
| Productivity | Free | 14 | Docs for Google Docs and Drive | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 15 | C.AI: AI Chatbot Assistant | AI assistant & writing | Free download; IAP/subscription unknown |
| Productivity | Free | 16 | Goodnotes: AI Notes, Docs, PDF | Notes & planning | Free download; IAP/subscription unknown |
| Productivity | Free | 17 | App for YouTube ℠ | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 18 | AI Chatbot - Ask AI Anything‎ | AI assistant & writing | Free download; IAP/subscription unknown |
| Productivity | Free | 19 | Microsoft OneNote | Notes & planning | Free download; IAP/subscription unknown |
| Productivity | Free | 20 | Mail+ for Gmail | Email | Free download; IAP/subscription unknown |
| Productivity | Free | 21 | Calendar for Google Calendar‎ | Calendar | Free download; IAP/subscription unknown |
| Productivity | Free | 22 | App for Google Search ®‎ | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 23 | NotchBox - Easier Drag & Drop | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Free | 24 | PDF Reader: PDF Editor,Convert | PDF workflow | Free download; IAP/subscription unknown |
| Productivity | Free | 25 | Openly a Link - Browser Picker | Other / manual review | Free download; IAP/subscription unknown |
| Productivity | Paid | 1 | Parchment: Agenda & Daily Note | Notes & planning | Paid download; exact price pending |
| Productivity | Paid | 2 | Magnet | Window management | Paid download; exact price pending |
| Productivity | Paid | 3 | Things 3 | Task management | Paid download; exact price pending |
| Productivity | Paid | 4 | Dark Reader for Safari | Browser productivity | Paid download; exact price pending |
| Productivity | Paid | 5 | Tampermonkey | Browser productivity | Paid download; exact price pending |
| Productivity | Paid | 6 | Scrivener 3 | Writing & authoring | Paid download; exact price pending |
| Productivity | Paid | 7 | LibreOffice | Office suite | Paid download; exact price pending |
| Productivity | Paid | 8 | Maccy | Clipboard management | Paid download; exact price pending |
| Productivity | Paid | 9 | BetterSnapTool | Window management | Paid download; exact price pending |
| Productivity | Paid | 10 | LosslessCut | Other / manual review | Paid download; exact price pending |
| Productivity | Paid | 11 | Parall Multi-Instance App Launcher | Other / manual review | Paid download; exact price pending |
| Productivity | Paid | 12 | SponsorBlock for Safari | Browser productivity | Paid download; exact price pending |
| Productivity | Paid | 13 | TextSniper | OCR & transcription | Paid download; exact price pending |
| Productivity | Paid | 14 | PDF Expert – Edit, Sign PDFs | PDF workflow | Paid download; exact price pending |
| Productivity | Paid | 15 | Undistracted Social Media | Other / manual review | Paid download; exact price pending |
| Productivity | Paid | 16 | Final Draft 13 | Writing & authoring | Paid download; exact price pending |
| Productivity | Paid | 17 | Whisper Notes - Speech to Text | OCR & transcription | Paid download; exact price pending |
| Productivity | Paid | 18 | GCal for Google Calendar | Calendar | Paid download; exact price pending |
| Productivity | Paid | 19 | MacFamilyTree 11 | Other / manual review | Paid download; exact price pending |
| Productivity | Paid | 20 | iA Writer | Writing & authoring | Paid download; exact price pending |
| Productivity | Paid | 21 | Greenshot | Other / manual review | Paid download; exact price pending |
| Productivity | Paid | 22 | Tampermonkey Bundle | Browser productivity | Paid download; exact price pending |
| Productivity | Paid | 23 | Marked QL - Markdown Preview | Markdown workflow | Paid download; exact price pending |
| Productivity | Paid | 24 | Cyberduck | Cloud & file transfer | Paid download; exact price pending |
| Productivity | Paid | 25 | UnTrap for YouTube | Browser productivity | Paid download; exact price pending |
| Utilities | Free | 1 | NordVPN: VPN Fast & Secure | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 2 | Color Widgets | Desktop customization | Free download; IAP/subscription unknown |
| Utilities | Free | 3 | DuckDuckGo, optional Duck.ai | Other / manual review | Free download; IAP/subscription unknown |
| Utilities | Free | 4 | App for Youtube! | Other / manual review | Free download; IAP/subscription unknown |
| Utilities | Free | 5 | Widgetter - Quick View Widgets | Desktop customization | Free download; IAP/subscription unknown |
| Utilities | Free | 6 | VPN: Super Unlimited, Fast VPN | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 7 | The Unarchiver | Compression & archives | Free download; IAP/subscription unknown |
| Utilities | Free | 8 | uBlock Origin Lite | Browser extensions & blockers | Free download; IAP/subscription unknown |
| Utilities | Free | 9 | Brother iPrint&Scan | Printing & device utilities | Free download; IAP/subscription unknown |
| Utilities | Free | 10 | Unzip - RAR ZIP 7Z Unarchiver | Compression & archives | Free download; IAP/subscription unknown |
| Utilities | Free | 11 | Happ - Proxy Utility | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 12 | Amphetamine | Keep-awake utilities | Free download; IAP/subscription unknown |
| Utilities | Free | 13 | Tailscale | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 14 | ExpressVPN: Ultra Secure VPN | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 15 | VPN Proxy Maste® Unlimited VPN | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 16 | Apple Configurator | System & network administration | Free download; IAP/subscription unknown |
| Utilities | Free | 17 | Surfshark VPN: stable & fast | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 18 | VPN cat: Fast Secure Unlimited | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 19 | CleanMyMac | Storage & file management | Free download; IAP/subscription unknown |
| Utilities | Free | 20 | WireGuard | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 21 | iWallpaper - Live Wallpaper | Desktop customization | Free download; IAP/subscription unknown |
| Utilities | Free | 22 | Free VPN by Free VPN .org™ | VPN & network privacy | Free download; IAP/subscription unknown |
| Utilities | Free | 23 | MacDroid - Manager for Android | Device transfer | Free download; IAP/subscription unknown |
| Utilities | Free | 24 | AdGuard: Ad Blocker for Safari | Browser extensions & blockers | Free download; IAP/subscription unknown |
| Utilities | Free | 25 | Speedtest by Ookla | System & network administration | Free download; IAP/subscription unknown |
| Utilities | Paid | 1 | Shadowrocket | VPN & network privacy | Paid download; exact price pending |
| Utilities | Paid | 2 | Wipr 2 | Browser extensions & blockers | Paid download; exact price pending |
| Utilities | Paid | 3 | Keka | Compression & archives | Paid download; exact price pending |
| Utilities | Paid | 4 | DaisyDisk | Storage & file management | Paid download; exact price pending |
| Utilities | Paid | 5 | Noir – Dark Mode for Safari | Browser extensions & blockers | Paid download; exact price pending |
| Utilities | Paid | 6 | RAR Extractor - Unarchiver Pro | Compression & archives | Paid download; exact price pending |
| Utilities | Paid | 7 | MediaInfo | System & network administration | Paid download; exact price pending |
| Utilities | Paid | 8 | GrandPerspective | Storage & file management | Paid download; exact price pending |
| Utilities | Paid | 9 | Klack | Other / manual review | Paid download; exact price pending |
| Utilities | Paid | 10 | SiteSucker | Other / manual review | Paid download; exact price pending |
| Utilities | Paid | 11 | LinkMyDroid | Device transfer | Paid download; exact price pending |
| Utilities | Paid | 12 | Quantumult X | VPN & network privacy | Paid download; exact price pending |
| Utilities | Paid | 13 | StopTheMadness Pro | Browser extensions & blockers | Paid download; exact price pending |
| Utilities | Paid | 14 | Parachute Backup For iCloud Photos & Drive | Backup | Paid download; exact price pending |
| Utilities | Paid | 15 | Find Any File (FAF) | Storage & file management | Paid download; exact price pending |
| Utilities | Paid | 16 | Dynamic Wallpaper Studio | Desktop customization | Paid download; exact price pending |
| Utilities | Paid | 17 | Pure Paste | Other / manual review | Paid download; exact price pending |
| Utilities | Paid | 18 | Caffeinated: Anti Sleep App | Keep-awake utilities | Paid download; exact price pending |
| Utilities | Paid | 19 | Vinegar - Tube Cleaner | Browser extensions & blockers | Paid download; exact price pending |
| Utilities | Paid | 20 | AutoMounter | System & network administration | Paid download; exact price pending |
| Utilities | Paid | 21 | Mapper for Safari | Browser extensions & blockers | Paid download; exact price pending |
| Utilities | Paid | 22 | Outpost Launcher | Other / manual review | Paid download; exact price pending |
| Utilities | Paid | 23 | Folder Preview | Other / manual review | Paid download; exact price pending |
| Utilities | Paid | 24 | Apple Remote Desktop | System & network administration | Paid download; exact price pending |
| Utilities | Paid | 25 | Paperman: Your screen as paper | Other / manual review | Paid download; exact price pending |
| Weather | Free | 1 | Weather Dock: Desktop forecast | Menu bar & widgets | Free download; IAP/subscription unknown |
| Weather | Free | 2 | Weather Widget Live | Menu bar & widgets | Free download; IAP/subscription unknown |
| Weather | Free | 3 | Mercury Weather | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 4 | Paku - Air Quality & AQI Map | Air quality | Free download; IAP/subscription unknown |
| Weather | Free | 5 | Accuweather - Forecast & UV | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 6 | Moonlitt: Moon Phase Tracker | Moon & solar tracking | Free download; IAP/subscription unknown |
| Weather | Free | 7 | Tide Alert (NOAA) - Tide Chart | Marine weather & tides | Free download; IAP/subscription unknown |
| Weather | Free | 8 | Desktop Clock Live | Weather wallpaper & desktop | Free download; IAP/subscription unknown |
| Weather | Free | 9 | Sun and Moon Tracker - Solar Path and Lunar Phases | Moon & solar tracking | Free download; IAP/subscription unknown |
| Weather | Free | 10 | Sunlitt: Sun tracker & seeker | Moon & solar tracking | Free download; IAP/subscription unknown |
| Weather | Free | 11 | WeatherAI - Forecast & Radar | Radar & severe weather | Free download; IAP/subscription unknown |
| Weather | Free | 12 | FrankWeather Radar Desktop | Radar & severe weather | Free download; IAP/subscription unknown |
| Weather | Free | 13 | Living Weather & Wallpapers HD | Weather wallpaper & desktop | Free download; IAP/subscription unknown |
| Weather | Free | 14 | MyRadar Accurate Weather Radar | Radar & severe weather | Free download; IAP/subscription unknown |
| Weather | Free | 15 | Moon Calendar + Phases | Moon & solar tracking | Free download; IAP/subscription unknown |
| Weather | Free | 16 | Weatherly | Menu bar & widgets | Free download; IAP/subscription unknown |
| Weather | Free | 17 | Weather Underground: Local Map | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 18 | Tide Guide: Charts & Tables | Marine weather & tides | Free download; IAP/subscription unknown |
| Weather | Free | 19 | Moon Phase Calendar LunarSight | Moon & solar tracking | Free download; IAP/subscription unknown |
| Weather | Free | 20 | Weather ۬ | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 21 | Sunny: Weather Forecasts | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 22 | ClassicWeather | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 23 | RAD Weather: Honest Forecast | General forecast | Free download; IAP/subscription unknown |
| Weather | Free | 24 | Weather Forecast App: Menu bar | Menu bar & widgets | Free download; IAP/subscription unknown |
| Weather | Free | 25 | NOAA Weather Radar Live Map | Radar & severe weather | Free download; IAP/subscription unknown |
| Weather | Paid | 1 | RadarScope | Radar & severe weather | Paid download; exact price pending |
| Weather | Paid | 2 | Metar-Taf Visual decoder | Aviation weather | Paid download; exact price pending |
| Weather | Paid | 3 | CARROT Weather | General forecast | Paid download; exact price pending |
| Weather | Paid | 4 | Radar Live Pro - doppler radar | Radar & severe weather | Paid download; exact price pending |
| Weather | Paid | 5 | RainAware | Other / manual review | Paid download; exact price pending |
| Weather | Paid | 6 | Radar HD Future Weather Radar | Radar & severe weather | Paid download; exact price pending |
| Weather | Paid | 7 | Weather Dock+ | Menu bar & widgets | Paid download; exact price pending |
| Weather | Paid | 8 | Wx US Weather App | General forecast | Paid download; exact price pending |
| Weather | Paid | 9 | Desktop Clock + | Weather wallpaper & desktop | Paid download; exact price pending |
| Weather | Paid | 10 | Weather-Display | General forecast | Paid download; exact price pending |
| Weather | Paid | 11 | eWeather HD - Weather & Alerts | General forecast | Paid download; exact price pending |
| Weather | Paid | 12 | Living Weather & Wallpaper Pro | Weather wallpaper & desktop | Paid download; exact price pending |
| Weather | Paid | 13 | WeatherTrack GRIB | Marine weather & tides | Paid download; exact price pending |
| Weather | Paid | 14 | Mach Desktop | Weather wallpaper & desktop | Paid download; exact price pending |
| Weather | Paid | 15 | Weather Widget Live + | Menu bar & widgets | Paid download; exact price pending |
| Weather | Paid | 16 | Live Dock Weather | Menu bar & widgets | Paid download; exact price pending |
| Weather | Paid | 17 | Deluxe Moon HD - Moon Phase Calendar | Moon & solar tracking | Paid download; exact price pending |
| Weather | Paid | 18 | Hurricane Track - NOAA Doppler | Radar & severe weather | Paid download; exact price pending |
| Weather | Paid | 19 | ClassicWeather HD | General forecast | Paid download; exact price pending |
| Weather | Paid | 20 | Tide Graph | Marine weather & tides | Paid download; exact price pending |
| Weather | Paid | 21 | Radar Extreme - NOAA Doppler | Radar & severe weather | Paid download; exact price pending |
| Weather | Paid | 22 | AeroWeather Menu Bar | Aviation weather | Paid download; exact price pending |
| Weather | Paid | 23 | Moon Phase Gadget | Moon & solar tracking | Paid download; exact price pending |
| Weather | Paid | 24 | Mach Wallpaper | Weather wallpaper & desktop | Paid download; exact price pending |

## Faz 2A kaynak indeksleri

- [Business — Top Free](https://apps.apple.com/us/mac/charts/6000?chart=top-free)
- [Business — Top Paid](https://apps.apple.com/us/mac/charts/6000?chart=top-paid)
- [Developer Tools — Top Free](https://apps.apple.com/us/mac/charts/6026?chart=top-free)
- [Developer Tools — Top Paid](https://apps.apple.com/us/mac/charts/6026?chart=top-paid)
- [Games — Top Free](https://apps.apple.com/us/mac/charts/6014?chart=top-free)
- [Games — Top Paid](https://apps.apple.com/us/mac/charts/6014?chart=top-paid)
- [Graphics & Design — Top Free](https://apps.apple.com/us/mac/charts/6027?chart=top-free)
- [Graphics & Design — Top Paid](https://apps.apple.com/us/mac/charts/6027?chart=top-paid)
- [Health & Fitness — Top Free](https://apps.apple.com/us/mac/charts/6013?chart=top-free)
- [Health & Fitness — Top Paid](https://apps.apple.com/us/mac/charts/6013?chart=top-paid)
- [Productivity — Top Free](https://apps.apple.com/us/mac/charts/6007?chart=top-free)
- [Productivity — Top Paid](https://apps.apple.com/us/mac/charts/6007?chart=top-paid)
- [Utilities — Top Free](https://apps.apple.com/us/mac/charts/6002?chart=top-free)
- [Utilities — Top Paid](https://apps.apple.com/us/mac/charts/6002?chart=top-paid)
- [Weather — Top Free](https://apps.apple.com/us/mac/charts/6001?chart=top-free)
- [Weather — Top Paid](https://apps.apple.com/us/mac/charts/6001?chart=top-paid)

## Faz 2 kapsam defteri

| Alt iş | Durum |
|---|---|
| 8 kategorinin US Top Free listesi | Tamamlandı |
| 8 kategorinin US Top Paid listesi | Tamamlandı |
| 399 chart kaydının araştırma nişi | Otomatik ön sınıflandırma tamamlandı; manuel QA bekliyor |
| `trackId/adamId`, geliştirici ve ürün URL’si | Faz 3–5 zenginleştirmesinde |
| Kesin USD ve TRY fiyatı | Faz 4–5 storefront/ürün sayfası doğrulamasında |
| Kalan kategori chart’ları | Faz 2B’de |
| Discover/Editoryal seed listeleri | Faz 2C’de |

**Sürüm:** 2A — 2 Ağustos 2026

# Faz 2B — İkinci ABD Mac Top Charts Envanteri

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Yeni kategoriler:** Education, Entertainment, Finance, Lifestyle  
**Yeni kayıt:** 200  
**Kümülatif chart kaydı:** 599  
**İsim-normalize benzersiz kayıt:** 592  
**Chart kategori kapsamı:** 12/20

> [!IMPORTANT]
> Apple’ın güncel ABD Mac Top Charts seçicisinde 20 kategori bulunuyor: Business, Developer Tools, Education, Entertainment, Finance, Games, Graphics & Design, Health & Fitness, Lifestyle, Medical, Music, News, Photo & Video, Productivity, Reference, Social Networking, Sports, Travel, Utilities ve Weather. Faz 2B sonunda bunların 12’si taranmıştır.

## Faz 2B kategori özeti

| Kategori | Free | Paid | Toplam |
|---|---:|---:|---:|
| Education | 25 | 25 | 50 |
| Entertainment | 25 | 25 | 50 |
| Finance | 25 | 25 | 50 |
| Lifestyle | 25 | 25 | 50 |
| **Yeni toplam** | **100** | **100** | **200** |

## Faz 2B pazar bulguları

- **Education:** Ücretsiz sıralama AI chatbot, flashcard, classroom ve typing ürünleriyle oldukça kalabalık. Ücretli tarafta sınav hazırlığı, erişilebilirlik, mesleki eğitim ve sınıf yönetimi daha güçlü.
- **Entertainment:** Ücretsiz pazar streaming wrapper’ları, medya oynatıcıları ve bölgesel video istemcileriyle dolu. Ücretli tarafta IPTV, Plex/Jellyfin istemcileri, console remote ve ekran koruyucular öne çıkıyor.
- **Finance:** Ücretsiz sıralamada yatırım, trading, kripto ve abonelikli bütçe ürünleri baskın. Ücretli tarafta gizlilik odaklı kişisel finans, checkbook, döviz ve tek amaçlı finansal hesap araçları bulunuyor.
- **Lifestyle:** Kategori oldukça dağınık; web-wrapper, smart-home, home design, tarif, günlük, kamera, evcil hayvan ve dini araçları aynı listede barındırıyor. Bu durum mikro-niş uygulamaların görünürlük kazanabileceğini gösteriyor.
- **Tek seferlik ödeme fırsatı:** Uzman eğitim, kişisel finans, IPTV/media client, recipe manager, baby/pet monitor ve home/garden planning alanlarında paid chart görünürlüğü devam ediyor.
- **Düşük kaliteli rekabet riski:** YouTube/Netflix wrapper’ları, genel AI chatbot’lar, trading chart kopyaları ve widget uygulamalarında isim/işlev benzerliği çok yüksek.

## Yeni niş dağılımı

| Araştırma nişi | Kayıt |
|---|---:|
| Other / manual review | 27 |
| Budgeting & personal finance | 12 |
| Trading & market analysis | 11 |
| Streaming services & wrappers | 9 |
| IPTV & live TV | 7 |
| AI tutor & writing | 6 |
| School & classroom management | 6 |
| Desktop widgets & personalization | 6 |
| Exam & certification prep | 5 |
| Coding education | 5 |
| Language & accessibility learning | 5 |
| Media player & library client | 5 |
| Visual entertainment & screensavers | 5 |
| Game streaming & emulation | 5 |
| Checkbook & check printing | 5 |
| Media lifestyle | 5 |
| Home, garden & landscape design | 5 |
| Baby & pet monitoring | 5 |
| Flashcards & quizzes | 4 |
| Typing & keyboard learning | 4 |
| Financial calculators | 4 |
| Shopping, inspiration & registry | 4 |
| Children's educational games | 3 |
| Practical skills training | 3 |
| Crypto wallet & trading | 3 |
| Currency conversion | 3 |
| Journal & personal organization | 3 |
| Smart home | 3 |
| Math & statistics | 2 |
| Geography & earth science | 2 |
| Anime & regional video | 2 |
| Interactive simulation & viewer | 2 |
| Audio visualization & processing | 2 |
| Credit cards & installment tracking | 2 |
| Debt & loan calculators | 2 |
| Recipes & cooking | 2 |
| Camera companion | 2 |
| Audiobook creation | 2 |
| Screen mirroring | 1 |
| Casual game | 1 |
| Bills & subscription tracking | 1 |
| Tax | 1 |
| Vehicle expense tracking | 1 |
| Puzzle | 1 |
| Real estate | 1 |
| Religion & spiritual practice | 1 |
| Keep-awake utility | 1 |
| Screensaver | 1 |
| Radio & aviation hobby | 1 |
| Network monitoring | 1 |

## Faz 2B uygulama envanteri

| Kategori | Liste | Sıra | Uygulama | Araştırma nişi | Fiyat durumu |
|---|---|---:|---|---|---|
| Education | Free | 1 | AI ChatbotㆍAsk AI Anything 5.4 | AI tutor & writing | Free download; IAP/subscription unknown |
| Education | Free | 2 | Chatbot: Ask Chat AI Assistant | AI tutor & writing | Free download; IAP/subscription unknown |
| Education | Free | 3 | Bluebook Exams | Exam & certification prep | Free download; IAP/subscription unknown |
| Education | Free | 4 | Ask AI Chat Bot Anything | AI tutor & writing | Free download; IAP/subscription unknown |
| Education | Free | 5 | Canvas by Instructure | School & classroom management | Free download; IAP/subscription unknown |
| Education | Free | 6 | Anki Notes: Flashcards Maker | Flashcards & quizzes | Free download; IAP/subscription unknown |
| Education | Free | 7 | Quizlet : Flashcards & Quizzes | Flashcards & quizzes | Free download; IAP/subscription unknown |
| Education | Free | 8 | Swift Playground | Coding education | Free download; IAP/subscription unknown |
| Education | Free | 9 | Chat Unlimited & Ask Brutus AI | Other / manual review | Free download; IAP/subscription unknown |
| Education | Free | 10 | ACT Gateway | Exam & certification prep | Free download; IAP/subscription unknown |
| Education | Free | 11 | Kahoot! Play & Create Quizzes | Flashcards & quizzes | Free download; IAP/subscription unknown |
| Education | Free | 12 | App for Google Classroom º | School & classroom management | Free download; IAP/subscription unknown |
| Education | Free | 13 | Acellus | Other / manual review | Free download; IAP/subscription unknown |
| Education | Free | 14 | Master of Typing: Tutor | Typing & keyboard learning | Free download; IAP/subscription unknown |
| Education | Free | 15 | Toca Boca World: Game & Play | Children's educational games | Free download; IAP/subscription unknown |
| Education | Free | 16 | Rosetta Stone Classic-2024 | Language & accessibility learning | Free download; IAP/subscription unknown |
| Education | Free | 17 | School Assistant – Planner | School & classroom management | Free download; IAP/subscription unknown |
| Education | Free | 18 | Typing Land | Typing & keyboard learning | Free download; IAP/subscription unknown |
| Education | Free | 19 | AI Assistant AI Chat Bot | AI tutor & writing | Free download; IAP/subscription unknown |
| Education | Free | 20 | ClassLink LaunchPad Extension | School & classroom management | Free download; IAP/subscription unknown |
| Education | Free | 21 | 不背单词-真实语境学英语单词 | Other / manual review | Free download; IAP/subscription unknown |
| Education | Free | 22 | Scratch | Coding education | Free download; IAP/subscription unknown |
| Education | Free | 23 | Grammar Checker : Spell Check AI | AI tutor & writing | Free download; IAP/subscription unknown |
| Education | Free | 24 | Animal Typing - Lite | Typing & keyboard learning | Free download; IAP/subscription unknown |
| Education | Free | 25 | Calculate84 | Math & statistics | Free download; IAP/subscription unknown |
| Education | Paid | 1 | IPA Keyboard | Typing & keyboard learning | Paid download; exact USD/TRY pending |
| Education | Paid | 2 | Dyslexia fonts - Accessibility | Language & accessibility learning | Paid download; exact USD/TRY pending |
| Education | Paid | 3 | FAA A&P Powerplant Test Prep | Exam & certification prep | Paid download; exact USD/TRY pending |
| Education | Paid | 4 | DriveFocus 2.0 | Practical skills training | Paid download; exact USD/TRY pending |
| Education | Paid | 5 | ASA's Sailing Challenge | Practical skills training | Paid download; exact USD/TRY pending |
| Education | Paid | 6 | WeaveIt | Practical skills training | Paid download; exact USD/TRY pending |
| Education | Paid | 7 | Earth 3D - World Atlas | Geography & earth science | Paid download; exact USD/TRY pending |
| Education | Paid | 8 | Earth Experience | Geography & earth science | Paid download; exact USD/TRY pending |
| Education | Paid | 9 | CCM Glossary App | Other / manual review | Paid download; exact USD/TRY pending |
| Education | Paid | 10 | Simplex Spelling Phonics 1 | Language & accessibility learning | Paid download; exact USD/TRY pending |
| Education | Paid | 11 | Pinyin - Chinese Pronunciation | Language & accessibility learning | Paid download; exact USD/TRY pending |
| Education | Paid | 12 | Regression Analysis | Math & statistics | Paid download; exact USD/TRY pending |
| Education | Paid | 13 | QuickScan for Schools | School & classroom management | Paid download; exact USD/TRY pending |
| Education | Paid | 14 | Learn Raspberry Pi Pico Pro | Coding education | Paid download; exact USD/TRY pending |
| Education | Paid | 15 | Learn Python Data Science | Coding education | Paid download; exact USD/TRY pending |
| Education | Paid | 16 | AI 50 Guide | AI tutor & writing | Paid download; exact USD/TRY pending |
| Education | Paid | 17 | Flashcards Deluxe | Flashcards & quizzes | Paid download; exact USD/TRY pending |
| Education | Paid | 18 | iDoceo - Planner and gradebook | School & classroom management | Paid download; exact USD/TRY pending |
| Education | Paid | 19 | Zoombinis | Children's educational games | Paid download; exact USD/TRY pending |
| Education | Paid | 20 | First Grade Learning Games | Children's educational games | Paid download; exact USD/TRY pending |
| Education | Paid | 21 | Hacktivate: Education Edition | Coding education | Paid download; exact USD/TRY pending |
| Education | Paid | 22 | FAA A&P General Test Prep | Exam & certification prep | Paid download; exact USD/TRY pending |
| Education | Paid | 23 | PDG PROmote | Exam & certification prep | Paid download; exact USD/TRY pending |
| Education | Paid | 24 | Team Shake | Other / manual review | Paid download; exact USD/TRY pending |
| Education | Paid | 25 | Proloquo2Go | Language & accessibility learning | Paid download; exact USD/TRY pending |
| Entertainment | Free | 1 | Amazon Prime Video | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 2 | Streaming for Netflix | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 3 | Friendly Streaming Browser | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 4 | Teleparty - Watch TV Together | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 5 | Crunchy Anime Browser | Anime & regional video | Free download; IAP/subscription unknown |
| Entertainment | Free | 6 | Elmedia Video Player | Media player & library client | Free download; IAP/subscription unknown |
| Entertainment | Free | 7 | Infuse | Media player & library client | Free download; IAP/subscription unknown |
| Entertainment | Free | 8 | Easy Streaming | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 9 | Streaming Player for Peacock TV | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 10 | 优酷视频-黑夜告白 | Other / manual review | Free download; IAP/subscription unknown |
| Entertainment | Free | 11 | 爱奇艺-这一秒过火 | Other / manual review | Free download; IAP/subscription unknown |
| Entertainment | Free | 12 | 腾讯视频-这一秒过火暑期必看爽剧 | Other / manual review | Free download; IAP/subscription unknown |
| Entertainment | Free | 13 | Dynamic Wallpaper Library | Visual entertainment & screensavers | Free download; IAP/subscription unknown |
| Entertainment | Free | 14 | Asobi: Remote Play | Game streaming & emulation | Free download; IAP/subscription unknown |
| Entertainment | Free | 15 | bilibili - All Your Fav Videos | Anime & regional video | Free download; IAP/subscription unknown |
| Entertainment | Free | 16 | App For Netflix. | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 17 | Midori: Remote Play | Game streaming & emulation | Free download; IAP/subscription unknown |
| Entertainment | Free | 18 | VidHub -Video Library & Player | Media player & library client | Free download; IAP/subscription unknown |
| Entertainment | Free | 19 | App for YouTube · Player | Other / manual review | Free download; IAP/subscription unknown |
| Entertainment | Free | 20 | Moonfin | Other / manual review | Free download; IAP/subscription unknown |
| Entertainment | Free | 21 | SenPlayer - Media Player | Media player & library client | Free download; IAP/subscription unknown |
| Entertainment | Free | 22 | Phone Mirroring: Mirror to Mac | Screen mirroring | Free download; IAP/subscription unknown |
| Entertainment | Free | 23 | Tubi TV+ | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Free | 24 | Game Emulator - PS1, GBA, DS | Game streaming & emulation | Free download; IAP/subscription unknown |
| Entertainment | Free | 25 | PBS: Watch TV & Documentaries | Streaming services & wrappers | Free download; IAP/subscription unknown |
| Entertainment | Paid | 1 | Console Remote | Game streaming & emulation | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 2 | IPTV Smart Pro - Live TV | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 3 | iSTB | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 4 | MKStreamer | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 5 | Reelo - Media Hub | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 6 | Algodoo Physics | Interactive simulation & viewer | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 7 | Plezy for Plex & Jellyfin | Media player & library client | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 8 | DAV Player | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 9 | TV Launcher - Live US Channels | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 10 | Magic Trail - Mouse Effects | Visual entertainment & screensavers | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 11 | Sharks 3D | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 12 | My Christmas Tree - Countdown | Visual entertainment & screensavers | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 13 | DDi Codec — for Dolby B/C NR | Audio visualization & processing | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 14 | Tv-Box | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 15 | Tivimax IPTV Player (Premium) | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 16 | Macgo Blu-ray Player Pro | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 17 | Aquarium Live HD+ | Visual entertainment & screensavers | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 18 | ProVisHD Music Visualizer | Audio visualization & processing | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 19 | Console Link | Game streaming & emulation | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 20 | Purple Crow For Safari | Other / manual review | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 21 | StbEmuTV (Premium) | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 22 | GSE SMART IPTV PRO | IPTV & live TV | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 23 | Fireplace Live HD+ | Visual entertainment & screensavers | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 24 | STEP and IGES File Viewer | Interactive simulation & viewer | Paid download; exact USD/TRY pending |
| Entertainment | Paid | 25 | FREECELL Ultimate | Casual game | Paid download; exact USD/TRY pending |
| Finance | Free | 1 | Webull: Advanced Trading | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 2 | Trading Charts View & Insights | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 3 | Copilot: Track & Budget Money | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 4 | Ledger Wallet™ crypto app | Crypto wallet & trading | Free download; IAP/subscription unknown |
| Finance | Free | 5 | Trump Accounts: Official App | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 6 | Trading Pro – Stocks Charts | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 7 | 同花顺-股票炒股软件 | Other / manual review | Free download; IAP/subscription unknown |
| Finance | Free | 8 | fomo - never miss out | Crypto wallet & trading | Free download; IAP/subscription unknown |
| Finance | Free | 9 | Expenses: Spending Tracker | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 10 | moomoo - Trade Stock & Option | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 11 | Trading Charts - Track Markets | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 12 | MetaTrader 5 | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 13 | 东方财富-股票开户证券炒股理财 | Other / manual review | Free download; IAP/subscription unknown |
| Finance | Free | 14 | Fleur - Budget Planner App | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 15 | CheckBook Pro 3 | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 16 | Trading Insights - AI Charts | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 17 | Money: Budget, Expense Tracker | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 18 | CardPointers for Credit Cards | Credit cards & installment tracking | Free download; IAP/subscription unknown |
| Finance | Free | 19 | Chronicle - Bill Organizer | Bills & subscription tracking | Free download; IAP/subscription unknown |
| Finance | Free | 20 | Budget Planner - Money Flow | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Free | 21 | Kalshi: Trade Events & Sports | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 22 | Chand | Currency conversion | Free download; IAP/subscription unknown |
| Finance | Free | 23 | Trust: Crypto & Bitcoin Wallet | Crypto wallet & trading | Free download; IAP/subscription unknown |
| Finance | Free | 24 | Futubull Legacy | Trading & market analysis | Free download; IAP/subscription unknown |
| Finance | Free | 25 | MM-Tweaks for Monarch Money | Budgeting & personal finance | Free download; IAP/subscription unknown |
| Finance | Paid | 1 | Money Pro: Personal Finance | Budgeting & personal finance | Paid download; exact USD/TRY pending |
| Finance | Paid | 2 | Moneydance 2024 | Budgeting & personal finance | Paid download; exact USD/TRY pending |
| Finance | Paid | 3 | Debt Lifter | Debt & loan calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 4 | Simple Register | Checkbook & check printing | Paid download; exact USD/TRY pending |
| Finance | Paid | 5 | StockSpy | Trading & market analysis | Paid download; exact USD/TRY pending |
| Finance | Paid | 6 | SEE Finance 3 | Other / manual review | Paid download; exact USD/TRY pending |
| Finance | Paid | 7 | My Money - Personal Accounting | Other / manual review | Paid download; exact USD/TRY pending |
| Finance | Paid | 8 | WISO Steuer 2026 | Tax | Paid download; exact USD/TRY pending |
| Finance | Paid | 9 | Just Checking | Checkbook & check printing | Paid download; exact USD/TRY pending |
| Finance | Paid | 10 | Accounts and Balances | Budgeting & personal finance | Paid download; exact USD/TRY pending |
| Finance | Paid | 11 | PayIn4 Total | Credit cards & installment tracking | Paid download; exact USD/TRY pending |
| Finance | Paid | 12 | MathU 12D Financial Calculator | Financial calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 13 | Bank Check Printer | Checkbook & check printing | Paid download; exact USD/TRY pending |
| Finance | Paid | 14 | Chekchek | Checkbook & check printing | Paid download; exact USD/TRY pending |
| Finance | Paid | 15 | CalcTape Paper Tape Calculator | Financial calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 16 | Walletry: Legacy | Budgeting & personal finance | Paid download; exact USD/TRY pending |
| Finance | Paid | 17 | Road Trip HD | Vehicle expense tracking | Paid download; exact USD/TRY pending |
| Finance | Paid | 18 | Profit Calculator : ProfitPal | Financial calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 19 | CheckCraft | Checkbook & check printing | Paid download; exact USD/TRY pending |
| Finance | Paid | 20 | triFX – Currency Converter | Currency conversion | Paid download; exact USD/TRY pending |
| Finance | Paid | 21 | Loan Calc | Debt & loan calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 22 | Exchange Rates 4 | Currency conversion | Paid download; exact USD/TRY pending |
| Finance | Paid | 23 | Trade Size stock trading risk | Trading & market analysis | Paid download; exact USD/TRY pending |
| Finance | Paid | 24 | MathU RPN Calc | Financial calculators | Paid download; exact USD/TRY pending |
| Finance | Paid | 25 | Webpage Background | Other / manual review | Paid download; exact USD/TRY pending |
| Lifestyle | Free | 1 | Save to Pinterest | Shopping, inspiration & registry | Free download; IAP/subscription unknown |
| Lifestyle | Free | 2 | App for YouTube • Watch YT | Media lifestyle | Free download; IAP/subscription unknown |
| Lifestyle | Free | 3 | Streaming Master | Media lifestyle | Free download; IAP/subscription unknown |
| Lifestyle | Free | 4 | PayPal Honey for Safari | Shopping, inspiration & registry | Free download; IAP/subscription unknown |
| Lifestyle | Free | 5 | MacWidget - Desktop Widgets | Desktop widgets & personalization | Free download; IAP/subscription unknown |
| Lifestyle | Free | 6 | Day One | Journal & personal organization | Free download; IAP/subscription unknown |
| Lifestyle | Free | 7 | Home Assistant | Smart home | Free download; IAP/subscription unknown |
| Lifestyle | Free | 8 | Planner 5D - AI Home Design | Home, garden & landscape design | Free download; IAP/subscription unknown |
| Lifestyle | Free | 9 | Brother P-touch Editor | Other / manual review | Free download; IAP/subscription unknown |
| Lifestyle | Free | 10 | Add to Zola Button | Shopping, inspiration & registry | Free download; IAP/subscription unknown |
| Lifestyle | Free | 11 | 4Plan Home & Interior Planner | Home, garden & landscape design | Free download; IAP/subscription unknown |
| Lifestyle | Free | 12 | iSudoku - Sudoku & Minesweeper | Puzzle | Free download; IAP/subscription unknown |
| Lifestyle | Free | 13 | Mela – Recipe Manager | Recipes & cooking | Free download; IAP/subscription unknown |
| Lifestyle | Free | 14 | Desktop Verse | Other / manual review | Free download; IAP/subscription unknown |
| Lifestyle | Free | 15 | Creators Mobile APP-Creator's | Other / manual review | Free download; IAP/subscription unknown |
| Lifestyle | Free | 16 | Pets Therapy - Desktop Pets | Baby & pet monitoring | Free download; IAP/subscription unknown |
| Lifestyle | Free | 17 | Camera Connect-Camera Transfer | Camera companion | Free download; IAP/subscription unknown |
| Lifestyle | Free | 18 | Digital Clock - Bedside Alarm | Desktop widgets & personalization | Free download; IAP/subscription unknown |
| Lifestyle | Free | 19 | Planner & Journal - Zinnia | Journal & personal organization | Free download; IAP/subscription unknown |
| Lifestyle | Free | 20 | iScape: Landscape Design | Home, garden & landscape design | Free download; IAP/subscription unknown |
| Lifestyle | Free | 21 | Add to MyRegistry.com Button | Shopping, inspiration & registry | Free download; IAP/subscription unknown |
| Lifestyle | Free | 22 | Controller for HomeKit | Smart home | Free download; IAP/subscription unknown |
| Lifestyle | Free | 23 | Zillow Real Estate & Rentals | Real estate | Free download; IAP/subscription unknown |
| Lifestyle | Free | 24 | App for YouTube: Ad-Free Video | Media lifestyle | Free download; IAP/subscription unknown |
| Lifestyle | Free | 25 | Streaming Browser: TV & Movies | Media lifestyle | Free download; IAP/subscription unknown |
| Lifestyle | Paid | 1 | Paprika Recipe Manager 3 | Recipes & cooking | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 2 | AudioBo • Audiobook Maker | Audiobook creation | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 3 | Cloud Baby Monitor | Baby & pet monitoring | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 4 | Audiobook Builder 2 | Audiobook creation | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 5 | Organize GoPro Files | Camera companion | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 6 | Universalis | Religion & spiritual practice | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 7 | Remember: Stickies Widget | Desktop widgets & personalization | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 8 | Dog Monitor | Baby & pet monitoring | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 9 | Bears Countdown | Desktop widgets & personalization | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 10 | Caffeinate. | Keep-awake utility | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 11 | Big Day Countdown + | Desktop widgets & personalization | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 12 | Aether | Other / manual review | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 13 | Code Rain SS | Screensaver | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 14 | PrinTodo | Journal & personal organization | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 15 | Step Outs | Other / manual review | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 16 | Blu-ray Player Pro· | Media lifestyle | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 17 | HomeCam for HomeKit | Smart home | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 18 | Baby Monitor 3G | Baby & pet monitoring | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 19 | Pet Monitor VIGI | Baby & pet monitoring | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 20 | Garden Planner | Home, garden & landscape design | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 21 | LunarCal | Other / manual review | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 22 | Desktop Stickers | Desktop widgets & personalization | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 23 | Yard Planner | Home, garden & landscape design | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 24 | ACARS | Radio & aviation hobby | Paid download; exact USD/TRY pending |
| Lifestyle | Paid | 25 | ClashX Pro :Service Monitoring | Network monitoring | Paid download; exact USD/TRY pending |

## Faz 2B kaynakları

- [Education — Top Free](https://apps.apple.com/us/mac/charts/6017?chart=top-free)
- [Education — Top Paid](https://apps.apple.com/us/mac/charts/6017?chart=top-paid)
- [Entertainment — Top Free](https://apps.apple.com/us/mac/charts/6016?chart=top-free)
- [Entertainment — Top Paid](https://apps.apple.com/us/mac/charts/6016?chart=top-paid)
- [Finance — Top Free](https://apps.apple.com/us/mac/charts/6015?chart=top-free)
- [Finance — Top Paid](https://apps.apple.com/us/mac/charts/6015?chart=top-paid)
- [Lifestyle — Top Free](https://apps.apple.com/us/mac/charts/6012?chart=top-free)
- [Lifestyle — Top Paid](https://apps.apple.com/us/mac/charts/6012?chart=top-paid)

## Kümülatif Faz 2 kapsamı

| Durum | Değer |
|---|---:|
| Taranan chart kategorisi | 12 / 20 |
| Taranan Free/Paid listesi | 24 |
| Toplam chart kaydı | 599 |
| İsim-normalize benzersiz kayıt | 592 |
| Tamamlanan kategoriler | Business, Developer Tools, Education, Entertainment, Finance, Games, Graphics & Design, Health & Fitness, Lifestyle, Productivity, Utilities, Weather |
| Faz 2C’de kalan kategoriler | Medical, Music, News, Photo & Video, Reference, Social Networking, Sports, Travel |

**Sürüm:** 2B — 2 Ağustos 2026

# Faz 2C — ABD Mac Top Charts Kategori Taraması Tamamlandı

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Yeni kategoriler:** Medical, Music, News, Photo & Video, Reference, Social Networking, Sports, Travel  
**Yeni chart kaydı:** 400  
**Kümülatif chart kaydı:** 999  
**İsim-normalize benzersiz kayıt:** 990  
**Chart kategori kapsamı:** 20/20

> [!IMPORTANT]
> 20/20 kategori tamamlanması, Mac App Store’daki bütün uygulamaların tamamlandığı anlamına gelmez. Bu yalnızca Apple’ın ABD Mac Top Free ve Top Paid listelerindeki **chart seed** katmanının tamamlandığı anlamına gelir. Faz 3’te chart dışındaki uzun kuyruk uygulamalar kategori, arama terimi, storefront ve geliştirici sorgularıyla eklenecektir.

## Kümülatif chart kapsamı

| Ölçüm | Değer |
|---|---:|
| Kategori | 20 / 20 |
| Free/Paid listesi | 40 |
| Chart placement kaydı | 999 |
| İsim-normalize benzersiz kayıt | 990 |
| Her listeden alınan kayıt | 25 |
| Storefront | ABD |

## Kullanım, indirme ve aktif kullanıcı verisi politikası

Apple, rakip uygulamaların kesin indirme ve aktif kullanıcı sayılarını herkese açık App Store ürün sayfalarında yayımlamaz. Bu araştırmada aşağıdaki kanıt sınıfları kullanılacaktır:

| Kod | Veri türü | Nasıl yazılacak? | Güven |
|---|---|---|---|
| OWNER-EXACT | Geliştiricinin kendi App Store Connect verisi | İlk indirme, yeniden indirme, aktif cihaz, oturum, ödeme yapan kullanıcı ve aktif plan; yalnızca erişim veya doğrulanmış açıklama varsa | Çok yüksek |
| DISCLOSED | Şirket/geliştirici tarafından açıklanmış sayı | Kaynak, tarih, platform ve metrik kapsamı zorunlu | Yüksek |
| THIRD-PARTY | Sensor Tower, data.ai veya benzeri tahmin | Açıkça `tahmin` denecek; ülke, dönem ve platform kapsamı ayrı yazılacak | Orta / düşük |
| PUBLIC-PROXY | Puan sayısı, chart sırası, Google Trends, web trafiği, GitHub yıldızı vb. | Kullanıcı/indirme sayısı gibi sunulmayacak; yalnızca talep sinyali | Düşük |
| NONE | Veri yok | `Kamuya açık güvenilir sayı bulunamadı` | N/A |

### Zorunlu kullanım alanları

Her uygulama için aşağıdaki sütunlar eklenecek veya geriye dönük doldurulacaktır:

- `download_value`, `download_period`, `download_scope`, `download_source`, `download_is_estimate`
- `active_users_value`, `active_users_period`, `active_users_scope`, `active_users_source`
- `rating_count`, `rating_storefront`, `rating_observed_at`
- `chart_category`, `chart_type`, `chart_rank`, `chart_observed_at`
- `demand_proxy_score`, `demand_proxy_explanation`, `metric_confidence`

> [!WARNING]
> Universal iPhone/iPad/Mac uygulamalarında üçüncü taraf indirme tahmini çoğu zaman yalnızca iOS mobil kapsamını veya birleşik uygulamayı gösterebilir. Mac’e özel rakam açıkça ayrılmıyorsa veri `Mac indirmesi` olarak yazılmayacaktır.

## Faz 2C pazar sinyalleri

- **Medical:** DICOM görüntüleme ve anatomi ürünleri ücretli chart’ın büyük bölümünü oluşturuyor; profesyonel tek amaçlı Mac yazılımı için ödeme isteği yüksek.
- **Music:** DAW, canlı performans, synthesizer, metadata, sheet music ve practice araçlarında hem ücretsiz hem ücretli güçlü talep var.
- **News:** Ücretli listede RSS/read-later ürünleri hâlâ belirgin; abonelik yerine tek seferlik, sakin ve yerel okuma deneyimi canlı bir niş.
- **Photo & Video:** Profesyonel video düzenleme yanında duplicate cleanup, shutter count, conversion, camera control ve astro-photo gibi dar yardımcı araçlar ücretli listede görünür.
- **Reference:** Dini referans, sözlük, astronomi, koleksiyon ve regülasyon araçları; offline/lifetime ürün için uygun.
- **Social Networking:** Ücretsiz listede büyük platform wrapper’ları yoğun; ücretli listede platform kontrolü, menu-bar client ve içerik filtreleme gibi yardımcı nişler bulunuyor.
- **Sports:** Ücretsiz listede streaming, fantasy ve takım yönetimi; ücretli listede scoring, coaching, golf, dalış ve veri dönüştürme araçları öne çıkıyor.
- **Travel:** Ücretsiz listede marka/booking ve flight tracking; ücretli listede GPX, offline map, packing ve road-trip araçları yoğun.

## Yeni niş dağılımı

| Araştırma nişi | Kayıt |
|---|---:|
| Other / manual review | 38 |
| RSS & feed readers | 17 |
| Social platform client | 16 |
| Bible & Christian reference | 13 |
| Anatomy education | 11 |
| DICOM & medical imaging | 11 |
| Messaging | 11 |
| Publisher & general news | 9 |
| Other / likely miscategorized | 9 |
| Video editing & post-production | 9 |
| Dictionary & thesaurus | 9 |
| GPS, GPX & offline maps | 9 |
| Flights & flight tracking | 8 |
| Photo editing | 7 |
| Translation & language | 7 |
| Mind sports & games | 6 |
| Trip planning & journaling | 6 |
| DAW & audio production | 5 |
| Music library & metadata | 5 |
| Camera companion & control | 5 |
| Coaching & team management | 5 |
| Scoring & statistics | 5 |
| Maps & route planning | 5 |
| Outdoor travel | 5 |
| Accommodation & rewards | 5 |
| Clinical communication & practice | 4 |
| Patient portal & health benefits | 4 |
| Specialist clinical tools | 4 |
| DJ & beat making | 4 |
| Sheet music & backing tracks | 4 |
| Public-safety alerts | 4 |
| Media player | 4 |
| Screen, webcam & streaming capture | 4 |
| Media conversion & encoding | 4 |
| Community & group chat | 4 |
| Football / soccer | 4 |
| Patient monitoring | 3 |
| Drug & clinical reference | 3 |
| Music widgets & mini players | 3 |
| Playlist transfer | 3 |
| Hardware & mixer control | 3 |
| Music players | 3 |
| Audio conversion & burning | 3 |
| Live performance & worship | 3 |
| Synthesizer & effects | 3 |
| Podcast | 3 |
| Animation & motion graphics | 3 |
| Astronomy | 3 |
| Video meetings | 3 |
| Sports streaming | 3 |
| Golf | 3 |
| Fantasy sports | 3 |
| Diving & marine | 3 |
| Packing lists | 3 |
| Clinical documentation & AI scribe | 2 |
| Music practice | 2 |
| Read later | 2 |
| News ticker & menu bar | 2 |
| AI image generation & enhancement | 2 |
| Photo cleanup | 2 |
| Camera shutter count | 2 |
| Movie catalogue | 2 |
| Game reference | 2 |
| Islamic reference | 2 |
| Collectibles | 2 |
| Law, regulation & government | 2 |
| YouTube browser control | 2 |
| Cycling & indoor training | 2 |
| Motorsport & racing | 2 |
| Activity logs & maps | 2 |
| Travel utilities | 2 |
| Travel rewards | 2 |
| Medical exam preparation | 1 |
| Pregnancy calculator | 1 |
| Dental | 1 |
| Dietary clinical guidance | 1 |
| Music identification | 1 |
| Karaoke | 1 |
| Music visualization | 1 |
| Web capture / miscategorized | 1 |
| Community news reader | 1 |
| Photo printing | 1 |
| Astrophotography | 1 |
| Offline knowledge library | 1 |
| Apple hardware reference | 1 |
| Utility / likely miscategorized | 1 |
| Computational knowledge | 1 |
| Historical atlas | 1 |
| Location sharing | 1 |
| Federated social | 1 |
| Email client / miscategorized | 1 |
| Dating | 1 |
| Baseball | 1 |
| Tennis & pickleball | 1 |
| Predictions & regulated picks | 1 |
| Basketball | 1 |
| Sports timer | 1 |
| Cricket | 1 |
| Cruise | 1 |
| Travel documents | 1 |
| Traffic cameras | 1 |
| Driver exam preparation | 1 |

## Faz 2C uygulama envanteri

| Kategori | Liste | Sıra | Uygulama | Araştırma nişi | Fiyat durumu | Kamuya açık kesin Mac kullanım/indirme |
|---|---|---:|---|---|---|---|
| Medical | Free | 1 | Complete Anatomy 3D Human Body Atlas & Courses | Anatomy education | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 2 | Epic Hyperspace | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 3 | Bee DICOM Viewer | DICOM & medical imaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 4 | LabRange Desktop | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 5 | IMV Dicom Viewer | DICOM & medical imaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 6 | Anatomy Learning - 3D Anatomy | Anatomy education | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 7 | AHA eBook Reader | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 8 | Anatomy 3D Atlas | Anatomy education | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 9 | Healthy Roster | Clinical communication & practice | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 10 | TigerConnect for Desktop | Clinical communication & practice | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 11 | Falcon Mx | DICOM & medical imaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 12 | Docket® - Immunization Records | Patient portal & health benefits | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 13 | Lilly Health™ | Patient portal & health benefits | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 14 | VA: Health and Benefits | Patient portal & health benefits | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 15 | Hearing Aid • Ear booster | Patient monitoring | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 16 | Freed - AI Scribe & Assistant | Clinical documentation & AI scribe | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 17 | Nursing Drug Handbook - NDH | Drug & clinical reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 18 | Medscape | Drug & clinical reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 19 | Davis's Drug Guide - Nurses | Drug & clinical reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 20 | MYIO | Clinical communication & practice | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 21 | Luka Mini – Glucose Readings | Patient monitoring | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 22 | Solventum Fluency Direct | Clinical documentation & AI scribe | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 23 | Human Anatomy Atlas + | Anatomy education | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 24 | Symplast Practice | Clinical communication & practice | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Free | 25 | Aetna Better Health - Medicaid | Patient portal & health benefits | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 1 | DICOM Quicklook by OsiriX | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 2 | DICOMpocket | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 3 | DCM Viewer | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 4 | Gray's Anatomy Premium Edition | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 5 | DICOM Viewer Pro | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 6 | 3D Human Anatomy Atlas 2026 | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 7 | Donut DICOM Viewer | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 8 | EMT PASS (new) | Medical exam preparation | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 9 | Pregnancy Wheel HD | Pregnancy calculator | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 10 | Miele-LXIV | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 11 | Essential Anatomy 5 | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 12 | Dental Professional | Dental | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 13 | Monash FODMAP Diet | Dietary clinical guidance | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 14 | Dicom Pilot | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 15 | OptoDrum | Specialist clinical tools | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 16 | Recognise Knee | Specialist clinical tools | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 17 | EP Calipers | Specialist clinical tools | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 18 | Gross Anatomy of the Skeleton | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 19 | Recognise | Specialist clinical tools | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 20 | Viewin Dicom Viewer | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 21 | Espresso Ray | DICOM & medical imaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 22 | Muscle Premium | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 23 | Anatomy & Physiology | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 24 | Weight-Monitor | Patient monitoring | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Medical | Paid | 25 | Surgical Anatomy - Premium Edition | Anatomy education | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 1 | VinylPod - Music Widget | Music widgets & mini players | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 2 | Logic Pro: Make Music | DAW & audio production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 3 | Silicio: Widgets + Mini Player | Music widgets & mini players | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 4 | djay - DJ App & AI Mixer | DJ & beat making | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 5 | PlaylistPort：Playlist Transfer | Playlist transfer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 6 | Shazam: Identify Songs | Music identification | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 7 | VirtualDJ | DJ & beat making | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 8 | TunesMechanic for iTunes | Music library & metadata | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 9 | Audio One: Easy Music Editing | DAW & audio production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 10 | X-AIR Edit | Hardware & mixer control | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 11 | Menu Bar Controller for Sonos | Hardware & mixer control | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 12 | [untitled] for Desktop | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 13 | X32 Edit | Hardware & mixer control | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 14 | Music Player : Songs Streaming | Music players | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 15 | Playlist for Spotify ® | Playlist transfer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 16 | MainStage: Perform Live | Music library & metadata | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 17 | Playlisty for Spotify | Playlist transfer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 18 | Transitions DJ | DJ & beat making | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 19 | To MP3 Converter 2 | Audio conversion & burning | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 20 | Musicnotes Sheet Music Player | Sheet music & backing tracks | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 21 | Remixlive - Make Music & Beats | DJ & beat making | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 22 | Playback | Live performance & worship | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 23 | Fidelia — Audiophile Player | Music players | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 24 | n-Track Studio DAW | DAW & audio production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Free | 25 | KaraFun: Karaoke, Battle, Quiz | Karaoke | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 1 | Logic Pro | DAW & audio production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 2 | MainStage | Music library & metadata | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 3 | forScore | Sheet music & backing tracks | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 4 | FL Studio Mobile | DAW & audio production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 5 | Mp3tag | Music library & metadata | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 6 | iReal Pro | Sheet music & backing tracks | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 7 | NaviBeat | Music players | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 8 | Minimoog Model D Synthesizer | Synthesizer & effects | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 9 | DelayScaper | Synthesizer & effects | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 10 | SongBook | Sheet music & backing tracks | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 11 | Metadatics | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 12 | AutoPad — Ambient Pad Loops | Live performance & worship | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 13 | Model 15 Modular Synthesizer | Synthesizer & effects | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 14 | MIDI Tape Recorder | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 15 | PanTunes | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 16 | Pro Audio Converter | Audio conversion & burning | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 17 | PolyNome: THE Metronome | Music practice | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 18 | Anytune: Practice Perfected | Music practice | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 19 | Export for iTunes | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 20 | CD Burn Pro - Music CD | Audio conversion & burning | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 21 | Studio Field | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 22 | PadLab - Live Pads | Live performance & worship | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 23 | Audio Tag Editor - MP3 & ID3 | Music library & metadata | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 24 | Phosphor Visualizer | Music visualization | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Music | Paid | 25 | Sleeve for Spotify, Music | Music widgets & mini players | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 1 | Ground News | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 2 | Noticias KGNS Telemundo | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 3 | Reeder. | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 4 | FireShot: Web Page Screenshots | Web capture / miscategorized | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 5 | Fox Sports 1510 KMND | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 6 | Instapaper | Read later | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 7 | World News App | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 8 | ONN : Live & Breaking News | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 9 | WSJ Print Edition | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 10 | AP News | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 11 | Unread: An RSS Reader | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 12 | Police Scanner Radio & Fire | Public-safety alerts | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 13 | Police Scanner: Crime Radar | Public-safety alerts | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 14 | Newsify: RSS Reader | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 15 | WACH FOX Mobile | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 16 | Folo - AI Reader | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 17 | NewsBreak: Local News & Alerts | Public-safety alerts | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 18 | The White House | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 19 | Nunus | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 20 | Reuters - Breaking World News | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 21 | Overcast: Podcast App | Podcast | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 22 | The New Yorker | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 23 | 腾讯新闻 Tencent News | Publisher & general news | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 24 | Frontline Wildfire Tracker | Public-safety alerts | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Free | 25 | Big News - Smart Reader | RSS & feed readers | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 1 | GoodLinks | Read later | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 2 | Reeder Classic. | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 3 | Current - RSS Feed Reader | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 4 | Downcast | Podcast | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 5 | RSS Button for Safari | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 6 | News Explorer | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 7 | YourPods: Podcast Player | Podcast | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 8 | NewsBar RSS reader | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 9 | Leaf - RSS News Reader | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 10 | Pulp | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 11 | RSS Reader | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 12 | Newsflow: The No.1 News Ticker | News ticker & menu bar | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 13 | Scrolling News Ticker | News ticker & menu bar | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 14 | App for Google: News Headlines | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 15 | lire | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 16 | RSS Feeds | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 17 | Readit – Reddit News Reader | Community news reader | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 18 | ProSpeech | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 19 | Block images for internet | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 20 | Den for RSS | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 21 | Harmonica Master Class | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 22 | Translator Professional+Widget | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 23 | MenuBar RSS | RSS & feed readers | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 24 | DeepSRT News | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| News | Paid | 25 | Universal To Do List | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 1 | CapCut: Photo & Video Editor | Video editing & post-production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 2 | Canva: AI Video & Photo Editor | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 3 | Apple Creator Studio | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 4 | Adobe Lightroom: Photo Editor | Photo editing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 5 | DaVinci Resolve | Video editing & post-production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 6 | Final Cut Pro: Create Video | Video editing & post-production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 7 | MKPlayer - MKV & Media Player | Media player | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 8 | GoPro Quik | Camera companion & control | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 9 | Adobe Photoshop Elements 2025 | Photo editing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 10 | CamPhoto | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 11 | TapRecord: Screen Recorder | Screen, webcam & streaming capture | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 12 | Cam.On: Webcam Video Recorder | Screen, webcam & streaming capture | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 13 | Photomator – Photo Editor | Photo editing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 14 | VN: Video Editor | Video editing & post-production | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 15 | Draw Things: Offline AI Art | AI image generation & enhancement | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 16 | Blackmagic Disk Speed Test | Camera companion & control | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 17 | App For Snapchat Tools | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 18 | GoPro Player | Media player | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 19 | OBS 4K | Screen, webcam & streaming capture | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 20 | Final Video Player - MKV & MP4 | Media player | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 21 | Darkroom: Photo & Video Editor | Photo editing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 22 | Fotor: AI Photo Editor, Design | Photo editing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 23 | Motion: Animate Effects | Animation & motion graphics | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 24 | Compressor: Encode Media | Media conversion & encoding | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Free | 25 | Mimeo Photos: Printed Memories | Photo printing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 1 | Final Cut Pro | Video editing & post-production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 2 | PhotoSweeper | Photo cleanup | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 3 | Upscayl | AI image generation & enhancement | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 4 | Helper for GoPro Files | Camera companion & control | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 5 | Motion | Animation & motion graphics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 6 | ShutterCount | Camera shutter count | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 7 | Stop Motion Studio Pro 2 | Animation & motion graphics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 8 | DaVinci Resolve Studio | Video editing & post-production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 9 | Compressor | Media conversion & encoding | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 10 | Duplicate Photos Fixer Pro | Photo cleanup | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 11 | Photographer's Bundle | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 12 | Webcam Settings | Screen, webcam & streaming capture | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 13 | Total Video Converter Pro: DVD | Media conversion & encoding | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 14 | ScreenFlow 10 | Video editing & post-production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 15 | ScriptStar | Video editing & post-production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 16 | Starry Landscape Stacker | Astrophotography | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 17 | Elmedia:universal video player | Media player | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 18 | Phiewer PRO | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 19 | XtoCC | Video editing & post-production | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 20 | ShutterLife: Shutter Count | Camera shutter count | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 21 | PhotoSketcher | Photo editing | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 22 | Permute 3 | Media conversion & encoding | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 23 | Bluetooth+ for Blackmagic Cams | Camera companion & control | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 24 | MixEffect Pro - Paid Up-Front | Camera companion & control | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Photo & Video | Paid | 25 | TouchRetouch: Object Removal | Photo editing | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 1 | Bible Study | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 2 | Translate Now - AI Translator | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 3 | Youdao Translate | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 4 | MyFlixer: Watch Movies,TV Show | Movie catalogue | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 5 | Bible: Chat, Widgets, Audio | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 6 | Game Codes for Roblox • | Game reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 7 | Night Sky | Astronomy | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 8 | Translate Hola – AI Translator | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 9 | LookUp: English Dictionary | Dictionary & thesaurus | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 10 | Pro: AI Translator For Google | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 11 | The-Bible | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 12 | Eudic | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 13 | Coptic Reader | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 14 | Oxford Deluxe (InApp) | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 15 | The Bible Memory App | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 16 | Kiwix | Offline knowledge library | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 17 | Bible InspiringLife | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 18 | Mactracker | Apple hardware reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 19 | Bible Verse Of The Day - BVW | Bible & Christian reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 20 | Athan Pro: Muslim Prayer Times | Islamic reference | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 21 | Collectr - TCG Collector App | Collectibles | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 22 | Translatium - Translator | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 23 | JAMES - AI Chat, Images, Audio | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 24 | Floating Clock-Timer&Stopwatch | Utility / likely miscategorized | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Free | 25 | Youdao Dictionary | Translation & language | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 1 | e-Sword X: Bible Study Extreme | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 2 | HolyBible K.J.V. Pro | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 3 | BibleDesk | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 4 | Webster's 1828 Dictionary | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 5 | Daily Bible: Verse Widget | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 6 | Companion Synonyms | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 7 | Roget's II: New Thesaurus | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 8 | Quran Majeed — القرآن المجيد | Islamic reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 9 | FAR/AIM by ASA | Law, regulation & government | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 10 | Movie Explorer Pro | Movie catalogue | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 11 | LDOCE | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 12 | Transit: Astronomical Events | Astronomy | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 13 | American Heritage® Dictionary | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 14 | Bible Dictionary & Concordance | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 15 | Latin Dictionary | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 16 | Advanced English Dictionary HD | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 17 | Moon Atlas 3D | Astronomy | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 18 | Lucky Block Mod for Minecraft | Game reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 19 | Oxford Dictionary of English. | Dictionary & thesaurus | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 20 | AyeTides | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 21 | Stamp Analyser | Collectibles | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 22 | WolframAlpha Classic | Computational knowledge | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 23 | Life Application Study Bible | Bible & Christian reference | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 24 | Congress Pro | Law, regulation & government | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Reference | Paid | 25 | Barrington Atlas | Historical atlas | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 1 | WhatsApp Messenger | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 2 | Telegram | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 3 | Apps for Instagram | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 4 | WeChat | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 5 | App for Facebook ® | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 6 | Desktop App for Tik Tok | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 7 | App for Facebook Messenger | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 8 | App For Team Meetings | Video meetings | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 9 | App for TikTok | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 10 | App for Google Meet | Video meetings | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 11 | LINE | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 12 | TextNow | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 13 | Save Pin : App for Pinterest | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 14 | App for Discord | Community & group chat | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 15 | Telegram Lite | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 16 | KakaoTalk | Messaging | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 17 | App for Facebook Messenger! | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 18 | 360 Tracker : Location Tracker | Location sharing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 19 | rednote | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 20 | Friendly Social Browser | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 21 | Minimal Theme for Twitter / X | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 22 | Desktop App for Discord | Community & group chat | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 23 | WA Chat Manager | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 24 | Apps for Facebook & Messenger | Social platform client | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Free | 25 | Join Meetings For Zoom | Video meetings | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 1 | Unite - GroupMe app | Community & group chat | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 2 | BetterChat for WhatsApp | Messaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 3 | Homecoming for Mastodon | Federated social | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 4 | Photo Slideshow Creator Pro | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 5 | Mango IRC | Messaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 6 | IPYNB Reader Pro | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 7 | Control Panel for Twitter | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 8 | YMailTab | Email client / miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 9 | DWG Viewer Pro | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 10 | Clean YT for Safari | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 11 | Disable Shorts for YouTube | YouTube browser control | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 12 | The Control Panel Bundle | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 13 | Yesterday For Old Reddit | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 14 | Fire - App for Tinder | Dating | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 15 | ChatShare for WhatsApp | Messaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 16 | Block YT Shorts for Safari | YouTube browser control | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 17 | ChatMate for Facebook | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 18 | Pinboard for Pinterest | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 19 | Team for Workplace | Community & group chat | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 20 | Downloader for Tumble | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 21 | iTab Pro | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 22 | One Chat All-in-One Messenger | Messaging | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 23 | Spring for Twitter | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 24 | instaLive Wallpaper | Other / likely miscategorized | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Social Networking | Paid | 25 | PinTab Pro for Pinterest | Social platform client | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 1 | TwiTracker : Stream Tracker | Sports streaming | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 2 | MiLB | Baseball | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 3 | KOMA FOOTBALL | Football / soccer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 4 | SwingVision: Tennis Pickleball AI | Tennis & pickleball | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 5 | Sleeper Sports | Predictions & regulated picks | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 6 | Next Shot: Golf GPS Scorecard | Golf | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 7 | Draft Sharks | Fantasy sports | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 8 | Nova Soccer Live Hub | Football / soccer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 9 | ROUVY Companion App | Cycling & indoor training | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 10 | DraftKings Predictions | Fantasy sports | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 11 | Catapult Scout | Coaching & team management | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 12 | Spry+ | Coaching & team management | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 13 | TeamReach – Your Team App | Coaching & team management | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 14 | RM Play | Sports streaming | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 15 | Scoreboard: Keep 2 Teams Score | Scoring & statistics | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 16 | Rank One | Coaching & team management | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 17 | CHLK | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 18 | TacticalPad | Coaching & team management | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 19 | DAZN: Stream Live Sports | Sports streaming | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 20 | Shot Tracer Pro | Motorsport & racing | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 21 | Sports Live Toolbar | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 22 | GAME CHANGER SAU | Other / manual review | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 23 | WNBA Events App | Basketball | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 24 | WalterPicks – Fantasy Football | Football / soccer | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Free | 25 | Shot Pattern - Golf GPS | Golf | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 1 | Tournament Bracket Generator | Scoring & statistics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 2 | Bridge Pairs Score | Scoring & statistics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 3 | Golf Tracer - Track Your Shots | Golf | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 4 | Pyramid Sol | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 5 | KMZ Map Snapper | Activity logs & maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 6 | DiveLogDT | Diving & marine | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 7 | Race Monitor | Motorsport & racing | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 8 | Basic Sports Timer | Sports timer | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 9 | Classic Minesweeper | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 10 | Statbook | Scoring & statistics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 11 | SeaNav US | Diving & marine | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 12 | Eagle | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 13 | PokerTimer | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 14 | Bridge Exercises | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 15 | Sports Scoreboard for OBS | Scoring & statistics | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 16 | AmmoBaseX | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 17 | SUPERB CHESS BOARD | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 18 | 拖拉机.斗地主.拱猪 | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 19 | Joseki - A Go Game Skill | Mind sports & games | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 20 | Fantasy Baseball Draft Kit '26 | Fantasy sports | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 21 | Track - Read your logs | Activity logs & maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 22 | Smart Soccer Coach++ | Football / soccer | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 23 | QZ - qdomyos-zwift | Cycling & indoor training | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 24 | CricLive | Cricket | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Sports | Paid | 25 | Dive Converter | Diving & marine | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 1 | App For Google Maps | Maps & route planning | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 2 | Flighty – Live Flight Tracker | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 3 | Smart App for Google Maps | Maps & route planning | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 4 | Wanderlog - Travel Planner | Trip planning & journaling | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 5 | Globe 3D – Planet Earth Guide | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 6 | Tripsy: Travel Planner | Trip planning & journaling | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 7 | World Clock Time Zone Widgets | Travel utilities | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 8 | Points Path | Travel rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 9 | Fly Delta | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 10 | Garmin BaseCamp | Outdoor travel | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 11 | Currency converter calculator! | Travel utilities | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 12 | Vrbo Owner | Accommodation & rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 13 | Flight Tracker - Plane Tracker | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 14 | RatePunk: Cheap Plane Tickets | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 15 | inRoute – Intelligent Routing | Maps & route planning | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 16 | Travel One for Airbnb | Accommodation & rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 17 | Atmos Rewards | Travel rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 18 | Southwest Airlines: Travel App | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 19 | The Guestbook: Hotel Rewards | Accommodation & rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 20 | Flight Tracker: Live Radar 24 | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 21 | Globe Planet 3D - Earth Map | Flights & flight tracking | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 22 | Topo Maps+ | Outdoor travel | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 23 | IHG One Rewards: Book Hotels | Accommodation & rewards | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 24 | Recreation.gov | Outdoor travel | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Free | 25 | Norwegian Cruise Line | Cruise | Free download; IAP/subscription pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 1 | Road Trip Planner | Trip planning & journaling | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 2 | GPX Editor | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 3 | GPX Viewer | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 4 | Passport Photo - An ID App | Travel documents | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 5 | myTracks | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 6 | Arrival - GPS driving assistant | Maps & route planning | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 7 | Explore - for Google Maps | Maps & route planning | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 8 | TrafficCamNZ | Traffic cameras | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 9 | Travel Journal | Trip planning & journaling | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 10 | CDL Exam Prep | Driver exam preparation | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 11 | Travel PackList | Packing lists | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 12 | Acana Map2Pin | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 13 | Geocaching Tools | Outdoor travel | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 14 | NavLink US | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 15 | GPX Binder | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 16 | My Travel World | Other / manual review | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 17 | Geo WPS | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 18 | Cartograph Maps 2 | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 19 | MyTravelsPlanner | Trip planning & journaling | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 20 | GPX File Creator | GPS, GPX & offline maps | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 21 | PackPoint Premium Packing List | Packing lists | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 22 | USFS & BLM Campgrounds | Outdoor travel | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 23 | Packing Pro | Packing lists | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 24 | DVC Planner | Accommodation & rewards | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |
| Travel | Paid | 25 | Trip | Trip planning & journaling | Paid download; exact USD/TRY pending | Bulunmadı / ürün bazında doğrulama bekliyor |

## Faz 2C Apple kaynakları

- [Medical — Top Free](https://apps.apple.com/us/mac/charts/6020?chart=top-free)
- [Medical — Top Paid](https://apps.apple.com/us/mac/charts/6020?chart=top-paid)
- [Music — Top Free](https://apps.apple.com/us/mac/charts/6011?chart=top-free)
- [Music — Top Paid](https://apps.apple.com/us/mac/charts/6011?chart=top-paid)
- [News — Top Free](https://apps.apple.com/us/mac/charts/6009?chart=top-free)
- [News — Top Paid](https://apps.apple.com/us/mac/charts/6009?chart=top-paid)
- [Photo & Video — Top Free](https://apps.apple.com/us/mac/charts/6008?chart=top-free)
- [Photo & Video — Top Paid](https://apps.apple.com/us/mac/charts/6008?chart=top-paid)
- [Reference — Top Free](https://apps.apple.com/us/mac/charts/6006?chart=top-free)
- [Reference — Top Paid](https://apps.apple.com/us/mac/charts/6006?chart=top-paid)
- [Social Networking — Top Free](https://apps.apple.com/us/mac/charts/6005?chart=top-free)
- [Social Networking — Top Paid](https://apps.apple.com/us/mac/charts/6005?chart=top-paid)
- [Sports — Top Free](https://apps.apple.com/us/mac/charts/6004?chart=top-free)
- [Sports — Top Paid](https://apps.apple.com/us/mac/charts/6004?chart=top-paid)
- [Travel — Top Free](https://apps.apple.com/us/mac/charts/6003?chart=top-free)
- [Travel — Top Paid](https://apps.apple.com/us/mac/charts/6003?chart=top-paid)

## Kullanım metriği metodoloji kaynakları

- [Apple App Analytics](https://developer.apple.com/app-store-connect/analytics/) — geliştiricinin kendi uygulaması için active devices, sessions, retention ve acquisition verileri.
- [Apple Analytics dashboard overview](https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-dashboard/) — first-time downloads, redownloads, paying users ve active plans tanımları.
- [Apple Sales and Trends metrics](https://developer.apple.com/help/app-store-connect/reference/reporting/sales-and-trends-metrics-and-dimensions/) — App and Bundle Units tanımı.
- [Sensor Tower downloads and revenue estimates](https://sensortower.com/blog/how-to-get-estimated-downloads-and-revenue-for-apps) — üçüncü taraf tahmin yaklaşımı.
- [data.ai downloads methodology](https://helpcenter.data.ai/community/s/article/Downloads-Revenue-Product-Overview-Metrics-Methodology) — sıralamaya dayalı tahmin metodolojisi.

## Faz 3 başlangıç durumu — tam katalog

Chart seed tamamlandı. Tam katalog katmanında aşağıdakiler zorunludur:

1. Apple Search API `entity=macSoftware` sorgu matrisi.
2. A–Z, 0–9, iki harfli kombinasyonlar ve 496 niş anahtar kelimesi.
3. ABD + Türkiye + GB + DE + CA + AU + JP storefront taraması.
4. `trackId/adamId` ile tekilleştirme; isimle tekilleştirme yapılmaması.
5. Her sorgunun sonuç sınırı ve yeni benzersiz kayıt kazanımının loglanması.
6. Üç ardışık turda yeni kayıt oranı düşene kadar doygunluk taraması.
7. Ürün sayfası, fiyat, geliştirici, puan ve sürüm zenginleştirmesi.

> [!CAUTION]
> Apple herkese açık tek parça bir “tüm Mac uygulamaları” katalog export’u sağlamadığı için `bütün uygulamalar` hedefi, kamuya açık kaynaklarla bulunabilen uygulamaların doygunluk esaslı tam envanteridir. Son dosya, ulaşılan toplamı ve kapsam güvenini açıkça raporlayacaktır.

**Sürüm:** 2C — 2 Ağustos 2026

# Faz 3A — Chart Dışı Uzun-Kuyruk Mac Uygulamaları

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Yeni `trackId` kaydı:** 75  
**Arama nişi:** 12  
**Chart ismiyle çakıştığı için çıkarılan kayıt:** 1

> [!IMPORTANT]
> Bu bölüm, önceki 20 kategori Top Free/Top Paid çekirdeğinde bulunmayan uygulamaları ekler. Tekilleştirme `trackId` ile yapılmıştır. Faz 3 tamamlanmış değildir; 496 niş ve çoklu storefront sorgularının yalnızca ilk doğrulanmış partisi işlenmiştir.

## Faz 3 metodoloji güncellemesi

Apple’ın arşivdeki Search API dokümanı `macSoftware` aramalarını, sorgu başına en fazla 200 sonucu ve yaklaşık dakikada 20 çağrı sınırını tanımlar. Ancak 2025–2026 döneminde herkese açık uç nokta için kesinti/404 raporları bulunduğundan, katalog toplama tek kaynağa bağlanmayacaktır. Apple App Store ürün sayfaları, arama motoru indeksleri, kategori/chart sayfaları ve birden fazla storefront çaprazlanacaktır.

### Tam katalog için zorunlu kaynak katmanları

1. Apple Mac Top Charts ve editoryal koleksiyonları.
2. App Store ürün sayfalarının arama motoru indeksleri.
3. Çalıştığı dönemlerde Apple Search/Lookup API.
4. US, TR, GB, DE, CA, AU ve JP storefront sorguları.
5. Uygulama adına, nişe, geliştiriciye ve dosya türüne göre uzun-kuyruk sorguları.
6. `trackId` ile tekilleştirme ve kaldırılmış/bölgesel kayıt kontrolü.

## Yeni kayıt özeti

| Boyut | Değer |
|---|---:|
| Chart-dışı benzersiz `trackId` | 75 |
| Kategori | 10 |
| Arama nişi | 12 |
| Ücretsiz veya freemium | 60 |
| Peşin ücretli | 6 |
| Lifetime/hibrit sinyali | 4 |
| Açıklanmış tüm-platform kullanıcı sinyali | 2 |

### Kategori dağılımı

| Kategori | Yeni uygulama |
|---|---:|
| Productivity | 28 |
| Utilities | 19 |
| News | 6 |
| Music | 6 |
| Business | 5 |
| Travel | 4 |
| Developer Tools | 2 |
| Finance | 2 |
| Health & Fitness | 2 |
| Lifestyle | 1 |

### Monetizasyon dağılımı

| Model | Yeni uygulama |
|---|---:|
| FREEMIUM | 31 |
| FREE | 26 |
| PAID | 6 |
| LIFE | 3 |
| SUB | 3 |
| FREEMIUM/SERVICE | 3 |
| UNKNOWN | 2 |
| HYBRID | 1 |

## Kullanım ve indirme alanlarının uygulanması

- Rakip uygulamanın **kesin Mac indirmesi**, yalnızca geliştiricinin Mac cihaz filtresiyle yayımladığı doğrulanmış App Store Connect verisi varsa yazılır.
- Şirketin açıkladığı “kullanıcı” sayısı Mac’e özel değilse `DISCLOSED-ALL-PLATFORMS` olarak tutulur.
- App Store puan sayısı yalnızca `PUBLIC-PROXY` talep sinyalidir; indirme veya aktif kullanıcı sayısı değildir.
- Apple’a göre geliştirici kendi uygulamasında Total Downloads, First-Time Downloads, Redownloads, Active Devices, Sessions ve Paying Users gibi metrikleri görebilir; rakiplerin bu verileri halka açık değildir.

## Faz 3A uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Offline | Kullanım/indirme sinyali | Kapsam | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|
| 1091193841 | Professional Invoicing | Business | VEGANTARAM TECHNOLOGIES PVT. LTD. | Free | FREE | Invoice, estimates & purchase orders | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/professional-invoicing/id1091193841?mt=12) |
| 6757134991 | Invoicer - Simply Invoices | Business | Gary Keeler | Free + single branding IAP | LIFE | Simple freelancer invoicing | Standalone workspace | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/invoicer-simply-invoices/id6757134991) |
| 711218993 | NeoOffice Invoice | Business | Edward Peterlin | Free | FREE | Simple invoices & payment tracking | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/neooffice-invoice/id711218993?mt=12) |
| 1163247388 | Express Invoice Invoicing | Business | NCH Software | Free + IAP | FREEMIUM | Small-business invoicing | Yes for core records; sending requires internet | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/express-invoice-invoicing/id1163247388?mt=12) |
| 434514810 | Billings Pro: Time & Invoice | Business | Marketcircle | Free download; subscription/service plan | SUB | Time tracking & invoicing | Cloud/service dependent | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/billings-pro-time-invoice/id434514810) |
| 6759334075 | Editorio | Developer Tools | Lovre Crncevic | Free | FREE | Native text, Markdown & code editor | Yes; native local editor | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/editorio/id6759334075?mt=12) |
| 442160987 | Flycut (Clipboard manager) | Developer Tools | General Arcade (Pte. Ltd.) | Free | FREE | Open-source clipboard manager for developers | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/flycut-clipboard-manager/id442160987?mt=12) |
| 6778432285 | Cifra: Invoices & Expenses | Finance | Tomas Parizek | Free + one-time Cifra Pro | LIFE | Invoice, expenses & Czech VAT | Primarily local; rates/registry may require internet | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/cifra-invoices-expenses/id6778432285?mt=12) |
| 1231388724 | PDF Text Scanner Pro | Finance | Emanuele Floris | Free + IAP | FREEMIUM | Offline PDF OCR | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/pdf-text-scanner-pro/id1231388724) |
| 1629226439 | Cronometer - Break Reminders | Health & Fitness | Khuong Pham | Free + IAP | FREEMIUM | Eye rest, stand & stretch reminders | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/cronometer-break-reminders/id1629226439?mt=12) |
| 1334078781 | Habit Tracker | Health & Fitness | Sudip Bag | $4.99 | PAID | Simple habit & bad-habit tracker | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/habit-tracker/id1334078781?mt=12) |
| 6444217677 | Lickable Menu Bar | Lifestyle | Honghao Zhang | Free | FREE | Classic menu bar appearance | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/lickable-menu-bar/id6444217677?mt=12) |
| 6449281141 | Tonal | Music | Not parsed in public result | Free + IAP | FREEMIUM | Audiophile library & metadata | Local-first; services optional | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/tonal/id6449281141?mt=12) |
| 6767955467 | Tagumi | Music | Nodoka, LLC | Free | FREE | Batch music metadata manager | Yes; MusicBrainz lookup optional | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/tagumi/id6767955467) |
| 1057068364 | To FLAC Converter 2 | Music | Not parsed in public result | Free + IAP | FREEMIUM | FLAC conversion + metadata | Conversion offline; metadata lookup online | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/to-flac-converter-2/id1057068364?mt=12) |
| 1631260641 | MP3 Tag Editor: Batch Rename | Music | Bitnite, TOO | Free + IAP | FREEMIUM | MP3 metadata & batch rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/mp3-tag-editor-batch-rename/id1631260641?mt=12) |
| 558317092 | Meta — Music Tag Editor | Music | Benjamin Jaeger | $22.99 | PAID | Professional music tag editor | Yes; lookup optional | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/meta-music-tag-editor/id558317092?mt=12) |
| 984278082 | Tag Editor 2 | Music | Not parsed in public result | Free + IAP | FREEMIUM | Spreadsheet-style batch audio tags | Yes; online lookup optional | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/tag-editor-2/id984278082) |
| 1037705049 | RSS Follower | News | Alexey Nikitin & Alexandr Bondar | Free + IAP | FREEMIUM | General RSS reader | Partial | 36 US ratings observed in indexed result; not an install count | PUBLIC-PROXY | [App Store](https://apps.apple.com/us/app/rss-follower/id1037705049?mt=12) |
| 605732865 | RSS Bot - News Notifier | News | Not parsed in public result | Free | FREE | Menu bar RSS notifications | No; feeds require internet | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/rss-bot-news-notifier/id605732865?mt=12) |
| 6475646828 | Riverside for Mac - RSS Reader | News | Maiku Yamaguchi | Free | FREE | Minimal RSS reader | Partial | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/riverside-for-mac-rss-reader/id6475646828) |
| 6768790083 | News App: RSS Reader & More | News | Hudley Holdings LLC | Free | FREE | Multi-source RSS/social feed reader | Partial; iCloud/feed internet dependency | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/news-app-rss-reader-more/id6768790083) |
| 6758415284 | Today - An RSS Reader | News | Jacob Spurlock | Free | FREE | Native RSS reader with AI hints | Partial; feed download requires internet | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/today-an-rss-reader/id6758415284?mt=12) |
| 1430856926 | tiny Reader | News | Pascal PLUCHON | Free + IAP | FREEMIUM | Tiny Tiny RSS client | No; requires TTRSS server | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/tiny-reader/id1430856926?mt=12) |
| 1483173268 | 22 Days - Habit Tracker | Productivity | Vladislav Kovalyov | $0.99 | PAID | 21-day habit formation | Yes | 1 US rating observed in indexed result; not an install count | PUBLIC-PROXY | [App Store](https://apps.apple.com/us/app/22-days-habit-tracker/id1483173268?mt=12) |
| 6752313155 | StreamWindow: 3D WindowManager | Productivity | 永亮 张 | Free + IAP | FREEMIUM | 3D window manager & switcher | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/streamwindow-3d-windowmanager/id6752313155?mt=12) |
| 6474854386 | LaunchPalette – App Switcher | Productivity | Seungwoo Choe | Free + IAP | FREEMIUM | App launcher & window manager | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/launchpalette-app-switcher/id6474854386?mt=12) |
| 595191960 | CopyClip - Clipboard History | Productivity | Not parsed in public result | Free | FREE | Basic clipboard history | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/copyclip-clipboard-history/id595191960?mt=12) |
| 6450152139 | Batch File Sort Rename | Productivity | 军 龙 | Free + IAP | FREEMIUM | Batch sort & rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/batch-file-sort-rename/id6450152139?mt=12) |
| 1544620654 | Clipboard Manager — Pasty | Productivity | Ivan Sapozhnik | Free + IAP | FREEMIUM | Clipboard history & collections | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/clipboard-manager-pasty/id1544620654?mt=12) |
| 1432799040 | Bonsai Time Tracker | Productivity | Bonsai | Free download; service plan | SUB | Freelancer project time tracking | Cloud/service dependent | No reliable public user total found | NONE | [App Store](https://apps.apple.com/us/app/bonsai-time-tracker/id1432799040?mt=12) |
| 6772501131 | Markdown Mate: Writing & Notes | Productivity | Tran Cong Minh | Free | FREE | Local-first Markdown notes | Yes; local-first | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/markdown-mate-writing-notes/id6772501131?mt=12) |
| 806601044 | Archimedes | Productivity | Not parsed in public result | Price not parsed | UNKNOWN | Markdown + LaTeX editor | Likely; local document editor | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/archimedes/id806601044?mt=12) |
| 1458220908 | Markdown Editor | Productivity | Satoshi Iwaki | Free | FREE | Markdown editor | Likely; local editor | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/markdown-editor/id1458220908?mt=12) |
| 6758913120 | FlowMD — Markdown Editor | Productivity | Phanith Ny | Free | FREE | Markdown live preview | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/flowmd-markdown-editor/id6758913120) |
| 6742777183 | OCR Fast Translation | Productivity | Not parsed in public result | $0.99/month or $29.99 lifetime | HYBRID | Offline screenshot translation | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/ocr-fast-translation/id6742777183?mt=12) |
| 6758425339 | 941 Tiles | Productivity | Christopher Crosley | $4.99 | PAID | One-click per-app window layouts | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/941-tiles/id6758425339?mt=12) |
| 1215383084 | PDFZone - PDF Automation | Productivity | iSolid apps | Free + IAP | FREEMIUM | PDF content extraction & rename | Yes; 100% on-device | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/pdfzone-pdf-automation/id1215383084?mt=12) |
| 1636192654 | Coffee: Time Tracker & Focus | Productivity | Andrei Ildiakov | Free + IAP | FREEMIUM | Personal time tracking & focus | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/coffee-time-tracker-focus/id1636192654?mt=12) |
| 1495643653 | WorkingHours: Time Tracker | Productivity | Timo Partl | Free + IAP | FREEMIUM | Personal timesheets & billing | Yes; no subscription positioned | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/workinghours-time-tracker/id1495643653?mt=12) |
| 1494460432 | Tappsk Daily Schedule Manager | Productivity | MATVEY KONDAKOV | Free | FREEMIUM/SERVICE | Planner, tasks, reminders & habits | Not verified | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/tappsk-daily-schedule-manager/id1494460432?mt=12) |
| 6745695203 | ClipBoardy: Clipboard Manager | Productivity | Tristan Jarrett | Free | FREE | Private clipboard history | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/clipboardy-clipboard-manager/id6745695203?mt=12) |
| 6758315962 | paperite | Productivity | Not parsed in public result | Free | FREE | Private on-device AI Markdown editor | Yes; listing says no cloud | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/paperite/id6758315962) |
| 6738119141 | Better Rename - Bulk Renamer | Productivity | publicspace.net | Free + IAP | FREEMIUM | Professional batch rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/better-rename/id6738119141) |
| 6757333924 | Command Reopen - Fix cmd tab | Productivity | 锋 陈 | Free + IAP | FREEMIUM | Restore minimized windows on app switch | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/command-reopen-fix-cmd-tab/id6757333924?mt=12) |
| 1359663922 | EasyScreenOCR - Image to Text | Productivity | 通 张 | Free + IAP | FREEMIUM | Screenshot OCR & translation | Yes; listing says 100% offline OCR | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/easyscreenocr-image-to-text/id1359663922?mt=12) |
| 6467188805 | Jibble: Time Tracker | Productivity | Jibble | Free | FREEMIUM/SERVICE | Team attendance & timesheets | Cloud/service dependent | 1.3 million users disclosed in 2024; all-platform service scope, not Mac installs | DISCLOSED-ALL-PLATFORMS | [App Store](https://apps.apple.com/us/app/jibble-time-tracker/id6467188805?mt=12) |
| 1539652800 | Everhour Time Tracker | Productivity | VIAVORA KONSALTING, OOO | Free download; service plans | SUB | Team project time tracking | Cloud/service dependent | No reliable public user total found | NONE | [App Store](https://apps.apple.com/us/app/everhour-time-tracker/id1539652800?mt=12) |
| 1364502317 | Clockify Desktop | Productivity | CAKE.com | Free; optional service plans | FREEMIUM/SERVICE | Team time tracking | Primarily cloud/service | Official site says used by millions; all-platform scope, not Mac installs | DISCLOSED-ALL-PLATFORMS | [App Store](https://apps.apple.com/us/app/clockify-desktop/id1364502317?mt=12) |
| 946047238 | Chrono Plus - Time Tracker | Productivity | Denys Ievenko | Free + IAP | FREEMIUM | Timesheet & work hours | Likely | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/chrono-plus-time-tracker/id946047238?mt=12) |
| 1438389787 | Clipboard Manager - Pasta | Productivity | Applorium Ltd | Free + IAP | FREEMIUM | Visual clipboard manager | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/clipboard-manager-pasta/id1438389787?mt=12) |
| 6770067475 | Markora — Markdown Editor | Productivity | Not parsed in public result | Free | FREE | WYSIWYG Markdown editor | Yes; listing says fully offline | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/markora-markdown-editor/id6770067475) |
| 1229416813 | Router | Travel | Not parsed in public result | Free | FREE | GPS route & GPX editor | Partial | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/router/id1229416813?mt=12) |
| 1484961734 | TrackGuide GPX Editor | Travel | Bert Torfs BVBA | Free | FREE | GPX route planning | Partial; maps may require internet | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/trackguide-gpx-editor/id1484961734?mt=12) |
| 1550425948 | FootMark Viewer & Editor | Travel | Not parsed in public result | Free + IAP | FREEMIUM | GPX/KML/TCX viewer & editor | Partial | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/footmark-viewer-editor/id1550425948?mt=12) |
| 6759854553 | Vroma Studio Track | Travel | Not parsed in public result | Free | FREE | Review, edit & replay GPX | Partial | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/vroma-studio-track/id6759854553?mt=12) |
| 6758432449 | AI File Renamer: Zush | Utilities | Kirill Isachenko | Free + IAP | FREEMIUM | AI content-aware file rename | Optional offline AI/Ollama | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/ai-file-renamer-zush/id6758432449?mt=12) |
| 6756887557 | OnDevice OCR Pro | Utilities | Not parsed in public result | Free + IAP | FREEMIUM | Batch PDF OCR & hot folder | Yes; entirely offline | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/ondevice-ocr-pro/id6756887557?mt=12) |
| 1175416599 | Mass Rename: File Batch Rename | Utilities | Georgios Trigonakis | $6.99 | PAID | Batch file rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/mass-rename-file-batch-rename/id1175416599?mt=12) |
| 1460461110 | Easy Batch Rename | Utilities | Not parsed in public result | Free + IAP | FREEMIUM | Bulk file rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/easy-batch-rename/id1460461110?mt=12) |
| 1619348240 | ClipTools | Utilities | Not parsed in public result | Free | FREE | Clipboard + text utilities | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/cliptools/id1619348240?mt=12) |
| 413857545 | Divvy - Window Manager | Utilities | Mizage, LLC | $13.99 | PAID | Grid window management | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/divvy-window-manager/id413857545) |
| 1452453066 | Hidden Bar | Utilities | Not parsed in public result | Price not parsed | UNKNOWN | Hide & organize menu bar icons | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/hidden-bar/id1452453066?mt=12) |
| 6475570650 | PicScan: Image to Text Scanner | Utilities | Technostacks Infotech Private Limited | Free + IAP | FREEMIUM | Image OCR & searchable archive | Not verified | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/picscan-image-to-text-scanner/id6475570650?mt=12) |
| 6747191017 | RenamerX | Utilities | Hatsuhito Shimizu | Free | FREE | Lightweight batch rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/renamerx/id6747191017?mt=12) |
| 1599516503 | Melior Editor | Utilities | Anthony Lagrede Consulting | Free | FREE | Markdown editor + whiteboard | Likely; local files | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/melior-editor/id1599516503?mt=12) |
| 1573769710 | Macarte - Menu to Switch Apps | Utilities | Colin Bradley | Free | FREE | Menu bar app switcher | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/macarte-menu-to-switch-apps/id1573769710?mt=12) |
| 6443843900 | iBar-Menubar icon control tool | Utilities | 宁波上官科技有限公司 | Free + IAP | FREEMIUM | Menu bar icon management | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/ibar-menubar-icon-control-tool/id6443843900?mt=12) |
| 419332741 | XMenu | Utilities | DEVONtechnologies, LLC | Free | FREE | Menu bar launcher & snippets | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/xmenu/id419332741?mt=12) |
| 1575588022 | MenubarX - Floating Browser | Utilities | 6X Studio LLC | Free + IAP | FREEMIUM | Menu bar web-app browser | No; web content dependent | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/menubarx-floating-browser/id1575588022?mt=12) |
| 1522041836 | OCR Text Recognition: Textify | Utilities | iSolid apps | Free + IAP | FREEMIUM | Offline OCR & searchable PDF | Yes; 100% on-device | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/ocr-text-recognition-textify/id1522041836?mt=12) |
| 6769397852 | QuietClip - Clipboard Manager | Utilities | Kemal Esensoy | Free + IAP | FREEMIUM | Private clipboard history | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/quietclip-clipboard-manager/id6769397852?mt=12) |
| 6756575502 | RenameFlow Pro | Utilities | Not parsed in public result | Free + one-time Pro IAP | LIFE | Professional metadata-aware rename | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/renameflow-pro/id6756575502) |
| 6761549177 | TextGrab-OCR Text Recognition | Utilities | 鹏宇 王 | Free + IAP | FREEMIUM | Screen & table OCR | Yes | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/textgrab-ocr-text-recognition/id6761549177?mt=12) |
| 6463065047 | iOCR-OCR&Translation | Utilities | Not parsed in public result | Free | FREE | Screenshot, Finder & clipboard OCR | Offline OCR option | No public exact Mac count | NONE | [App Store](https://apps.apple.com/us/app/iocr-ocr-translation/id6463065047?mt=12) |

## Sorgu kapsama defteri

| Sorgu nişi | Yeni benzersiz kayıt | Durum |
|---|---:|---|
| markdown editor | 8 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| batch rename | 8 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| OCR offline | 8 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| clipboard manager | 7 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| time tracker | 7 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| invoice billing | 6 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| menu bar utility | 6 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| RSS reader | 6 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| music metadata | 6 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| window manager | 5 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| habit tracker | 4 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |
| GPX editor | 4 | İlk tur tamamlandı; storefront ve eş anlamlı genişletmesi bekliyor |

## Bu turdaki önemli pazar sinyalleri

- **Markdown:** Çok sayıda 2026 tarihli, ücretsiz, native ve offline ürün var. Basit Markdown editörü tek başına güçlü bir savunma oluşturmuyor; matematik, whiteboard, Git, meeting transcription veya on-device AI gibi dikeyleşme gerekiyor.
- **Clipboard:** Ücretsiz/freemium rekabet yoğun; gizlilik, koleksiyonlar, geliştirici iş akışı ve hızlı arama temel beklenti hâline gelmiş durumda.
- **Batch rename:** Metadata, OCR ve offline AI ile içeriğe göre yeniden adlandırma yeni farklılaşma alanı; tek seferlik Pro yükseltmesi yaygın.
- **OCR:** Offline/on-device vurgusu güçlü bir satın alma nedeni. Aylık + lifetime hibrit fiyat modeli de görülüyor.
- **Invoicing:** Genel fatura ürünleri kalabalık; ülkeye özgü vergi/VAT, QR ödeme ve tek seferlik lisans daha savunulabilir.
- **Menu bar/window management:** Mac’e özgü davranışlar nedeniyle native küçük araçlar hâlâ ücretli satış yapabiliyor.
- **Time tracking:** Hizmet tabanlı büyük ürünlerin toplam kullanıcı sayısı açıklanabilse de bu rakam Mac App Store indirmesi değildir; offline ve aboneliksiz kişisel takip ayrı bir alt niştir.
- **RSS/GPX/music metadata:** Dar, yerel dosya odaklı ve uzman kullanıcıya yönelik araçlar chart dışında geniş bir uzun kuyruk oluşturuyor.

## Faz 3A kaynak notları

- Apple Search API dokümanı: https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html
- Apple App Analytics: https://developer.apple.com/app-store-connect/analytics/
- Apple Analytics metric definitions: https://developer.apple.com/help/app-store-connect-analytics/reference/metrics-definitions/
- Clockify resmî kullanıcı ifadesi: https://clockify.me/
- Jibble’ın 1,3 milyon kullanıcı açıklaması: https://www.jibble.io/creating-billion-dollar-time-tracking-software-company

## Faz 3 sonraki tarama sırası

1. PDF, file converter, duplicate finder, download manager ve backup.
2. Database, API client, Git, terminal, JSON/CSV/XML ve developer menu-bar.
3. Recipe, plant care, home inventory, personal finance ve receipt management.
4. Audio recorder, podcast, subtitle, video converter ve photo metadata.
5. TR/GB/DE/CA/AU/JP storefront eşleştirmesi.
6. A–Z/0–9 ve geliştirici-kataloğu genişletmesi.

**Sürüm:** 3A — 2 Ağustos 2026

# Faz 3B — İkinci Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana storefront:** United States; bazı kayıtlar başka Apple storefront’unda doğrulanmıştır  
**Yeni benzersiz `trackId`:** 105  
**Önceki envanterle çakıştığı için çıkarılan:** 1  
**Temsil edilen kategori:** 6

> [!IMPORTANT]
> Bu bölüm Apple App Store ürün sayfaları veya Apple sayfalarını indeksleyen güncel arama sonuçlarıyla doğrulanan uygulamaları içerir. Fiyat veya geliştirici bilgisi sonuçta görünmüyorsa alan açıkça `doğrulama bekliyor` bırakılmıştır; tahmin yapılmamıştır.

## Faz 3B kapsamı

| Küme | Uygulama sayısı |
|---|---:|
| PDF ve belge dönüştürme | 16 |
| Duplicate finder ve temizleme | 13 |
| Backup ve sync | 11 |
| Database | 11 |
| Git/API/SFTP | 27 |
| Receipt ve expense | 15 |
| Personal finance | 17 |
| **Toplam** | **105** |

## Monetizasyon görünümü

| Model | Kayıt |
|---|---:|
| UNKNOWN | 52 |
| FREEMIUM | 26 |
| PAID | 12 |
| FREE | 6 |
| SUB | 3 |
| HYBRID | 2 |
| LIFE | 1 |
| FREE/SERVICE | 1 |
| PAID/LIFE | 1 |
| FREEMIUM/LIFE | 1 |

## Kullanım ve indirme verisi durumu

- Bu partide rakip uygulamalar için geliştirici tarafından açıklanmış, **Mac’e özel kesin indirme veya aktif kullanıcı sayısı bulunmadı**.
- Apple ürün sayfasındaki rating sayısı bulunduğunda sonraki ürün-zenginleştirme fazında `PUBLIC-PROXY` olarak eklenecektir; indirme sayısı olarak yorumlanmayacaktır.
- Universal veya hizmet tabanlı uygulamalarda açıklanan toplam kullanıcı sayısı, Mac kurulumu ayrı verilmedikçe `all-platform` olarak tutulacaktır.

## Faz 3B uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Platform | Offline/bağımlılık | Kesin Mac indirme/MAU | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|
| 1477152278 | Zoho Expense: Expense Reports | Business | Zoho Corporation | Free download; service plans | SUB | Corporate expenses and receipt OCR | Only for Mac | Cloud/service dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/zoho-expense-expense-reports/id1477152278?mt=12) |
| 582840582 | General DB | Business | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Desktop SQL database builder | Mac | Local database | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/general-db/id582840582) |
| 901110441 | Ninox Database | Business | Ninox Software | Mac purchase / service plans | HYBRID | No-code database and app platform | Mac + iOS + web | Local/cloud sync | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ninox-database/id901110441) |
| 482807403 | Shoeboxed Uploader | Business | Shoeboxed.com | Free | FREE/SERVICE | Receipt upload companion | Only for Mac | Shoeboxed service dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/shoeboxed-uploader/id482807403?mt=12) |
| 1483089298 | Expense for Business | Business | Starkode | Free + IAP | FREEMIUM | Team expenses and receipt scanning | Only for Mac | Cloud/team workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/expense-for-business/id1483089298) |
| 6752702773 | DevTools - Developer Toolkit | Developer Tools | Developer not parsed | $2.99 | PAID | 38 native developer utilities | Only for Mac | Local tools; HTTP requests use network | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/devtools-developer-toolkit/id6752702773) |
| 6475777033 | Aspen - Your API’s Best Friend | Developer Tools | Treblle Limited | Free | FREE | AI-powered native HTTP client | Only for Mac | Local request history; AI capability may connect | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/aspen-your-apis-best-friend/id6475777033) |
| 959467315 | Database Pro | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Access and SQLite database viewer/editor | Only for Mac | Local database | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/database-pro/id959467315?mt=12) |
| 6757170632 | devPad | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Edge panel with code, AI and API tools | Only for Mac | Local storage; AI may use cloud | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/devpad/id6757170632?mt=12) |
| 1099475282 | SnailGit Lite – Git for Finder | Developer Tools | Langui.net | Free | FREE | Finder-integrated Git client | Mac | Local repositories | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/snailgit-lite-git-for-finder/id1099475282) |
| 847260112 | SnailGit – Git for Finder | Developer Tools | Langui.net | Fiyat doğrulaması bekliyor | PAID | Finder-integrated Git client | Only for Mac | Local repositories | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/snailgit-git-for-finder/id847260112?mt=12) |
| 1475511261 | Gitfox | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Full Git GUI | Mac | Local repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/gitfox/id1475511261?mt=12) |
| 1582642693 | TaoGit | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Git GUI client | Only for Mac | Local repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/taogit/id1582642693) |
| 1575689398 | Git Credential Manager | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Git authentication helper | Only for Mac | Local credential storage/network auth | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/git-credential-manager/id1575689398?mt=12) |
| 1524200727 | Gotcha Rest Client | Developer Tools | Binbin Shen | Free + IAP | FREEMIUM | HTTP client and Swagger/OpenAPI | Only for Mac | No network required except API calls | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/gotcha-rest-client/id1524200727?mt=12) |
| 1040403936 | Simple Git Server | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | LAN Git server | Only for Mac | Local network | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/simple-git-server/id1040403936) |
| 959332335 | Git Browser | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Lightweight Git client | Only for Mac | Local repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/git-browser/id959332335?mt=12) |
| 6476895438 | Git Browser Lite | Developer Tools | Developer not parsed | Free | FREE | Lightweight Git client | Only for Mac | Local repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/git-browser-lite/id6476895438) |
| 6747738193 | DevKnife | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Local developer toolbox with HTTP client | Only for Mac | Tools run locally | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/devknife/id6747738193) |
| 6747081748 | API_TESTER | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Menu-bar API client | Mac | Local request storage | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/api-tester/id6747081748) |
| 828466809 | SQLPro for MSSQL | Developer Tools | Hankinsoft Development | Fiyat doğrulaması bekliyor | UNKNOWN | Microsoft SQL Server client | Only for Mac | Database connection required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sqlpro-for-mssql/id828466809) |
| 1504776265 | Git Mounter | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Mount Git repositories | Only for Mac | Local/remote Git | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/git-mounter/id1504776265?mt=12) |
| 985614903 | SQLPro Studio | Developer Tools | Hankinsoft Development | Free + IAP | FREEMIUM | Multi-database SQL client | Only for Mac | Database connection required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sqlpro-studio/id985614903) |
| 899174769 | SQLPro for MySQL | Developer Tools | Hankinsoft Development | Fiyat doğrulaması bekliyor | UNKNOWN | MySQL and MariaDB client | Only for Mac | Database connection required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sqlpro-for-mysql/id899174769) |
| 6748295494 | ApiNova | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Native API client | Only for Mac | Local request workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/vn/app/apinova/id6748295494?mt=12) |
| 1603003585 | Gitonium Git Client | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Native Git GUI and diff | Mac | Local repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/gitonium-git-client/id1603003585?mt=12) |
| 597182608 | SQL Studio | Developer Tools | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Native Microsoft SQL client | Mac | Database connection required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sql-studio/id597182608) |
| 6744867438 | Base - SQLite Editor | Developer Tools | Menial | Free + one-time unlock | LIFE | Native SQLite editor | Only for Mac | Offline local database | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/base-sqlite-editor/id6744867438) |
| 6752625438 | NativeRest | Developer Tools | NativeSoft, LLC | $8.99 | PAID | Offline-capable REST API client | Only for Mac | Offline local workspaces | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/nativerest/id6752625438?mt=12) |
| 1228242832 | EasyGit | Developer Tools | Georgios Verigakis | Free / no subscription | FREE | Private Git hosting on iCloud | Only for Mac | iCloud dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/easygit/id1228242832) |
| 1631827909 | ApiScout REST Api HTTP Client | Developer Tools | Ruslan Sayfutdinov | Free + IAP | FREEMIUM | REST API development client | Only for Mac | Local request workspace | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/apiscout-rest-api-http-client/id1631827909?mt=12) |
| 6446987963 | Redis Insight | Developer Tools | Redis | Free | FREE | Redis GUI and analysis | Mac | Local/remote Redis connections | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/redis-insight/id6446987963) |
| 446135273 | SQL Database Pro | Developer Tools | Impact Financials | Fiyat doğrulaması bekliyor | UNKNOWN | SQLite database editor | Only for Mac | Offline local database | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sql-database-pro/id446135273?mt=12) |
| 6462117890 | OpenSFTP | Developer Tools | Developer not parsed | Free + IAP | FREEMIUM | SSH, terminal and SFTP client | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/opensftp/id6462117890?mt=12) |
| 6755695843 | Money Chat M — expense tracker | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | AI expense entry and budgeting | Only for Mac | AI processing scope not verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/money-chat-m-expense-tracker/id6755695843?mt=12) |
| 6755680136 | Budget Planner: Bill Organizer | Finance | Nimra Jamil | Free + IAP | FREEMIUM | Budget and bill organizer | Only for Mac | Local/cloud status not verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/budget-planner-bill-organizer/id6755680136?mt=12) |
| 1477715536 | PocketMoney | Finance | PocketMoney GmbH | Free + subscriptions | SUB | Budget and expense tracking | Only for Mac | Local/sync workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pocketmoney/id1477715536?mt=12) |
| 1501244873 | MoneyStats - Budget Planner | Finance | Tom Tennstedt | Free + IAP | FREEMIUM | Budget, bank import and receipt scanner | Only for Mac | Local/iCloud; bank import online | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/moneystats-budget-planner/id1501244873?mt=12) |
| 634892482 | MoneyControl Budget Tracker | Finance | Priotecs IT GmbH | Free + IAP | FREEMIUM | Budget, recurring expenses and receipts | Only for Mac | Local data; optional sync | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/moneycontrol-budget-tracker/id634892482?mt=12) |
| 1591642644 | Cashculator: Personal Finance | Finance | Apparent Software Inc. | Free + IAP | FREEMIUM | Cash-flow planning and forecasting | Only for Mac | Local-first finance planning | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/cashculator-personal-finance/id1591642644?mt=12) |
| 1556431950 | Gekko Accounting - Desktop | Finance | Gekko | Free/service plan pending | SUB | Costs, invoices and time | Only for Mac | Service dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/gekko-accounting-desktop/id1556431950?mt=12) |
| 1502129505 | Zacc - Smart Expense tracker | Finance | iSolid apps | Free + IAP | FREEMIUM | Create expenses from PDF documents | Only for Mac | Local document processing | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/zacc-smart-expense-tracker/id1502129505?mt=12) |
| 405383164 | Budget | Finance | Snowmint Creative Solutions LLC | $39.99 | PAID | Envelope budgeting | Only for Mac | Standalone; optional iOS sync | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/budget/id405383164?mt=12) |
| 6444531544 | MoneyWell : Personal Budgeting | Finance | Diligent Robot | Free + IAP | FREEMIUM | Envelope budgeting | Only for Mac | Local-first | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/moneywell-personal-budgeting/id6444531544) |
| 964789074 | Expense Manager | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Expense and receipt records | Only for Mac | Local workflow not fully verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/expense-manager/id964789074) |
| 579040146 | HomeBudget Lite (w/ Sync) | Finance | Developer not parsed | Free limited | FREEMIUM | Household budget and bills | Mac | Local/sync workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/homebudget-lite-w-sync/id579040146?mt=12) |
| 6745615041 | Budgix: Budget Planner | Finance | RANR Studios LLC | Free + IAP | FREEMIUM | Income and expense budgeting | Only for Mac | Local data not fully verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/budgix/id6745615041) |
| 1482614257 | MoneyMeter | Finance | SN AnyDevice Software Solutions | Free | FREE | Income and expense tracker | Only for Mac | Local workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/moneymeter/id1482614257) |
| 439577896 | ReceiptBox: Receipt Tracker | Finance | Georgios Trigonakis | $1.99 | PAID | Manual receipt and expense organizer | Only for Mac | Local records | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/receiptbox-receipt-tracker/id439577896) |
| 1608080728 | CheckBook 3 | Finance | Splasm Software | Free + IAP | FREEMIUM/LIFE | No-subscription money manager | Only for Mac | Local/iCloud/network sync | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/checkbook-3/id1608080728?mt=12) |
| 1255878751 | Visual Budget Easy | Finance | Pascal Meziat | Free + IAP | FREEMIUM | Personal accounting and budget | Only for Mac | Local workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/visual-budget-easy/id1255878751?mt=12) |
| 882637653 | Debit & Credit | Finance | Ivan Pavlov Pty Ltd | Free + IAP | FREEMIUM | Personal finance manager | Only for Mac | Local/iCloud workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/debit-credit/id882637653?mt=12) |
| 6766120236 | FlowFunds Finance Planner | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Personal financial scenario planning | Only for Mac | Local/cloud status not verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/flowfunds-finance-planner/id6766120236?mt=12) |
| 1484750198 | Receipt Ticket Storage | Finance | Developer not parsed | $6.99 | PAID | Private local receipt archive | Only for Mac | Offline local data; iCloud optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/receipt-ticket-storage/id1484750198) |
| 6768749208 | Perfinova: Net Worth Tracker | Finance | Developer not parsed | No subscription stated; exact price pending | PAID/LIFE | Private net-worth tracking | Only for Mac | Local-only, no bank login | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/perfinova-net-worth-tracker/id6768749208?mt=12) |
| 1604977734 | Receipts Space | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Receipt search, tagging and reports | Only for Mac | Shared-folder/local workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/receipts-space/id1604977734) |
| 6760080439 | Quick Accounts Books | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Receipt tracker and expense ledger | Only for Mac | Local/cloud status not verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/quick-accounts-books/id6760080439?mt=12) |
| 407094598 | GreenBooks - Money Manager | Finance | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Simple personal finance manager | Only for Mac | Local workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/greenbooks-money-manager/id407094598?mt=12) |
| 586594646 | Backups for Final Cut Pro | Photo & Video | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Final Cut project backup | Only for Mac | Local scheduled backup | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/backups-for-final-cut-pro/id586594646) |
| 1619925971 | UPDF: AI PDF Editor, Converter | Productivity | Superace Software | Free/IAP doğrulaması bekliyor | FREEMIUM | AI PDF editor and converter | Mac + iOS/iPadOS | Editing local; AI cloud dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/updf-ai-pdf-editor-converter/id1619925971) |
| 1621134062 | PDF Converter, Reader & Editor | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | All-in-one PDF converter | Only for Mac | Local file conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-reader-editor/id1621134062?mt=12) |
| 781326302 | EPUB & PDF interconverter | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | EPUB/PDF conversion | Mac | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/epub-pdf-interconverter/id781326302) |
| 1221383257 | JPG to PDF | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Image to PDF conversion | Mac version available | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/jpg-to-pdf/id1221383257) |
| 1024974133 | Mountain Duck | Productivity | iterate GmbH | Fiyat doğrulaması bekliyor | PAID | Mount cloud and server storage | Mac | Cloud/network dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/mountain-duck/id1024974133) |
| 1081041948 | The Document Converter | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Multi-format document conversion | Mac | Conversion model not fully verified | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/the-document-converter/id1081041948?mt=12) |
| 513825638 | Enolsoft PDF Converter | Productivity | Enolsoft | Fiyat doğrulaması bekliyor | UNKNOWN | PDF conversion | Only for Mac | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/enolsoft-pdf-converter/id513825638) |
| 422540826 | PDF Converter Pro | Productivity | Wondershare | Fiyat doğrulaması bekliyor | UNKNOWN | PDF conversion | Mac | Offline core conversion likely | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-pro/id422540826?mt=12) |
| 615956269 | PDF Reader: Edit, Fill, Sign | Productivity | Kdan Mobile | Free/IAP doğrulaması bekliyor | FREEMIUM | PDF edit, OCR and AI | Mac + iOS/iPadOS | Offline editing; AI connected | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-reader-edit-fill-sign/id615956269?mt=12) |
| 6753673093 | PDF Converter :Editor & Reader | Productivity | Hira Razzaq | Fiyat doğrulaması bekliyor | UNKNOWN | PDF editor and converter | Only for Mac | Local document workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-editor-reader/id6753673093) |
| 1459989579 | PDF Converter, Editor & Reader | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | PDF editor and converter | Only for Mac | Local document workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-editor-reader/id1459989579?mt=12) |
| 6496689357 | PDF Reader + Converter | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | PDF reader and converter | Only for Mac | Local document workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-reader-converter/id6496689357) |
| 1467708337 | Quick PDF Converter | Productivity | iPDFApps | $29.99 | PAID | PDF to DOCX/PPTX/XLSX | Only for Mac | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/quick-pdf-converter/id1467708337) |
| 6471829327 | PDF Converter! Convert to Word | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | PDF to Office conversion | Only for Mac | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-convert-to-word/id6471829327?mt=12) |
| 693049050 | PDF to Text Converter Expert | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | PDF to text conversion | Only for Mac | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-to-text-converter-expert/id693049050) |
| 1194023259 | PDFGenius | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | PDF utility suite | Mac | Local document workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdfgenius/id1194023259) |
| 1568395334 | Collections Database | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Personal custom database | Mac | Local-first | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/collections-database/id1568395334) |
| 1211616656 | PDF Converter OCR | Productivity | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Scanned PDF OCR conversion | Mac | Local OCR; Intel/Rosetta risk noted | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pdf-converter-ocr/id1211616656) |
| 1457961323 | diskDedupe | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | APFS clone-based deduplication | Mac | On-device APFS processing | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diskdedupe/id1457961323) |
| 904801687 | ChronoSync Express | Utilities | Econ Technologies | Fiyat doğrulaması bekliyor | UNKNOWN | Backup, mirror and bidirectional sync | Mac | Local/NAS/network backup | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/chronosync-express/id904801687) |
| 6651839688 | iBackup Viewer | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Browse and export iOS backups | Only for Mac | Local backup inspection | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ibackup-viewer/id6651839688) |
| 1339090659 | Sync - Backup and Restore | Utilities | Miciniti | Free + IAP | FREEMIUM | Cloud/local backup and restore | Only for Mac | Cloud/local hybrid | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sync-backup-and-restore/id1339090659) |
| 6780279043 | Upstream - FTP & SFTP Client | Utilities | Developer not parsed | Free + advanced unlock | FREEMIUM | Dual-pane FTP/SFTP client | Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/upstream-ftp-sftp-client/id6780279043?mt=12) |
| 1531356846 | Duplicate Finder and Cleaner | Utilities | MoneyPlant Technologies | Free trial / purchase unknown | FREEMIUM | Duplicate and similar-file cleanup | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-finder-and-cleaner/id1531356846?mt=12) |
| 1028377047 | OnlyOne X - Duplicates Cleaner | Utilities | Developer not parsed | Free shell / paid unlock unclear | FREEMIUM | Duplicate cleaner | Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/onlyone-x-duplicates-cleaner/id1028377047) |
| 6479635558 | 4DDiG Duplicate File Deleter | Utilities | Tenorshare | $24.99 monthly / $59.99 annual / $69.99 lifetime | HYBRID | Duplicate file cleanup | Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/4ddig-duplicate-file-deleter/id6479635558) |
| 1602331946 | Duplicate Files Finder - Fixer | Utilities | Samotya Software | Fiyat doğrulaması bekliyor | UNKNOWN | Duplicate file cleanup | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-files-finder-fixer/id1602331946) |
| 1516615983 | Duplicate Files Fixer | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Duplicate file cleanup | Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-files-fixer/id1516615983?mt=12) |
| 1438318036 | Duplicate Files Sweeper | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Duplicate files and Photos cleanup | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-files-sweeper/id1438318036) |
| 1032755628 | Duplicate File Finder Remover | Utilities | Nektony | Free + Pro IAP | FREEMIUM | Duplicate files, folders and similar media | Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-file-finder-remover/id1032755628?mt=12) |
| 1295683946 | 1Click Duplicate Finder | Utilities | Developer not parsed | Free + IAP | FREEMIUM | Duplicate, similar and large files | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/1click-duplicate-finder/id1295683946?mt=12) |
| 1298486723 | FileZilla Pro - FTP and Cloud | Utilities | FileZilla | Fiyat doğrulaması bekliyor | PAID | FTP/SFTP and cloud transfer | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/filezilla-pro-ftp-and-cloud/id1298486723?mt=12) |
| 1455237064 | Speedy Duplicate Finder | Utilities | Developer not parsed | Free + IAP | FREEMIUM | Fast duplicate finder | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/speedy-duplicate-finder/id1455237064) |
| 595553555 | Backup Guru LE | Utilities | FelixDev | Fiyat doğrulaması bekliyor | UNKNOWN | File backup and sync | Only for Mac | Local backup | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/backup-guru-le/id595553555) |
| 6503973158 | Duplicate File Finder:DupDupGo | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Lightweight duplicate finder | Only for Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/duplicate-file-finder-dupdupgo/id6503973158?mt=12) |
| 1300094971 | SFTP Server | Utilities | Langui.net | $6.99 | PAID | Local SFTP server | Only for Mac | Local/network server | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sftp-server/id1300094971?mt=12) |
| 6738340521 | Zero Duplicates | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Local duplicate detection | Mac | All scanning local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/zero-duplicates/id6738340521?mt=12) |
| 1479424852 | Transfer: File Server | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Local file-transfer server | Only for Mac | Local/network server | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/transfer-file-server/id1479424852?mt=12) |
| 6446834339 | Dupes Master | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Metadata-aware duplicate finder | Mac | On-device scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/be/app/dupes-master/id6446834339?mt=12) |
| 6756709885 | Sync: Backup & Restore Files | Utilities | Miciniti | Free + IAP | FREEMIUM | Multi-cloud and USB backup | Mac | Cloud/local hybrid | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sync-backup-restore-files/id6756709885?mt=12) |
| 6757720267 | Gopher FTP | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Native SFTP/FTP client | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/gopher-ftp/id6757720267?mt=12) |
| 601887982 | Flash Drive Backup | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Removable-drive backup | Only for Mac | Local backup | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/flash-drive-backup/id601887982) |
| 6746113014 | Backone | Utilities | Developer not parsed | One-time purchase | PAID | S3 and Backblaze B2 backup | Mac | Cloud backup; no subscription | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/backone/id6746113014) |
| 1484196148 | SFTP Commander | Utilities | Marcin Labenski | $5.99 | PAID | SFTP/FTP/FTPS client | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/sftp-commander/id1484196148?mt=12) |
| 599283805 | Backup | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | Scheduled folder backup | Mac | Local file copy | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/backup/id599283805?mt=12) |
| 1270635822 | Ultimate Backup | Utilities | Developer not parsed | Fiyat doğrulaması bekliyor | UNKNOWN | User-profile and Photos backup | Only for Mac | Local backup | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ultimate-backup/id1270635822) |

## Faz 3B pazar sinyalleri

- **PDF pazarı:** İsim ve özellik benzerliği çok yüksek. OCR, offline çalışma, format doğruluğu, batch workflow ve güvenilir lifetime fiyatı olmadan farklılaşmak zor.
- **Duplicate finder:** Ücretsiz tarama + ücretli silme/otomatik seçim yaygın. $24.99 aylık ile $69.99 lifetime arasında agresif hibrit fiyat örneği bulunuyor; güven ve geri alınabilir silme kritik.
- **Backup:** Yerel klasör kopyalama, NAS, USB, S3/B2 ve multi-cloud ayrı mikro-nişler. Aboneliksiz tek seferlik cloud-backup client hâlâ farklılaşabiliyor.
- **Database:** SQLite, MSSQL, MySQL, Redis ve no-code database ayrı ürün pazarları. Native hız, düşük bellek kullanımı ve bir defalık unlock güçlü satın alma argümanları.
- **Git/API:** Yeni native API istemcileri hesap zorunluluğu olmaması, local workspace ve hızlı açılışla Postman türü ağır araçlara karşı konumlanıyor.
- **Receipt/personal finance:** Tam otomatik bankacılık ürünlerinin yanında local-only, bank login gerektirmeyen ve aboneliksiz araçlar belirgin bir gizlilik nişi oluşturuyor.

## Veri kalitesi notları

- `Only for Mac` etiketi Apple sayfasında görülen kayıtlarda doğrudan yazıldı.
- Başka storefront’ta bulunan ancak aynı Apple `trackId` ile doğrulanan kayıtlar korunmuştur.
- Fiyatı arama sonucunda görünmeyen uygulamalara ücret tahmini eklenmemiştir.
- Aynı uygulamanın farklı başlık varyantları `trackId` ile tekilleştirilmiştir.

## Sonraki Faz 3C tarama kümeleri

1. File converter, archive, download manager, disk analyzer ve data recovery.
2. JSON/XML/YAML/CSV, regex, diff/merge, log viewer ve network debugging.
3. Recipe, pantry, plant care, home inventory, wardrobe ve pet care.
4. Audio recorder, podcast, subtitle, transcription ve media metadata.
5. Türkiye, Almanya, Japonya ve diğer storefront’larda US sonuçlarında görünmeyen uygulamalar.

**Sürüm:** 3B — 2 Ağustos 2026

# Faz 3C — Üçüncü Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Yeni benzersiz `trackId`:** 78  
**Önceki envanterle çakıştığı için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 258

> [!IMPORTANT]
> Bu turdaki kayıtlar Apple ürün sayfalarında Mac, Only for Mac veya Mac uyumluluğu sinyali bulunan uygulamalardan oluşturulmuştur. Evrensel uygulamalarda Mac türü kesinleşmediyse platform alanında ayrıca belirtilmiştir.

## Faz 3C küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Archive & compression | 15 |
| Download managers | 5 |
| Disk analysis & cleanup | 13 |
| Data recovery | 6 |
| Structured-data editors | 12 |
| Regex | 7 |
| Diff & merge | 10 |
| Logs & network debugging | 14 |
| **Toplam benzersiz kayıt** | **78** |

## Kategori dağılımı

| Kategori | Kayıt |
|---|---:|
| Developer Tools | 40 |
| Utilities | 35 |
| Productivity | 1 |
| Business | 1 |
| Education | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| UNKNOWN | 50 |
| FREEMIUM | 13 |
| FREE | 7 |
| PAID | 4 |
| LIFE | 3 |
| PAID/LIFE | 1 |

## Kullanım ve indirme verisi

- Bu partide kamuya açık olarak doğrulanabilen **Mac’e özel kesin indirme veya aylık aktif kullanıcı sayısı bulunmadı**.
- App Store’da `Ratings & Reviews` sayıları bazı ürünlerde görülebiliyor; bunlar daha sonraki zenginleştirme turunda talep proxy’si olarak alınacak.
- Review içindeki “şu kadar GB temizledim” veya “şu fiyatı ödedim” gibi kullanıcı ifadeleri ürün kullanım sayısı değildir.
- Fiyatın yalnızca eski bir review içinde görüldüğü kayıtlarda güncel fiyat olarak kabul edilmedi; `current price pending` şeklinde işaretlendi.

## Faz 3C uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Platform | Offline/bağımlılık | Kesin Mac indirme/MAU | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|
| 6499133085 | Zip: RAR ZIP 7Z Extractor | Business | CYNOBLE TECHNOLOGY LIMITED | Free | FREE | Archive extraction and file management | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/zip-rar-zip-7z-extractor/id6499133085?mt=12) |
| 6755523203 | Developer Tools Pro | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | 100+ conversion, formatting and encoding tools | Mac | Primarily local tools | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/developer-tools-pro/id6755523203) |
| 6747320780 | Logzi | Developer Tools | Developer not parsed | Free sample + CloudWatch IAP | FREEMIUM | AWS CloudWatch desktop log client | Only for Mac | Cloud service required for live data | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/logzi/id6747320780?mt=12) |
| 6742788999 | LogShow - Log Viewer & Parser | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Apache, Nginx and system log parser | Only for Mac | Offline local logs | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/logshow-log-viewer-parser/id6742788999) |
| 6661031747 | Pulse – Network Logger | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Apple-platform network log viewer | Mac | Local log viewing | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pulse-network-logger/id6661031747) |
| 6446118001 | smasi CSV-Wizard | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Batch CSV cleanup and conversion | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/smasi-csv-wizard/id6446118001) |
| 1122008420 | Table Tool | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | CSV create, edit and convert | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/table-tool/id1122008420?mt=12) |
| 6758530171 | CSVMagic | Developer Tools | Developer not parsed | $2.99 | PAID | CSV editing, filtering and visualization | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/csvmagic/id6758530171) |
| 6774656906 | DiskStash | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Developer-cache and build-artifact cleaner | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diskstash/id6774656906) |
| 412742800 | Compare | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | File and directory compare/merge | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/compare/id412742800?mt=12) |
| 1661588357 | JuxtaCode | Developer Tools | Developer not parsed | 14-day trial + one-time unlock | LIFE | Git history, code diff and conflict resolution | Only for Mac | Offline repositories; remote optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/juxtacode/id1661588357?mt=12) |
| 1602229284 | Proxygen | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | HTTP proxy and remote API debugging | Mac + iPhone/iPad | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/proxygen/id1602229284) |
| 6744374600 | ParseLab | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | JSON, YAML, TOML, XML, PLIST, INI and CSV editor | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/parselab/id6744374600) |
| 6759005643 | Logfile Expert | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Local and SSH remote log analysis | Only for Mac | Offline local / network for SSH | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/logfile-expert/id6759005643) |
| 1543753042 | Log-Viewer | Developer Tools | Developer not parsed | Free/open source status pending | FREE | Local tail-style log viewer | Only for Mac | Offline local logs | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/log-viewer/id1543753042?mt=12) |
| 6755344508 | Logarithmic: Log View/AppTrace | Developer Tools | Developer not parsed | $9.99 | PAID | Log tailing, sessions and MCP/AI integration | Only for Mac | Local logs; AI optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/logarithmic-log-view-apptrace/id6755344508?mt=12) |
| 1546140065 | RegExp | Developer Tools | Developer not parsed | Free + one-time unlock | LIFE | Multi-engine regex testing | Mac + iPhone/iPad | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/regexp/id1546140065) |
| 6477299212 | CSV Editor Pro X | Developer Tools | Indigogo LTD | Exact price pending | UNKNOWN | Native CSV editor with bulk operations | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/csv-editor-pro-x/id6477299212?mt=12) |
| 6757188997 | ABDiff | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Native multimodal diff and Git mergetool | Only for Mac | No uploads or cloud processing | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/abdiff/id6757188997?mt=12) |
| 1024640650 | CotEditor | Developer Tools | CotEditor Project | Free | FREE | Native plain-text and source editor | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/coteditor/id1024640650?mt=12) |
| 6760928924 | Regex Tool: Pattern Editor | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Native real-time regex tester | Only for Mac | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/regex-tool-pattern-editor/id6760928924?mt=12) |
| 6759225443 | Diff Forge | Developer Tools | Developer not parsed | No subscription; exact price pending | PAID/LIFE | Native text compare and merge | Mac availability requires final QA | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diff-forge/id6759225443?mt=12) |
| 6754194710 | JSON Viewer & Formatter | Developer Tools | Developer not parsed | Free/Pro status pending | FREEMIUM | Offline JSON format, validate and compare | Mac compatibility requires product-page QA | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/json-viewer-formatter/id6754194710) |
| 6742767975 | Packet Capture Pro: HTTPS | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Packet capture, HTTP proxy and API testing | Mac + iPhone | Network/VPN required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/packet-capture-pro-https/id6742767975) |
| 6758266023 | JSON Viewer & Editor | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Privacy-first offline JSON editor | Mac | Fully offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/json-viewer-editor/id6758266023) |
| 6760284919 | OnePreview | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Quick Look for Markdown, data, logs, SQLite and ZIP | Mac + iPhone/iPad | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/onepreview/id6760284919) |
| 6745112974 | Log Viewer | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Real-time local log monitor and search | Only for Mac | Offline local logs | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/log-viewer/id6745112974) |
| 429449079 | Patterns - The Regex App | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Regex builder, test and reference | Only for Mac | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/patterns-the-regex-app/id429449079?mt=12) |
| 422501241 | Regex Tester/Builder | Developer Tools | Developer not parsed | $4.99 observed in review; current price pending | PAID | Regex learning and testing | Only for Mac | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/regex-tester-builder/id422501241?mt=12) |
| 6450203331 | Log-Viewer SSH | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Remote tail -f over SSH | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/log-viewer-ssh/id6450203331) |
| 6743792866 | SocksSSH | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | SSH tunnels, SOCKS5 proxy and connection logs | Mac + Apple platforms | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/socksssh/id6743792866) |
| 6504801865 | JuxtaText | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Text compare and three-way merge | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/juxtatext/id6504801865?mt=12) |
| 6749842857 | Diff Pro Max - File Compare | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Text, PDF, Excel, image, audio and video diff | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diff-pro-max-file-compare/id6749842857?mt=12) |
| 1459748650 | CompareMerge2 | Developer Tools | Developer not parsed | Free limited + IAP | FREEMIUM | Text, binary, folder, archive and document diff | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/comparemerge2/id1459748650?mt=12) |
| 478570084 | CompareMerge | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Text-file comparison and merge | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/comparemerge/id478570084?mt=12) |
| 1616105820 | Egern | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Traffic interception, rules and modification | Mac + Apple platforms | Network/VPN required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/egern/id1616105820) |
| 1565766176 | Power YAML Editor | Developer Tools | Developer not parsed | Paid; exact price pending | PAID | Tree-based YAML editor and converter | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/power-yaml-editor/id1565766176?mt=12) |
| 6479258228 | Otter Log Console | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Unified OSLog console and filtering | Mac | Offline local logs | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/otter-log-console/id6479258228) |
| 6742394218 | MintFlow NetStack | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | VPN, proxy and HTTP debugging toolkit | Mac + Apple platforms | Network/VPN required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/mintflow-netstack/id6742394218) |
| 1550861119 | ViRE – Regex You Can Read | Developer Tools | Developer not parsed | 7-day trial; unlock price pending | FREEMIUM | Visual regex and unit-test workbench | Only for Mac | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/vire-regex-you-can-read/id1550861119) |
| 6745237099 | RegExpress | Developer Tools | Developer not parsed | Free + one-time Pro | LIFE | Visual regex explanation and testing | Mac + iPhone/iPad | Offline | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/regexpress/id6745237099) |
| 1659922841 | RegEx Tool | Education | Developer not parsed | Exact price pending | UNKNOWN | Regex tutorials and tester | Mac compatibility requires product-page QA | Offline content likely | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/regex-tool/id1659922841) |
| 1626263929 | Unzip – ZIP 7Z RAR Extractor | Productivity | Little Sweet Technology Co., Ltd. | Free | FREE | Lightweight archive manager | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/unzip-zip-7z-rar-extractor/id1626263929) |
| 6757130989 | Download Manager: IDM AI | Utilities | Developer not parsed | Exact price pending | UNKNOWN | AI-assisted download discovery and management | Mac compatibility requires product-page QA | Internet/AI dependent | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/download-manager-idm-ai/id6757130989) |
| 6756637009 | 4DDiG Data Recovery | Utilities | Tenorshare | Free scan / paid recovery; exact price pending | FREEMIUM | AI-assisted file recovery and repair | Only for Mac | Offline storage scan; AI scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/4ddig-data-recovery/id6756637009) |
| 1003170604 | iBoysoft Data Recovery | Utilities | iBoysoft | Free scan / paid recovery; exact price pending | FREEMIUM | APFS and external-media recovery | Only for Mac | Offline storage scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/iboysoft-data-recovery/id1003170604?mt=12) |
| 1492424532 | ZipMaster | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Archive create, preview and extract | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/zipmaster/id1492424532?mt=12) |
| 1521938791 | RAR Extractor-Unzip RAR ZIP 7Z | Utilities | Developer not parsed | Free/trial; exact IAP pending | FREEMIUM | Archive extraction and compression | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/rar-extractor-unzip-rar-zip-7z/id1521938791?mt=12) |
| 1127253508 | Unzip One: RAR ZIP Extractor | Utilities | Trend Micro, Incorporated | Free | FREE | Archive extraction, compression and encryption | Only for Mac | Offline local files; LAN sharing optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/unzip-one-rar-zip-extractor/id1127253508?mt=12) |
| 1535136051 | RAR Extractor - Unzip File | Utilities | 万林 彭 | Free + IAP | FREEMIUM | Archive extraction, preview and encryption | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/rar-extractor-unzip-file/id1535136051?mt=12) |
| 892162982 | 7Zip Browser | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Archive preview without extraction | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/7zip-browser/id892162982?mt=12) |
| 1039668027 | iLove Data Recovery | Utilities | Developer not parsed | Free scan / paid recovery; exact price pending | FREEMIUM | Deleted and formatted-media recovery | Only for Mac | Offline storage scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ilove-data-recovery/id1039668027?mt=12) |
| 740355970 | EaseUS Data Recovery Wizard | Utilities | EaseUS | Free scan / paid recovery; exact price pending | FREEMIUM | Deleted-file and formatted-drive recovery | Only for Mac | Offline storage scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/easeus-data-recovery-wizard/id740355970?mt=12) |
| 1208148558 | Data Recovery Essential | Utilities | Developer not parsed | Free daily recovery up to 100MB; paid tiers pending | FREEMIUM | Deleted-file recovery | Only for Mac | Offline storage scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/data-recovery-essential/id1208148558?mt=12) |
| 6761764836 | WarpFetch | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Direct-link, batch, FTP and SFTP downloader | Only for Mac | Internet/network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/warpfetch/id6761764836?mt=12) |
| 1435575700 | DirEqual | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Directory comparison | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/direqual/id1435575700?mt=12) |
| 6782939594 | DiskLens: Disk Space Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Disk analysis, duplicates and search | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/disklens-disk-space-analyzer/id6782939594?mt=12) |
| 6759896440 | DiskSpace - Cleaner & Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Disk map and system-data analysis | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diskspace-cleaner-analyzer/id6759896440?mt=12) |
| 1604650441 | EncryptedZip2 for zip rar | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Encrypted archive preview and extraction | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/encryptedzip2-for-zip-rar/id1604650441?mt=12) |
| 1669937452 | Storage Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | File-tree and treemap storage analyzer | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/storage-analyzer/id1669937452?mt=12) |
| 1434280883 | Unzip Files & RAR Extractor | Utilities | Developer not parsed | Free | FREE | Floating-drop archive extraction | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/unzip-files-rar-extractor/id1434280883?mt=12) |
| 431224317 | Disk Drill Data Recovery | Utilities | CleverFiles | Free scan / paid recovery; exact price pending | FREEMIUM | Mac and external-drive data recovery | Only for Mac | Offline storage scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/disk-drill-data-recovery/id431224317?mt=12) |
| 1450246547 | BestZip - Unarchive RAR&7Z&ZIP | Utilities | Chengdu Jieyou Technology Co., Ltd | Free + IAP | FREEMIUM | Multi-format archive manager | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/bestzip-unarchive-rar-7z-zip/id1450246547) |
| 1048421894 | jDM | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Native download manager with resume | Only for Mac | Internet required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/jdm/id1048421894?mt=12) |
| 6742862284 | iDM | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Native segmented download manager | Mac | Internet required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/idm/id6742862284) |
| 418423076 | YemuZip | Utilities | Developer not parsed | Exact price pending | UNKNOWN | PC-friendly ZIP creation | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/yemuzip/id418423076) |
| 488920185 | Disk Space Analyzer Pro | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Professional disk-space analyzer | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/disk-space-analyzer-pro/id488920185) |
| 6471000223 | UnZip Rar | Utilities | 路 张 | Free | FREE | RAR, 7z and ZIP extraction | Only for Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/unzip-rar/id6471000223) |
| 6775048425 | Orbyte - Disk Space Cleaner | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Safe disk cleanup with protected paths | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/orbyte-disk-space-cleaner/id6775048425) |
| 847809913 | Download Shuttle: Speed Boost | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Segmented download accelerator | Only for Mac | Internet required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/download-shuttle-speed-boost/id847809913?mt=12) |
| 446243721 | Disk Space Analyzer: Inspector | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Sunburst disk-space analyzer | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/disk-space-analyzer-inspector/id446243721?mt=12) |
| 6748727528 | Clean Space - Disk Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Sunburst storage analysis and review queue | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/clean-space-disk-analyzer/id6748727528?mt=12) |
| 6758895498 | KLARITY DISK | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Treemap and file-age heatmap analyzer | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/klarity-disk/id6758895498) |
| 6746690781 | DiskVisualizer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Treemap and file-extension disk analytics | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/diskvisualizer/id6746690781) |
| 715464874 | Disk Map: Visualize Disk Usage | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Treemap disk visualization | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/disk-map-visualize-disk-usage/id715464874?mt=12) |
| 6758438961 | TriClean Disk Cleaner Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Treemap, large-file and safe-trash cleanup | Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/triclean-disk-cleaner-analyzer/id6758438961?mt=12) |
| 764936294 | Purple Tree | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Visual disk analyzer with duplicate content | Only for Mac | Offline local scan | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/purple-tree/id764936294?mt=12) |
| 478738838 | iZip Archiver | Utilities | Developer not parsed | Exact price pending | UNKNOWN | ZIP, ZIPX, RAR, TAR and 7Z manager | Mac | Offline local files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/izip-archiver/id478738838?mt=12) |

## Faz 3C pazar sinyalleri

- **Archive:** Çok sayıda ücretsiz veya freemium kopya bulunuyor. Basit ZIP/RAR açıcı pazarı kalabalık; Quick Look, batch preview, şifre yönetimi ve güvenli kurumsal arşivleme daha savunulabilir.
- **Download manager:** 2025–2026 döneminde Apple Silicon’a göre optimize edilmiş native ürünler yeniden ortaya çıkıyor. Segmentli indirme tek başına yeterli değil; batch import, checksum, SFTP ve güvenli otomasyon fark yaratıyor.
- **Disk analyzer:** En hızlı büyüyen kümelerden biri. 2026’da yayımlanan ürünlerin çoğu treemap + safe Trash + developer cache temizliği kombinasyonuna yönelmiş.
- **Data recovery:** Güven, dosya önizleme ve ücret öncesi ücretsiz tarama standart hâline gelmiş. Bu alan teknik risk ve destek maliyeti yüksek.
- **Structured data:** JSON/YAML/CSV araçlarında offline, native ve tek seferlik fiyat mesajı güçlü. Ancak basit formatter pazarı çok kolay kopyalanabilir.
- **Regex/diff:** Dar profesyonel araçlar tek seferlik satın alma ile yaşayabiliyor. Visual explanation, multi-format diff ve Git entegrasyonu temel farklılaşma eksenleri.
- **Logs/network:** Local-first log viewer ile VPN/HTTPS interception ürünleri ayrı pazarlar. Güvenlik, sertifika kurulumu ve gizlilik açıklaması ürün başarısı için kritik.

## Veri kalitesi ve sınırlamalar

- Apple sayfasında açıkça `Only for Mac` görülen kayıtlar doğrudan işaretlendi.
- Bazı Universal/iPad uygulamalarında Mac dağıtım türünün native mi yoksa Apple-silicon iPad sürümü mü olduğu Faz 5’te doğrulanacak.
- Kesin güncel fiyat görünmeyen ürünler için üçüncü taraf fiyat tahmini yazılmadı.
- Aynı isimli iki ayrı `Log Viewer` kaydı farklı Apple kimlikleri taşıdığı için ayrı uygulama olarak korundu.

## Faz 3D sonraki tarama kümeleri

1. Network diagnostics, Wi-Fi scanner, port scanner, DNS, WHOIS ve packet tools.
2. Audio recorder, podcast, subtitle, transcription ve media conversion.
3. Recipe, pantry, plant care, home inventory, wardrobe ve pet care.
4. Türkiye, Almanya, Japonya ve diğer storefront’larda ABD’de görünmeyen uygulamalar.
5. Geliştirici kataloglarından aynı satıcıya ait chart-dışı uygulamalar.

**Sürüm:** 3C — 2 Ağustos 2026

# Faz 3D — Dördüncü Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Kaynak kapsamı:** Apple App Store ürün sayfaları ve Apple ürün sayfalarının güncel arama indeksleri  
**Yeni benzersiz `trackId`:** 82  
**Önceki envanterde bulunduğu için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 340  
**Top Charts dahil toplam veri satırı:** 1339

> [!IMPORTANT]
> `Mac compatibility requires final QA` yazılan ürünler Apple ürün sayfasında Mac uyumluluğu sinyali taşısa da native Mac, Catalyst veya Apple-silicon iPad dağıtım türü bu fazda kesinleşmemiştir. Faz 5 ürün sayfası zenginleştirmesinde ayrılacaktır.

## Faz 3D küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Network diagnostics | 20 |
| Media conversion | 17 |
| Audio/screen recording | 17 |
| Transcription & subtitles | 28 |
| **Toplam** | **82** |

## Kategori dağılımı

| Kategori | Kayıt |
|---|---:|
| Photo & Video | 31 |
| Utilities | 19 |
| Productivity | 15 |
| Music | 11 |
| Developer Tools | 5 |
| Business | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| FREEMIUM | 31 |
| UNKNOWN | 29 |
| PAID | 11 |
| FREE | 6 |
| SUB | 4 |
| HYBRID | 1 |

## Kullanım ve indirme sayıları

- Bu partide uygulama bazında kamuya açık, doğrulanmış ve **Mac’e özel kesin indirme/aktif kullanıcı sayısı bulunmadı**.
- Apple rating sayısı ve chart görünürlüğü sonraki zenginleştirmede yalnızca talep proxy’si olarak tutulacaktır.
- “Professional”, “millions”, “#1” veya benzeri pazarlama ifadeleri doğrulanabilir kullanıcı metriği olmadığı sürece sayı alanına yazılmayacaktır.
- Universal uygulamalarda mobil kullanıcı veya indirme sayısı Mac kullanımıyla birleştirilmeyecektir.

## Faz 3D uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Platform | Offline/bağımlılık | Kesin Mac indirme/MAU | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|
| 685310398 | Voice Recorder & Audio Editor | Business | Developer not parsed | Free + subscription/IAP | SUB | Voice recorder and podcast creator | Mac-compatible universal listing; type pending | Local recording; cloud uploads optional | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/voice-recorder-audio-editor/id685310398) |
| 990108872 | Audio Recorder & Music Editor Pro Lite | Music | 小磊 张 | Free | FREE | Audio recording and editing | Only for Mac | Offline local recording | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/audio-recorder-music-editor-pro-lite/id990108872?mt=12) |
| 970044455 | WavePad Audio Editor | Music | NCH Software | Free + IAP | FREEMIUM | Audio recording, editing and restoration | Only for Mac | Offline editing; AI feature scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/wavepad-audio-editor/id970044455?mt=12) |
| 1667175220 | Audio Capture Pro | Music | Developer not parsed | Free + IAP | FREEMIUM | Microphone and system-sound recorder | Only for Mac | Offline local capture | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/audio-capture-pro/id1667175220?mt=12) |
| 569460823 | MP3 Audio Recorder | Music | SEASOFT LTD. | Free + IAP | FREEMIUM | Microphone-to-MP3 recording | Only for Mac | Offline local recording | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/mp3-audio-recorder/id569460823?mt=12) |
| 845313878 | Easy Audio Recorder Lite | Music | Max Schlee | Free | FREE | Simple voice and music recorder | Only for Mac | Offline local recording | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/easy-audio-recorder-lite/id845313878?mt=12) |
| 1204109589 | Pro Microphone: Audio Recorder | Music | Inline Solutions s.r.o. | Free + IAP | FREEMIUM | Voice and music recording studio | Only for Mac | Offline local recording | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pro-microphone-audio-recorder/id1204109589?mt=12) |
| 975818620 | Professional Recorder & Editor | Music | Music Topia | Free + IAP | FREEMIUM | Voice, lecture and podcast recording/editing | Only for Mac | Offline local recording | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/professional-recorder-editor/id975818620?mt=12) |
| 6757546910 | Detail Capture | Photo & Video | Detail Technologies B.V. | Free + IAP | FREEMIUM | Camera and screen video recording | Only for Mac | Local capture; AI feature scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/detail-capture/id6757546910?mt=12) |
| 6737765196 | Screen Recorder: Record Audio | Photo & Video | Developer not parsed | Exact price pending | UNKNOWN | Screen and voice recording | Only for Mac | Offline recording supported | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/screen-recorder-record-audio/id6737765196?mt=12) |
| 6756659300 | knooth | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Screen recording, on-device AI audio cleanup and captions | Only for Mac | On-device AI; no cloud claimed | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/knooth/id6756659300?mt=12) |
| 593854334 | Movavi Screen Recorder | Photo & Video | Movavi | Free + IAP | FREEMIUM | Screen, system audio and microphone recording | Only for Mac | Offline capture; system-audio plugin required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/movavi-screen-recorder/id593854334?mt=12) |
| 1581903884 | Screen Recorder - EaseUS | Photo & Video | EaseUS | Free + IAP | FREEMIUM | Screen, system audio and podcast capture | Only for Mac | Local recording; plugin/service details pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/screen-recorder-easeus/id1581903884) |
| 6759790705 | SoundTake | Productivity | Harshad Jadav | $0.99 | PAID | Studio voice, interview and podcast recorder | Only for Mac | Offline local recording; no subscription | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/soundtake/id6759790705) |
| 1534312255 | Jack: System Audio Recorder | Productivity | Denk Alexandru | Free + IAP | FREEMIUM | System audio, microphone and screen capture | Only for Mac | Offline local capture | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/jack-system-audio-recorder/id1534312255?mt=12) |
| 1610255722 | Voice Memos - Audio Recorder | Productivity | Bitnite, TOO | Free + IAP | FREEMIUM | Voice recording and AI speech-to-text | Only for Mac | Recording local; AI scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/voice-memos-audio-recorder/id1610255722?mt=12) |
| 1059636487 | Apowersoft Audio Recorder | Utilities | Apowersoft Limited | Free | FREE | System and microphone audio recording | Only for Mac | Offline recording; online streams as source | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/apowersoft-audio-recorder-record-high-quality-audio/id1059636487?mt=12) |
| 418357707 | Cocoa Packet Analyzer | Developer Tools | Developer not parsed | Paid; exact price pending | PAID | Native PCAP protocol analyzer | Only for Mac; macOS 26+ in current listing | Offline existing PCAP files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/cocoa-packet-analyzer/id418357707) |
| 1612790003 | Audio Converter - One Click | Music | Developer not parsed | Free + IAP | FREEMIUM | Batch audio and video-to-audio conversion | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/audio-converter-one-click/id1612790003) |
| 1081480270 | The Audio Converter | Music | Developer not parsed | Subscription; exact tiers pending | SUB | General audio format converter | Only for Mac | Conversion processing model requires privacy QA | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/the-audio-converter/id1081480270?mt=12) |
| 1073828411 | To Audio Converter 2 | Music | Amvidia Limited | Free + IAP | FREEMIUM | Offline batch audio converter | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/to-audio-converter-2/id1073828411) |
| 1518836004 | Video Converter | Photo & Video | Developer not parsed | Free/IAP status pending | FREEMIUM | Apple-Silicon hardware-accelerated media converter | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/video-converter/id1518836004) |
| 1082682593 | The Video Converter | Photo & Video | Developer not parsed | Subscription; exact tiers pending | SUB | General video converter | Only for Mac | Conversion processing model requires privacy QA | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/the-video-converter/id1082682593?mt=12) |
| 406133389 | Video Converter Movavi | Photo & Video | Movavi | Exact price pending | UNKNOWN | High-speed video, audio and image conversion | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/video-converter-movavi/id406133389?mt=12) |
| 1637557903 | Video Converter X2 | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Multi-format video and audio converter | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/video-converter-x2/id1637557903) |
| 6446034307 | Any Converter - Video & Audio | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Native video and audio conversion | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/any-converter-video-audio/id6446034307) |
| 1463931354 | Video Converter and Compressor | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Video conversion, compression, trim and merge | Mac-compatible listing; type pending | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/video-converter-and-compressor/id1463931354) |
| 6480383511 | Video converter - transcoder | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Video transcoding | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/video-converter-transcoder/id6480383511?mt=12) |
| 1570653446 | Focus Video - Format Converter | Photo & Video | Developer not parsed | Exact price pending | UNKNOWN | Video/audio conversion and compression | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/focus-video-format-converter/id1570653446?mt=12) |
| 1294207675 | Media Converter - video to mp3 | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Video/audio conversion, compression and extraction | Mac-compatible universal listing; type pending | Local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/media-converter-video-to-mp3/id1294207675) |
| 464195348 | Leawo Video Converter Lite | Photo & Video | Leawo | Free + IAP | FREEMIUM | Video/audio converter with optional media toolbox | Only for Mac | Local conversion; optional online features | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/leawo-video-converter-lite/id464195348) |
| 6758224381 | TranscribeEN: Audio to Text | Productivity | Dinesh Gurung | Free | FREE | Multilingual media to English transcript | Only for Mac | Processing scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/transcribeen-audio-to-text/id6758224381?mt=12) |
| 1532271726 | Ping • Uptime Monitor | Utilities | Developer not parsed | Free + Pro unlock | FREEMIUM | Continuous ICMP/TCP uptime monitor | Only for Mac | Network required; history local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ping-uptime-monitor/id1532271726) |
| 6751464821 | Converleon — File Converter | Utilities | Developer not parsed | Subscriptions/IAP | SUB | Multi-format file, media and document converter | Only for Mac | Local conversion scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/converleon-file-converter/id6751464821) |
| 1381004916 | Discovery - DNS-SD Browser | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Bonjour and DNS-SD service browser | Only for Mac | Local network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916) |
| 1541544797 | My NsLookup | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | DNS record query utility | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/my-nslookup/id1541544797) |
| 1607817004 | Certy | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Dynamic DNS and TLS certificate automation | Mac availability requires final QA | Internet and Zonomi account required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/certy/id1607817004) |
| 6759235383 | SSL Inspector | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | TLS certificate chain and pinning inspector | Only for Mac | Network required; certificate export local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ssl-inspector/id6759235383) |
| 472226235 | LanScan | Utilities | Developer not parsed | Free trial + Pro IAP | FREEMIUM | ARP, DNS, SMB and mDNS network scanner | Only for Mac | Local network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/lanscan/id472226235) |
| 6749780949 | Wi-Fi Analyzer Network Scanner | Utilities | Developer not parsed | Free features; IAP status pending | FREEMIUM | Home-network scanner and security score | Mac compatibility requires final product-page QA | Network required; reports local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/wi-fi-analyzer-network-scanner/id6749780949) |
| 562315041 | Network Analyzer: net tools | Utilities | Developer not parsed | Exact price pending | UNKNOWN | LAN scanner, ping, traceroute, port and DNS | Universal/Mac availability requires final QA | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-analyzer-net-tools/id562315041) |
| 623413384 | LAN Scan - Network Scanner | Utilities | Developer not parsed | Paid; exact price pending | PAID | LAN, ARP, Bonjour, NetBIOS and port scanner | Only for Mac | Local network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/lan-scan-network-scanner/id623413384) |
| 6745189969 | Ping – Network Tools | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Latency monitoring, DNS, traceroute and port scan | Mac compatibility requires final product-page QA | Network required; history local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ping-network-tools/id6745189969) |
| 6760156527 | TraceBar | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Menu-bar continuous traceroute monitor | Only for Mac | Network required; diagnostics discarded on close | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/tracebar/id6760156527) |
| 6758589382 | Netutilus: Network Utility | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Native all-in-one network utility | Only for Mac | Network required; results local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/netutilus-network-utility/id6758589382) |
| 507659816 | Network Radar | Utilities | Developer not parsed | Paid; exact price pending | PAID | Network discovery, monitoring and port scan | Only for Mac | Network required; inventory local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-radar/id507659816) |
| 1557453461 | Network Toolbox - Net Security | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Network security, clients and packet utilities | Mac compatibility requires final QA | Network and third-party services required for some tools | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-toolbox-net-security/id1557453461) |
| 609759211 | Super Ping | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Ping, port scan and monitoring | Mac-supported universal app | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/super-ping/id609759211) |
| 1246455042 | Network Utilities & Analyzer | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Ping, traceroute, port, DNS, WHOIS and SSH | Mac-compatible universal listing; type pending | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-utilities-analyzer/id1246455042) |
| 557405467 | Network Analyzer Pro | Utilities | Developer not parsed | Paid; exact price pending | PAID | Professional LAN, IPv6, port and DNS diagnostics | Universal/Mac availability requires final QA | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-analyzer-pro/id557405467) |
| 1350044974 | PingDoctor | Utilities | Developer not parsed | Paid; exact price pending | PAID | Professional ping and traceroute | Only for Mac | Network required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/pingdoctor/id1350044974) |
| 6757384027 | VPN Peek: DNS Leak Detector | Utilities | Developer not parsed | Exact price pending | UNKNOWN | VPN state and DNS-leak diagnostics | Only for Mac | Network/VPN required | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/vpn-peek-dns-leak-detector/id6757384027) |
| 6760950154 | WiFiWize | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Wi-Fi quality score, LAN tools and menu-bar monitor | Mac availability shown; delivery type pending | Network required; analysis local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/wifiwize/id6760950154) |
| 6475303256 | Network Analyzer: WiFi Scanner | Utilities | Developer not parsed | Free/IAP status pending | UNKNOWN | Wi-Fi, LAN and network diagnostics | Mac compatibility shown in Apple listing; delivery type pending | Network required; analysis local | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/network-analyzer-wifi-scanner/id6475303256) |
| 6741365157 | Headroom: Podcasting Toolkit | Music | Headroom | Free | FREE | Podcast metadata, transcription, chapters and export | Only for Mac | Local project workflow; AI feature scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/headroom-podcasting-toolkit/id6741365157?mt=12) |
| 6444749497 | UniConverter 14: Video Toolbox | Photo & Video | Wondershare | Free + IAP | FREEMIUM | 1000+ format conversion and offline subtitle generation | Only for Mac | Local conversion; some toolbox features connected | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/uniconverter-14-video-toolbox/id6444749497) |
| 6508170078 | Auto Captions | Photo & Video | Fast Hatch Apps | Exact price pending | UNKNOWN | Automatic video captions | Only for Mac | Transcription processing scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/auto-captions/id6508170078) |
| 1031927291 | Subtitle Edit Pro-Video Editor | Photo & Video | Developer not parsed | $9.99 | PAID | Burn SRT, ASS and SSA subtitles into video | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subtitle-edit-pro-video-editor/id1031927291?mt=12) |
| 423292019 | UniConverter-Video Converter | Photo & Video | Wondershare | Exact price pending | UNKNOWN | Conversion, compression, metadata, subtitle and screen tools | Only for Mac | Local conversion; online toolbox features possible | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/uniconverter-video-converter/id423292019) |
| 6760584178 | Syncscribe: Video Subtitles | Photo & Video | Developer not parsed | Exact price pending | UNKNOWN | Local transcription, translation and subtitle video export | Mac | Fully local core workflow; no account claimed | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/syncscribe-video-subtitles/id6760584178?mt=12) |
| 6461211708 | SrtSubToolbox Lite | Photo & Video | 鹏 边 | Current price pending | UNKNOWN | Merge and separate bilingual SRT files | Only for Mac | Offline local subtitle files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/srtsubtoolbox-lite/id6461211708?mt=12) |
| 1588379446 | Underword | Photo & Video | Developer not parsed | Free | FREE | Native video subtitle editor | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/underword/id1588379446?mt=12) |
| 687457926 | Subs Factory | Photo & Video | Developer not parsed | $17.99 + IAP | HYBRID | Professional subtitles and captions editor | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subs-factory/id687457926?mt=12) |
| 1617557042 | SRT Edit Pro-Make and Edit | Photo & Video | 均卓 陈 | $19.99 | PAID | SRT subtitle and timecode editing | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/srt-edit-pro-make-and-edit/id1617557042?mt=12) |
| 862438829 | Subtitle Studio 2 | Photo & Video | TheKeptPromise | $12.99 | PAID | Subtitle create, sync, translate and embed | Only for Mac | Local media; macOS transcription/translation features | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subtitle-studio-2/id862438829?mt=12) |
| 1449752748 | SubShift | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Subtitle synchronization and editing | Only for Mac | Offline local subtitle files | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subshift/id1449752748?mt=12) |
| 595916528 | Subtitle Factory | Photo & Video | Developer not parsed | $4.99 | PAID | Switchable subtitle tracks for MP4 and MOV | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subtitle-factory/id595916528) |
| 1441555493 | Simon Says Transcription | Photo & Video | Simon Says, Inc. | Free + transcription IAP | FREEMIUM | Video and audio AI transcription | Only for Mac | Transcription service dependency likely | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/simon-says-transcription/id1441555493?mt=12) |
| 1516632589 | VideoZ-Compressor & Converter | Photo & Video | Developer not parsed | Exact price pending | UNKNOWN | Video conversion, editing and subtitle processing | Only for Mac | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/videoz-compressor-converter/id1516632589?mt=12) |
| 1617772720 | Remux - Video Converter | Photo & Video | Developer not parsed | Free + IAP | FREEMIUM | Video remux, compress, subtitle and audio extraction | Mac supported; Apple silicon required in current listing | Offline local conversion | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/remux-video-converter/id1617772720?platform=mac) |
| 1065306078 | Subtitle Edit Pro | Photo & Video | Developer not parsed | $29.99 | PAID | Waveform-based SRT subtitle editor | Only for Mac | Offline local media | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subtitle-edit-pro/id1065306078?mt=12) |
| 6529536388 | SRTGen | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Apple-Silicon subtitle generator | Only for Mac | Local transcription claimed | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/srtgen/id6529536388?mt=12) |
| 1513310770 | Audio Transcribe: Voice, Text | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Audio/video transcription studio | Only for Mac | AI processing scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/audio-transcribe-voice-text/id1513310770?mt=12) |
| 1659864300 | Jojo Transcribe | Productivity | Developer not parsed | Exact price pending | UNKNOWN | File, system-audio and subtitle transcription | Mac | Apple-silicon system-audio transcription supported | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/jojo-transcribe/id1659864300) |
| 6469347673 | Subtitlo | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Live presentation subtitles for Keynote and PowerPoint | Only for Mac | Real-time speech processing; translation scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/subtitlo/id6469347673) |
| 1537291264 | Libretto • AI Speech to Text | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Offline audio/video transcription and translation | Only for Mac | Offline transcription claimed; YouTube import needs internet | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/libretto-ai-speech-to-text/id1537291264?mt=12) |
| 6747063873 | MocaSubtitle | Productivity | 红蓉 李 | Free + IAP | FREEMIUM | Speech/OCR bilingual subtitle production | Only for Mac | Native Mac processing; model scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/mocasubtitle/id6747063873?mt=12) |
| 1446580517 | Noted: Record, AI-Transcribe | Productivity | Noted App Ltd | Free/IAP status pending | FREEMIUM | Timestamped notes, recording and transcription | Only for Mac | Recording local; iCloud sync and AI transcription | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/noted-record-ai-transcribe/id1446580517?mt=12) |
| 6755741599 | Voice Recorder — Audio Editor | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Voice recording, editing and transcription | Only for Mac; Apple silicon required | Recording local; transcription scope pending | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/voice-recorder-audio-editor/id6755741599) |
| 1669896755 | AI Transcription | Productivity | AppAhead Studio | Exact price pending | UNKNOWN | Whisper audio/video transcription and subtitle export | Only for Mac | On-device whisper.cpp workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/ai-transcription/id1669896755?mt=12) |
| 1663169504 | Transkript - Speech to Text | Productivity | Developer not parsed | Free/IAP status pending | FREEMIUM | Whisper file and podcast transcription | Only for Mac | Local transcription; podcast search/RSS needs internet | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/transkript-speech-to-text/id1663169504?mt=12) |
| 6450404233 | Whisper Mate | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Whisper transcription for audio, video and podcasts | Only for Mac | On-device Whisper workflow | Kamuya açık güvenilir sayı bulunamadı | [Apple App Store](https://apps.apple.com/us/app/whisper-mate/id6450404233?mt=12) |

## Faz 3D pazar sinyalleri

- **Network diagnostics:** Genel araç paketleri kalabalık; menü çubuğu traceroute, SSL pinning, DNS leak, Bonjour keşfi ve PCAP görüntüleme gibi tek amaçlı profesyonel araçlar daha net konumlanıyor.
- **Audio recording:** Ücretsiz/freemium kayıt uygulaması çok; sistem sesi yakalama, podcast iş akışı, noise cleanup ve tamamen on-device çalışma temel farklılaştırıcılar.
- **Transcription:** Whisper tabanlı local-first ürün sayısı hızla artmış durumda. Basit audio-to-text yerine bilingual subtitle, podcast metadata, system-audio capture ve video export kombinasyonları öne çıkıyor.
- **Subtitle editing:** Ücretsiz temel editörlerin yanında $4.99–$29.99 aralığında profesyonel tek seferlik ürünler görünür; waveform, frame-accurate timing ve embed/export kapsamı fiyat gücünü artırıyor.
- **Media conversion:** Çok kalabalık ve isim benzerliği yüksek. Apple Silicon donanım hızlandırması, offline batch processing, codec şeffaflığı, subtitle handling ve lifetime fiyat olmadan savunulması zor.
- **Gizlilik fırsatı:** On-device AI ve hesapsız local workspace, özellikle toplantı, podcast ve hassas medya dosyalarında satın alma gerekçesi oluşturuyor.

## Veri kalitesi notları

- Fiyatı Apple arama sonucunda açıkça görülen ürünlerde güncel görünen değer yazıldı.
- Fiyat görünmeyen ürünler için üçüncü taraf veya eski review fiyatı tahmin edilmedi.
- Aynı işlevi taşıyan fakat farklı `trackId` değerine sahip uygulamalar ayrı tutuldu.
- Bazı evrensel ürünlerin Mac dağıtım türü Faz 5’te native/Catalyst/iPad-on-Mac olarak ayrılacaktır.

## Faz 3E sonraki tarama kümeleri

1. Recipe, pantry, grocery, meal planning ve kitchen utilities.
2. Plant care, gardening, pet care, home inventory ve wardrobe.
3. Font, icon, color, screenshot, mockup ve design asset araçları.
4. Türkiye, Almanya ve Japonya storefront’larında ABD’de görünmeyen yerel uygulamalar.
5. A–Z/0–9 ve geliştirici-kataloğu doygunluk taramasının genişletilmesi.

**Sürüm:** 3D — 2 Ağustos 2026

# Faz 3E — Beşinci Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Yeni benzersiz `trackId`:** 40  
**Önceki chart/uzun-kuyruk envanteriyle çakıştığı için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 380  
**Top Charts dahil toplam veri satırı:** 1379

> [!IMPORTANT]
> Bu fazda popüler fakat Apple sayfasında `Only for iPhone` veya `Not verified for macOS` yazan uygulamalar eklenmedi. Apple sayfasında M1 Mac uyumluluğu açıkça bulunan iPad uygulamaları ise `Designed for iPad on Apple silicon` etiketiyle ayrı tutuldu.

## Faz 3E küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Recipe, pantry & meal planning | 13 |
| Home inventory & collections | 10 |
| Pet care & monitoring | 7 |
| Garden, plant & home design | 6 |
| Wardrobe & outfits | 4 |
| **Toplam** | **40** |

## Kategori dağılımı

| App Store kategorisi | Kayıt |
|---|---:|
| Lifestyle | 15 |
| Food & Drink | 8 |
| Productivity | 6 |
| Graphics & Design | 3 |
| Reference | 2 |
| Medical | 2 |
| Finance | 1 |
| Business | 1 |
| Education | 1 |
| Utilities | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| FREEMIUM | 11 |
| PAID | 10 |
| FREE/SERVICE | 4 |
| FREE | 4 |
| HYBRID | 4 |
| FREEMIUM/SUB | 3 |
| UNKNOWN | 2 |
| SUB | 1 |
| FREEMIUM/SERVICE | 1 |

## Kullanım/indirme veri kalitesi

| Kanıt sınıfı | Kayıt |
|---|---:|
| NONE | 29 |
| PUBLIC-PROXY | 8 |
| PRODUCT-SCALE | 2 |
| DISCLOSED-ALL-PLATFORMS | 1 |

- Mac’e özel kesin indirme veya aylık aktif kullanıcı sayısı bu partide yine bulunmadı.
- `Ratings` sayısı yalnızca App Store talep proxy’si olarak kaydedildi.
- Şirketin tüm platformlar için açıkladığı kullanıcı/topluluk sayısı Mac kurulumu olarak yorumlanmadı.
- Veri tabanının test edildiği kayıt sayısı gibi ürün ölçek sinyalleri `PRODUCT-SCALE` sınıfında tutuldu.

## Faz 3E uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Offline/bağımlılık | Kullanım/indirme sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 6463813036 | PlantThis - Plant Identifier | Education | TS Technology | Free + IAP | FREEMIUM/SUB | Plant identification, journal and care reminders | Only for Mac | Photo identification likely cloud dependent | No public exact Mac count; developer claims 12,000+ plant coverage, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/plantthis-plant-identifier/id6463813036?mt=12) |
| 1502610858 | FloorDesign2 | Graphics & Design | Developer not parsed | Free + IAP | FREEMIUM | Floor plans, remodel and garden-bed planning | Only for Mac | Local design project | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/floordesign2/id1502610858) |
| 1455656994 | DreamPlan Home Design Software | Graphics & Design | NCH Software | Free + IAP | FREEMIUM | Home, deck, landscape and garden design | Only for Mac | Local 2D/3D project workflow | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/dreamplan-home-design-software/id1455656994?mt=12) |
| 997732583 | Home Design 3D Outdoor&Garden | Graphics & Design | Anuman | $4.99 | PAID | Outdoor and garden layout design | Only for Mac | Local 2D/3D design | Developer describes an 80M-user worldwide product community; not Mac installs | DISCLOSED-ALL-PLATFORMS | [Apple App Store](https://apps.apple.com/us/app/home-design-3d-outdoor-garden/id997732583) |
| 6754510785 | AI Home - Interior Design App | Lifestyle | Raeny Nadeem | Free + IAP | FREEMIUM/SUB | AI interior, curtain and garden visualization | Only for Mac | AI generation likely cloud dependent | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-home-interior-design-app/id6754510785?mt=12) |
| 1342163391 | Home Design 3D | Productivity | Anuman | Free + IAP | FREEMIUM | 2D/3D home design | Only for Mac | Local project workflow | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/home-design-3d/id1342163391?mt=12) |
| 984074571 | Nano Inventory | Business | Erziman Asaliyev | $9.99 | PAID | Warehouse and sales inventory | Only for Mac | Local business inventory | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/nano-inventory/id984074571?mt=12) |
| 1035159896 | Nano Home Inventory | Finance | Erziman Asaliyev | $7.99 | PAID | Belongings, warranty, insurance and maintenance tracking | Only for Mac | Local database; companion sync available | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/nano-home-inventory/id1035159896?mt=12) |
| 414539108 | Librarian Pro | Lifestyle | Koingo Software, Inc. | $29.99 | PAID | Books, movies, music, games and collection catalog | Only for Mac | Local collection database; metadata lookup optional | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/librarian-pro/id414539108) |
| 6764484145 | Afolio - Brick Tracker | Lifestyle | The Half Bakery Pty Ltd | Free + IAP | FREEMIUM | Brick-set and minifigure collection tracking | Only for Mac | Local/account behavior pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/afolio-brick-tracker/id6764484145) |
| 1330312571 | Xmanage | Lifestyle | fennel | Exact price pending | UNKNOWN | General-purpose collection manager | Only for Mac; native Apple silicon and Intel support stated | Local collection database | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/xmanage/id1330312571?mt=12) |
| 1524335878 | Under My Roof Home Inventory + | Lifestyle | Binary Formations, LLC | Free limited + subscription | SUB | Home inventory, insurance, maintenance and moving boxes | Mac, iPhone and iPad universal purchase | Device-local data; personal iCloud sync optional | 496 US ratings observed; rating count is not downloads | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/under-my-roof-home-inventory/id1524335878) |
| 1124615151 | BluePlum Home Inventory | Lifestyle | Blue Plum Software Inc, The | $24.99 | PAID | Insurance-focused home asset inventory | Only for Mac | Local storage; compressed/iCloud Drive backup | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/blueplum-home-inventory/id1124615151?mt=12) |
| 6739799065 | AssetManage | Productivity | Paul Dembowski | Free + IAP | FREEMIUM | Asset tracking and inventory management | Only for Mac | Local asset database; barcode/data sources pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/assetmanage/id6739799065) |
| 1067686758 | Steward Database Lite | Productivity | 天舟 陈 | Free limited | FREEMIUM | Custom database with home-inventory template | Only for Mac | Local database with CSV and backup | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/steward-database-lite/id1067686758?mt=12) |
| 1246752474 | Inventory Manager | Productivity | INSPIRING-LIFE TECHNOLOGIES PRIVATE LIMITED | Free + IAP | FREEMIUM | Home inventory, receipts, manuals and warranties | Only for Mac | Developer states personal data is stored locally | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/inventory-manager/id1246752474?mt=12) |
| 789811691 | Inventory Pro | Lifestyle | Developer not parsed | $0.99 | PAID | Basic location-based personal inventory | Only for Mac | Local inventory | No public exact Mac count; indexed reviews include severe usability complaints | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/inventory-pro/id789811691?mt=12) |
| 1467982511 | iCollect Everything | Lifestyle | iCollect Everything, LLC | Free + IAP / Pro account linkage | FREEMIUM/SERVICE | Collectibles and general inventory | Only for Mac | Account/mobile Pro dependency for full ecosystem | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/icollect-everything/id1467982511?mt=12) |
| 1488136125 | Easy Home Inventory :) | Lifestyle | shaojun lin | Free | FREE | Home storage, low-stock and expiration tracking | Only for Mac | Local inventory | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/easy-home-inventory/id1488136125?mt=12) |
| 1405582225 | PetCam App - Dog Camera App | Lifestyle | Klug Home Solutions Tecnologia Ltda | Free with 7-day full-version trial; later pricing pending | FREEMIUM | Live pet camera, noise alerts and two-way communication | Only for Mac | Network and paired Apple device required | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/petcam-app-dog-camera-app/id1405582225?mt=12) |
| 1487478466 | Easy Home Inventory | Lifestyle | shaojun lin | $4.99 | PAID | Paid home storage and inventory edition | Only for Mac | Local database with backup/restore | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/easy-home-inventory/id1487478466?mt=12) |
| 1625644483 | Pet Medical Tracker-Pet Health | Medical | Developer not parsed | Exact price pending | UNKNOWN | Pet medical visits, diagnosis and treatment history | Only for Mac; non-US storefront verification | Local record workflow; exact sync behavior pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/uz/app/pet-medical-tracker-pet-health/id1625644483?mt=12) |
| 6757344325 | VetDiary | Medical | Developer not parsed | $44.99 | PAID | Pet visits, vaccines, medication and reminders | Only for Mac; Apple M1 or later | Fully offline; no account or sign-in | Developer reports testing with about 2,000 owners and pets; test scale, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/vetdiary/id6757344325?mt=12) |
| 6740460074 | AI Recipes: Meal Planner | Food & Drink | Developer not parsed | Free + IAP | FREEMIUM/SUB | AI recipes from pantry ingredients | Only for Mac | AI generation likely cloud dependent | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-recipes-meal-planner/id6740460074?mt=12) |
| 6756961925 | Recipe Maker - Meal Planner | Food & Drink | ZEN TECH | Free + IAP | FREEMIUM | Cookbook, weekly meal planner and shopping list | Only for Mac | Local core workflow; connected features pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/recipe-maker-meal-planner/id6756961925) |
| 6593686940 | Kitchen & Pantry Tracker | Food & Drink | Peter Balazs Szucs | Free + IAP ($3.99 / $29.90 shown) | HYBRID | Fridge, freezer, pantry inventory and shopping list | Designed for iPad; Apple page lists M1 Mac compatibility | Local inventory; optional connected features pending QA | 1 US rating observed; not an install count | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/kitchen-pantry-tracker/id6593686940) |
| 6761448354 | WhatDo?! Kitchen Planner | Food & Drink | DeadBeet LLC | $19.99 + IAP | HYBRID | Fridge, freezer, pantry, recipes and household meal planning | Only for Mac | Local inventory plus connected AI/community features | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/whatdo-kitchen-planner/id6761448354?mt=12) |
| 6762028936 | Meal Map Desktop | Food & Drink | Meal Map LLC | Free | FREE | Meal planning, ingredient shopping and recipe prep | Only for Mac | Apple page states no data collected; internet needs pending | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/meal-map-desktop/id6762028936?mt=12) |
| 1315583175 | Recipe Keeper | Food & Drink | Tudorspan Limited | Free + IAP | FREEMIUM | Recipe organizer, OCR, shopping list and meal planner | Native Mac listing | Works offline; cross-device sync optional | No public exact Mac downloads; Mac rating total not used as installs | NONE | [Apple App Store](https://apps.apple.com/us/app/recipe-keeper/id1315583175?mt=12) |
| 6757105305 | Saverd Clipper for Safari | Food & Drink | Saverd, LLC | Free | FREE/SERVICE | Safari recipe capture extension | Only for Mac | Saverd web/service connection required | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/saverd-clipper-for-safari/id6757105305?mt=12) |
| 6741941273 | Plan To Eat Recipe Clipper | Food & Drink | Plan To Eat, LLC | Free; Plan to Eat account/service required | FREE/SERVICE | Safari recipe clipper and editor | Only for Mac | Internet and Plan to Eat account required | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/plan-to-eat-recipe-clipper/id6741941273) |
| 1372458798 | Favorite Recipes | Lifestyle | Developer not parsed | Free + IAP | FREEMIUM | Local recipe organizer and search | Only for Mac | Local recipe library | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/favorite-recipes/id1372458798?mt=12) |
| 1593108511 | Cook'n Capture Plugin | Productivity | Developer not parsed | Free | FREE/SERVICE | Recipe capture plugin for Cook'n | Only for Mac | Requires Cook'n ecosystem and internet for capture | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/cookn-capture-plugin/id1593108511?mt=12) |
| 1475975349 | Copy Me That recipe manager | Productivity | Copy Me That | Free | FREE/SERVICE | Recipe clipping, shopping list and meal planning | Only for Mac | Web recipe import and account sync require internet | Mac listing says not enough ratings for an overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/copy-me-that-recipe-manager/id1475975349?mt=12) |
| 1095062787 | Brewing Recipes | Reference | @pps4Me | $1.99 | PAID | Beer brewing recipe library and brewing logs | Only for Mac | Offline reference and local logs | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/brewing-recipes/id1095062787?mt=12) |
| 946833065 | Records Database | Reference | Andrea Gelati | Free + subscription/lifetime options | HYBRID | Custom database templates including home inventory and recipes | Only for Mac | Local database; exact sync dependencies pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/records-database/id946833065?mt=12) |
| 412648913 | Dress Assistant | Lifestyle | Software de Arte | $29.99 | PAID | Desktop wardrobe catalogue and outfit matching | Only for Mac | Local photo-based wardrobe | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/dress-assistant/id412648913?mt=12) |
| 1492616993 | My Wardrobe - Virtual Closet | Lifestyle | 辉英 钟 | $8.99 + IAP | HYBRID | Digital closet, outfit planning and style statistics | Only for Mac | iCloud synchronization and backup | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/my-wardrobe-virtual-closet/id1492616993?mt=12) |
| 6757370492 | Wontsy - Wishlist & Outfits | Lifestyle | Developer not parsed | Free | FREE | Wishlist, wardrobe planning and outfit collages | Only for Mac | Local/web item capture behavior pending QA | No public exact Mac count | NONE | [Apple App Store](https://apps.apple.com/us/app/wontsy-wishlist-outfits/id6757370492?mt=12) |
| 6502149767 | Garment: Wardrobe Manager | Utilities | James Spann | Free | FREE | Clothing inventory, tags, measurements and export | Only for Mac | Local wardrobe; Apple page lists limited non-linked user content | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/garment-wardrobe-manager/id6502149767?mt=12) |

## Faz 3E pazar sinyalleri

- **Recipe/meal planning:** Klasik Mac ürünleri offline yerel kitaplık ve tek seferlik fiyatla; yeni ürünler AI, receipt OCR, pantry deduction ve household collaboration ile ayrışıyor.
- **Pantry:** Mac-native pantry uygulaması sayısı hâlâ sınırlı. Çok sayıda mobil ürün Mac için doğrulanmamış; bu durum masaüstünde geniş veri girişi ve toplu düzenleme odaklı ürün fırsatı yaratıyor.
- **Home inventory:** $0.99’dan $24.99’a kadar peşin fiyatlar ve abonelikli daha kapsamlı ürünler birlikte bulunuyor. Sigorta raporu, warranty, receipt, barcode ve local-first saklama temel değer alanları.
- **Garden/home design:** Profesyonel garden planner ve 3D tasarım ürünleri peşin ücret alabiliyor; yalnızca AI görsel üretimi yapan yeni ürünler ise çoğunlukla freemium/abonelik.
- **Wardrobe:** Native Mac rekabet mobil pazara göre çok düşük. Mevcut ürünler fotoğraf tabanlı katalog ve basit outfit collage sunuyor; modern background removal, cost-per-wear ve packing workflow boşluğu var.
- **Pet care:** Mac pazarı büyük ölçüde kamera istasyonu ve klinik kayıt aracına ayrılmış. Tamamen offline veteriner/pet record ürünü yüksek peşin fiyatla konumlanabiliyor.

## Dışlanan önemli mobil ürünler

Aşağıdaki popüler ürünler araştırma sinyali olarak görüldü ancak güncel Apple sayfasında Mac mağaza uygulaması olarak doğrulanmadığı için envantere eklenmedi:

- MealBoard — `Designed for iPad. Not verified for macOS`
- Planta — `Only for iPhone`
- Whering — `Only for iPhone`; açıklanan 9M+ kullanıcı Mac kullanıcısı değildir
- OpenWardrobe — `Designed for iPad. Not verified for macOS`
- Pantry Inventory - Food Stock — `Only for iPhone`
- Fridge And Pantry Inventory — `Designed for iPad. Not verified for macOS`

## Faz 3F sonraki tarama kümeleri

1. Font manager, font creator, icon generator, color picker ve design asset araçları.
2. Screenshot, annotation, mockup ve App Store marketing-asset araçları.
3. Translation, dictionary, writing, citation ve academic-reference uzun kuyruğu.
4. Türkiye, Almanya ve Japonya storefront’larında ABD’de bulunmayan yerel Mac uygulamaları.
5. Geliştirici kataloglarından aynı satıcının chart dışı uygulamalarının genişletilmesi.

**Sürüm:** 3E — 2 Ağustos 2026

# Faz 3F — Altıncı Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Yeni benzersiz `trackId`:** 75  
**Önceki envanterle çakıştığı için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 455  
**Top Charts dahil toplam veri satırı:** 1454

> [!IMPORTANT]
> Mobil mağazada popüler görünmesine rağmen Apple sayfasında `Designed for iPad. Not verified for macOS` yazan uygulamalar Mac envanterine alınmadı. Universal iPhone/iPad/Mac uygulamaları ise native Mac ürünlerinden ayrı platform etiketiyle tutuldu.

## Faz 3F küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Fonts & typography | 16 |
| App icons & Xcode assets | 17 |
| Mockups & App Store marketing | 16 |
| Color & palettes | 14 |
| Screenshot capture & annotation | 12 |
| **Toplam** | **75** |

## Kategori dağılımı

| App Store kategorisi | Kayıt |
|---|---:|
| Developer Tools | 32 |
| Graphics & Design | 30 |
| Productivity | 8 |
| Utilities | 4 |
| Photo & Video | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| FREE | 28 |
| FREEMIUM | 26 |
| PAID | 7 |
| UNKNOWN | 4 |
| HYBRID | 2 |
| FREE/DONATION | 2 |
| LIFE | 2 |
| FREEMIUM/LIFE | 1 |
| FREEMIUM/SERVICE | 1 |
| SUB | 1 |
| FREE/SERVICE | 1 |

## Kullanım ve indirme verisi

| Kanıt sınıfı | Kayıt |
|---|---:|
| NONE | 59 |
| PUBLIC-PROXY | 14 |
| PRODUCT-SCALE | 2 |

- Bu partide hiçbir rakip için Mac’e özel doğrulanmış kesin indirme veya MAU sayısı yayımlanmamıştır.
- App Store rating sayıları yalnızca `PUBLIC-PROXY` olarak tutulur.
- Font sayısı, desteklenen dil sayısı veya üretilen asset boyutu kullanıcı sayısı değildir; `PRODUCT-SCALE` olarak ayrılır.
- Universal uygulamalardaki toplam rating, yalnızca Mac kullanıcılarını temsil etmez.

## Faz 3F uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Offline/bağımlılık | Kullanım/indirme sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 6751547497 | DevIconGen | Developer Tools | Developer not parsed | Free + IAP | FREEMIUM | 50+ platform icon sizes and Contents.json export | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/devicongen/id6751547497) |
| 1381100887 | Icon Maker - Design App Icons | Developer Tools | Developer not parsed | Free | FREE | App icon design, resize and conversion | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/icon-maker-design-app-icons/id1381100887?mt=12) |
| 1294179975 | AppIconBuilder | Developer Tools | 嘉伟 戈 | Free + optional $0.99 donation | FREE/DONATION | App icon export, ICNS and Android assets | Only for Mac | Offline local generation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/appiconbuilder/id1294179975?mt=12) |
| 866571115 | Asset Catalog Creator | Developer Tools | BRIDGETECH SOLUTIONS LIMITED | Free + IAP | FREEMIUM | App icons, interface assets and xcasset merging | Only for Mac | Offline local generation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/asset-catalog-creator/id866571115?mt=12) |
| 6480373509 | Icon Preview | Developer Tools | Developer not parsed | Free | FREE | Dock and menu-bar icon preview | Only for Mac | Offline local file watching | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/icon-preview/id6480373509?mt=12) |
| 1595632719 | Developer Tool | Developer Tools | Developer not parsed | Free | FREE | Icon slicing and App Store screenshot-size reference | Only for Mac | Offline local tools | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/developer-tool/id1595632719) |
| 6761715204 | iCon Maker - iConly | Developer Tools | Raghava Naidu | Free; $1.99 monthly, $9.99 yearly, $14.99 lifetime | HYBRID | Icon, asset and App Store screenshot generation | Only for Mac | Native local processing; Apple Vision background removal | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/icon-maker-iconly/id6761715204?mt=12) |
| 6757913340 | GlotShot: Screenshot Maker | Developer Tools | 渊博 胡 | Free + one-time Pro IAP | LIFE | Localized screenshots, icons and App Store previews | Only for Mac | Local projects; translation can use Ollama/local or connected AI | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/glotshot-screenshot-maker/id6757913340?mt=12) |
| 6741403123 | Simple App Icon Generator | Developer Tools | Endika Moreno | Free | FREE | Multiplatform icon and metadata generation | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/simple-app-icon-generator/id6741403123?mt=12) |
| 6743756340 | IconGenie - App Icon Maker | Developer Tools | 利龙 张 | Free | FREE | One-click iOS, Android and macOS icon export | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/icongenie-app-icon-maker/id6743756340?mt=12) |
| 1575220747 | Bakery - Simple Icon Creator | Developer Tools | Developer not parsed | Free | FREE | Placeholder icons, Xcode assets and screenshot templates | Only for Mac | Offline local generation | No public exact Mac downloads; indexed reviews indicate developer usage | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/bakery-simple-icon-creator/id1575220747?mt=12) |
| 554660130 | Icon Tool for Developers | Developer Tools | Developer not parsed | Free testing + Pro IAP | FREEMIUM/LIFE | Production icon variants and platform asset export | Only for Mac | Offline local generation; Xcode tools may be required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/icon-tool-for-developers/id554660130?mt=12) |
| 6782444111 | IconForge | Developer Tools | JudeWorks | Free | FREE | Xcode-compatible image presets and asset folders | Only for Mac | Source image remains local | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/iconforge/id6782444111?mt=12) |
| 1052532083 | App Icon Set Creator | Developer Tools | Erik Wegener | Free | FREE | Xcode-ready appiconset generation | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/app-icon-set-creator/id1052532083?mt=12) |
| 1483484785 | AppIcon Maker (xcAsset Creator) | Developer Tools | Developer not parsed | Free | FREE | iOS, iPad, Mac and watchOS asset generation | Only for Mac | Offline local generation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/appicon-maker-xcasset-creator/id1483484785?mt=12) |
| 1671463332 | IconAssistant | Developer Tools | Luke Drushell | Free | FREE | macOS corner radius and appiconset generation | Only for Mac | Offline local generation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/iconassistant/id1671463332?mt=12) |
| 992115977 | Image2icon - Make your icons | Graphics & Design | Developer not parsed | Free + IAP | FREEMIUM | Mac file, folder and app icon creation | Only for Mac | Offline local image processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/image2icon-make-your-icons/id992115977?mt=12) |
| 6760190373 | Hameleon Menu Bar Color Picker | Developer Tools | Developer not parsed | Free | FREE | CSS, SwiftUI, UIKit and Tailwind color picker | Only for Mac | Fast private local sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/hameleon-menu-bar-color-picker/id6760190373?mt=12) |
| 413897608 | Pastel | Developer Tools | Steven Troughton-Smith | Free + IAP | FREEMIUM | Cross-device palette library and developer code export | Universal iPhone, iPad and Mac | iCloud sync optional; local palette editing | 1.4K US ratings observed; not downloads or Mac-only users | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/pastel/id413897608) |
| 446103121 | HexColor | Developer Tools | Developer not parsed | Free | FREE | Lightweight system color and HEX utility | Only for Mac | Offline local color picker | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/hexcolor/id446103121?mt=12) |
| 6449466690 | Affability | Developer Tools | Stef Kors | Free | FREE | SwiftUI, NSColor and UIColor clipboard picker | Only for Mac | Offline local screen sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/affability/id6449466690?mt=12) |
| 561995913 | Color Maker | Graphics & Design | Developer not parsed | Free + IAP | FREEMIUM | Color editing, palette and picker add-on | Only for Mac | Offline local color workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/color-maker/id561995913?mt=12) |
| 1586440491 | DuckMode | Graphics & Design | Caven Lim | Free + IAP | FREEMIUM | Color input, conversion and developer formats | Only for Mac | Offline local color utility | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/duckmode/id1586440491?mt=12) |
| 1453592782 | Color Wheel | Graphics & Design | Developer not parsed | Exact price pending | UNKNOWN | Digital, classic and abstract color wheels | Only for Mac | Offline local design reference | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/color-wheel/id1453592782?mt=12) |
| 1665356285 | Prevely | Graphics & Design | Developer not parsed | Exact price pending | UNKNOWN | Image viewer, lens and 19 color-code formats | Only for Mac | Offline local image and screen sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/prevely/id1665356285?mt=12) |
| 1195076754 | Color Picker - Pikka | Graphics & Design | Developer not parsed | Free + IAP | FREEMIUM | Magnifier, palettes and project collections | Only for Mac | Offline screen sampling and local library | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/color-picker-pikka/id1195076754?mt=12) |
| 6754931745 | Hexo - Color Palette Manager | Graphics & Design | CARLOS FERNANDEZ PLAZA | Free + IAP | FREEMIUM | Menu-bar picker and palette library | Only for Mac | Offline local palettes; desktop sync behavior pending | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/hexo-color-palette-manager/id6754931745) |
| 6768383702 | ColorCopy Pro | Graphics & Design | A Beautiful Site, LLC | Free + IAP | FREEMIUM | Menu-bar picker, formats and palette workflow | Only for Mac | Offline local screen sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/colorcopy-pro/id6768383702) |
| 6764863442 | Color Picker: Paletta One | Graphics & Design | Stanislav Duplinskiy | Free | FREE | Palette extraction from images | Only for Mac | Offline local image analysis | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/color-picker-paletta-one/id6764863442?mt=12) |
| 6741204341 | SwatchKeep | Graphics & Design | Davide Vago | Free + IAP | FREEMIUM | Shared macOS color palettes | Only for Mac | Local palette system; app integrations | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/swatchkeep/id6741204341?mt=12) |
| 6738003520 | Simple Color Picker App | Utilities | Jack Finnis | Free | FREE | Pixel color sampling and profile conversion | Only for Mac | Offline screen sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/simple-color-picker-app/id6738003520?mt=12) |
| 1470820747 | DfontSplitter | Developer Tools | Peter Upfold | Free | FREE | DFONT, suitcase and TTC to TTF conversion | Only for Mac | Offline local conversion | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/dfontsplitter/id1470820747?mt=12) |
| 647697434 | 550 Royalty Free Fonts | Graphics & Design | 128bit Technologies | Free | FREE | Commercial-use OpenType font pack | Only for Mac | Offline font assets after download | 550-font catalogue is product scale, not user count | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/550-royalty-free-fonts/id647697434?mt=12) |
| 1540682562 | Best Fonts 5 | Graphics & Design | Developer not parsed | Free + IAP | FREEMIUM | Compare installed and uninstalled fonts | Only for Mac | Offline font preview | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/best-fonts-5/id1540682562) |
| 1315267499 | Font Manager Deluxe | Graphics & Design | 128bit Technologies | $9.99 | PAID | Font collection preview and management | Only for Mac | Local font library | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/font-manager-deluxe/id1315267499) |
| 610893330 | Font Studio | Graphics & Design | NERALAB SRL | Free | FREE | Font preview, filtering, tags and style editing | Only for Mac | Local font library; last major indexed update is old | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/font-studio/id610893330?mt=12) |
| 1475782381 | RightFont - font manager | Graphics & Design | 立毅 成 | Free | FREE | Font preview, sync, activation and design-app integration | Only for Mac | Local font management; cloud-font sync optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/rightfont-font-manager/id1475782381?mt=12) |
| 700757313 | Halloween Fonts: Free Commercial Use Holiday Fonts | Graphics & Design | 128bit Technologies | Free | FREE | Halloween commercial-use font pack | Only for Mac | Offline font files after export | 45-font catalogue is product scale, not user count | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/halloween-fonts-free-commercial-use-holiday-fonts/id700757313?mt=12) |
| 464149293 | ID Font Catalog | Graphics & Design | Foil, Graphics, & More | $14.99 | PAID | InDesign-based font sample catalogue | Only for Mac | Requires Adobe InDesign; local font catalogue | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/id-font-catalog/id464149293) |
| 6759393799 | FontPeek | Graphics & Design | Abdelhak Akermi | $9.99 | PAID | Menu-bar installed-font preview and comparison | Only for Mac | Offline local font preview | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/fontpeek/id6759393799) |
| 1175857180 | Glyphs Mini 2 | Graphics & Design | schriftgestaltung.de | $45.99 | PAID | OTF and WOFF font creation | Only for Mac | Offline local font design | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/glyphs-mini-2/id1175857180?mt=12) |
| 1062679359 | Typeface 4 | Graphics & Design | Floor Steeg | Free + IAP | FREEMIUM | Professional font manager and activation | Only for Mac | Local font library; Adobe auto-activation integration | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/typeface-4/id1062679359?mt=12) |
| 760246983 | Free Fonts - Christmas Collection | Graphics & Design | 128bit Technologies | Free | FREE | Seasonal commercial-use font pack | Only for Mac | Offline font files after export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/free-fonts-christmas-collection/id760246983) |
| 507086472 | Font picker | Graphics & Design | Developer not parsed | $3.99 | PAID | Simple font preview and comparison | Only for Mac | Offline local font preview | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/font-picker/id507086472?mt=12) |
| 6462861529 | FontConverter | Graphics & Design | Developer not parsed | Exact price pending | UNKNOWN | Type 1 and legacy font conversion | Only for Mac | Offline local font conversion | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/fontconverter/id6462861529?mt=12) |
| 6449619333 | Font book: 3000+ Font Manager | Productivity | Shafia Rana | Free + IAP | FREEMIUM | Font library, calligraphy and installable fonts | Only for Mac | Local font assets; acquisition model requires QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/font-book-3000-font-manager/id6449619333) |
| 654635320 | EverFont - Font Preview Tool for Developers and Designers | Utilities | OnDemandWorld | Free | FREE | Font sampling and PDF font catalogue | Only for Mac | Offline local font preview | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/everfont-font-preview-tool-for-developers-and-designers/id654635320?mt=12) |
| 6467930383 | AppScreen Studio Design Mockup | Developer Tools | Momentarium LLC | Free + IAP | FREEMIUM | ASO screenshots, device syncing and 45+ language localization | Only for Mac | Local design; translation and upload may require network | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/appscreen-studio-design-mockup/id6467930383?mt=12) |
| 6473832582 | Screenshot Studio - App Mockup | Developer Tools | Sarun Wongpatcharapakorn | Free + IAP | FREEMIUM | App Store and Google Play screenshots, localization and upload | Universal iPhone and Mac | Local project design; AI translation/upload require network | 12 US ratings observed; not downloads | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/screenshot-studio-app-mockup/id6473832582) |
| 6505051046 | Layups Screenshot Mockup Tool | Developer Tools | Aaron F Stephenson | Free | FREE | App Store device frames, templates and exports | Only for Mac | Local design and export | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/layups-screenshot-mockup-tool/id6505051046?mt=12) |
| 1604170100 | ScreenShop - Screenshot Maker | Developer Tools | Eilon Krauthammer | Free + IAP | FREEMIUM | App Store screenshot templates and multi-size export | Only for Mac | Local design and export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/screenshop-screenshot-maker/id1604170100?mt=12) |
| 6443696943 | Mockup Screenshot | Developer Tools | Mert Can Kus | €0.99 in Germany storefront | PAID | Apple-device App Store screenshot framing | Universal iPhone, iPad and Mac | Local design and export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/de/app/mockup-screenshot/id6443696943) |
| 1499052260 | Color Picker Plus | Developer Tools | 万林 彭 | Free | FREE | HEX, RGB and HSL screen picker | Only for Mac | Offline screen sampling | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/color-picker-plus/id1499052260?mt=12) |
| 6444053674 | Bezel It - Frame Screenshots | Developer Tools | Hodgepodge Apps LLC | Free + IAP | FREEMIUM | Image, GIF and video device mockups | Only for Mac | Local design and export; Shortcuts automation | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/bezel-it-frame-screenshots/id6444053674?mt=12) |
| 6751584461 | App Store Screenshot Dev | Developer Tools | 2001 Ventures AS | Free | FREE | Local screenshot translation, localization and device frames | Only for Mac | All processing claimed local; no account or subscription | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/app-store-screenshot-dev/id6751584461?mt=12) |
| 6749189493 | Screenshots editor: App Frames | Developer Tools | Jorge Romanos | Free + IAP | FREEMIUM | Localized App Store screenshots, variants and direct upload | Only for Mac | Local design; App Store Connect upload requires network | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/screenshots-editor-app-frames/id6749189493?mt=12) |
| 6751829199 | ButterKit | Developer Tools | Zachary Spitulski | Free; $4.99 weekly, $9.99 monthly, $39.99 yearly, $79.99 lifetime | HYBRID | Simulator capture, 50-language localization and App Store Connect publishing | Only for Mac; requires macOS 26+ | Local/on-device options plus cloud AI by user API key | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/butterkit/id6751829199?mt=12) |
| 1573793948 | Screen Shot Generator & Editor | Graphics & Design | Muhammad Younas | Free + subscription IAP | SUB | App Store mockups, frames, text and exact-size export | Only for Mac | Local design; subscription required for premium features | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/screen-shot-generator-editor/id1573793948?mt=12) |
| 6781419446 | Store Screenshot Creator | Graphics & Design | Gary Cox | Free creation + one-time Pro export IAP | LIFE | App marketing artboards, device frames and batch export | Only for Mac | Local design and export | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/store-screenshot-creator/id6781419446?mt=12) |
| 6443880552 | Mockup Baker | Graphics & Design | Freepik Company S.L.U. | Free | FREE/SERVICE | Photoshop-connected 3D mockup rendering | Only for Mac | External rendering service and Photoshop plug-in required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mockup-baker/id6443880552?mt=12) |
| 6783978366 | Mockup Generator Creator | Graphics & Design | NEURASYNC | Free | FREE | Screenshot framing and mockup generation | Only for Mac | Local design and export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mockup-generator-creator/id6783978366) |
| 6766568592 | Framed: Mockup Studio | Graphics & Design | Brandon Schembri | Free + IAP | FREEMIUM | Screenshots to device mockups | Only for Mac | Local design and export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/framed-mockup-studio/id6766568592) |
| 1483390752 | Store ScreenShot Maker | Utilities | 袁杰 张 | $3.99 | PAID | Device shells and batch App Store screenshot output | Universal iPhone, iPad and Mac | Local design and export | 6 US ratings observed; not downloads | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/store-screenshot-maker/id1483390752) |
| 1079116587 | Launch - App Screenshot Creator | Developer Tools | FBeasleySoftware | Free + IAP | FREEMIUM | iPhone and iPad screenshot text, frames and sizing | Only for Mac | Local design and export | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/launch-app-screenshot-creator/id1079116587?mt=12) |
| 6749874426 | ShotFit: Screenshot Mockups | Graphics & Design | Zebin Huang | Free + IAP | FREEMIUM | 3D screenshot frames, backgrounds and social presets | Only for Mac | Local design and export | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/shotfit-screenshot-mockups/id6749874426?mt=12) |
| 6758053530 | Scap: Screenshot & Markup Edit | Graphics & Design | 楚江 王 | Free + IAP | FREEMIUM | Screenshot, annotation and sketching | Only for Mac | Local capture and markup | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/scap-screenshot-markup-edit/id6758053530?mt=12) |
| 6745431351 | Sleekshot | Photo & Video | Viktar Mahayeu | Free | FREE | Frozen-screen capture and annotation | Only for Mac | Local capture and markup | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/sleekshot/id6745431351?mt=12) |
| 6761925964 | SnapEdit - Screenshot Editor | Productivity | Developer not parsed | Free + optional donation | FREE/DONATION | Clipboard screenshot markup editor | Only for Mac | Offline local annotation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/snapedit-screenshot-editor/id6761925964?mt=12) |
| 6759284400 | Zkitch – Screenshot Annotation | Productivity | KAZUYA TAKECHI | Free + IAP | FREEMIUM | Lightweight screenshot annotation | Only for Mac | Local capture and markup | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/zkitch-screenshot-annotation/id6759284400?mt=12) |
| 425955336 | Skitch - Snap. Mark up. Share. | Productivity | Evernote | Free + IAP | FREEMIUM/SERVICE | Screenshot capture and visual annotation | Only for Mac | Local annotation with Evernote integration | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/skitch-snap-mark-up-share/id425955336?mt=12) |
| 6479216439 | Tuji | Productivity | Hangzhou Tongming Technology Company Limited | Free + IAP | FREEMIUM | Screenshot, annotation and presentation capture | Only for Mac | Local capture; connected sharing pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/tuji/id6479216439) |
| 6473518479 | McShot — Screenshot Mastery | Productivity | ROMAN SIDOROFF | Free | FREE | Screenshot, annotation and share workflow | Only for Mac | Local capture; sharing optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mcshot-screenshot-mastery/id6473518479) |
| 1221250572 | Xnip - Screenshot & Annotation | Productivity | 自达 张 | Free + IAP | FREEMIUM | Screenshot, pinning, measurement and annotation | Only for Mac | Fully local; listing says no network permission | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/xnip-screenshot-annotation/id1221250572?mt=12) |
| 6755657068 | TrarrenShot - Screenshot | Productivity | Ko Jui Lin | Free + IAP | FREEMIUM | Screenshot, scrolling capture, annotation and sharing | Only for Mac | Local capture; sharing may use connected services | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/trarrenshot-screenshot/id6755657068?mt=12) |
| 955324462 | Apowersoft Screenshot | Utilities | Apowersoft | Exact price pending | UNKNOWN | Regional, window and full-screen capture | Only for Mac | Local capture; upload/share features may connect | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/gb/app/apowersoft-screenshot/id955324462) |

## Faz 3F pazar sinyalleri

- **Font yönetimi:** Ücretsiz basit preview araçlarından $45.99 font creation ürünlerine kadar geniş fiyat aralığı var. Profesyonel değer; activation, Adobe integration, variable fonts, glyph editing ve takım font library yönetiminden geliyor.
- **App icon araçları:** Tek görseli resize etmek neredeyse tamamen ücretsizleşmiş durumda. Ücretli değer; background removal, batch projects, Android/Web/Windows desteği, Contents.json doğruluğu ve screenshot studio ile oluşuyor.
- **Color picker:** Çok sayıda ücretsiz menü çubuğu aracı var. Sadece HEX kopyalayan yeni ürünün para kazanma ihtimali düşük; WCAG, code formats, palette sync, design-token export ve team sharing gerekiyor.
- **Screenshot annotation:** Native, hafif ve local-first ürünler çok sayıda. Scrolling capture, pin-to-screen, blur/redaction, OCR ve automatic sensitive-data masking güçlü farklılaşma alanları.
- **App Store screenshot pazarı:** 2025–2026’da yoğun şekilde büyümüş. Multi-language localization, direct App Store Connect upload, screenshot variants/A-B tests ve CI/Fastlane integration yeni satın alma gerekçeleri.
- **Fiyat:** Basit screenshot framer ürünleri ücretsiz veya yaklaşık $1–$4 iken, tam publishing platformları $4.99 haftalık ile $79.99 lifetime seviyesine çıkabiliyor.
- **Offline fırsatı:** App Store Screenshot Dev gibi tamamen local ve hesapsız araçlar; API-key veya hesap zorunlu rakiplere karşı güçlü bir güven mesajı oluşturuyor.

## Doğrulandı fakat Mac envanterine alınmayan örnekler

- Coolors — 2M+ günlük yaratıcı ve 10K rating açıklıyor; ancak Apple sayfasında `Designed for iPad. Not verified for macOS`.
- App Icon Maker (ID 6737986804) — Apple sayfasında `Designed for iPad. Not verified for macOS`.
- Color Identifier: Color Picker — Apple sayfasında `Designed for iPad. Not verified for macOS`.
- Font Maker: Create Your Font — güncel sayfa mobil kullanım odaklı; native Mac ürünü olarak doğrulanmadı.

## Faz 3G sonraki tarama kümeleri

1. Translation, dictionary, grammar, citation and academic-reference tools.
2. Writing, screenplay, novel, research notes and bibliography managers.
3. Türkiye, Almanya and Japonya storefront-local Mac apps.
4. Developer catalogue expansion and A–Z/0–9 saturation queries.
5. Chart kayıtlarına `trackId`, developer, exact price and rating enrichment.

**Sürüm:** 3F — 2 Ağustos 2026

# Faz 3G — Yedinci Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Aday kayıt:** 77  
**Yeni benzersiz `trackId`:** 77  
**Önceki chart/uzun-kuyruk envanteriyle çakıştığı için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 532  
**Top Charts dahil toplam veri satırı:** 1531

> [!IMPORTANT]
> Bu turda Scrivener 3, Grammarly ve Oxford Dictionary gibi önceki Top Charts envanterinde bulunan ürünler otomatik olarak dışlandı. Uygulamanın adı değişmiş olsa bile aynı `trackId` yeniden eklenmedi.

## Faz 3G küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Translation & language utilities | 11 |
| Novel, screenplay & long-form writing | 24 |
| Dictionaries & lexical reference | 11 |
| Grammar & writing assistants | 7 |
| Academic research & citations | 24 |
| **Toplam** | **77** |

## Kategori dağılımı

| App Store kategorisi | Kayıt |
|---|---:|
| Productivity | 57 |
| Reference | 10 |
| Education | 9 |
| Lifestyle | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| UNKNOWN | 30 |
| PAID | 13 |
| FREEMIUM | 11 |
| FREEMIUM/SUB | 8 |
| SUB | 4 |
| FREE | 3 |
| LIFE | 3 |
| FREE/SERVICE | 2 |
| FREEMIUM/LIFE | 1 |
| SUB/SERVICE | 1 |
| PAID/SERVICE | 1 |

## Kullanım ve indirme kanıtları

| Kanıt sınıfı | Kayıt |
|---|---:|
| NONE | 64 |
| PUBLIC-PROXY | 6 |
| PRODUCT-SCALE | 5 |
| EDITORIAL-SIGNAL | 2 |

- Bu partide kamuya açık ve doğrulanmış **Mac’e özel indirme veya aylık aktif kullanıcı sayısı bulunmadı**.
- Sözlükteki kelime sayısı, desteklenen dil sayısı veya AI kelime limiti kullanıcı sayısı değildir.
- Apple ödülleri ve editoryal seçkiler `EDITORIAL-SIGNAL`, App Store rating sayıları `PUBLIC-PROXY` olarak tutuldu.
- iPhone/iPad/Mac evrensel ürünlerde toplam rating yalnızca Mac kullanımını temsil etmez.

## Faz 3G uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Offline/bağımlılık | Kullanım/indirme sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 1410212159 | Citationsy | Education | Citationsy Ltd. | Exact price/service plan pending | SUB/SERVICE | Citation creation and bibliography export | Only for Mac | Citationsy account/service dependency | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/citationsy/id1410212159?mt=12) |
| 1021762639 | Citation Generator | Education | J.G. Mobile Apps | Exact price pending | PAID | Offline APA citation and bibliography generation | Only for Mac | Offline citation storage and templates | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/citation-generator/id1021762639?mt=12) |
| 1025669335 | MLA Citation Generator | Education | J.G. Mobile Apps | Exact price pending | PAID | Offline MLA citation and bibliography generation | Only for Mac | Offline citation storage and templates | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mla-citation-generator/id1025669335?mt=12) |
| 1423522373 | MarginNote 3 | Education | MarginNote | Exact price/IAP pending | FREEMIUM | PDF/EPUB notes, mind maps, flashcards and research | Only for Mac | Local documents with iCloud collaboration optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/marginnote-3/id1423522373) |
| 1023020023 | Thesis Generator | Education | J.G. Mobile Apps | Exact price pending | PAID | Thesis statements and essay outlines | Only for Mac | Offline idea generation and templates | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/thesis-generator/id1023020023) |
| 406421537 | Booxter Lite | Lifestyle | Deep Prose Software | Free | FREE | Book and media collection with BibTeX export | Only for Mac | Local catalogue; metadata lookup optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/booxter-lite/id406421537?mt=12) |
| 6743034049 | Noteworthy PDF: Margin Notes | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Academic PDF annotation with visible margin notes | Only for Mac | Native local PDF workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/noteworthy-pdf-margin-notes/id6743034049?mt=12) |
| 1537845384 | Essayist: Academic Writing App | Productivity | Essayist Software | Free trial + IAP/subscription; exact tiers pending | FREEMIUM/SUB | Academic writing, citations and reference management | Mac/iPad listing; Mac availability confirmed | Web search requires internet; document work local/cloud sync | Apple named it Mac App of the Year 2025; award is not user count | EDITORIAL-SIGNAL | [Apple App Store](https://apps.apple.com/us/app/essayist-academic-writing-app/id1537845384) |
| 922765270 | LiquidText | Productivity | LiquidText, Inc. | Free + IAP/subscription | FREEMIUM/SUB | Document review, excerpts, links and research workspaces | iPad-first app with Mac compatibility | Local documents; collaboration and cloud import connected | No Mac-specific user count; editorial awards are not downloads | EDITORIAL-SIGNAL | [Apple App Store](https://apps.apple.com/us/app/liquidtext/id922765270) |
| 6763628045 | BibKit | Productivity | Silicon Suite | Exact price pending | UNKNOWN | Focused PDF and BibTeX reference manager | Only for Mac | Local research library; online metadata optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/bibkit/id6763628045?mt=12) |
| 1501646723 | Knotes | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Kindle and reading-note knowledge manager | Only for Mac | Cloud import/sync required for some sources | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/knotes/id1501646723) |
| 6757381177 | KMate: Notes & Vocab Manager | Productivity | Developer not parsed | Exact price/IAP pending | UNKNOWN | Kindle highlights, notes, vocabulary and reading analytics | Only for Mac | Kindle import connected; personal iCloud sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/kmate-notes-vocab-manager/id6757381177?mt=12) |
| 458866234 | Texifier - LaTeX Editor | Productivity | Valletta Ventures | Exact price pending | PAID | LaTeX, BibTeX, indexing and live typesetting | Only for Mac | Local TeX engine; package downloads require internet | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/texifier-latex-editor/id458866234?mt=12) |
| 6775087546 | LiquidWorkspace | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Linked writing, research, references and visual planning | Native Mac listing | Local workspace with optional sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/liquidworkspace/id6775087546) |
| 6751741956 | LeedPDF | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Local PDF drawing and research annotation | Only for Mac | All processing claimed local | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/leedpdf/id6751741956) |
| 6761349832 | Lattice: Reference Manager | Productivity | 毅 范 | Free + IAP | FREEMIUM/LIFE | Local-first PDF, BibTeX and citation manager | Only for Mac | Local library; web import and Zotero integration optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lattice-reference-manager/id6761349832?mt=12) |
| 686459498 | PaperShip - Mendeley & Zotero | Productivity | Shazino | $9.99 | PAID/SERVICE | Mendeley/Zotero library and PDF annotation client | Only for Mac | Requires Mendeley or Zotero account | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/papership-mendeley-zotero/id686459498?mt=12) |
| 1518159265 | MarkNode | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Mind-map outlining and Markdown thesis/book writing | Only for Mac | Local document workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/marknode/id1518159265?mt=12) |
| 1290342643 | Story Planner for Writers | Productivity | Developer not parsed | One-time purchase; exact price pending | LIFE | Novel, screenplay, essay and research outlining | Only for Mac | Local project workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/story-planner-for-writers/id1290342643?mt=12) |
| 1575605022 | Lattics - Brain-like Writing | Productivity | Developer not parsed | $5.99 monthly / $35.99 yearly | SUB | Research cards, bibliography, PDF extraction and thesis writing | Only for Mac | Local app plus connected web app and sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lattics-brain-like-writing/id1575605022?mt=12) |
| 1254949442 | NoteTaker 5 | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Research notebook, outlines, audio notes and publishing | Mac listing | Local notebooks with iCloud sharing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/notetaker-5/id1254949442) |
| 1522407225 | MonsterWriter: Thesis & Papers | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Thesis, paper, citation, Zotero and LaTeX writing | Only for Mac | Local editor; Zotero/lookup features connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/monsterwriter-thesis-papers/id1522407225?mt=12) |
| 1449826029 | Notebooks: Write and Organize | Productivity | Alfons Schmid | Exact price/IAP pending | UNKNOWN | Writing, tasks, research and book organization | Mac-compatible universal listing | Local files with configurable storage/sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/notebooks-write-and-organize/id1449826029) |
| 417583544 | Reference Miner | Reference | Sonny Software, LLC | Exact price pending | UNKNOWN | Academic database search, EZProxy and PDF capture | Only for Mac | Online scholarly search required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/reference-miner/id417583544) |
| 6754507115 | AI Grammar Checker and Writer | Education | Jannat Tariq | Free + IAP | FREEMIUM | Grammar, paraphrase, summarization and dictionary | Only for Mac | AI service dependency pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-grammar-checker-and-writer/id6754507115?mt=12) |
| 997615882 | Simple Furigana | Education | Developer not parsed | Paid; exact current price pending | PAID | Japanese furigana annotation and dictionary lookup | Only for Mac | Local annotation; optional dictionary downloads | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/simple-furigana/id997615882?mt=12) |
| 1165762449 | Collins Dictionary | Reference | Antony Lewis | Exact price pending | PAID | Collins English dictionary and pronunciations | Only for Mac | Offline dictionary database | 722,000 entries and phrases are product scale, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/collins-dictionary/id1165762449) |
| 725292882 | Megawords | Reference | Developer not parsed | Exact price pending | UNKNOWN | Dictionary, rhyme, wildcard, crossword and anagram search | Only for Mac | Offline lexical database | 400,000-word dictionary is product scale, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/megawords/id725292882) |
| 442806060 | WordWeb Pro Dictionary | Reference | Antony Lewis | Exact price pending | PAID | English dictionary, thesaurus and audio pronunciation | Only for Mac | Offline dictionary database | 70,000 audio pronunciations are product scale, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/wordweb-pro-dictionary/id442806060) |
| 308750436 | Dictionary.com: English Words | Reference | Curiosity Media, Inc. | Free + ads/IAP | FREEMIUM | English dictionary, thesaurus, grammar and word of the day | Designed for iPhone/iPad; M1 Mac compatibility listed | Offline capability varies by content | 2M+ definitions/synonyms are product scale, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/dictionary-com-english-words/id308750436) |
| 435330169 | Shorter Oxford English Dict | Reference | Antony Lewis | Exact price pending | PAID | Historical and contemporary English dictionary | Only for Mac | Offline dictionary database | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/shorter-oxford-english-dict/id435330169) |
| 524941905 | Slovoed Dictionaries | Reference | Paragon Technologie GmbH | Free + dictionary IAP | FREEMIUM | Multilingual downloadable dictionary catalogue | Only for Mac | Downloaded dictionaries can work offline | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/slovoed-dictionaries/id524941905?mt=12) |
| 500583211 | Chambers Dictionary | Reference | Antony Lewis | Exact price pending | PAID | Offline English dictionary and word-game search | Only for Mac | Offline dictionary database | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/chambers-dictionary/id500583211) |
| 498829958 | Chambers Thesaurus | Reference | Antony Lewis | Exact price pending | PAID | Offline English thesaurus | Only for Mac | Offline lexical database | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/chambers-thesaurus/id498829958?mt=12) |
| 656113391 | XXI Century Dictionaries | Reference | Paragon Technologie GmbH | Free + dictionary IAP | FREEMIUM | Russian and bilingual dictionary catalogue | Only for Mac | Downloaded dictionaries can work offline | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/xxi-century-dictionaries/id656113391?mt=12) |
| 1451305054 | AI English Grammar Check Spell | Education | Developer not parsed | Paid/IAP status pending | UNKNOWN | English grammar, spelling and synonym checker | Only for Mac | Processing method pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-english-grammar-check-spell/id1451305054?mt=12) |
| 6757104080 | Grammar checker & paraphrase | Productivity | Developer not parsed | Exact price pending | UNKNOWN | AI grammar correction and paraphrasing | Only for Mac | AI service dependency likely | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/grammar-checker-paraphrase/id6757104080) |
| 1541809406 | Scribens : Grammar Checker | Productivity | Scribens | Free limited + Premium service | FREEMIUM/SUB | Browser grammar checking and paraphrasing | Only for Mac | Online Scribens service required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/scribens-grammar-checker/id1541809406) |
| 766176336 | 1Checker | Productivity | Xiaobao Online | Free | FREE/SERVICE | English grammar and writing suggestions | Only for Mac | Online checking service likely | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/1checker/id766176336?mt=12) |
| 6738683741 | QuillBot: AI Writing Assistant | Productivity | QuillBot | Free + Premium IAP | FREEMIUM/SUB | Grammar, paraphrase, summarization and generative writing | Only for Mac | Cloud AI service required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quillbot-ai-writing-assistant/id6738683741?mt=12) |
| 6502833800 | Grammar Checker & Rephraser | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Spelling, grammar and sentence rephrasing | Only for Mac | AI/service dependency likely | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/grammar-checker-rephraser/id6502833800?mt=12) |
| 6744279654 | Compose: AI Writing Assistant | Productivity | Developer not parsed | Free + subscription/IAP status pending | FREEMIUM/SUB | System-wide rewriting and generative writing | Only for Mac | Cloud AI likely required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/compose-ai-writing-assistant/id6744279654) |
| 6742030152 | Infinite Library: AI Book Maker | Productivity | Developer not parsed | Free + IAP/subscription | FREEMIUM/SUB | AI long-form book and screenplay generation | iPhone, iPad and Mac | Cloud AI and web research required | 10K/20K free words and 100K output are product limits, not users | PRODUCT-SCALE | [Apple App Store](https://apps.apple.com/us/app/infinite-library-ai-book-maker/id6742030152) |
| 6754580397 | NovelDesk: Novel Writing App | Productivity | Developer not parsed | Exact price/IAP pending | UNKNOWN | Apple-silicon novel-writing workspace | Only for Mac; M1 or later | Local project workflow; AI/sync pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/noveldesk-novel-writing-app/id6754580397?mt=12) |
| 871198005 | xScreenplay | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Distraction-free screenplay editor | Only for Mac | Local screenplay files | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/xscreenplay/id871198005?mt=12) |
| 1180883279 | Draft Writing - Script & Blog | Productivity | Developer not parsed | Exact price/IAP pending | UNKNOWN | Fiction, scripts, blogs, characters and scenes | Only for Mac | Local editing with cloud storage option | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/draft-writing-script-blog/id1180883279) |
| 6746042932 | Authorcise | Productivity | Developer not parsed | Exact price/IAP pending | UNKNOWN | Focused writing exercises and author workflow | Only for Mac | Local writing workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/authorcise/id6746042932?mt=12) |
| 1549538329 | Beat | Productivity | Lauri-Matti Parppei | Free | FREE | Fountain screenwriting, outlining and revisions | Only for Mac | Fully local and open source | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/beat/id1549538329?mt=12) |
| 1520190857 | JotterPad - Novel, Screenplay | Productivity | Two App Studio | Free + subscription/IAP | FREEMIUM/SUB | Markdown and Fountain writing and publishing | Mac-compatible universal listing | Local writing; cloud and publishing features connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/jotterpad-novel-screenplay/id1520190857) |
| 511850807 | WriteStudio | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Multi-page document and organized writing workspace | Only for Mac | Local documents; Apple Intelligence optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/writestudio/id511850807?mt=12) |
| 1641661226 | L1 - Simply Write, Simply Right | Productivity | Kiloma | Free + IAP | FREEMIUM | Multilingual keyboard-language and spelling correction | Only for Mac | System-wide text processing; privacy behavior pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/l1-simply-write-simply-right/id1641661226?mt=12) |
| 6761337268 | Verso Writer | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Native Mac word processor | Only for Mac | Local document workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/verso-writer/id6761337268?mt=12) |
| 6745401961 | Nodes - by the WERK | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Native structured writing app | Only for Mac | Local writing workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/nodes-by-the-werk/id6745401961?mt=12) |
| 580546268 | Novel Writer | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Novel planning, chapters and visual organization | Only for Mac | Local project workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/novel-writer/id580546268) |
| 1361725141 | MyStory.today | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM | Novel, scenes, corkboard, timeline and AI writing | iPhone, iPad and Mac | Cross-device sync; AI features connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mystory-today/id1361725141) |
| 6758745141 | cwote | Productivity | Developer not parsed | Exact price/IAP pending | UNKNOWN | Novel, screenplay and AI-assisted creative writing | Mac availability listed | Manual writing local; AI connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/cwote/id6758745141) |
| 1445242832 | Storyist 4 | Productivity | Storyist Software | Free trial; $59.99 Standard / $29.99 upgrade | LIFE | Novel, screenplay, corkboard and publishing workspace | Only for Mac | Local projects; iCloud/iOS sync optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/storyist-4/id1445242832?mt=12) |
| 1556415183 | FiveActs | Productivity | Synium Software GmbH | $29.99 observed; current promotion may vary | PAID | Novel, screenplay, stage play, characters and revisions | Only for Mac | Local native Mac project workflow | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/fiveacts/id1556415183?mt=12) |
| 6756551874 | Scriptease: Screenwriting | Productivity | Developer not parsed | One-time purchase; exact price pending | LIFE | Offline screenwriting and production planning | Only for Mac | Fully offline; no account required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/scriptease-screenwriting/id6756551874) |
| 6756072342 | Quill Studio | Productivity | Weverest Solutions LLC | Free | FREE | Offline-first novel, screenplay and worldbuilding workspace | Only for Mac | Local PouchDB with optional online sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quill-studio/id6756072342?mt=12) |
| 488557039 | Fade In | Productivity | General Coffee Co. | Paid; exact current price pending | PAID | Professional screenplay writing and revisions | Mac App Store version is Mac-only | Local projects; collaboration can connect | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/fade-in/id488557039) |
| 1577516695 | Mendeley Web Importer | Productivity | Elsevier | Free | FREE/SERVICE | Safari reference and PDF importer | Only for Mac | Mendeley account and web access required | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/mendeley-web-importer/id1577516695?mt=12) |
| 1191200443 | TwelvePoint Writing Studio | Productivity | morePaths.com | $22.99 | PAID | Screenplay, novel, comic and stage-play publishing | Only for Mac | Local writing; no data collected stated | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/twelvepoint-writing-studio/id1191200443) |
| 721350229 | Logline | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Screenplay, treatment and outline editor | Only for Mac | Local project workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/logline/id721350229?mt=12) |
| 6770947857 | Manifold App | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Visual guides, reference cards and writing planning | Only for Mac | Manual local workspace | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/manifold-app/id6770947857?mt=12) |
| 1502685031 | Notewrap: Writers Note Book | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Writer notebook, loose-leaf pages and book projects | Only for Mac | Local documents with iCloud sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/notewrap-writers-note-book/id1502685031) |
| 6755037592 | Grammar Checker : Spell Check | Education | Developer not parsed | Free + IAP | FREEMIUM | System-wide grammar, translation and dictionary | Only for Mac | AI/service dependency pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/grammar-checker-spell-check/id6755037592?mt=12) |
| 6686403979 | Translator - Offline Translate | Productivity | Developer not parsed | Exact price pending | UNKNOWN | 38-language offline translator | Only for Mac | Uses macOS offline translation capability | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/translator-offline-translate/id6686403979?mt=12) |
| 6446244627 | Lingvanex Web Translator | Productivity | Lingvanex | Free + subscription; exact current tiers pending | SUB | Browser and webpage translation | Only for Mac | Web translation requires internet | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lingvanex-web-translator/id6446244627?mt=12) |
| 858617889 | Translate Pro: Text Translator | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Clipboard, menu-bar and multi-window translation | Only for Mac | On-device translation for supported pairs; cloud for others | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/translate-pro-text-translator/id858617889?mt=12) |
| 6754808002 | Quick Translate - Fast & Smart | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Menu-bar translation using Apple Translation | Only for Mac | Offline for supported Apple language pairs | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quick-translate-menu-bar-app/id6754808002) |
| 1254982908 | Lingvanex Offline Translator | Productivity | Lingvanex | Free + subscription; exact current tiers pending | SUB | Offline text, document and dictionary translation | Only for Mac | Offline language packs; account/subscription for Pro | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lingvanex-offline-translator/id1254982908?mt=12) |
| 1128242453 | Pro Translate - translator app | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Private on-device offline translation | Only for Mac | Offline and on-device AI claimed | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/pro-translate-translator-app/id1128242453) |
| 6761548322 | Translix - Screen Translate | Productivity | Developer not parsed | Free + 7-day Pro trial; tiers pending | FREEMIUM/SUB | Screen-area, hover and system-audio translation | Mac App Store listing | Apple/Google/Youdao/local-LLM engines; dependency varies | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/app/id6761548322) |
| 1667225994 | Lookupper | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Selection-based translation and dictionary lookup | Only for Mac | Translation provider dependency pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lookupper/id1667225994) |
| 1217010477 | Intelligent Translator | Productivity | Developer not parsed | Free; $0.99 monthly / $9.99 yearly | SUB | System-wide translation, pronunciation and word lookup | Only for Mac | Online translation; basic features available without premium | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/intelligent-translator/id1217010477) |
| 1467716481 | Translator X - OCR Tool | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Text, screenshot OCR and image translation | Only for Mac | OCR/translation uploads images and text according to listing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/translator-x-ocr-tool/id1467716481) |

## Faz 3G pazar sinyalleri

- **Translation:** Apple’ın on-device translation altyapısı, basit metin çevirisini metalaştırıyor. Ücretli değer; system-audio translation, screen overlay, document formatting, offline LLM ve system-wide hotkey iş akışında.
- **Dictionary:** Büyük lisanslı sözlükler tek seferlik ücret almaya devam ediyor. Genel İngilizce sözlükten ziyade hukuk, tıp, etimoloji, crossword, akademik dil ve iki dilli uzman sözlükler daha savunulabilir.
- **Grammar:** Genel AI grammar ürünleri çok benzer. Mac-native farklılaşma; tamamen local model, herhangi bir metin alanında çalışma, kurum sözlüğü, style guide ve hassas belge gizliliği üzerinden oluşabilir.
- **Academic reference:** Zotero/Mendeley entegrasyonu ile local-first BibTeX yöneticileri arasında açık bir bölünme var. Yeni hafif ürünler ağır, eski reference-manager arayüzlerine karşı hız ve gizlilikle konumlanıyor.
- **Thesis writing:** Citation, bibliography, equations, cross-reference, Mermaid ve LaTeX export’un tek uygulamada birleşmesi ücretli değer yaratıyor.
- **Screenwriting:** Ücretsiz Beat gibi güçlü rakipler temel Fountain formatını metalaştırmış durumda. Ücretli ürünler production planning, revisions, Final Draft interoperability, storyboard, character graph ve publishing ile farklılaşıyor.
- **Novel writing:** Scrivener/Storyist türü klasik ürünlere karşı yeni uygulamalar offline-first sync, worldbuilding, timeline, AI scene summaries ve daha sade native arayüz vaat ediyor.
- **Fiyat gücü:** Profesyonel uzun-form yazım ürünlerinde yaklaşık $22.99–$59.99 tek seferlik fiyatlar hâlâ görülüyor; basit grammar/translation araçları ise çoğunlukla freemium veya abonelik.

## Faz 3H sonraki tarama kümeleri

1. Calendar, email, meeting, transcription notes and personal CRM long tail.
2. Security, password, encryption, privacy and file-vault tools.
3. Türkiye, Almanya and Japonya storefront-local applications.
4. Developer catalogue expansion and A–Z/0–9 saturation queries.
5. Existing 999 chart records için `trackId`, developer, exact price and rating enrichment.

**Sürüm:** 3G — 2 Ağustos 2026

# Faz 3H — Sekizinci Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Aday kayıt:** 80  
**Yeni benzersiz `trackId`:** 80  
**Önceki envanterde bulunduğu için çıkarılan:** 0  
**Faz 3 kümülatif chart-dışı kayıt:** 612  
**Top Charts dahil toplam veri satırı:** 1611

> [!IMPORTANT]
> Şirketlerin açıkladığı “millions of users” gibi sayılar Mac App Store indirmesi değildir. Bu rakamlar yalnızca `DISCLOSED-ALL-PLATFORMS` olarak tutulmuştur. Mac’e özgü kesin indirme/MAU sayısı bulunmadığında alan açıkça boş bırakılmamıştır.

## Faz 3H küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Calendar & scheduling | 16 |
| Passwords, encryption & vaults | 29 |
| Email & inbox | 13 |
| Meeting notes & transcription | 18 |
| Personal CRM & contacts | 4 |
| **Toplam** | **80** |

## Kategori dağılımı

| App Store kategorisi | Kayıt |
|---|---:|
| Productivity | 62 |
| Utilities | 15 |
| Business | 3 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| UNKNOWN | 30 |
| FREEMIUM/SUB | 22 |
| FREEMIUM | 7 |
| FREE | 6 |
| SUB | 5 |
| PAID | 3 |
| HYBRID | 2 |
| FREEMIUM/SUB/LIFE | 2 |
| FREEMIUM/SERVICE | 1 |
| FREEMIUM/LIFE | 1 |
| FREE/SERVICE | 1 |

## Kullanım/indirme kanıtı

| Kanıt sınıfı | Kayıt |
|---|---:|
| NONE | 70 |
| PUBLIC-PROXY | 4 |
| DISCLOSED-ALL-PLATFORMS | 3 |
| EDITORIAL-SIGNAL | 2 |
| PRODUCT-CLAIM | 1 |

- App Store rating sayısı indirme değildir; `PUBLIC-PROXY` sınıfında tutulur.
- Şirketin toplam müşteri veya kullanıcı açıklaması `DISCLOSED-ALL-PLATFORMS` sınıfındadır.
- Apple sistem uygulamalarında dahi Mac’e özgü aktif kullanıcı sayısı kamuya açık değildir.
- Güvenlik ürünlerinde pazarlama sıfatları yerine şifreleme yöntemi, local/cloud modeli ve hesap zorunluluğu kaydedilmiştir.

## Faz 3H uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Offline/bağımlılık | Kullanım/indirme sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 1435279326 | Top Contacts - Contact Manager | Business | Developer not parsed | Free + Pro IAP | FREEMIUM/LIFE | Contacts, relationships, tasks, calendar and files | Mac; separate iOS companion | Local devices and iCloud; no third-party sync claimed | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/top-contacts-contact-manager/id1435279326?mt=12) |
| 6444851827 | Across: Modern Calendar | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Calendar, reminders, countdowns and daily planning | iPhone, iPad, Mac and Apple Watch | Apple Calendar/Reminders local integration; sync via Apple services | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/across-calendario-moderno/id6444851827?l=en-US) |
| 608834326 | Calendars: Schedule Planner | Productivity | Readdle Technologies Limited | Free + Pro subscription | FREEMIUM/SUB | Calendar, tasks, habits and daily planning | Mac, iPhone, iPad and Apple Watch | Google/iCloud sync and meeting services require internet | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/calendars-schedule-planner/id608834326?platform=mac) |
| 975937182 | Fantastical - Calendar | Productivity | Flexibits Inc. | Free + 14-day Premium trial/subscription | FREEMIUM/SUB | Calendar, tasks, scheduling polls and meeting links | Mac, iPhone, iPad and Apple Watch | Local calendar access; cloud calendars and meeting integrations connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/fantastical-calendar/id975937182?mt=12) |
| 1314445497 | Menubar Calendar | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Floating calendar and clock | Only for Mac | Local calendar display | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/menubar-calendar/id1314445497) |
| 1558360383 | Menu Bar Calendar | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Menu-bar calendar and Google Calendar launch | Only for Mac | Apple Calendar local; Google Calendar option connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/menu-bar-calendar/id1558360383?mt=12) |
| 1662205314 | QuickCal - menu bar calendar | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Menu-bar calendar and schedule | Only for Mac | Local calendar data | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quickcal-menu-bar-calendar/id1662205314) |
| 510684580 | CalendarMenu 4 | Productivity | Developer not parsed | Paid; exact price pending | PAID | Menu-bar calendar, contacts birthdays and reminders | Only for Mac | Local Calendar, Contacts and Reminders | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/calendarmenu-4/id510684580?mt=12) |
| 1088779979 | Mini Calendar | Productivity | Developer not parsed | Free; no IAP | FREE | Menu-bar monthly calendar | Only for Mac | Local calendar display | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mini-calendar/id1088779979) |
| 6504735260 | Næste – Menu Bar Calendar | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Minimal calendar event list | Only for Mac | Integrates with local macOS Calendar | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/n%C3%A6ste-menu-bar-calendar/id6504735260) |
| 6737839295 | CalendarPeek | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Next-event menu-bar calendar | Only for Mac | Local Calendar and Maps integration; no account required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/calendarpeek/id6737839295?mt=12) |
| 6744621424 | Sidebar Calendar | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Persistent sidebar and menu-bar calendar | Only for Mac | Reads local Apple Calendar; external accounts through system calendar | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/sidebar-calendar/id6744621424) |
| 1173663647 | BusyCal: Calendar & Reminders | Productivity | Busy Apps FZE | Free trial + active subscription | SUB | Professional calendar and reminders | Only for Mac | Local calendars supported; Exchange/Google/Todoist connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/busycal-calendar-reminders/id1173663647?mt=12) |
| 1481535767 | Singularity: To Do List, Tasks | Productivity | Developer not parsed | Free + Pro/Elite plans | FREEMIUM/SUB | Tasks, day plans and calendar scheduling | Only-for-Mac listing with cross-device service | Account and device sync connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/singularity-to-do-list-tasks/id1481535767) |
| 6496284092 | Next Up: Menu Bar Calendar | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Today agenda in the menu bar | Only for Mac | Reads local calendar events | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/next-up-menu-bar-calendar/id6496284092) |
| 6445813049 | Spark Mail - AI Email & Inbox | Productivity | Readdle Technologies Limited | Free + Premium subscription | FREEMIUM/SUB | Unified inbox, calendar and AI email workflow | Only for Mac | Email accounts and AI features require network | Brand describes Spark as loved by millions; all-platform claim, not Mac installs | DISCLOSED-ALL-PLATFORMS | [Apple App Store](https://apps.apple.com/us/app/spark-mail-ai-email-inbox/id6445813049?mt=12) |
| 533757624 | SpinOffice CRM | Business | Developer not parsed | Free limited + cloud plans | FREEMIUM/SUB | SMB CRM, email archive, projects and documents | Mac App Store listing | Cloud encrypted storage and IMAP integration | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/spinoffice-crm/id533757624?mt=12) |
| 6749230975 | Dove - AI Email Assistant | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | AI-first unified email client | Mac, iPad and iPhone | Mail accounts and AI require network | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/dove-ai-email-assistant/id6749230975?platform=mac) |
| 1108187098 | Mail | Productivity | Apple | Free/system app | FREE | Apple email client with Intelligence summaries | Apple platforms including Mac | Mail accounts require network; offline mailbox cache | System-app usage is not publicly separated for Mac | NONE | [Apple App Store](https://apps.apple.com/us/app/mail/id1108187098) |
| 6749447444 | Mailbird - The Email App | Productivity | Mailbird, Inc. | Exact price pending | UNKNOWN | Customizable multi-account email client | Only for Mac | Mail servers required; local cache and attachment workflow | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mailbird-the-email-app/id6749447444?mt=12) |
| 1236045954 | Canary Mail App | Productivity | Mailr Tech LLP | Free + Growth/Pro plans | FREEMIUM/SUB | Email, AI copilot, encryption and anti-phishing | Mac-compatible Apple-platform app | Email and AI connected; PGP/SecureSend available | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/canary-mail-app/id1236045954?mt=12) |
| 6508165504 | Mail+ App for Gmail | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Gmail desktop client/wrapper | Only for Mac | Google account and network required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mail-app-for-gmail/id6508165504?mt=12) |
| 6756658450 | MailPro: email app for Gmail | Productivity | Appify Apps LLC | Exact price pending | UNKNOWN | High-performance Gmail client | Only for Mac | Google account and network required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mailpro-email-app-for-gmail/id6756658450?mt=12) |
| 1484231533 | AltaMail | Productivity | EuroSmartz Ltd | Free trial + IAP | FREEMIUM | Highly customizable email and automation client | Only for Mac | Email servers required; local rules and views | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/altamail/id1484231533?mt=12) |
| 6478043112 | MsgFiler 4 - Inbox Zero Email | Productivity | Developer not parsed | Monthly/annual subscription | SUB | Keyboard-based Apple Mail filing | Only for Mac | Works with local Apple Mail database | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/msgfiler-4-inbox-zero-email/id6478043112) |
| 1176895641 | Spark Classic – Email App | Productivity | Readdle Technologies Limited | Free + IAP/status pending | FREEMIUM | Legacy Spark email client | Only for Mac | Email accounts require network; offline cache available | Apple Best of App Store signal; not download count | EDITORIAL-SIGNAL | [Apple App Store](https://apps.apple.com/us/app/spark-classic-email-app/id1176895641?mt=12) |
| 6745995785 | Clay for Safari | Productivity | Clay | Free/service account | FREE/SERVICE | LinkedIn/Gmail personal CRM sidebar | Only for Mac | Clay account and web services required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/clay-for-safari/id6745995785) |
| 918858936 | Airmail - Lightning Fast Email | Productivity | Bloop S.R.L. | Exact current price/IAP pending | FREEMIUM/SUB | Multi-account native email client | Only for Mac | Offline operations; mail servers and sync connected | Apple Design Award 2017; award is not usage count | EDITORIAL-SIGNAL | [Apple App Store](https://apps.apple.com/us/app/airmail-lightning-fast-email/id918858936?mt=12) |
| 6746069877 | Marco – Email | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Privacy-first unified email client | iPhone, iPad and Mac | IMAP/Gmail/Outlook/iCloud network dependency | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/marco-email/id6746069877) |
| 6502156163 | Omi - Smart Meeting Notes | Productivity | Based Hardware | Free + service/IAP pending | FREEMIUM/SERVICE | Always-available meeting memory, tasks and API | Mac-compatible Apple-platform app | Online/offline modes; cloud-free deployment option claimed | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/omi-smart-meeting-notes/id6502156163) |
| 6759878308 | Whisperer: Local AI Transcribe | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Apple-silicon local meeting and media transcription | Mac and iPhone | Neural Engine/Metal local processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/whisperer-local-ai-transcribe/id6759878308) |
| 6473629578 | Spellar: AI Meeting Note Taker | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | Live meeting copilot, notes and integrations | Mac-compatible Apple-platform app | Apple Speech/Whisper bridge plus connected AI/integrations | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/spellar-ai-meeting-note-taker/id6473629578) |
| 6477414161 | Notes.ai | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Local meeting transcription and transcript chat | Mac; Apple M1 or later | Whisper and local language model; exports to Notion/Obsidian may connect | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/notes-ai/id6477414161) |
| 6752535574 | Menubar Meeting Transcriber | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Local system-audio and microphone meeting transcription | Only for Mac | Whisper transcription fully local; no account | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/menubar-meeting-transcriber/id6752535574?mt=12) |
| 6759488047 | Alt: AI Meeting Note Taker | Productivity | Developer not parsed | Free + subscription | FREEMIUM/SUB | Meeting and voice-note transcription | Mac and other Apple devices | Local mode available; cloud transcription also offered | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/alt-ai-meeting-note-taker/id6759488047?platform=mac) |
| 6755390155 | AI Note Taker for Meetings | Productivity | Developer not parsed | Subscription; exact tiers pending | SUB | Meeting recorder, transcription and AI summaries | iPhone, iPad and Mac; M1 required | Cloud AI service indicated by privacy URLs | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-note-taker-for-meetings/id6755390155) |
| 6773110790 | Mumr: Meeting Recorder | Productivity | Developer not parsed | Free | FREE | Meeting recording and local/Apple Intelligence summaries | Only for Mac | Local Apple Intelligence option; other summarizers pending QA | Not enough ratings for an App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/mumr-meeting-recorder/id6773110790?mt=12) |
| 1526330329 | Laxis: AI Meeting Note Taker | Productivity | Laxis, Inc. | Free + service plans | FREEMIUM/SUB | Meeting recording, transcription and CRM integration | Mac via Apple-silicon compatible app | Web app and Salesforce/HubSpot integrations connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/laxis-ai-meeting-assistant/id1526330329) |
| 6450138660 | Memo - Smart AI Meeting Notes | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | Meeting recording, transcription, summaries and chat | Mac-compatible Apple-platform app | User can choose on-device or cloud AI | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/memo-ai-meeting-note-taker/id6450138660) |
| 6476989700 | AI Meeting Notes - Tablo | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | Meeting transcription and AI notes | iPhone, iPad and Mac | AI processing/service dependency pending QA | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-meeting-notes-tablo/id6476989700) |
| 6478665147 | Meeting.ai: AI Visual Notes | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | Meeting transcription and visual summaries | Mac-compatible Apple-platform app | AI service dependency pending QA | Marketing claim of 65% better recall is not a user count | PRODUCT-CLAIM | [Apple App Store](https://apps.apple.com/us/app/meeting-ai-ai-visual-notes/id6478665147) |
| 6751551175 | Meeting Mind | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Meeting transcription, speaker labeling and summaries | Mac App Store listing | Ollama/Apple Intelligence local options; OpenRouter optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/meeting-mind/id6751551175?mt=12) |
| 6760836937 | MoosePad: AI Meeting Notes | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Meeting transcription, summaries and speaker labels | Mac, iPhone and iPad | Transcription on device; AI summaries may use connected processing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/moosepad-ai-meeting-notes/id6760836937) |
| 6754086711 | Inscribe: Transcriptions & AI | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Meeting, file, OCR and system-audio knowledge base | Mac App Store listing | Apple Intelligence/built-in local model; connected imports optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/inscribe-transcriptions-ai/id6754086711) |
| 6737804988 | Noteum: AI Meeting Note Taker | Productivity | Developer not parsed | Free + IAP/subscription pending | FREEMIUM/SUB | Online-meeting transcription and notes | Mac-compatible Apple-platform app | Zoom/Meet/Teams and AI service dependency | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ai-note-taker-meeting-memos/id6737804988) |
| 6760206449 | Boring Meeting – Call Recorder | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Private meeting/call recorder and transcriber | Only for Mac; Apple silicon | 100% local/offline; no account | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/boring-meeting-call-recorder/id6760206449?mt=12) |
| 1385055809 | QuickRecorder - Voice Library | Productivity | Developer not parsed | Free + Pro IAP | FREEMIUM | Recording, local Whisper, meeting minutes and summaries | Mac-compatible app | Transcription local; cloud storage optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quickrecorder-voice-library/id1385055809) |
| 6751912612 | CrypNote | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Encrypted local notes and images | Mac-compatible app | Encryption on device; keys stored in Keychain | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/crypnote/id6751912612) |
| 1285392450 | Standard Notes | Productivity | Standard Notes Ltd. | Free + subscription | FREEMIUM/SUB | End-to-end encrypted notes and files | iPhone, iPad, Mac and web | Encrypted sync; offline local access | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/standard-notes/id1285392450) |
| 897283731 | Strongbox - Password Manager | Productivity | Phoebe Code Limited | Free + IAP; yearly Pro $24.99 observed | FREEMIUM/SUB/LIFE | KeePass and Password Safe vault | Mac, iPhone, iPad and Apple Watch | Local/open database files; cloud provider optional | 4.1K US ratings observed; not Mac-only usage | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/strongbox-password-manager/id897283731) |
| 1591056366 | Secrets - Password Manager | Productivity | Outer Corner, Unipessoal LDA | Free + IAP | FREEMIUM | Native password, passkey and secure-data manager | iPhone, iPad and Mac | Encrypted iCloud sync; no vendor-server sync claimed | 185 US ratings observed; not Mac downloads | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/secrets-password-manager/id1591056366) |
| 732710998 | Enpass - Password Manager | Productivity | Enpass Technologies Inc. | Free + Premium plans | FREEMIUM/SUB/LIFE | Offline-first password and passkey manager | Only for Mac | Vault can be stored locally or in user's chosen cloud | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/enpass-password-manager/id732710998?mt=12) |
| 6754113900 | Secure Local Notes | Productivity | Developer not parsed | Exact price pending | UNKNOWN | On-device encrypted private notes | Mac-compatible Apple-platform app | Offline, no account and no tracking claimed | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/secure-local-notes/id6754113900) |
| 1137397744 | Bitwarden Password Manager | Productivity | Bitwarden Inc. | Free + optional Premium plans | FREEMIUM/SUB | Open-source password and passkey manager | Mac and other platforms | End-to-end encrypted sync; self-hosting available | No public Mac-specific count | NONE | [Apple App Store](https://apps.apple.com/us/app/bitwarden-password-manager/id1137397744) |
| 517914548 | Dashlane Password Manager | Productivity | Dashlane | Free + subscription | FREEMIUM/SUB | Password manager, breach monitoring and secure notes | Mac-compatible Apple-platform app | Cloud service; encrypted local/offline access | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/dashlane-password-manager/id517914548?platform=mac) |
| 1627460689 | Password Manager by 2Stable | Productivity | 2Stable | Free + IAP/subscription | FREEMIUM/SUB | Passwords, 2FA, files, photos and private groups | Mac-compatible app | End-to-end encrypted sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/password-manager/id1627460689) |
| 6443490629 | Proton Pass - Password Manager | Productivity | Proton AG | Free + IAP/subscription | FREEMIUM/SUB | Passwords, passkeys, aliases, 2FA and encrypted notes | Mac-compatible Apple-platform app | End-to-end encrypted Proton sync | 6.7K US ratings observed; not Mac downloads | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/proton-pass-password-manager/id6443490629) |
| 414781829 | Keeper Password Manager | Productivity | Keeper Security, Inc. | Free + subscription/IAP | FREEMIUM/SUB | Passwords, passkeys, files and secure sharing | Only-for-Mac listing | Zero-knowledge encrypted service; offline cache | Keeper says trusted by millions; all-platform, not Mac installs | DISCLOSED-ALL-PLATFORMS | [Apple App Store](https://apps.apple.com/us/app/keeper-password-manager/id414781829?mt=12) |
| 1511601750 | 1Password: Password Manager | Productivity | AgileBits Inc. | Free download + subscription | SUB | Passwords, passkeys, identities and secure vaults | Mac and other platforms | Zero-knowledge cloud sync; offline cached access | Company says millions of people and 90,000+ businesses; all-platform, not Mac installs | DISCLOSED-ALL-PLATFORMS | [Apple App Store](https://apps.apple.com/us/app/1password-password-manager/id1511601750) |
| 6443917910 | NordPass Password Manager | Productivity | Nordvpn S.A. | Free + IAP; TR listing shows ₺139.99 monthly | FREEMIUM/SUB | Passwords, passkeys, secure notes and file storage | Only for Mac | Zero-knowledge cloud service; 3GB file storage on plans | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/nordpass-password-manager/id6443917910?mt=12) |
| 1087080039 | Quick View Calendar | Productivity | Jeffrey Morgan | Exact price pending | UNKNOWN | Simple menu-bar month view | Only for Mac | Local display; no cloud account required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quick-view-calendar/id1087080039) |
| 935235287 | Encrypto: Secure Your Files | Utilities | MacPaw Way Ltd | Free | FREE | AES-256 file and folder encryption | Only for Mac | Fully local encryption; sharing optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/encrypto-secure-your-files/id935235287?mt=12) |
| 6760589273 | FileBit: Encrypt & Lock Files | Utilities | Developer not parsed | Exact price pending | UNKNOWN | AES-256-GCM file vault and secure shredding | Only for Mac | Local CryptoKit encryption and Touch ID | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/filebit-encrypt-lock-files/id6760589273) |
| 984596109 | The Vault - Security Made Easy | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Authenticated AES encrypted data vault | Mac App Store listing | Local encryption using CommonCrypto | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/the-vault-security-made-easy/id984596109) |
| 1560822163 | Cryptomator: Protect Privacy | Utilities | Skymatic GmbH | Paid/IAP status pending | PAID | Client-side cloud-file encryption | Mac-compatible Apple-platform app | Encrypts locally; user-selected cloud storage | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/cryptomator-protect-privacy/id1560822163) |
| 6745215321 | Content Vault | Utilities | Content Vault Ltd | Exact price pending | UNKNOWN | Device-specific encrypted media and PDF sharing | Only for Mac | AES-256 local encryption; key exchange for sharing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/content-vault/id6745215321?mt=12) |
| 6764484161 | Bound: Private Vault | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Disguised encrypted photo, video and document vault | Mac-compatible app | Local encrypted vault; no tracking claimed | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/bound-private-vault/id6764484161) |
| 1547771496 | Simpleum Safe 3 - Encryption | Utilities | Simpleum Media GmbH | Exact price pending | PAID | Encrypted document safe and archive | Only for Mac | Local encryption; PBKDF2 and safe-file storage | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/simpleum-safe-3-encryption/id1547771496) |
| 6746755801 | LockDown - Secure Photo Vault | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Encrypted document, photo and video vault | Only for Mac | Local encryption and password protection | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lockdown-secure-photo-vault/id6746755801) |
| 6746962777 | File Vault: Safe Photos, Files | Utilities | Developer not parsed | Exact price/IAP pending | UNKNOWN | Encrypted documents, photos and videos | Mac App Store listing | Local file encryption and private media preview | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/file-vault-safe-photos-files/id6746962777?mt=12) |
| 1498304829 | Privaulty: Folder Vault Secure | Utilities | Developer not parsed | Free trial; $1.99 monthly / $14.99 yearly / lifetime option | HYBRID | Encrypted folder vault and iCloud backup | Only for Mac | On-the-fly local encryption; iCloud optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/privaulty-folder-vault-secure/id1498304829?mt=12) |
| 1595447434 | TextCrypt - Encrypted Storage | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Encrypted notes, passwords and files | Mac-compatible app | Local storage or encrypted cloud sync options | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/textcrypt-encrypted-storage/id1595447434) |
| 410755452 | Password Pad Lite | Utilities | Developer not parsed | Free | FREE | Password-encrypted free-form note files | Only for Mac | Local encrypted note files | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/password-pad-lite/id410755452?mt=12) |
| 896560988 | File Vault | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Password-protected private-file manager | Only for Mac | Local protected files | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/file-vault/id896560988?mt=12) |
| 6473799789 | Passwords | Utilities | Apple | Free/system app | FREE | Passwords, passkeys, Wi-Fi credentials and AutoFill | Apple platforms including Mac and Windows sync support | Encrypted iCloud sync; local device access | System-app usage is not publicly separated for Mac | NONE | [Apple App Store](https://apps.apple.com/us/app/passwords/id6473799789) |
| 6468237241 | Spartan - Photo & Video Vault | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Private encrypted media and file vault | Only for Mac | Local encryption | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/spartan-photo-video-vault/id6468237241) |
| 916377538 | Contacts Journal CRM | Business | Developer not parsed | Free limited + one-time personal unlock; teams subscription | HYBRID | Contact logs, todos, files, companies and follow-ups | Mac App Store app with iOS counterpart | Local/iCloud data; team sharing through iCloud | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/contacts-journal-crm/id916377538?mt=12) |
| 1451429218 | Queue Personal CRM | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Personal relationships, reminders and interaction imports | iPhone and Mac | Google Calendar/Gmail and contacts imports require connected accounts | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/queue-personal-crm/id1451429218) |
| 964258399 | BusyContacts | Productivity | Busy Apps FZE | 14-day trial + active subscription | SUB | Professional contact manager and lightweight CRM | Only for Mac | Local Contacts plus connected accounts; BusyCal integration | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/busycontacts/id964258399?mt=12) |
| 6776393696 | Follow Up: Personal CRM | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Relationship history and follow-up reminders | Native Mac and iOS | All data stored on device; local notifications | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/follow-up-personal-crm/id6776393696) |

## Faz 3H pazar sinyalleri

- **Calendar:** Basit menu-bar calendar pazarı çok kalabalık ve çoğunlukla ücretsiz. Ücretli değer; scheduling polls, meeting proposals, timezone, task integration, calendar sets ve natural-language entry üzerinden oluşuyor.
- **Email:** Genel unified-inbox ürünleri abonelik ve AI katmanına kayıyor. Privacy-first native client, Apple Mail üzerine çalışan tek amaçlı utilities ve peşin/lifetime alternatifleri daha açık boşluklar.
- **Meeting notes:** 2025–2026 Mac pazarında local Whisper/Apple Intelligence ürünleri hızla artmış durumda. Sistem sesi + mikrofon, speaker labels, searchable history ve local summaries artık temel beklentiye yaklaşıyor.
- **Personal CRM:** Native Mac rekabeti sınırlı. Follow-up reminders, interaction history, contact/company links ve iCloud/local-first saklama; ağır satış CRM’lerine karşı net konumlanıyor.
- **Passwords:** Apple Passwords ücretsiz tabanı yükselttiği için yeni şifre yöneticileri passkey, cross-platform, team sharing, hardware key, audit, alias ve self-hosting ile ayrışmak zorunda.
- **Encrypted vault:** Basit “klasörü gizleme” yerine AES-GCM/AES-256, authenticated encryption, secure shredding, Touch ID ve portable encrypted container ürün değerini belirliyor.
- **Fiyat:** Küçük menu-bar uygulamalarında free/one-time baskın; meeting/email/password ürünlerinde abonelik yaygın; local file-encryption araçlarında free veya lifetime seçenekleri hâlâ güçlü.

## Faz 3I sonraki tarama kümeleri

1. Automation, macro, Shortcuts, text expansion and launcher long tail.
2. Remote desktop, virtualization, file sharing and collaboration utilities.
3. Türkiye, Almanya and Japonya storefront-local Mac applications.
4. Developer catalog expansion and A–Z/0–9 saturation queries.
5. Existing chart records için `trackId`, developer, exact price, rating and version enrichment.

**Sürüm:** 3H — 2 Ağustos 2026

# Faz 3I — Dokuzuncu Chart-Dışı Uzun-Kuyruk Partisi

**Gözlem tarihi:** 2 Ağustos 2026  
**Ana kaynak:** Apple App Store ürün sayfaları  
**Aday kayıt:** 75  
**Yeni benzersiz `trackId`:** 69  
**Önceki chart/uzun-kuyruk envanteriyle çakıştığı için çıkarılan:** 6  
**Faz 3 kümülatif chart-dışı kayıt:** 681  
**Top Charts dahil toplam veri satırı:** 1680

> [!IMPORTANT]
> Apple sayfasında Mac uyumluluğu bulunan fakat masaüstü istemci biçimi kesinleşmeyen evrensel remote uygulamalar `final QA` etiketiyle tutuldu. iPhone/iPad-only olduğu açıkça görülen ürünler Mac envanterine alınmadı.

## Faz 3I küme özeti

| Küme | Yeni uygulama |
|---|---:|
| Automation, macros & workflows | 25 |
| Text expansion & snippets | 15 |
| Launchers & switchers | 16 |
| Remote, virtualization & file sharing | 13 |
| **Toplam** | **69** |

## Kategori dağılımı

| App Store kategorisi | Kayıt |
|---|---:|
| Productivity | 40 |
| Utilities | 25 |
| Developer Tools | 2 |
| Lifestyle | 1 |
| Photo & Video | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| UNKNOWN | 26 |
| FREEMIUM | 21 |
| PAID | 13 |
| FREEMIUM/SUB | 3 |
| FREE | 2 |
| LIFE | 2 |
| PAID/SUB | 1 |
| FREE/SERVICE | 1 |

## Kullanım/indirme kanıtı

| Kanıt sınıfı | Kayıt |
|---|---:|
| NONE | 59 |
| PUBLIC-PROXY | 7 |
| MAINTENANCE-RISK | 3 |

- Bu partide hiçbir ürün için kamuya açık, doğrulanmış **Mac’e özel kesin indirme veya MAU sayısı** bulunmadı.
- Review içinde belirtilen satın alma fiyatı, güncel App Store fiyatı sayılmadı.
- Desteklenen protokol, mimari veya özellik sayısı `PRODUCT-SCALE`; kullanıcı sayısı değildir.
- Legacy uygulamalarda eski güncelleme ve uyumluluk şikâyetleri `MAINTENANCE-RISK` olarak işaretlendi.

## Faz 3I uygulama envanteri

| Track ID | Uygulama | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Offline/bağımlılık | Kullanım/indirme sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 6741457777 | AutoMouseClicker | Lifestyle | 论 李 | $5.99 | PAID | Mouse and keyboard automation recorder | Only for Mac | Local recording and playback | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/automouseclicker/id6741457777) |
| 6466106779 | Retrobatch Pro | Photo & Video | Flying Meat Inc. | Free + IAP | FREEMIUM | Node-based batch-image automation and Shortcuts integration | Only for Mac | Local files; JavaScript and clipboard workflows | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/retrobatch-pro/id6466106779?mt=12) |
| 6463636684 | Rocket Typist | Productivity | Developer not parsed | Exact price/IAP pending | FREEMIUM | Cross-device text expander | Mac, iPhone and iPad | Local snippets with iCloud sync | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/rocket-typist/id6463636684) |
| 6748924282 | LaunchDeck: App Launcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Grouped launch modes for apps and websites | Only for Mac | Local launcher; websites connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/launchdeck-app-launcher/id6748924282) |
| 1307848592 | Text Expansion Pro | Productivity | Developer not parsed | Exact price pending | PAID | Legacy text-expansion utility | Only for Mac | Local expansion | Indexed reviews report old-macOS compatibility problems | MAINTENANCE-RISK | [Apple App Store](https://apps.apple.com/us/app/text-expansion-pro/id1307848592?mt=12) |
| 6756636709 | MacroLoop | Productivity | Henrique Bersani | Free + IAP | FREEMIUM | Mouse and keyboard macro recording, scheduling and loops | Only for Mac | All recordings and playback run locally | Not enough ratings for overview; a review mentions buying Premium for $5, not verified current price | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/macroloop/id6756636709) |
| 6753730468 | FlashWrite | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Privacy-first system-wide abbreviation expansion | Only for Mac | All data stored locally | Not enough ratings for App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/flashwrite/id6753730468) |
| 6759798788 | Rulebook: File Automation | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Rule-based file and folder automation | Only for Mac | Local watched-folder processing | Not enough ratings for App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/rulebook-file-automation/id6759798788) |
| 6757748498 | FileMason | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Watched-folder move, copy, rename, delete and tagging rules | Only for Mac | 24/7 local folder monitoring with undo history | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/filemason/id6757748498) |
| 1594183810 | Shortery | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Event triggers for Apple Shortcuts | Only for Mac | Local system-event automation; called shortcuts may use services | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/shortery/id1594183810) |
| 1567748223 | SwiftyMenu | Utilities | 圣罡 汤 | Free + IAP | FREEMIUM | Finder right-click scripts, apps and terminal automation | Only for Mac | Operations and scripts run locally | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/swiftymenu/id1567748223?mt=12) |
| 1517291304 | Gamepad Mapper | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Gamepad-to-keyboard/mouse automation | Only for Mac | Local input mapping | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/gamepad-mapper/id1517291304?mt=12) |
| 528183797 | Joystick Mapper | Utilities | Developer not parsed | Exact price pending | PAID | Joystick and gamepad keyboard/mouse mapping | Only for Mac | Local input mapping | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/joystick-mapper/id528183797?mt=12) |
| 6747758704 | Ghost Input: Record and Play | Utilities | Georgios Trigonakis | $5.99 | PAID | Keyboard and mouse action recording and replay | Only for Mac | Local Accessibility-based recording | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/ghost-input-record-and-play/id6747758704) |
| 1447884454 | Action Shortcuts: Automation | Utilities | Maxim Ananov | Free + IAP | FREEMIUM | Keyboard/menu execution of AppleScript, Automator and shell scripts | Only for Mac | Local script execution | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/action-shortcuts-automation/id1447884454?mt=12) |
| 6742142873 | Lingon 10 | Utilities | Peter Borg Apps AB | Exact price pending | PAID | Launchd jobs, scheduled commands and background automation | Only for Mac | Local launchd configuration and scripts | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lingon-10/id6742142873?mt=12) |
| 6478646159 | Tiny Clicker | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Mouse/keyboard macro recording and timing control | Only for Mac | Local automation | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/tiny-clicker/id6478646159) |
| 1555844307 | MouseBoost Pro | Utilities | Yuuan Ltd | $7.99 | PAID | Paid 60+ tool Finder automation suite | Only for Mac | Local Finder, Shell and AppleScript operations | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mouseboost-pro/id1555844307?mt=12) |
| 443370764 | Repeater | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Record and replay UI actions for testing and repetitive work | Only for Mac | Local input recording | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/repeater/id443370764) |
| 6447680045 | MousHero for Safari | Utilities | Cesare Forelli | $1.99 | PAID | Safari right-click URL-scheme automation | Only for Mac | Local Safari extension; target automations may connect | 1 rating observed; not an install count | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/moushero-for-safari/id6447680045?mt=12) |
| 6740313656 | Mouse Jiggler – Mouse Mover | Utilities | Bohdan Bilous | Free + IAP | FREEMIUM | Scheduled and variable mouse movement | Only for Mac | Local Accessibility-based cursor automation | Reviews confirm Pro purchases but do not reveal install count | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/mouse-jiggler-mouse-mover/id6740313656?mt=12) |
| 1586568802 | Simple Macro | Utilities | Developer not parsed | Exact price pending | UNKNOWN | Simple mouse and keyboard macro recorder | Only for Mac | Local action recording | Not enough ratings for App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/simple-macro/id1586568802?mt=12) |
| 1576440429 | Almighty - Powerful Tweaks | Utilities | Khuong Pham | Free + IAP | FREEMIUM | System tweaks, hotkeys, scripts and multi-step workflows | Only for Mac | Most operations local; custom scripts supported | Not enough ratings for App Store overview | PUBLIC-PROXY | [Apple App Store](https://apps.apple.com/us/app/almighty-powerful-tweaks/id1576440429?mt=12) |
| 525319418 | EventScripts | Utilities | Developer not parsed | Exact price pending | UNKNOWN | System-event and proximity triggered AppleScript automation | Only for Mac | Local AppleScript and event triggers | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/eventscripts/id525319418) |
| 435410196 | Stay | Utilities | Developer not parsed | Free | FREE | Window-layout restoration with hotkeys and script actions | Only for Mac | Local window management and shell-script actions | Legacy-update risk; no public exact Mac downloads | MAINTENANCE-RISK | [Apple App Store](https://apps.apple.com/us/app/stay/id435410196?mt=12) |
| 6747335010 | Quick Launch Switcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Fast visual app launcher and switcher | Only for Mac | Local installed-app indexing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quick-launch-switcher/id6747335010?mt=12) |
| 6754261327 | M-Launcher - App Launcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Grid launcher, app organizer and system-file navigator | Only for Mac | Local app/file indexing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/m-launcher-app-launcher/id6754261327?mt=12) |
| 6746273626 | Dory - App Switcher | Productivity | Segev Sherry | $9.99 | PAID | Habit-learning zero-config launcher and switcher | Only for Mac | Local usage learning | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/dory-app-switcher/id6746273626?mt=12) |
| 6758429774 | Corner Deck: App Launcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Hot-corner app, website and command launcher | Only for Mac | Local launcher; websites connected | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/corner-deck-app-launcher/id6758429774) |
| 6742973359 | Quick Apps Launcher | Productivity | Developer not parsed | One-time purchase; exact price pending | LIFE | Hotkey launcher for favorite applications | Only for Mac | Local app launcher | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/shortcut-quick-app-launcher/id6742973359?mt=12) |
| 6748739667 | App Switcher and Launcher | Productivity | Wise Tech Labs Private Limited | Exact price pending | UNKNOWN | Keyboard-first app switcher and launcher | Only for Mac | Local installed-app indexing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/app-switcher-and-launcher/id6748739667?mt=12) |
| 6752657468 | Launchie App Launcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Lightweight customizable Mac launcher | Only for Mac | Local app launcher | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/launchie-app-launcher/id6752657468) |
| 6762567563 | FolderyMenu: Menu Bar Files | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Menu-bar file, folder and application launcher | Only for Mac | Local file indexing and Quick Look | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/folderymenu/id6762567563) |
| 1563735522 | Charmstone | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Mouse-direction app launcher and focus switcher | Only for Mac | Local launcher | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/charmstone/id1563735522) |
| 724472954 | Manico | Productivity | Developer not parsed | Exact price pending | PAID | Number-key application launcher and usage counter | Only for Mac | Local app switching and usage graph | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/manico/id724472954) |
| 6739782043 | Launchy: App Launcher | Productivity | Ivan Sapozhnik | Free + IAP | FREEMIUM | Radial app, file and folder launcher | Only for Mac | Local launcher with optional iCloud settings sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/launchy-app-launcher/id6739782043?mt=12) |
| 6748283184 | G Orbit : Launcher & Switcher | Productivity | Developer not parsed | Free + IAP | FREEMIUM | Radial menu-bar launcher for apps and web tools | Only for Mac | Local apps; websites require internet | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/g-orbit-launcher-switcher/id6748283184?mt=12) |
| 6740396517 | Quick App Launcher (QAL) Pro | Productivity | Developer not parsed | Paid; exact price pending | PAID | Search, tags, AI categories and app grid | Only for Mac | Local installed-app indexing; AI categorization scope pending | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quick-app-launcher-qal-pro/id6740396517?mt=12) |
| 6476907452 | Applight – Smart App Switcher | Productivity | Seungwoo Choe | Exact price/IAP pending | FREEMIUM | Searchable app and window switcher | Only for Mac | Local app/window indexing | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/applight-smart-app-switcher/id6476907452?mt=12) |
| 6758021004 | App Palette | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Visual app palette and running-state launcher | Only for Mac | Local installed-app access | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/app-palette/id6758021004) |
| 6749490386 | AppSpace Launcher | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Workspace launcher, folders, hidden apps and quit timer | Only for Mac | Local app organization and launch | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/appspace-launcher/id6749490386?mt=12) |
| 6751540294 | StarDesk - Remote Desktop | Productivity | Developer not parsed | Exact price/IAP pending | FREEMIUM/SUB | 4K multi-platform remote desktop and file transfer | Mac-compatible multi-platform app | Remote network/service required | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/stardesk-remote-desktop/id6751540294) |
| 692035811 | TeamViewer Remote Control | Productivity | TeamViewer Germany GmbH | Free + subscription/IAP | FREEMIUM/SUB | Remote access, support and bidirectional file transfer | Apple page lists Mac compatibility; desktop-client modality needs final QA | TeamViewer service required | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/teamviewer-remote-control/id692035811?platform=mac) |
| 1617419574 | DeskIn Remote Desktop | Productivity | Developer not parsed | Free + service plans | FREEMIUM/SUB | Remote control, file transfer, screen extension and support | Cross-platform app with Mac support | DeskIn network/service required | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/deskin-remote-desktop/id1617419574) |
| 352019548 | RealVNC Viewer: Remote Desktop | Productivity | RealVNC | Free/service account status pending | FREE/SERVICE | VNC remote access to Mac, Windows and Linux | Mac-compatible Apple-platform app | RealVNC server/service or direct VNC required | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/realvnc-viewer-remote-desktop/id352019548) |
| 1663047912 | Screens 5: VNC Remote Desktop | Productivity | Edovia Inc. | Exact price/IAP pending | PAID/SUB | VNC remote desktop, SSH, file transfer and curtain mode | iPhone, iPad, Mac and Vision Pro | Remote network required; iCloud settings sync | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/screens-5-vnc-remote-desktop/id1663047912?platform=mac) |
| 486899236 | Remoter | Productivity | Remoter Labs LLC | $9.99 | PAID | VNC, RDP, SSH, Telnet and remote macros | Only for Mac | Remote network required; saved profiles local | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/remoter/id486899236?mt=12) |
| 6761764462 | QuickRemote - Desktop Manager | Productivity | Developer not parsed | Free + Pro IAP | FREEMIUM | VNC/RDP profiles, LAN discovery and multi-session control | Apple-platform app; Mac mode requires final QA | Remote network required | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quickremote-desktop-manager/id6761764462) |
| 6760924092 | BIShare: File Transfer | Utilities | Developer not parsed | Exact price/IAP pending | FREEMIUM | Bonjour-based Apple-device file transfer and SharePlay | Mac-compatible Apple-platform app | Local-network transfer; FaceTime for SharePlay | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/bishare-file-transfer/id6760924092) |
| 488665335 | Secure File Share Server | Utilities | Developer not parsed | Free + IAP | FREEMIUM | Browser-based local file server with permissions and HTTPS | Only for Mac | Local-network server; no third-party cloud required | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/secure-file-share-server/id488665335?mt=12) |
| 6758573445 | SyncDrop: Photo & File Backup | Utilities | Developer not parsed | Exact price/IAP pending | FREEMIUM | Cloud-free local-network file sharing | Only for Mac with mobile counterparts | Local-network peer-to-peer transfer | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/syncdrop-photo-file-backup/id6758573445?mt=12) |
| 530573877 | Sync Folders | Utilities | Developer not parsed | Exact price/IAP pending | FREEMIUM | Incremental folder synchronization | Mac App Store app | Local, external and network folders | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/sync-folders/id530573877?platform=mac) |
| 1605485521 | Remote Desktop Scanner | Utilities | Sascha Simon | Free + IAP | FREEMIUM | LAN discovery and one-click VNC/SSH connection | Only for Mac | Local-network scanning and credentials | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/remote-desktop-scanner/id1605485521?mt=12) |
| 6752865855 | EasyJoin: File Transfer & Sync | Utilities | Panagiotis Spiropoulos | Free + one-time Pro IAP | LIFE | Mac–Android P2P file, clipboard and SMS integration | Only for Mac | Local-network peer-to-peer; no cloud required for core transfers | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/easyjoin-file-transfer-sync/id6752865855?mt=12) |
| 1527428847 | Snip : Snippets Manager | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Code snippets, Markdown preview and Gist sync | Only for Mac | Local library; GitHub sync optional | Legacy last indexed update in 2021 | MAINTENANCE-RISK | [Apple App Store](https://apps.apple.com/us/app/snip-snippets-manager/id1527428847?mt=12) |
| 6757330954 | SnipperApp 3 | Developer Tools | Developer not parsed | Exact price pending | UNKNOWN | Developer snippets, command center and GitHub Gist sync | Only for Mac | Local library; iCloud/Gist sync optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/snipperapp-3/id6757330954) |
| 6474688391 | TypeIt4Me 7 | Productivity | Developer not parsed | Exact price pending | PAID | Classic text expansion, prompts, dates and autocorrect | Only for Mac | Local expansion; import and sync options | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/typeit4me-7/id6474688391?mt=12) |
| 6752991699 | Text Catalyst: Paste & Expand | Productivity | Sense LLC | Free + IAP | FREEMIUM | Clipboard history and text expansion | Only for Mac | Local searchable clipboard and snippets | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/text-catalyst/id6752991699?mt=12) |
| 468369783 | iClip – Clipboard Manager | Productivity | Thomas Tempelmann | $14.99 | PAID | Clipboard sets, snippets and AppleScript automation | Only for Mac | Local clip library and AppleScript support | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/iclip-clipboard-manager/id468369783?mt=12) |
| 6759178453 | ExpandCaptain Snippet Keyboard | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Cross-device snippet keyboard and direct Mac expansion | Mac and mobile Apple devices; M1 Mac required | Local snippets; sync behavior pending QA | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/expandcaptain-snippet-keyboard/id6759178453) |
| 1381314885 | AutoTyper – Keyboard Shortcuts | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Dynamic phrases, merge tags and auto-paste | Only for Mac | Local phrase storage and Accessibility paste | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/autotyper-keyboard-shortcuts/id1381314885) |
| 1459047306 | LazyBoard: Keyboard Shortcuts | Productivity | Developer not parsed | Exact price/IAP pending | FREEMIUM | Phrase library and keyboard shortcuts | Mac, iPhone and iPad | Local phrases; sync optional | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/lazyboard-keyboard-shortcuts/id1459047306?platform=mac) |
| 1597462934 | Fast Text - Text Expander | Productivity | Wise Tech Labs Private Limited | Exact price pending | UNKNOWN | System-wide text snippets and abbreviations | Only for Mac | Local expansion; export/import | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/fast-text-text-expander/id1597462934) |
| 1530751461 | Snippety - Text Expander | Productivity | Developer not parsed | Free + Pro IAP | FREEMIUM | Text expansion, live templates, AI placeholders and collaboration | iPhone, iPad and Mac | Local snippets with iCloud sync/collaboration optional | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/snippety-text-expander/id1530751461?platform=mac) |
| 6755919256 | ShortKeys | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Text expansion, tags, JSON backup and Shortcuts deep links | Apple-platform app including Mac compatibility | Local snippets with iCloud sync | No public Mac-specific downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/shortkeys/id6755919256) |
| 6746696183 | Snippet: Visual copy & paste | Productivity | Developer not parsed | Exact price pending | UNKNOWN | Visual clipboard and reusable snippet library | Only for Mac | Local clipboard history | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/snippet-visual-copy-paste/id6746696183) |
| 6758690107 | Clipboard & Snippets - SnipIt | Utilities | enugo k.k. | Free + IAP | FREEMIUM | Clipboard history, macros, prompts and text expansion | Only for Mac | Local history; iCloud sync optional | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/clipboard-snippets-snipit/id6758690107?mt=12) |
| 1551462255 | MouseBoost | Utilities | Yuuan Ltd | Free + IAP | FREEMIUM | Finder right-click tools, scripts and clipboard automation | Only for Mac | Local Finder, Shell and AppleScript operations | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/mouseboost/id1551462255?mt=12) |
| 1142743710 | QuickKey–Email & Text Expander | Utilities | LittleFin LLC | Free | FREE | Placeholder-based email and text expansion | Only for Mac | Local snippets with iCloud sync | No public exact Mac downloads | NONE | [Apple App Store](https://apps.apple.com/us/app/quickkey-email-text-expander/id1142743710?mt=12) |

## Faz 3I pazar sinyalleri

- **Macro automation:** Accessibility tabanlı recorder pazarı 2025–2026’da yeniden büyüyor. Basit record/replay ürünü $5.99 civarında satılabiliyor; scheduling, variables, image recognition, undo ve güvenli permission onboarding fiyat gücünü artırıyor.
- **Shortcuts automation:** macOS Shortcuts’ın eksik kalan event-trigger katmanı ayrı bir pazar. Uygulama açılması, Wi-Fi, güç, ekran, cihaz, klasör ve toplantı olayları ücretli değer yaratıyor.
- **Text expansion:** Basit abbreviation expansion ücretsizleşmiş durumda. Ücretli değer; placeholders, forms, dates, team libraries, iCloud collaboration, code/Gist sync, statistics ve local AI işlemlerinde.
- **Launchers:** Yeni launcher sayısı çok yüksek ve çoğu yalnızca görsel farklılık sunuyor. Sürdürülebilir ürün için window switching, workspaces, commands, file search, browser tabs ve automation actions gerekir.
- **Remote desktop:** Protokol genişliği ve performans fiyatı belirliyor. Jump Desktop $34.99, Apple Remote Desktop $79.99; ürünlerin hedefleri bireysel uzaktan erişim ile kurumsal Mac yönetimi arasında ayrılıyor.
- **Virtualization:** UTM açık QEMU mimarisi ve çoklu işlemci emülasyonuyla; Parallels ise Windows entegrasyonu ve daha yönetilen deneyimle farklılaşıyor. Destek maliyeti ve OS uyumluluğu bu nişte yüksektir.
- **Local file sharing:** Cloud-free LAN transferi, özellikle Mac–Android aktarımı, büyük dosyalar, gizlilik ve aylık depolama ücreti istemeyen kullanıcılar için belirgin fırsat.
- **Legacy risk:** Text Expansion Pro, Snip ve Stay gibi eski ürünler talebin varlığını gösterse de güncel macOS uyumluluğu yeni rakipler için önemli bir avantaj.

## Örnek fiyat merdiveni

| Mikro-niş | Örnek | Görünen fiyat |
|---|---|---:|
| Safari automation | MousHero | $1.99 |
| Macro recorder | AutoMouseClicker | $5.99 |
| Macro recorder | Ghost Input | $5.99 |
| Finder automation | MouseBoost Pro | $7.99 |
| App switcher | Dory | $9.99 |
| Clipboard/snippets | iClip | $14.99 |
| Remote desktop | Jump Desktop | $34.99 |
| Virtualization | Parallels Desktop App Store Edition | $79.99 |
| Fleet administration | Apple Remote Desktop | $79.99 |

## Faz 3J sonraki tarama kümeleri

1. Türkiye, Almanya ve Japonya storefront-local Mac uygulamaları.
2. A–Z/0–9 sorgu doygunluk turu ve geliştirici katalog genişletmesi.
3. Daha önce bulunan geliştiricilerin tüm Mac kataloglarının taranması.
4. Phase 3 tekrar/uyumluluk denetimi ve kaldırılmış ürün kontrolü.
5. Faz 4 için ürün sayfası ve monetizasyon zenginleştirme kuyruğunun hazırlanması.

**Sürüm:** 3I — 2 Ağustos 2026

# Faz 3J — Türkiye, Almanya ve Japonya Storefront Taraması

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront’lar:** Türkiye, Almanya, Japonya  
**Aday Apple kimliği:** 70  
**Yeni benzersiz `trackId`:** 58  
**Önceki envanter/chart adıyla çakıştığı için çıkarılan:** 12  
**Faz 3 kümülatif chart-dışı kayıt:** 739  
**Top Charts dahil toplam veri satırı:** 1738

> [!IMPORTANT]
> `Storefront keşfi`, uygulamanın yalnızca o ülkede satıldığı anlamına gelmez. Kayıt, ABD çekirdeğinde bulunmayıp ilgili ülkenin chart, ürün sayfası, yerel dil veya doygunluk sorgusunda keşfedildiğini gösterir.

## Storefront dağılımı

| Storefront | Yeni kayıt |
|---|---:|
| TR | 21 |
| DE | 8 |
| JP | 29 |
| **Toplam** | **58** |

## Kategori dağılımı

| Kategori | Kayıt |
|---|---:|
| Productivity | 36 |
| Utilities | 21 |
| Reference | 1 |

## Monetizasyon dağılımı

| Model | Kayıt |
|---|---:|
| PAID | 29 |
| UNKNOWN | 17 |
| FREE | 3 |
| FREEMIUM | 3 |
| FREE/SERVICE | 2 |
| PAID/LIFE | 1 |
| FREE/DONATION | 1 |
| FREE/HARDWARE | 1 |
| FREEMIUM/SUB | 1 |

## Talep ve kullanım kanıtı

| Kanıt sınıfı | Kayıt |
|---|---:|
| LOCAL-CHART-PROXY | 36 |
| STOREFRONT-DISCOVERY | 16 |
| SATURATION-DISCOVERY | 5 |
| EDITORIAL-SIGNAL | 1 |

- Yerel chart sırası `LOCAL-CHART-PROXY` olarak kaydedildi; indirme veya aktif kullanıcı sayısı değildir.
- `Not enough ratings` ifadesi düşük rating hacmini gösterir ancak sıfır indirme anlamına gelmez.
- Editorial feature, cihaz/format sayısı ve ürün kataloğu kullanıcı sayısı değildir.
- Uygulama bazında doğrulanmış Mac download/MAU yalnızca geliştirici açıklaması varsa yazılacaktır.

## Faz 3J uygulama envanteri

| Track ID | Uygulama | Storefront | Kategori | Geliştirici | Fiyat | Model | Niş | Mac türü | Talep/kullanım sinyali | Kanıt | Kaynak |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 6791568030 | Penvyn | DE | Productivity | Developer not parsed | Paid chart; exact EUR price pending | PAID | FRITZ!Box call monitoring | Only for Mac | DE Productivity Paid chart #2 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/penvyn/id6791568030?mt=12) |
| 6447090616 | Whisper Notes: Sprache zu Text | DE | Productivity | Developer not parsed | Paid chart; exact EUR price pending | PAID | Offline Whisper transcription and notes | Mac-compatible listing | DE Productivity Paid chart #15 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/whisper-notes-sprache-zu-text/id6447090616?platform=mac) |
| 595543758 | oneSafe | DE | Productivity | Lunabee Pte. Ltd. | Paid chart; exact EUR price pending | PAID | Passwords, data and photo vault | Only for Mac | DE Productivity Paid chart #24 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/onesafe/id595543758?mt=12) |
| 1579902068 | xSearch for Safari | DE | Productivity | Developer not parsed | Paid chart; exact EUR price pending | PAID | Instant search-engine switching in Safari | Mac-compatible listing | DE Productivity Paid chart #19 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/xsearch-for-safari/id1579902068?platform=mac) |
| 948660805 | AusweisApp Bund | DE | Utilities | Governikus GmbH & Co. KG | Free | FREE/SERVICE | German electronic identity and online identification | Mac-compatible listing | DE Utilities Free chart #1 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/ausweisapp-bund/id948660805?platform=mac) |
| 1659087771 | HokusFokus | DE | Utilities | Developer not parsed | Free + IAP | FREEMIUM | Hide inactive windows and focus workspace | Only for Mac | Germany storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/de/app/hokusfokus/id1659087771) |
| 6740147178 | QuickDrop - Android Transfer | DE | Utilities | Developer not parsed | Free + IAP | FREEMIUM | Android Quick Share receiver and file transfer | Mac-compatible listing | DE Utilities Free chart #19 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/quickdrop-android-transfer/id6740147178?platform=mac) |
| 1317704208 | eduVPN client | DE | Utilities | Developer not parsed | Free | FREE/SERVICE | Research and education federation VPN | Only for Mac | DE Utilities Free chart #14 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/de/app/eduvpn-client/id1317704208?mt=12) |
| 6754601983 | CCCCorners | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Custom hot-corner actions | Only for Mac | JP Productivity Paid chart #21 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/ccccorners/id6754601983?mt=12) |
| 1144653900 | CleanUSBDrive | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Remove hidden metadata files from USB drives | Only for Mac | JP Productivity Paid chart #20 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/cleanusbdrive/id1144653900?mt=12) |
| 6470132467 | Clicker – Presentation Remote | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Presentation remote control | Mac-compatible listing | JP Productivity Paid chart #23 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/clicker-presentation-remote/id6470132467?platform=mac) |
| 1384206666 | DemoPro - 画面注釈 | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Live screen annotation, cursor highlight and whiteboard | Only for Mac | JP Productivity Paid chart #9 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/demopro-%E7%94%BB%E9%9D%A2%E6%B3%A8%E9%87%88/id1384206666?mt=12) |
| 519475454 | Hides | JP | Productivity | Developer not parsed | Exact JPY price pending | UNKNOWN | Automatically hide inactive applications | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/hides/id519475454?mt=12) |
| 6759033332 | Monora - ポモドーロタイマー | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Unobtrusive visual Pomodoro timer | Only for Mac | JP Productivity Paid chart #17 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/monora-%E3%83%9D%E3%83%A2%E3%83%89%E3%83%BC%E3%83%AD%E3%82%BF%E3%82%A4%E3%83%9E%E3%83%BC/id6759033332?mt=12) |
| 6770181778 | Noticky | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Desktop sticky-note utility | Only for Mac | JP Productivity Paid chart #15 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/noticky/id6770181778?mt=12) |
| 975974524 | RapidCopy | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | High-speed file copy and synchronization | Only for Mac | JP Productivity Paid chart #12 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/rapidcopy/id975974524?mt=12) |
| 421340897 | Tab Launcher | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Colorful screen-edge tabs for apps and files | Only for Mac | JP Productivity Paid chart #16 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/tab-launcher/id421340897?mt=12) |
| 1142625137 | Window Focus - Dim Screen | JP | Productivity | FIPLAB Ltd | Exact JPY price pending | UNKNOWN | Dim background windows and highlight active work | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/window-focus-dim-screen/id1142625137) |
| 457622435 | Yoink | JP | Productivity | Eternal Storms Software | Exact JPY price pending | PAID | Temporary drag-and-drop shelf | Only for Mac | Multiple Apple editorial features | EDITORIAL-SIGNAL | [Apple App Store](https://apps.apple.com/jp/app/yoink/id457622435) |
| 1230288277 | stone | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Japanese-focused text editor | Only for Mac | JP Productivity Paid chart #14 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/stone/id1230288277?mt=12) |
| 6788107913 | to-md | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | PDF, Word and Excel to Markdown conversion | Only for Mac | JP Productivity Paid chart #11 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/to-md/id6788107913?mt=12) |
| 1612892223 | ながら視聴 TVer（PiP） | JP | Productivity | Developer not parsed | Paid chart; exact JPY price pending | PAID | Picture-in-picture viewing for TVer | Only for Mac | JP Productivity Paid chart #10 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/%E3%81%AA%E3%81%8B-%E3%82%89%E8%A6%96%E8%81%B4-tver-pip/id1612892223?mt=12) |
| 1585757563 | NTFS Disk by Omi NTFS | JP | Utilities | JingZhi He | Free + VIP IAP | FREEMIUM/SUB | NTFS disk mount and management | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/ntfs-disk-by-omi-ntfs/id1585757563) |
| 1369524274 | QR Capture | JP | Utilities | Developer not parsed | Free chart; exact IAP status pending | FREE | Screen QR-code capture | Only for Mac | JP Utilities Free chart #15 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/qr-capture/id1369524274?mt=12) |
| 483820530 | QR Journal | JP | Utilities | Developer not parsed | Free chart; exact status pending | FREE | QR-code history and organization | Only for Mac | JP Utilities Free chart #25 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/qr-journal/id483820530?mt=12) |
| 6757801838 | RunCat Neo | JP | Utilities | Takuto Nakamura | Free + donation IAP | FREE/DONATION | Animated menu-bar CPU and custom-metric monitor | Only for Mac; macOS 26+ | JP Utilities Free chart #1; not enough ratings | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/runcat-neo/id6757801838?mt=12) |
| 507968596 | Secret Folder | JP | Utilities | Developer not parsed | Exact JPY price pending | UNKNOWN | Hide and reveal selected folders | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/secret-folder/id507968596) |
| 6778057096 | Store Fix | JP | Utilities | Developer not parsed | Exact JPY price pending | UNKNOWN | Rewrite App Store links to selected storefront | Mac, iPad and iPhone | Japan storefront/A–Z saturation discovery | SATURATION-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/store-fix/id6778057096?platform=mac) |
| 1587601078 | Super Window: Content Viewer | JP | Utilities | Joe Manto | Exact JPY price pending | UNKNOWN | Floating content viewer window | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/super-window-content-viewer/id1587601078) |
| 6753709318 | System Status Monitor: CPU RAM | JP | Utilities | Developer not parsed | Free + Pro IAP | FREEMIUM | CPU, RAM, disk, battery, network and sensor monitoring | Mac-compatible listing | Japan storefront discovery; exact Mac usage count unavailable | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/system-status-monitor-cpu-ram/id6753709318?platform=mac) |
| 1614816445 | TEPRA LINK 2 | JP | Utilities | KING JIM CO., LTD. | Free | FREE/HARDWARE | TEPRA label-printer design and printing | Mac-compatible listing | JP Utilities Free chart #23 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/jp/app/tepra-link-2/id1614816445?platform=mac) |
| 6760681801 | Utilify | JP | Utilities | PlayPalApps | Exact JPY price pending | UNKNOWN | 18-tool everyday technology toolkit | Mac requires Apple M1 or later | A–Z/storefront saturation discovery | SATURATION-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/utilify/id6760681801) |
| 6758023870 | Utilimate: The utilities app | JP | Utilities | Developer not parsed | Exact JPY price pending | UNKNOWN | All-in-one utility suite | Mac requires Apple M1 or later | A–Z/storefront saturation discovery | SATURATION-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/utilimate-the-utilities-app/id6758023870) |
| 6746359139 | Utilita | JP | Utilities | Developer not parsed | Exact JPY price pending | UNKNOWN | General utility toolkit | Mac requires Apple M1 or later | A–Z/storefront saturation discovery | SATURATION-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/utilita/id6746359139) |
| 6759199533 | Ytilities | JP | Utilities | Developer not parsed | Exact JPY price pending | UNKNOWN | General Mac utility suite | Mac requires Apple M1 or later | A–Z/storefront saturation discovery | SATURATION-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/ytilities/id6759199533) |
| 1165804840 | ZoomIn | JP | Utilities | Roland Rabien | Exact JPY price pending | UNKNOWN | Screen magnification utility | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/zoomin/id1165804840) |
| 6758077205 | 便利なNotch | JP | Utilities | Nakamoto Satoshi | Exact JPY price pending | UNKNOWN | Notch-based quick utility | Only for Mac | Japan storefront discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/jp/app/%E4%BE%BF%E5%88%A9%E3%81%AAnotch/id6758077205?mt=12) |
| 1020812363 | CopyClip 2 - Clipboard Manager | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Clipboard history and search | Only for Mac | TR Productivity Paid chart #13 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/copyclip-2-clipboard-manager/id1020812363?mt=12) |
| 430798174 | HazeOver • Distraction Dimmer | TR | Productivity | Pointum | Paid chart; exact TR price pending | PAID | Active-window distraction dimming | Only for Mac | TR Productivity Paid chart #6 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/hazeover-distraction-dimmer/id430798174?mt=12) |
| 1494642810 | Keys for Safari | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Keyboard-first Safari navigation | Mac-compatible listing | TR Productivity Paid chart #8 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/keys-for-safari/id1494642810?platform=mac) |
| 6758096737 | LaunchBA | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Launcher/productivity utility | Only for Mac | TR Productivity Paid chart #24 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/launchba/id6758096737?mt=12) |
| 6764493329 | MarkWell — Bookmark Manager | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Cross-device bookmark manager | Mac-compatible listing | TR Productivity Paid chart #11 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/markwell-bookmark-manager/id6764493329?platform=mac) |
| 6760967658 | NotchPrompter | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Teleprompter displayed in MacBook notch | Only for Mac | TR Productivity Paid chart #22 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/notchprompter/id6760967658?mt=12) |
| 6754604148 | Popout Timer & Stopwatch | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Floating timer, stopwatch and countdown | Only for Mac | TR Productivity Paid chart #16 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/popout-timer-stopwatch/id6754604148?mt=12) |
| 1469774098 | QSpace | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Multi-pane Finder replacement and file manager | Only for Mac | TR Productivity Paid chart #10 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/qspace/id1469774098?mt=12) |
| 6752781428 | Quit All Apps | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Bulk quit and safe app-closing utility | Only for Mac | TR Productivity Paid chart #4 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/quit-all-apps/id6752781428?mt=12) |
| 6756614788 | Scripta: UYAP Doküman Asistanı | TR | Productivity | Developer not parsed | Exact TR price/IAP pending | UNKNOWN | UYAP legal-document assistant | Apple page exposes Mac platform | Türkiye-specific legal workflow discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/scripta-uyap-dok%C3%BCman-asistan%C4%B1/id6756614788?platform=mac) |
| 1441958036 | SideNotes – Screen Edge Notes | TR | Productivity | Apptorium | Paid chart; exact TR price pending | PAID | Screen-edge notes and snippets | Only for Mac | TR Productivity Paid chart #14 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/sidenotes-screen-edge-notes/id1441958036?mt=12) |
| 6746357735 | TextClip | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Fast text capture utility | Only for Mac | TR Productivity Paid chart #12 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/textclip/id6746357735?mt=12) |
| 6761997773 | UDF Doküman Dönüştürücü | TR | Productivity | Developer not parsed | Exact TR price/IAP pending | UNKNOWN | UYAP UDF document conversion | Apple page exposes Mac platform | Türkiye-specific legal-document discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/udf-dok%C3%BCman-d%C3%B6n%C3%BC%C5%9Ft%C3%BCr%C3%BCc%C3%BC/id6761997773?platform=mac) |
| 6761714883 | UDF Dönüştürücü | TR | Productivity | Developer not parsed | Exact TR price/IAP pending | UNKNOWN | UYAP UDF file conversion | Apple page exposes Mac platform | Türkiye-specific UYAP workflow discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/udf-d%C3%B6n%C3%BC%C5%9Ft%C3%BCr%C3%BCc%C3%BC/id6761714883?platform=mac) |
| 6778448920 | UDF Studio | TR | Productivity | Eymex | Free | FREE | UYAP UDF editor, converter, signature verification and e-signature | Mac, iPad and iPhone | TR Productivity Free chart #23; not enough ratings | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/udf-studio/id6778448920?platform=mac) |
| 6770569447 | UDF dosya açma - UDF Editör | TR | Productivity | Developer not parsed | Exact TR price/IAP pending | UNKNOWN | UDF viewer and editor | Apple page exposes Mac platform | Türkiye-specific UYAP workflow discovery | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/udf-dosya-a%C3%A7ma-udf-edit%C3%B6r/id6770569447?platform=mac) |
| 6775472958 | WorkPlanner | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Work planning and productivity | Only for Mac | TR Productivity Paid chart #18 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/workplanner/id6775472958?mt=12) |
| 1238604516 | timeEdition - Time Tracking | TR | Productivity | Developer not parsed | Paid chart; exact TR price pending | PAID | Hours, projects and timesheet tracking | Only for Mac | TR Productivity Paid chart #17 | LOCAL-CHART-PROXY | [Apple App Store](https://apps.apple.com/tr/app/timeedition-time-tracking/id1238604516?mt=12) |
| 854063979 | Tureng | TR | Reference | Tureng | Exact TR price pending | UNKNOWN | Turkish-English dictionary and menu-bar lookup | Only for Mac | Türkiye storefront discovery; not enough ratings for overview | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/tureng/id854063979) |
| 6753361696 | Image to Text - Capture | TR | Utilities | Developer not parsed | One-time purchase; exact TR price pending | PAID/LIFE | Offline menu-bar OCR | Only for Mac | Listing states offline, no subscription and no tracking | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/image-to-text-capture/id6753361696?mt=12) |
| 1554515538 | TRex - Copy the Uncopyable | TR | Utilities | Developer not parsed | Exact TR price pending | UNKNOWN | OCR, table extraction, watch mode and local/LLM processing | Only for Mac | Türkiye storefront discovery; active 2026 feature updates | STOREFRONT-DISCOVERY | [Apple App Store](https://apps.apple.com/tr/app/trex-copy-the-uncopyable/id1554515538?mt=12) |

## Faz 3J ülke bazlı pazar sinyalleri

- **Türkiye:** UYAP/UDF formatı, e-imza ve hukuk dokümanı dönüşümü ayrı bir dikey pazar oluşturuyor. UDF Studio’nun yerel Productivity chart’a girmesi masaüstü hukuk araçlarında talep sinyali.
- **Türkiye:** Notch teleprompter, text capture, bookmark, floating timer ve multi-pane file manager gibi küçük native utilities peşin ücretli listede yer alıyor.
- **Almanya:** AusweisApp ve eduVPN gibi kamu/üniversite altyapısına bağlı istemciler güçlü yerel dağıtım oluşturuyor; FRITZ!Box çağrı takibi gibi cihaz-ekosistemi odaklı ücretli ürünler de görünür.
- **Almanya:** Clipboard, offline transcription, Safari search extension ve Markdown Quick Look gibi dar profesyonel araçlar ücretli chart’ta kalabiliyor.
- **Japonya:** Menü-bar uygulamaları, edge folders, Pomodoro, USB temizleme, QR ve TEPRA yazıcı araçları güçlü bir Mac-native mikro-utility kültürü gösteriyor.
- **Japonya:** Text editor, high-speed copy, Office/PDF-to-Markdown ve lossless media araçları peşin ücretli chart’a girebiliyor.
- **Doygunluk:** Utilita, Utilimate, Utilify ve Ytilities gibi benzer adlar genel all-in-one utility pazarının aşırı kalabalık olduğunu gösteriyor.

## Faz 3 durum değerlendirmesi

Faz 3A–3J ile niş sorgular, üç ek storefront, yerel chart’lar ve ilk A–Z/doygunluk örnekleri işlendi. `Bütün uygulamalar` hedefi için keşif tamamen kapanmış sayılmaz; kalan storefront’lar, geliştirici katalogları ve iki karakterli sorgu matrisi sonraki doygunluk döngülerinde devam edecektir.

## Sıradaki çalışma — Faz 4A

1. Mevcut chart satırlarına Apple `trackId` eşleme.
2. Exact TRY/USD/EUR/JPY fiyat ve IAP zenginleştirmesi.
3. Developer, rating count, son güncelleme ve minimum macOS.
4. Native/Catalyst/iPad-on-Mac dağıtım türü ayrımı.
5. Demand proxy score ve güven katsayısı.

**Sürüm:** 3J — 2 Ağustos 2026

# Faz 4A — 20 Kategorinin Ücretli Chart Liderleri

**Gözlem ve doğrulama tarihi:** 2 Ağustos 2026  
**Storefront:** United States; bir fiyat alanında doğrulanmış UK fallback  
**Kapsam:** Her mevcut Mac Top Charts kategorisinin 1 numaralı ücretli uygulaması  
**Zenginleştirilen Apple kimliği:** 20 / 20

> [!IMPORTANT]
> Faz 4A bir ürün-sayfası zenginleştirme pilotidir. `Rating` universal uygulamalarda tüm desteklenen Apple platformlarını birleştirebilir; Mac’e özel indirme veya MAU değildir. `Pending` alanlarına tahmin yazılmamıştır.

## Tamamlanma özeti

| Alan | Tamamlanan |
|---|---:|
| Apple `trackId` | 20 / 20 |
| Geliştirici | 20 / 20 |
| ABD kesin peşin fiyat | 19 / 20 |
| Bölgesel kesin fiyat fallback | 1 / 20 |
| Kullanılabilir rating/rating proxy | 13 / 20 |
| Kesin sürüm + güncelleme tarihi | 11 / 20 |
| Minimum macOS/hardware bilgisi | 9 / 20 |

## Fiyat görünümü

- 19 doğrulanmış ABD fiyatında medyan: **$7.99**.
- Ortalama: **$36.52**; Final Cut Pro ve Logic Pro ortalamayı belirgin biçimde yukarı çekiyor.
- Aralık: **$0.99–$299.99**.
- DICOM Quicklook için USD fiyat tahmini yapılmadı; doğrulanmış UK fiyatı £5.99 olarak tutuldu.

## Platform ve model görünümü

- Açıkça native/Only for Mac olarak sınıflanan: **13**.
- Universal/Catalyst veya çoklu Apple platformu: **7**.
- Abonelik ya da opsiyonel IAP katmanı bulunan: **3**.
- `PAID/LIFE`, doğrulanan mağaza kimliğinde kalıcı temel satın alma bulunduğunu gösterir; geliştiricinin ayrı yeni abonelik ürünü yayımlamadığını garanti etmez.

## Faz 4A envanteri

| Chart kategorisi | # | Uygulama | Track ID | Resmî kategori | Geliştirici | Fiyat | IAP | Model | Rating | Rating kapsamı | Sürüm / güncelleme | Minimum macOS / donanım | Dağıtım | Not | Güven | Kaynak |
|---|---:|---|---:|---|---|---:|---|---|---|---|---|---|---|---|:---:|---|
| Business | 1 | UTM Virtual Machines | 1538878817 | Developer Tools | Turing Software LLC | $9.99 | No IAP verified | PAID | US overview not parsed; GB 4.3/13 | Regional product-page proxy | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Chart category differs from official category; QEMU-based local virtualization. | B | [Apple App Store](https://apps.apple.com/us/app/utm-virtual-machines/id1538878817?mt=12) |
| Developer Tools | 1 | RegEx+ | 1511763524 | Developer Tools | 圣罡 汤 | $1.99 | No IAP shown | PAID | 4.0 / 4 | US universal product rating | 1.0 — 2026-04-14 | macOS 26.0+ | Universal iPhone/iPad/Mac | Low rating volume; unusually high current minimum OS. | A | [Apple App Store](https://apps.apple.com/us/app/regex/id1511763524) |
| Games | 1 | Palworld | 6503918400 | Adventure | Pocketpair, Inc. | $29.99 | No IAP shown | PAID | Exact US rating overview pending | Mac product | 1.0.5 — 2026-08-02 observation | macOS 14.0+; Apple M1+ | Native Mac / Apple silicon | 33.3 GB game; hardware floor materially narrows addressable Mac base. | A- | [Apple App Store](https://apps.apple.com/us/app/palworld/id6503918400?mt=12) |
| Graphics & Design | 1 | Pixelmator Pro | 1289583905 | Graphics & Design | Apple | $49.99 | No IAP shown | PAID/LIFE | 4.8 / ~18K | US Mac product rating | 3.7 — 2025-06-30 | Exact minimum macOS pending | Native Mac | Legacy perpetual ID. New Creator Studio/subscription listing uses a different Apple ID. | A | [Apple App Store](https://apps.apple.com/us/app/pixelmator-pro/id1289583905?mt=12) |
| Health & Fitness | 1 | Streaks | 963034692 | Health & Fitness | Crunchy Bagel | $5.99 | No current subscription required for base app | PAID/LIFE | 4.8 / ~27K | Universal product rating; not Mac-only | 11.3.7 — 2026-07-31 | macOS 14.6+ | Universal Apple-platform app | Large rating base, but rating total combines supported Apple platforms. | A | [Apple App Store](https://apps.apple.com/us/app/streaks/id963034692) |
| Productivity | 1 | Parchment: Agenda & Daily Note | 6779987526 | Productivity | Chris Lawley | $4.99 | No IAP shown | PAID/LIFE | 4.8 / 87 | Universal product rating | 1.0.4 — 2026-07-24 | macOS 26.0+ | Universal iPhone/iPad/Mac | Very recent product with strong early rating but limited rating volume. | A | [Apple App Store](https://apps.apple.com/us/app/parchment-agenda-daily-note/id6779987526) |
| Utilities | 1 | Shadowrocket | 932747118 | Utilities | Shadow Launch Technology Limited | $2.99 | No base IAP requirement shown | PAID | 4.5 / ~620 | US universal product rating | 2.2.90 — 2026-07-07 | Exact minimum macOS pending | Universal/Catalyst-style Mac distribution | Mac demand exists, but rating total is not Mac-specific. | B+ | [Apple App Store](https://apps.apple.com/us/app/shadowrocket/id932747118) |
| Weather | 1 | RadarScope | 288419283 | Weather | Base Velocity LLC | $9.99 | Tier subscriptions available | PAID+SUB | 4.2 / ~2.7K | Universal product rating | 5.5.6 — 2026-07-01 | macOS 13.5+ | Universal/Catalyst Mac app | Upfront purchase plus recurring professional radar tiers. | A | [Apple App Store](https://apps.apple.com/us/app/radarscope/id288419283) |
| Education | 1 | IPA Keyboard | 1461264628 | Education | Patrick Pedersen | $3.99 | No IAP shown | PAID/LIFE | Not enough ratings for overview | US Mac product | 2.2.1 — 2023-10-30 | macOS 10.11+ | Native Mac | Clear specialist niche; update recency is a maintenance-risk signal. | A | [Apple App Store](https://apps.apple.com/us/app/ipa-keyboard/id1461264628?mt=12) |
| Entertainment | 1 | Console Remote | 6738534883 | Entertainment | 莼乾 沈 | $7.99 | No IAP shown on parsed header | PAID | 4.2 / 10 | Universal product rating | 27.0.10 — 2026-07-03 | Exact Mac minimum pending | Universal iPhone/iPad/Mac | Fast update cadence; rating sample remains small. | A- | [Apple App Store](https://apps.apple.com/us/app/console-remote/id6738534883) |
| Finance | 1 | Money Pro: Personal Finance | 972572731 | Finance | iBear LLC | $0.99 | Subscriptions/IAP available | PAID+SUB | 3.9 / ~231 | US Mac product rating | Exact current version/date pending | Exact minimum macOS pending | Native Mac | Low entry price with recurring sync/service upsell; reviews show subscription-friction risk. | B+ | [Apple App Store](https://apps.apple.com/us/app/money-pro-personal-finance/id972572731?mt=12) |
| Lifestyle | 1 | Paprika Recipe Manager 3 | 1303222628 | Lifestyle | Hindsight Labs LLC | $29.99 | Mac version sold separately; no base subscription | PAID/LIFE | Not enough ratings for overview | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Offline local data; separate purchases per platform. Editors’ Choice signal. | A- | [Apple App Store](https://apps.apple.com/us/app/paprika-recipe-manager-3/id1303222628?mt=12) |
| Medical | 1 | DICOM Quicklook by OsiriX | 1440819115 | Medical | Pixmeo SARL | US exact pending; UK £5.99 | No IAP shown | PAID | 4.0 / 4 in US reviews | US rating; UK price | 1.5 — 2025-02-22 | macOS 15+ | Native Mac / Apple silicon build | No USD conversion invented; medical-image viewer states no data collected. | A- | [Apple App Store](https://apps.apple.com/us/app/dicom-quicklook-by-osirix/id1440819115?mt=12) |
| Music | 1 | Logic Pro | 634148309 | Music | Apple | $199.99 | No IAP shown for legacy product | PAID/LIFE | Not enough ratings for overview | US Mac product | Current exact version/date pending | Exact macOS version pending; 6 GB minimum install storage | Native Mac | Legacy perpetual ID; newer subscription/Creator Studio products must remain separate. | A- | [Apple App Store](https://apps.apple.com/us/app/logic-pro/id634148309?mt=12) |
| News | 1 | GoodLinks | 1474335294 | News | Ngoc Luu | $9.99 | Annual Feature Upgrade $4.99 + tips | PAID+OPTIONAL-IAP | 4.7 / 630 | Universal product rating | 3.3.4 — 2026-06-22 | macOS 13.0+ | Universal iPhone/iPad/Mac | No account; iCloud sync. Optional annual feature-upgrade model rather than mandatory subscription. | A | [Apple App Store](https://apps.apple.com/us/app/goodlinks/id1474335294) |
| Photo & Video | 1 | Final Cut Pro | 424389933 | Photo & Video | Apple | $299.99 | No IAP shown for legacy product | PAID/LIFE | Exact current overview pending | US Mac product | Current exact version/date pending | macOS 15.6+; 8 GB RAM; 7.2 GB disk | Native Mac | Highest base price in pilot. Legacy perpetual product must be separated from newer bundled/subscription offerings. | A- | [Apple App Store](https://apps.apple.com/us/app/final-cut-pro/id424389933?mt=12) |
| Reference | 1 | e-Sword X: Bible Study Extreme | 968437868 | Reference | Rick Meyers | $9.99 | Optional downloadable resources; exact IAP status pending | PAID | 4.5 / ~883 | US Mac product rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Offline core library and strong specialist one-time pricing. | A- | [Apple App Store](https://apps.apple.com/us/app/e-sword-x-bible-study-extreme/id968437868?mt=12) |
| Social Networking | 1 | Unite - GroupMe app | 1152517150 | Social Networking | Furnace Creek Software LLC | $7.99 | No IAP shown | PAID | 4.6 / ~995 | US Mac product rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Paid native wrapper/client can retain demand where official desktop experience is weak. | A- | [Apple App Store](https://apps.apple.com/us/app/unite-groupme-app/id1152517150?mt=12) |
| Sports | 1 | Tournament Bracket Generator | 1380547373 | Sports | IWT SOFTWARE LABS LLC | $2.99 | No IAP shown | PAID/LIFE | Not enough ratings for overview | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Single-elimination-only utility; narrow scope yet chart leadership. | B+ | [Apple App Store](https://apps.apple.com/us/app/tournament-bracket-generator/id1380547373?mt=12) |
| Travel | 1 | Road Trip Planner | 805071244 | Travel | Kyle Modesitt | $3.99 | No subscription; Lite demo exists | PAID/LIFE | Exact rating overview pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac | Explicit no-subscription positioning and a separate Lite acquisition funnel. | A- | [Apple App Store](https://apps.apple.com/us/app/road-trip-planner/id805071244?mt=12) |

## Kritik kimlik ayrımları

### Legacy kalıcı lisans ile yeni abonelik ürününü karıştırma

- **Pixelmator Pro — `1289583905`:** Chart’taki $49.99 kalıcı Mac ürünü. Apple Creator Studio içindeki yeni sürüm ayrı Apple kimliğiyle değerlendirilmelidir.
- **Logic Pro — `634148309`:** Chart’taki $199.99 kalıcı Mac ürünü. Yeni paket veya abonelik sürümlerinin indirme/rating/fiyat verisi bu kimlikle birleştirilmemelidir.
- **Final Cut Pro — `424389933`:** Chart’taki $299.99 kalıcı ürün. Bundle/Creator Studio varyantları ayrı SKU ve ayrı pazar kaydıdır.

### Chart kategorisi ile resmî ürün kategorisi

- UTM, Business chart’ında lider görünürken ürün sayfasının resmî kategorisi Developer Tools’dur.
- Palworld chart katmanında Games olarak tutulur; ürün sayfasında Adventure alt kategorisi görünür.
- Analiz ve fırsat skorunda iki alan da korunmalıdır; aksi hâlde kategori payı yanlış hesaplanır.

## Faz 4A pazar sinyalleri

- **Medyan $7.99:** Mac ücretli chart liderliğinde küçük, tek amaçlı native araçların hâlâ kalıcı lisansla satılabildiğini gösteriyor.
- **Yüksek fiyat gücü uzmanlıkta:** Final Cut Pro, Logic Pro ve Pixelmator Pro profesyonel üretim iş akışlarında $49.99–$299.99 aralığını koruyor.
- **Upfront + recurring hibrit:** RadarScope ve Money Pro gibi ürünler düşük/orta peşin fiyatı profesyonel veri veya sync aboneliğiyle tamamlıyor.
- **Dar niş chart liderliği:** IPA Keyboard ve Tournament Bracket Generator düşük rating hacmiyle lider olabiliyor; bazı kategorilerde rekabet yoğunluğu genel Productivity/Utilities’den çok daha düşük.
- **Bakım riski:** IPA Keyboard gibi 2023’ten beri güncellenmeyen bir ücretli lider, modern ve aktif geliştirilen alternatif için fırsat sinyali olabilir.
- **Universal rating yanılgısı:** Streaks, RadarScope ve GoodLinks rating hacmi güçlü olsa da toplamın Mac payı bilinmiyor.
- **Perpetual-license talebi:** Paprika, Road Trip Planner, e-Sword X ve profesyonel Apple uygulamaları aboneliksiz satın alma mesajıyla ücretli chart’ta kalıyor.

## Veri güven kodu

| Kod | Anlam |
|---|---|
| A | Apple ürün sayfasında kimlik, fiyat, geliştirici ve ana teknik alanlar doğrulandı |
| A- | Çekirdek metadata doğrulandı; bir veya iki ikincil alan pending |
| B+ | Kimlik/fiyat doğrulandı; rating, sürüm ya da platform türünde kısmi belirsizlik var |
| B | Çekirdek kimlik doğrulandı; birden fazla zenginleştirme alanı bekliyor |

## Faz 4B kuyruğu

1. 20 kategorinin ücretsiz chart liderleri.
2. Ücretli liderlerde eksik sürüm, minimum macOS ve US rating alanlarının tamamlanması.
3. TRY/EUR/JPY fiyat karşılaştırması ve satın alma gücü normalize edilmiş fiyat.
4. IAP/subscription tier’larının ürün başına tam dökümü.
5. İlk 5 ücretli uygulamaya genişletme ve kategori içi fiyat dağılımı.

**Sürüm:** 4A — 2 Ağustos 2026

# Faz 4B — 20 Kategorinin Ücretsiz Chart Liderleri

**Gözlem ve doğrulama tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kapsam:** Her mevcut Mac Top Charts kategorisinin 1 numaralı ücretsiz uygulaması  
**Zenginleştirilen Apple kimliği:** 20 / 20

> [!IMPORTANT]
> `Free chart`, uygulamanın ücretsiz kullanılabildiği anlamına gelmez. Bu tabloda free download, gerçek ücretsiz kullanım, hizmet hesabı, trial, subscription ve IAP ayrı alanlarda gösterilmiştir.

## Tamamlanma özeti

| Alan | Tamamlanan |
|---|---:|
| Apple `trackId` | 20 / 20 |
| Geliştirici | 20 / 20 |
| Free-download ve gelir modeli | 20 / 20 |
| Kullanılabilir rating/rating proxy | 11 / 20 |
| Kesin veya güçlü sürüm/güncelleme sinyali | 2 / 20 |
| Minimum macOS bilgisi | 5 / 20 |

## Ücretsiz etiketinin gerçek anlamı

- Ücretli katman, subscription, trial veya IAP taşıyan lider: **11 / 20**.
- Ücretsiz/hizmet tabanlı çekirdeği bulunan lider: **5 / 20**.
- App Store `Free` sırası edinim hacmini gösterir; abonelik geliri, finansal hizmet geliri veya dış hizmet üyeliğini göstermez.

## Dağıtım türü

- Açıkça native/Only for Mac: **11**.
- Universal veya çoklu Apple-platform ürünü: **9**.
- Universal uygulamaların rating toplamı Mac talebini tek başına temsil etmez.

## Faz 4B envanteri

| Chart kategorisi | # | Uygulama | Track ID | Resmî kategori | Geliştirici | İndirme fiyatı | IAP / gelir katmanı | Model | Rating | Rating kapsamı | Sürüm / güncelleme | Minimum macOS | Dağıtım | Offline / bağımlılık | Not | Güven | Kaynak |
|---|---:|---|---:|---|---|---|---|---|---|---|---|---|---|---|---|:---:|---|
| Business | 1 | Open Link for Chrome & Firefox | 1530712347 | Business | Cristian Gav | Free download | 3-day annual trial; subscription + lifetime license | FREEMIUM/HYBRID | 3.9 / 8.6K | US Mac rating | Current version number/date pending; 2026 Tahoe redesign indexed | Exact minimum macOS pending | Native Mac / Only for Mac | Local browser selection; license validation connected | The listing explicitly says the app is not free to use despite its free-download chart status. | A- | [Apple App Store](https://apps.apple.com/us/app/open-link-for-chrome-firefox/id1530712347) |
| Developer Tools | 1 | Xcode | 497799835 | Developer Tools | Apple | Free | No IAP | FREE | Rating count pending | US Mac product | Current exact App Store version/date pending | Current exact minimum macOS pending | Native Mac / Only for Mac | Core IDE works locally; downloads, signing and distribution use Apple services | Genuinely free acquisition; monetizes indirectly through Apple’s developer ecosystem. | A- | [Apple App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12) |
| Games | 1 | Steam Link | 1246969117 | Entertainment | Valve Corporation | Free | No IAP shown | FREE/SERVICE | Rating count pending | Universal product; Mac-specific count unavailable | Current exact version/date pending | macOS 10.13+ | Universal Apple-platform app | Requires a computer running Steam and usually the same local network | Free companion client; value is tied to the user’s Steam library and host computer. | A- | [Apple App Store](https://apps.apple.com/us/app/steam-link/id1246969117?platform=mac) |
| Graphics & Design | 1 | Pixelmator Pro: Edit Images | 6746662575 | Graphics & Design | Apple | Free download | Apple Creator Studio subscription; 30-day trial | FREE+SUB | 4.7 / 1.1K | US Mac rating | Current exact version/date pending | Current exact minimum macOS pending | Mac and iPad product / Creator Studio edition | Editing local; subscription/account and some intelligence features depend on Apple services | Separate from the $49.99 perpetual Mac ID 1289583905. Never merge ratings or revenue. | A | [Apple App Store](https://apps.apple.com/us/app/pixelmator-pro-edit-images/id6746662575?platform=mac) |
| Health & Fitness | 1 | Portal - Escape Into Nature | 1436994560 | Health & Fitness | Portal Labs Ltd | Free download | Premium subscription/IAP; exact current tiers pending | FREEMIUM/SUB | 4.8 / 2.5K | US Mac rating | Active July 2026 editorial/event updates; exact version pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Downloaded scenes may work locally; catalogue/account features connected | Editors’ Choice. Mac rating is smaller than the 10K all-platform rating shown on the generic page. | A | [Apple App Store](https://apps.apple.com/us/app/portal-escape-into-nature/id1436994560?platform=mac) |
| Productivity | 1 | Microsoft Word | 462054704 | Productivity | Microsoft Corporation | Free download | Qualifying Microsoft 365 subscription required for full experience | FREE+SUB/SERVICE | Mac rating count pending | US Mac product | Current exact version/date pending | Current exact minimum macOS pending | Native Mac / Only for Mac | Local document work plus Microsoft 365 account, licensing, OneDrive and collaboration | Free-download rank measures acquisition, not free usage; the listing explicitly requires a qualifying subscription. | A- | [Apple App Store](https://apps.apple.com/us/app/microsoft-word/id462054704?mt=12) |
| Utilities | 1 | NordVPN: VPN Fast & Secure | 905953485 | Utilities | Nordvpn S.A. | Free download | Paid VPN subscription/IAP | FREE+SUB/SERVICE | 4.7 / 10K | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac/Apple TV | NordVPN account, subscription and network service required | Generic page shows roughly 692K ratings across platforms; Mac page shows about 10K. | A | [Apple App Store](https://apps.apple.com/us/app/nordvpn-vpn-fast-secure/id905953485?platform=mac) |
| Weather | 1 | Weather Dock: Desktop forecast | 886290397 | Weather | Voros Innovation | Free download | IAP; exact premium tiers pending | FREEMIUM | 4.5 / 7.6K | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Weather data requires internet; UI and preferences local | Strong rating volume for a narrow desktop/menu-bar utility; IAP conversion remains unknown. | A- | [Apple App Store](https://apps.apple.com/us/app/weather-dock-desktop-forecast/id886290397?mt=12) |
| Education | 1 | AI Chatbot・Ask AI Anything | 6753711999 | Education | Hira Amin | Free download | $5.99 weekly; $14.99 monthly; $99.99 lifetime | FREEMIUM/HYBRID | Not enough ratings for overview | US Mac product | 2.0 — 2026-07-27 approximately (listed as 6 days before observation) | macOS 12.0+ | Native Mac / Only for Mac | OpenAI API and web-search functions require internet | Chart title included a model/version suffix; current Apple page title changed. Track ID is authoritative. | A | [Apple App Store](https://apps.apple.com/us/app/ai-chatbot-ask-ai-anything/id6753711999?mt=12) |
| Entertainment | 1 | Amazon Prime Video | 545519333 | Entertainment | AMZN Mobile LLC | Free download | Prime service; rentals, purchases and channels/IAP | FREE/SERVICE+IAP | 4.8 / ~3M | All-platform US product rating; not Mac-only | Current exact version/date pending | macOS 11.4+ | Universal iPhone/iPad/Mac/Apple TV | Streaming/account required; selected titles support offline download | The rating total reflects the whole Apple-platform product, making it unsuitable as Mac demand alone. | A | [Apple App Store](https://apps.apple.com/us/app/amazon-prime-video/id545519333) |
| Finance | 1 | Webull: Advanced Trading | 1334590352 | Finance | Webull Technologies Pte. Ltd. | Free | Brokerage/service monetization; no app subscription required for core trading | FREE/FINANCIAL-SERVICE | 3.1 / 265 | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac App Store product | Brokerage account, identity verification and market connectivity required | A free client can lead the chart while revenue comes from brokerage activity rather than App Store billing. | A- | [Apple App Store](https://apps.apple.com/us/app/webull-advanced-trading/id1334590352?mt=12) |
| Lifestyle | 1 | Save to Pinterest | 6473649042 | Lifestyle | Pinterest, Inc. | Free | No direct IAP shown; Pinterest account/service required | FREE/SERVICE | 2.7 / 118 | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac Safari extension | Internet and Pinterest account required | Low rating and recurring extension complaints despite chart leadership indicate weak category competition. | A- | [Apple App Store](https://apps.apple.com/us/app/save-to-pinterest/id6473649042?mt=12) |
| Medical | 1 | Complete Anatomy | 1141323850 | Medical | 3D4Medical from Elsevier | Free download | 3-day premium trial + annual subscription | FREE-TRIAL/SUB | Rating count pending | US Mac product | Current exact version/date pending | Works best on macOS 11.0+; exact hard minimum pending | Native Mac / Only for Mac | Account and subscription required for premium content; downloaded assets local | High-value professional education product uses a short trial rather than a meaningful free tier. | A- | [Apple App Store](https://apps.apple.com/us/app/complete-anatomy/id1141323850?mt=12) |
| Music | 1 | VinylPod - Music Widget | 6443989711 | Music | 裕涛 兰 | Free download | IAP; exact tiers pending | FREEMIUM | 4.6 / 14K | US Mac rating | 1.6.11 — 2025-11-19 | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Reads playback from Apple Music, Spotify and other media services | Mac rating volume is notably high for a decorative now-playing/widget utility. | A | [Apple App Store](https://apps.apple.com/us/app/vinylpod-music-widget/id6443989711?platform=mac) |
| News | 1 | Ground News | 1324203419 | News | Ground News | Free download | Premium subscription/service; exact tiers pending | FREEMIUM/SUB | Rating count pending | Mac product page; exact count not parsed | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | News aggregation and bias data require internet | Product-scale claim: 50K sources and 60K articles/day; these are not users or downloads. | B+ | [Apple App Store](https://apps.apple.com/us/app/ground-news/id1324203419?platform=mac) |
| Photo & Video | 1 | CapCut: Photo & Video Editor | 1500855883 | Photo & Video | Bytedance Pte. Ltd | Free download | IAP/subscription and paid assets/features | FREEMIUM/SUB | 4.8 / 26K | US Mac rating | Current exact version/date pending | macOS 10.14+ | Universal iPhone/iPad/Mac | Core editing local; accounts, cloud, templates and AI services can require network | Generic product rating is about 1.1M, while the Mac page is about 26K; platform segmentation matters. | A | [Apple App Store](https://apps.apple.com/us/app/capcut-photo-video-editor/id1500855883?platform=mac) |
| Reference | 1 | Bible Study | 472790630 | Reference | Gospel Technologies LLC | Free download | Paid Bible translations/resources; several $9.99 examples | FREEMIUM/IAP | Rating count pending | US Mac product | Current exact version/date pending | macOS 14.0+ | Native Mac / Only for Mac | Core library can be local; store/download/sync features connected | A free core product monetizes through licensed content rather than a mandatory subscription. | A | [Apple App Store](https://apps.apple.com/us/app/bible-study/id472790630?mt=12) |
| Social Networking | 1 | WhatsApp Messenger | 310633997 | Social Networking | WhatsApp Inc. | Free | No subscription fees for consumer messaging; IAP label exists on listing | FREE/SERVICE | 4.7 / ~123K | Mac platform rating observed in localized US page; generic product has ~18M | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac/Apple Watch | Account/phone identity and network service required; local message cache | Developer states over 2B users across 180+ countries; this is all-platform usage, not Mac installs. | A | [Apple App Store](https://apps.apple.com/us/app/whatsapp-messenger/id310633997?platform=mac) |
| Sports | 1 | TwiTracker : Stream Tracker | 6766197443 | Sports | Muhammad Ahmad Owais | Free download | IAP; exact tiers pending | FREEMIUM | Not enough ratings for overview | US Mac product | Initial listing/update observed 2026-07-07; exact current version pending | Exact minimum macOS pending | Native Mac / Only for Mac | Streaming-channel analytics require network/API access | A newly released, low-rating-volume product can lead a very thin paid/free Mac Sports category. | A- | [Apple App Store](https://apps.apple.com/us/app/twitracker-stream-tracker/id6766197443?mt=12) |
| Travel | 1 | App For Google Maps | 6780524604 | Travel | T & A Artisan LLC | Free download | IAP; exact tiers pending | FREEMIUM | Not enough ratings for overview | US Mac product | Initial listing observed 2026-07-16; exact current version pending | Exact minimum macOS pending | Native Mac / Only for Mac | Google map/navigation data and live traffic require network | Chart title matches this ID; multiple near-identical Google Maps wrappers exist, so ID-level dedupe is essential. | A- | [Apple App Store](https://apps.apple.com/us/app/app-for-google-maps/id6780524604?mt=12) |

## Kimlik ve başlık değişikliği riskleri

- **Pixelmator Pro:** Free Creator Studio ürünü `6746662575`; $49.99 kalıcı Mac ürünü `1289583905`. Ayrı SKU, rating ve gelir kayıtlarıdır.
- **AI Chatbot:** Chart başlığındaki model/version eki değişmiştir. Geçerli kayıt `6753711999`; ürün sayfasındaki başlık ve model pazarlaması güncellemelerle değişebilir.
- **Google Maps wrappers:** Birbirine çok benzeyen birçok uygulama vardır. Travel lideri için `6780524604` kullanıldı; isimle tekilleştirme güvenli değildir.
- **Steam Link:** Resmî kategori Entertainment iken Games chart’ında lider görünür. Chart ve resmî kategori ayrı tutulmalıdır.

## Faz 4B pazar sinyalleri

- **Free chart ≠ free product:** Open Link, Word, NordVPN, Complete Anatomy ve AI Chatbot ücretsiz indirilse de temel gelir mekanizması subscription, trial veya lifetime unlock’tır.
- **Hizmet ekonomisi:** Webull, WhatsApp, Prime Video ve Save to Pinterest’te App Store ödemesi ürün ekonomisinin yalnızca küçük bir kısmı veya hiçbiri değildir.
- **Platform rating farkı:** NordVPN yaklaşık 10K Mac rating’ine karşı generic sayfada yüz binlerce; CapCut yaklaşık 26K Mac rating’ine karşı generic sayfada 1.1M rating taşır.
- **Dar kategori zayıflığı:** TwiTracker ve App For Google Maps gibi yeni, rating özeti oluşmamış ürünlerin lider olabilmesi Sports ve Travel chart’larında rekabetin dönemsel olarak ince olduğunu gösteriyor.
- **Local-first küçük araç fırsatı:** Weather Dock ve VinylPod gibi sınırlı işlevli, masaüstüne özgü ürünler binlerce Mac rating’i toplayabiliyor.
- **Content-IAP modeli:** Bible Study zorunlu abonelik yerine lisanslı çeviri ve kaynakları ayrı IAP olarak satıyor.
- **Yüksek frekanslı subscription riski:** AI Chatbot’ta haftalık $5.99 ve aylık $14.99 yanında $99.99 lifetime bulunması, AI wrapper pazarındaki yüksek fiyat baskısını gösteriyor.
- **Gerçek ücretsiz savunma:** Xcode ve Steam Link doğrudan ücret katmanı olmadan daha büyük ekosistemlerin kullanımını artıran companion/platform ürünleridir.

## Rating kanıtının yorumlanması

| Örnek | Mac rating | Generic/all-platform rating | Yorum |
|---|---:|---:|---|
| Portal | ~2.5K | ~10K | Mac talebi anlamlı fakat toplamın yalnızca bir bölümü |
| NordVPN | ~10K | ~692K | Generic rating’i Mac kullanıcı sayısı gibi kullanmak büyük hata |
| CapCut | ~26K | ~1.1M | Mac ürünü güçlü ancak mobil ağırlık çok daha büyük |
| WhatsApp | ~123K görülen Mac sayfası | ~18M | 2B kullanıcı açıklaması tüm platformları kapsar |

## Faz 4C kuyruğu

1. Ücretli ve ücretsiz liderlerde eksik sürüm, minimum macOS ve rating alanlarını tamamlama.
2. 40 lider için TRY/USD/EUR/JPY fiyat ve subscription tier karşılaştırması.
3. Her kategorinin ilk 5 ücretsiz ve ilk 5 ücretli uygulamasına genişletme.
4. Rating velocity, güncelleme recency ve chart rank tabanlı demand proxy score.
5. Native/Catalyst/iPad-on-Mac ayrımının kesinleştirilmesi.

**Sürüm:** 4B — 2 Ağustos 2026

# Faz 4C — Beş Büyük Kategoride İlk 5 Free + İlk 5 Paid

**Gözlem ve doğrulama tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kategoriler:** Business, Developer Tools, Productivity, Utilities, Graphics & Design  
**Chart pozisyonu:** 50  
**Faz 4A/4B liderleri dışında net yeni zenginleştirilen pozisyon:** 40

> [!IMPORTANT]
> Bu bölüm yeni uygulama envanteri eklemekten çok mevcut chart satırlarını ürün sayfası metadata’sıyla zenginleştirir. Microsoft 365 bir `APP_BUNDLE` olduğu için normal track ID ile aynı nesne türünde değerlendirilmemelidir.

## Kapsam özeti

| Ölçü | Sonuç |
|---|---:|
| Tamamlanan kategori | 5 / 20 |
| Free chart pozisyonu | 25 |
| Paid chart pozisyonu | 25 |
| Toplam pozisyon | 50 |
| Net yeni pozisyon profili | 40 |
| Normal uygulama kaydı | 49 |
| App bundle | 1 |
| Kesin USD peşin fiyatı bulunan kayıt | 16 |
| Kullanılabilir rating sinyali | 15 / 50 |
| Kesin/güçlü sürüm-güncelleme sinyali | 10 / 50 |
| Minimum macOS veya donanım sinyali | 13 / 50 |

## Kategori tamamlanma matrisi

| Kategori | Free Top 5 | Paid Top 5 | Toplam |
|---|---:|---:|---:|
| Business | 5 | 5 | 10 |
| Developer Tools | 5 | 5 | 10 |
| Productivity | 5 | 5 | 10 |
| Utilities | 5 | 5 | 10 |
| Graphics & Design | 5 | 5 | 10 |

## Doğrulanmış peşin USD fiyatları

- Doğrulanmış kesin fiyat sayısı: **16**.
- Medyan: **$9.99**.
- Aralık: **$1.99–$49.99**.
- Fiyatı Apple sayfasında güvenilir biçimde ayrıştırılamayan paid-chart ürünlerine tarihsel veya üçüncü taraf fiyat yazılmadı.

## Faz 4C ayrıntılı envanter

| Chart kategorisi | Liste | # | Uygulama | Nesne | Apple ID | Resmî kategori | Geliştirici | Fiyat | Gelir katmanı | Model | Rating | Rating kapsamı | Sürüm / güncelleme | Minimum macOS | Dağıtım | Offline / bağımlılık | Not | Güven | Kaynak |
|---|---|---:|---|---|---:|---|---|---|---|---|---|---|---|---|---|---|---|:---:|---|
| Business | Free | 1 | Open Link for Chrome & Firefox | APP | 1530712347 | Business | Cristian Gav | Free download | 3-day annual trial; subscription + lifetime license | FREEMIUM/HYBRID | 3.9 / 8.6K | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local browser selection; licensing connected | Free chart status does not mean free use; listing explicitly requires a paid license after trial. | A- | [Apple App Store](https://apps.apple.com/us/app/open-link-for-chrome-firefox/id1530712347) |
| Business | Free | 2 | Windows App | APP | 1295203466 | Business | Microsoft Corporation | Free | Windows 365, Azure Virtual Desktop, Dev Box or configured RDP endpoint | FREE/SERVICE | Rating count pending | US Mac product | Current exact version/date pending | Current release support note excludes older macOS versions | Native Mac / Only for Mac | Remote Microsoft or RDP service required | Success depends on enterprise/cloud endpoints rather than App Store billing. | A- | [Apple App Store](https://apps.apple.com/us/app/windows-app/id1295203466?mt=12) |
| Business | Free | 3 | Slack for Desktop | APP | 803453959 | Business | Slack Technologies, Inc. | Free download | Slack workspace service; paid team plans outside base download | FREE/SERVICE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Internet and Slack workspace required | App Store acquisition is free; revenue is primarily workspace subscription/service based. | A- | [Apple App Store](https://apps.apple.com/us/app/slack-for-desktop/id803453959?mt=12) |
| Business | Free | 4 | PDFgear: PDF Editor & Reader | APP | 6469021132 | Business | PDFgear Tech Ltd. | Free | No mandatory IAP verified in current listing | FREE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Core PDF editing local; online/AI tools may connect | A genuinely free full-feature PDF editor creates severe price pressure on simple PDF utilities. | A- | [Apple App Store](https://apps.apple.com/us/app/pdfgear-pdf-editor-reader/id6469021132?mt=12) |
| Business | Free | 5 | Okta Verify | APP | 490179405 | Business | Okta, Inc. | Free | Enterprise identity service required | FREE/SERVICE | Not enough ratings for overview | US Apple-platform product | Active 2026 release notes; exact version pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Okta organization/account and network required | Distribution follows enterprise identity adoption rather than consumer App Store monetization. | A- | [Apple App Store](https://apps.apple.com/us/app/okta-verify/id490179405) |
| Business | Paid | 1 | UTM Virtual Machines | APP | 1538878817 | Developer Tools | Turing Software LLC | $9.99 | No IAP verified | PAID | US overview pending; regional 4.3 / 13 proxy | Regional product-page proxy | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | VMs local; OS downloads/network optional | Business-chart placement differs from official Developer Tools category. | B | [Apple App Store](https://apps.apple.com/us/app/utm-virtual-machines/id1538878817?mt=12) |
| Business | Paid | 2 | Jump Desktop (RDP, VNC, Fluid) | APP | 524141863 | Business | Phase Five Systems | $34.99 | No mandatory subscription verified for base Mac app | PAID/LIFE | Rating count pending | US Mac product | Active updates; exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Remote endpoint/network required | Professional protocol breadth supports a substantially higher one-time price than simple VNC clients. | A- | [Apple App Store](https://apps.apple.com/us/app/jump-desktop-rdp-vnc-fluid/id524141863?mt=12) |
| Business | Paid | 3 | Sync Folders Pro | APP | 522706442 | Business | VADIM ZYBIN | $8.99 | IAP shown; exact items pending | PAID+IAP | 4.6 / 37 | US universal product rating | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Local, external and network folders | Low rating volume but paid chart visibility indicates a durable specialist file-sync niche. | A- | [Apple App Store](https://apps.apple.com/us/app/sync-folders-pro/id522706442) |
| Business | Paid | 4 | Antivirus Zap - Virus Scanner | APP | 1212019923 | Business | Voros Innovation | $9.99 | No IAP verified in parsed header | PAID | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local file scan; signature/update services may connect | Security positioning enables a one-time price despite strong free/system alternatives. | A- | [Apple App Store](https://apps.apple.com/us/app/antivirus-zap-virus-scanner/id1212019923?mt=12) |
| Business | Paid | 5 | Virtual Teleprompter Pro | APP | 1591588588 | Business | matthew sheedy | $6.99 | No IAP shown | PAID/LIFE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local overlay/teleprompter workflow | A narrow presentation utility can hold paid-chart visibility at a sub-$10 lifetime price. | A- | [Apple App Store](https://apps.apple.com/us/app/virtual-teleprompter-pro/id1591588588?mt=12) |
| Developer Tools | Free | 1 | Xcode | APP | 497799835 | Developer Tools | Apple | Free | No IAP | FREE | Rating count pending | US Mac product | Current exact version/date pending | macOS 26.2+; Apple M1+ in current listing | Native Mac / Only for Mac | Core IDE local; SDKs, signing and distribution connected | High minimum OS/hardware sharply differs from older-compatible developer utilities. | A | [Apple App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12) |
| Developer Tools | Free | 2 | TestFlight | APP | 899247664 | Developer Tools | Apple | Free | No IAP | FREE/SERVICE | 4.8 / ~14K | Mac-filtered US rating; generic page ~787K | Current exact version/date pending | Exact minimum macOS pending | Universal Apple-platform app | Apple beta-distribution service required | Platform-filtered rating is essential; generic rating overstates Mac evidence by orders of magnitude. | A | [Apple App Store](https://apps.apple.com/us/app/testflight/id899247664?platform=mac) |
| Developer Tools | Free | 3 | Apple Developer | APP | 640199958 | Developer Tools | Apple | Free download | Developer Program $98.99; Xcode Cloud/WeatherKit tiers | FREE/SERVICE+IAP | 2.9 / 528 | US universal product rating | Current exact version/date pending | macOS 15.0+ | Universal iPhone/iPad/Mac/Apple TV | Apple developer account and services required | IAP represents ecosystem memberships and cloud capacity, not conventional consumer upgrades. | A | [Apple App Store](https://apps.apple.com/us/app/apple-developer/id640199958) |
| Developer Tools | Free | 4 | Transporter | APP | 1450874784 | Developer Tools | Apple | Free | No IAP | FREE/SERVICE | Rating count pending | US Mac product | Apple-silicon support noted; exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | App Store Connect account/service required | A free publishing utility whose demand is derived from paid-content distribution workflows. | A- | [Apple App Store](https://apps.apple.com/us/app/transporter/id1450874784?mt=12) |
| Developer Tools | Free | 5 | Termius: SSH Client & Terminal | APP | 1176074088 | Developer Tools | Termius Corporation | Free download | Premium subscription/IAP | FREEMIUM/SUB | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | SSH/Mosh/Telnet/SFTP endpoints and account sync | Free terminal entry point monetizes sync, teams and advanced connection workflows. | A- | [Apple App Store](https://apps.apple.com/us/app/termius-ssh-client-terminal/id1176074088?mt=12) |
| Developer Tools | Paid | 1 | RegEx+ | APP | 1511763524 | Developer Tools | 圣罡 汤 | $1.99 | No IAP shown | PAID/LIFE | 4.0 / 4 | US universal rating | 1.0 — 2026-04-14 | macOS 26.0+ | Universal iPhone/iPad/Mac | Offline regex workflow | Very low price and rating volume; current OS floor is unusually high. | A | [Apple App Store](https://apps.apple.com/us/app/regex/id1511763524) |
| Developer Tools | Paid | 2 | Monodraw | APP | 920404675 | Developer Tools | Helftone | $9.99 | No IAP shown | PAID/LIFE | Not enough ratings for overview | US Mac product | Current exact version/date pending | macOS 11.0+ | Native Mac / Only for Mac | Offline ASCII diagram editing | A focused developer-documentation tool sustains a $9.99 permanent price. | A | [Apple App Store](https://apps.apple.com/us/app/monodraw/id920404675?mt=12) |
| Developer Tools | Paid | 3 | TerminalWidget | APP | 6764288419 | Developer Tools | Brett Terpstra | $19.99 | No IAP shown | PAID/LIFE | Not enough ratings for overview | US universal product | 2.0.3 — 2026-08-02 observation | macOS 14.0+ | Universal iPhone/iPad/Mac | Local terminal/widget workflow | A recently updated niche developer utility can command $19.99 without a subscription. | A | [Apple App Store](https://apps.apple.com/us/app/terminalwidget/id6764288419) |
| Developer Tools | Paid | 4 | Virtual Location | APP | 1459663647 | Developer Tools | 业坤 张 | $5.99 | IAP shown | PAID+IAP | 4.0 / 128 | US Mac rating | 3.34 — 2025-12-24 | Exact minimum macOS pending | Native Mac / Only for Mac | Developer/debugging workflow; device/location interfaces | Localized pages may show stale $4.99; current English page shows $5.99. | A | [Apple App Store](https://apps.apple.com/us/app/virtual-location/id1459663647?mt=12) |
| Developer Tools | Paid | 5 | App Explorer: Homebrew Catalog | APP | 6745115168 | Developer Tools | Harshad Jadav | Paid chart; exact USD pending | No IAP details parsed | PAID | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Homebrew catalogue data may require internet | Exact price was not exposed reliably; no estimate was inserted. | B+ | [Apple App Store](https://apps.apple.com/us/app/app-explorer-homebrew-catalog/id6745115168?mt=12) |
| Productivity | Free | 1 | Microsoft Word | APP | 462054704 | Productivity | Microsoft Corporation | Free download | Qualifying Microsoft 365 subscription for full experience | FREE+SUB/SERVICE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local documents plus account, licensing, OneDrive and collaboration | Mac-specific ID differs from Microsoft’s mobile/universal Word listing. | A- | [Apple App Store](https://apps.apple.com/us/app/microsoft-word/id462054704?mt=12) |
| Productivity | Free | 2 | Microsoft Excel | APP | 462058435 | Productivity | Microsoft Corporation | Free download | Qualifying Microsoft 365 subscription for full editing | FREE+SUB/SERVICE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local spreadsheets plus licensing, OneDrive and collaboration | Mac chart ID 462058435 must not be replaced with mobile/universal ID 586683407. | A | [Apple App Store](https://apps.apple.com/us/app/microsoft-excel/id462058435?mt=12) |
| Productivity | Free | 3 | Microsoft Outlook | APP | 985367838 | Productivity | Microsoft Corporation | Free download | Optional Microsoft 365 premium/ad-free features | FREE/SERVICE+SUB | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Mail/calendar accounts and network required | Mac-specific Outlook ID differs from iOS ID 951937596. | A | [Apple App Store](https://apps.apple.com/us/app/microsoft-outlook/id985367838?mt=12) |
| Productivity | Free | 4 | Microsoft 365 | APP_BUNDLE | 1450038993 | Productivity | Microsoft Corporation | Free bundle download | Microsoft 365 subscription/service | FREE+SUB/BUNDLE | Bundle rating not comparable to a single app | App bundle | Bundle contents and versions vary | Requirements depend on included apps | Mac App Bundle | Account/licensing and connected services | This is an App Bundle ID, not a normal application track ID; keep object type separate. | A | [Apple App Store](https://apps.apple.com/us/app-bundle/microsoft-365/id1450038993) |
| Productivity | Free | 5 | Microsoft PowerPoint | APP | 462062816 | Productivity | Microsoft Corporation | Free download | Qualifying Microsoft 365 subscription for full editing | FREE+SUB/SERVICE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local presentations plus licensing, OneDrive and collaboration | Mac chart ID 462062816 differs from universal/mobile ID 586449534. | A | [Apple App Store](https://apps.apple.com/us/app/microsoft-powerpoint/id462062816?mt=12) |
| Productivity | Paid | 1 | Parchment: Agenda & Daily Note | APP | 6779987526 | Productivity | Chris Lawley | $4.99 | No IAP shown | PAID/LIFE | 4.8 / 87 | Universal product rating | 1.0.4 — 2026-07-24 | macOS 26.0+ | Universal iPhone/iPad/Mac | Local notes with Apple-platform sync | Strong early rating but low volume and a very high current OS floor. | A | [Apple App Store](https://apps.apple.com/us/app/parchment-agenda-daily-note/id6779987526) |
| Productivity | Paid | 2 | Magnet | APP | 441258766 | Productivity | CrowdCafé | Paid; exact current USD pending | No subscription or IAP stated | PAID/LIFE | Rating count pending | US Mac product | Current exact version/date pending | Supports macOS 13/14; optimized for macOS 15 | Native Mac / Only for Mac | Local window management | Exact current price was not reliably exposed; no historic price was substituted. | A- | [Apple App Store](https://apps.apple.com/us/app/magnet/id441258766?mt=12) |
| Productivity | Paid | 3 | Things 3 | APP | 904280696 | Productivity | Cultured Code GmbH & Co. KG | $49.99 | No subscription; separate platform purchases | PAID/LIFE | Rating count pending | US Mac product | Things 3.22 prepared for macOS 26 | Exact minimum macOS pending | Native Mac / Only for Mac | Local database and Apple-cloud sync options | Premium one-time pricing remains viable for a polished personal task manager. | A | [Apple App Store](https://apps.apple.com/us/app/things-3/id904280696?mt=12) |
| Productivity | Paid | 4 | Dark Reader for Safari | APP | 1438243180 | Productivity | Dark Reader Ltd | Paid; exact current USD pending | Single purchase; no ads or data collection claimed | PAID/LIFE | Rating count pending | Universal product rating | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Local Safari extension; website access needed for operation | Multiple similarly named products exist; original ID 1438243180 is retained. | A- | [Apple App Store](https://apps.apple.com/us/app/dark-reader-for-safari/id1438243180) |
| Productivity | Paid | 5 | Tampermonkey | APP | 6738342400 | Productivity | Jan Biniok | Paid; exact current USD pending | No IAP details parsed | PAID | 3.1 / 58 | US universal product rating | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Safari extension; userscripts may connect to websites | Current universal ID differs from older Mac-only Tampermonkey listing. | A- | [Apple App Store](https://apps.apple.com/us/app/tampermonkey/id6738342400) |
| Utilities | Free | 1 | NordVPN: VPN Fast & Secure | APP | 905953485 | Utilities | Nordvpn S.A. | Free download | Paid VPN subscription/IAP | FREE+SUB/SERVICE | 4.7 / ~10K | Mac-filtered US rating; generic page ~692K | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac/Apple TV | NordVPN account, network and service required | Generic rating must not be used as Mac demand. | A | [Apple App Store](https://apps.apple.com/us/app/nordvpn-vpn-fast-secure/id905953485?platform=mac) |
| Utilities | Free | 2 | Color Widgets | APP | 1531594277 | Utilities | Digital Charms | Free download | Premium themes/widgets and IAP | FREEMIUM/SUB | 4.6 / ~517K | Generic all-platform rating; Mac-specific count pending | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac/Apple Watch | Local widgets with content/theme services | Very large generic rating base is primarily a cross-platform signal. | B+ | [Apple App Store](https://apps.apple.com/us/app/color-widgets/id1531594277) |
| Utilities | Free | 3 | DuckDuckGo, optional Duck.ai | APP | 663592361 | Utilities | DuckDuckGo, Inc. | Free download | Optional Privacy Pro: $9.99 monthly / $99.99 yearly; higher Pro tiers also listed | FREE+SUB/SERVICE | 4.2 / 607 | Mac-filtered US rating; generic page ~2.4M | Current exact version/date pending | macOS 12.3+ | Native/universal Mac browser product | Internet required; local browser/privacy controls | Mac rating is tiny relative to generic mobile-heavy rating, reinforcing platform segmentation. | A | [Apple App Store](https://apps.apple.com/us/app/duckduckgo-optional-duck-ai/id663592361?platform=mac) |
| Utilities | Free | 4 | App for Youtube! | APP | 6463126936 | Lifestyle | Minham Samuel | Free download | IAP/premium features | FREEMIUM | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | YouTube web/service required | Official category differs from chart category; many near-identical wrappers make ID-level dedupe critical. | A- | [Apple App Store](https://apps.apple.com/us/app/app-for-youtube/id6463126936?mt=12) |
| Utilities | Free | 5 | Widgetter - Quick View Widgets | APP | 1553223588 | Utilities | Developer not parsed | Free download | Premium/ads/IAP; exact tiers pending | FREEMIUM | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local widgets; weather/media content may connect | Price tiers and developer metadata remain pending rather than guessed. | B | [Apple App Store](https://apps.apple.com/us/app/widgetter-quick-view-widgets/id1553223588?mt=12) |
| Utilities | Paid | 1 | Shadowrocket | APP | 932747118 | Utilities | Shadow Launch Technology Limited | $2.99 | No mandatory IAP shown | PAID | 4.5 / ~620 | US universal product rating | 2.2.90 — 2026-07-07 | Exact minimum macOS pending | Universal/Catalyst-style Mac distribution | Proxy/network configuration required | Low entry price and cross-platform rating; Mac-only share unknown. | B+ | [Apple App Store](https://apps.apple.com/us/app/shadowrocket/id932747118) |
| Utilities | Paid | 2 | Wipr 2 | APP | 1662217862 | Utilities | Kaylee Calderolla | Paid; exact USD pending | Filtr/IAP layer shown; exact items pending | PAID+IAP | Rating count pending | Universal product rating | Current exact version/date pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Safari content-blocking rules; updates connected | Current Turkish storefront showed ₺249.99, but no USD conversion was invented. | A- | [Apple App Store](https://apps.apple.com/us/app/wipr-2/id1662217862) |
| Utilities | Paid | 3 | Keka | APP | 470158793 | Utilities | Jorge Garcia Armero / Keka | $6.99 | IAP shown | PAID+IAP | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Offline archive processing | Classic Mac Store ID differs from newer universal Keka listing; IDs must remain separate. | A | [Apple App Store](https://apps.apple.com/us/app/keka/id470158793?mt=12) |
| Utilities | Paid | 4 | DaisyDisk | APP | 411643860 | Utilities | Software Ambience Corp. | Paid; exact current USD pending | No current subscription verified | PAID/LIFE | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local storage scan | Price not exposed reliably in parsed page; no remembered historic price was inserted. | A- | [Apple App Store](https://apps.apple.com/us/app/daisydisk/id411643860?mt=12) |
| Utilities | Paid | 5 | Noir – Dark Mode for Safari | APP | 1581140954 | Utilities | Jeffrey Kuiken | Paid; exact current USD pending | No IAP details parsed | PAID/LIFE | Rating count pending | Universal product rating | Active 2026 version history; exact current version pending | Exact minimum macOS pending | Universal iPhone/iPad/Mac | Safari extension and website access | Multiple Noir listings exist; active current ID 1581140954 retained. | A- | [Apple App Store](https://apps.apple.com/us/app/noir-dark-mode-for-safari/id1581140954) |
| Graphics & Design | Free | 1 | Pixelmator Pro: Edit Images | APP | 6746662575 | Graphics & Design | Apple | Free download | Apple Creator Studio subscription; 30-day trial | FREE+SUB | 4.7 / 1.1K | US Mac rating | Current exact version/date pending | Exact minimum macOS pending | Mac and iPad / Creator Studio edition | Editing local; subscription/account and some intelligence features connected | Separate from perpetual Mac ID 1289583905. | A | [Apple App Store](https://apps.apple.com/us/app/pixelmator-pro-edit-images/id6746662575?platform=mac) |
| Graphics & Design | Free | 2 | Designs for Cricut Maker | APP | 6466179127 | Graphics & Design | Developer not parsed | Free download | IAP/premium asset catalogue; exact tiers pending | FREEMIUM/SUB | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Asset downloads and Cricut workflow connected | Unofficial Cricut-focused products use highly similar names; ID and developer disclosure are critical. | B+ | [Apple App Store](https://apps.apple.com/us/app/designs-for-cricut-maker/id6466179127?mt=12) |
| Graphics & Design | Free | 3 | Design Space For Cricut Studio | APP | 6747343023 | Graphics & Design | Developer not parsed | Free download | Subscription/IAP for templates and design assets | FREEMIUM/SUB | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Online asset catalogue and Cricut-related workflow | Near-duplicate naming increases consumer-confusion and metadata-matching risk. | B+ | [Apple App Store](https://apps.apple.com/us/app/design-space-for-cricut-studio/id6747343023?mt=12) |
| Graphics & Design | Free | 4 | ibisPaint - Your Art Studio | APP | 6737590363 | Graphics & Design | ibis inc. | Free download | Daily time limit/free tier plus paid plans/IAP | FREEMIUM/SUB | Rating count pending | Mac product | Current exact version/date pending | Exact minimum macOS pending | Mac-compatible product | Core drawing local; cloud/material features connected | Reviews mention a one-hour-per-day free limit, so free rank is not equivalent to unrestricted free use. | A- | [Apple App Store](https://apps.apple.com/us/app/ibispaint-your-art-studio/id6737590363?platform=mac) |
| Graphics & Design | Free | 5 | Sweet Home 3D | APP | 669289700 | Graphics & Design | Emmanuel Puybaret / eTeks | Free download | IAP/subscription or catalogue add-ons; exact tiers pending | FREEMIUM | Rating count pending | US Mac product | Current exact version/date pending | Exact minimum macOS pending | Native Mac / Only for Mac | Local 2D/3D design; furniture/catalogue resources may connect | Mac-specific ID differs from universal/mobile Sweet Home 3D listing. | A- | [Apple App Store](https://apps.apple.com/us/app/sweet-home-3d/id669289700?mt=12) |
| Graphics & Design | Paid | 1 | Pixelmator Pro | APP | 1289583905 | Graphics & Design | Apple | $49.99 | No IAP shown | PAID/LIFE | 4.8 / ~18K | US Mac rating | 3.7 — 2025-06-30 | Exact minimum macOS pending | Native Mac / Only for Mac | Local image editing | Legacy perpetual ID; do not merge with Creator Studio subscription edition. | A | [Apple App Store](https://apps.apple.com/us/app/pixelmator-pro/id1289583905?mt=12) |
| Graphics & Design | Paid | 2 | Callipeg Studio: 2D Animation | APP | 6757113249 | Graphics & Design | Enoben | $29.99 | No subscription | PAID/LIFE | Not enough ratings for overview | US Mac product | 1.0.2 — current 2026 observation | macOS 15.0+; Apple M1+ | Native Mac / Only for Mac | Local animation projects | Professional niche launches directly at $29.99 with no subscription and no data collection claim. | A | [Apple App Store](https://apps.apple.com/us/app/callipeg-studio-2d-animation/id6757113249?mt=12) |
| Graphics & Design | Paid | 3 | Sketchbook Pro | APP | 1570472288 | Graphics & Design | Sketchbook, Inc. | Paid; exact current USD pending | No IAP details parsed | PAID/LIFE | Rating count pending | US Mac product | 9.1.26 — 2024-05-06 | Exact minimum macOS pending | Native Mac / Only for Mac | Local drawing workflow | Older update date creates maintenance-risk signal despite top-five paid rank. | A- | [Apple App Store](https://apps.apple.com/us/app/sketchbook-pro/id1570472288?mt=12) |
| Graphics & Design | Paid | 4 | Logoist 6 – Graphic Design | APP | 6754276978 | Graphics & Design | Synium Software GmbH | US exact pending; Türkiye ₺999.99 observed | No IAP details parsed | PAID | Rating count pending | Mac/Apple-platform product | Current exact version/date pending | macOS 15.0+ | Universal iPhone/iPad/Mac | Local vector/graphic design | Regional exact price retained without currency conversion. | A- | [Apple App Store](https://apps.apple.com/us/app/logoist-6-graphic-design/id6754276978) |
| Graphics & Design | Paid | 5 | Krita | APP | 1594607976 | Graphics & Design | Stichting Krita Foundation | $12.99 | No IAP shown | PAID/LIFE | Not enough ratings for overview | US Mac product | Active updates; exact current version pending | macOS 10.14+ | Native Mac / Only for Mac | Offline digital painting | Broad OS compatibility contrasts with newer tools requiring macOS 15–26 and Apple silicon. | A | [Apple App Store](https://apps.apple.com/us/app/krita/id1594607976?mt=12) |

## Faz 4C kimlik ve eşleme riskleri

### Microsoft Mac kimlikleri

- Word `462054704`, Excel `462058435`, Outlook `985367838` ve PowerPoint `462062816` Mac chart kimlikleridir.
- Mobil/universal Microsoft kimlikleriyle değiştirilirse rating, sürüm ve platform kapsamı yanlış birleşir.
- Microsoft 365 `1450038993` bir `APP_BUNDLE` kimliğidir; normal uygulama gibi sayılmamalıdır.

### Aynı isim, farklı SKU

- Pixelmator Pro perpetual `1289583905`; Creator Studio sürümü `6746662575`.
- Keka klasik Mac Store ürünü `470158793`; yeni universal ürün ayrı kimliktir.
- Tampermonkey güncel universal ürün `6738342400`; eski Mac-only kayıt ayrıdır.
- Noir için aktif güncel kayıt `1581140954`; benzer isimli ayrı ürünler bulunur.
- Cricut ve YouTube wrapper pazarlarında benzer adlar çok yüksek olduğundan isim tabanlı dedupe güvenli değildir.

## Faz 4C pazar sinyalleri

- **Free Top 5 çoğunlukla servis ekonomisi:** Microsoft, Slack, Okta, NordVPN, Termius ve Apple dağıtım araçlarında indirme ücretsiz; ekonomik değer hesap, kurum, abonelik veya ekosistem hizmetinden geliyor.
- **Gerçek ücretsiz rekabet:** PDFgear, Xcode, TestFlight ve Transporter gibi ürünler basit ücretli alternatiflerin fiyatlandırma alanını daraltıyor.
- **Developer Tools fiyat gücü:** Monodraw $9.99 ve TerminalWidget $19.99 ile dar, profesyonel ve local-first araçların kalıcı lisansla yaşayabildiğini gösteriyor.
- **Productivity premium sınırı:** Things 3’ün $49.99 kalıcı fiyatı, yüksek kalite ve uzun vadeli bakımın aboneliksiz modelde de fiyat gücü yaratabildiğini gösteriyor.
- **Graphics ikiye ayrılıyor:** Ücretsiz/subscription tasarım ürünleri edinimi domine ederken Callipeg $29.99, Krita $12.99 ve Pixelmator Pro $49.99 profesyonel peşin satın alma katmanını koruyor.
- **Minimum OS parçalanması:** Krita macOS 10.14+, Monodraw 11+, TerminalWidget 14+, Callipeg 15+ M1 ve Xcode 26.2+ M1 gerektiriyor. Aynı kategoride erişilebilir Mac tabanı dramatik biçimde değişiyor.
- **Platform-rating yanılgısı:** TestFlight Mac filtresinde yaklaşık 14K rating taşırken generic sayfa yüz binlerce rating gösteriyor; DuckDuckGo’da da Mac 607 ile generic yaklaşık 2.4M arasında büyük fark var.
- **Bakım fırsatı:** Sketchbook Pro’nun son doğrulanmış güncellemesinin 2024 olması, aktif geliştirilen native çizim araçları için fırsat sinyali.
- **Kategori uyumsuzluğu:** UTM Business chart’ında fakat resmî Developer Tools kategorisinde; App for Youtube Utilities chart’ında fakat resmî Lifestyle kategorisinde. İki kategori alanı korunmalı.

## Faz 4D kuyruğu

1. Education, Entertainment, Finance, Health & Fitness ve Lifestyle kategorilerinde Top 5 Free + Paid.
2. Medical, Music, News, Photo & Video ve Reference kategorilerinde Top 5.
3. Social Networking, Sports, Travel ve Weather ile kalan kategori kapsamının tamamlanması.
4. Eksik exact price, rating, version ve minimum macOS alanlarını ikinci doğrulama turunda tamamlama.
5. İlk demand proxy skorunu chart rank, Mac rating, rating velocity, update recency, price ve platform türünden hesaplama.

**Sürüm:** 4C — 2 Ağustos 2026

# Faz 4D — İkinci Beş Kategoride İlk 5 Free + İlk 5 Paid

**Gözlem tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kategoriler:** Education, Entertainment, Finance, Health & Fitness, Lifestyle  
**Yeni zenginleştirilen chart pozisyonu:** 50  
**Faz 4C + 4D kümülatif Top 5 kapsamı:** 10 kategori / 100 pozisyon

> [!IMPORTANT]
> Chart sıralamaları 2 Ağustos 2026 gözlemidir ve değişebilir. Kesin fiyatı ürün sayfasından ayrıştırılamayan uygulamalara tahmin yazılmadı. Universal rating, Mac’e özel indirme veya kullanıcı sayısı değildir.

## Kapsam özeti

| Ölçü | Sonuç |
|---|---:|
| Tamamlanan yeni kategori | 5 |
| Free pozisyon | 25 |
| Paid pozisyon | 25 |
| Toplam yeni pozisyon | 50 |
| Kesin USD peşin fiyat | 5 |
| Kesin fiyat medyanı | $7.99 |

## Faz 4D ayrıntılı envanter

| Kategori | Liste | # | Uygulama | Apple ID | Fiyat | Model | Niş | Dağıtım | Doğrulama/not | Kaynak |
|---|---|---:|---|---:|---|---|---|---|---|---|
| Education | Free | 1 | AI Chatbot・Ask AI Anything | 6753711999 | Free + IAP | FREEMIUM/HYBRID | AI assistant using third-party model APIs | Only for Mac | Insufficient rating overview; weekly/monthly/lifetime monetization; branding-confusion risk | [Apple App Store](https://apps.apple.com/us/app/ai-chatbot-ask-ai-anything/id6753711999?mt=12) |
| Education | Free | 2 | Bluebook Exams | 1645016851 | Free | FREE/SERVICE | College Board digital exam client | Mac-compatible | Demand tied to institutional exams rather than consumer IAP | [Apple App Store](https://apps.apple.com/us/app/bluebook-exams/id1645016851?platform=mac) |
| Education | Free | 3 | Chatbot: Ask Chat AI Assistant | 6741155738 | Free + IAP | FREEMIUM/SUB | General AI chatbot | Only for Mac | One of several near-identical AI wrappers in Education Top 5 | [Apple App Store](https://apps.apple.com/us/app/chatbot-ask-chat-ai-assistant/id6741155738?mt=12) |
| Education | Free | 4 | Ask AI Chat Bot Anything | 6758142837 | Free + IAP | FREEMIUM/SUB | General AI assistant | Only for Mac | Recently indexed product; Mac rating evidence remains weak | [Apple App Store](https://apps.apple.com/us/app/ask-ai-chat-bot-anything/id6758142837?mt=12) |
| Education | Free | 5 | AI Chatbot- Chat Ask Assistant | 6740460020 | Free + IAP | FREEMIUM/SUB | General AI chatbot | Only for Mac | Education acquisition chart is heavily saturated by AI wrappers | [Apple App Store](https://apps.apple.com/us/app/ai-chatbot-chat-ask-assistant/id6740460020?mt=12) |
| Education | Paid | 1 | Zoombinis | 1047336944 | $11.99 | PAID/LIFE | Logic and problem-solving education game | Only for Mac | Version 2.4.5 dated 2025-10-16; macOS 11+; no data collected | [Apple App Store](https://apps.apple.com/us/app/zoombinis/id1047336944?mt=12) |
| Education | Paid | 2 | Kioku Animals | 1041744545 | $2.00 | PAID/LIFE | Animal memory-learning game | Mac-compatible | Low-price educational game; chart page confirms rank #2 | [Apple App Store](https://apps.apple.com/us/app/kioku-animals/id1041744545?platform=mac) |
| Education | Paid | 3 | Letter Tiles for Learning | 1314838376 | Paid; exact USD pending | PAID | Phonics, spelling and word construction | Apple-silicon Mac compatibility | Requires M1 Mac; education-material companion rather than broad consumer product | [Apple App Store](https://apps.apple.com/us/app/letter-tiles-for-learning/id1314838376?platform=mac) |
| Education | Paid | 4 | Animal Typing | 796608673 | Paid; exact USD pending | PAID/LIFE | Touch-typing tutor | Only for Mac | Separate mobile Animal Typing ID also exists; Mac chart identity retained | [Apple App Store](https://apps.apple.com/us/app/animal-typing/id796608673?mt=12) |
| Education | Paid | 5 | Mindsight Journey | 6742457617 | Paid; exact USD pending | PAID | Mindsight and remote-viewing exercises | Mac-compatible | Very narrow wellness/education hybrid can reach paid chart Top 5 | [Apple App Store](https://apps.apple.com/us/app/mindsight-journey/id6742457617?platform=mac) |
| Entertainment | Free | 1 | Amazon Prime Video | 545519333 | Free download | FREE/SERVICE+IAP | Streaming, rentals, purchases and channels | Universal Apple-platform app | All-platform rating is not Mac demand; subscription/service economy | [Apple App Store](https://apps.apple.com/us/app/amazon-prime-video/id545519333?platform=mac) |
| Entertainment | Free | 2 | Streaming for Netflix | 6751184690 | Free + IAP | FREEMIUM | Streaming-service desktop wrapper/browser | Only for Mac | Unofficial wrapper niche; relies on third-party services | [Apple App Store](https://apps.apple.com/us/app/streaming-for-netflix/id6751184690?mt=12) |
| Entertainment | Free | 3 | Teleparty - Watch TV Together | 6471985961 | Free + IAP/service | FREEMIUM/SERVICE | Synchronized watch parties | Only for Mac | Network and supported streaming subscriptions required | [Apple App Store](https://apps.apple.com/us/app/teleparty-watch-tv-together/id6471985961?mt=12) |
| Entertainment | Free | 4 | Friendly Streaming Browser | 553245401 | Free + IAP | FREEMIUM | Multi-service streaming browser | Only for Mac | Long-lived utility combining multiple web services | [Apple App Store](https://apps.apple.com/us/app/friendly-streaming-browser/id553245401?mt=12) |
| Entertainment | Free | 5 | Crunchy Anime Browser | 6771866555 | Free + IAP | FREEMIUM | Anime streaming browser/client | Only for Mac | Recently indexed narrow wrapper; account/service dependent | [Apple App Store](https://apps.apple.com/us/app/crunchy-anime-browser/id6771866555?mt=12) |
| Entertainment | Paid | 1 | iSTB | 1497473331 | Paid; exact USD pending | PAID+IAP | IPTV player with EPG and VOD | Universal/Mac-compatible | IPTV credentials and provider required | [Apple App Store](https://apps.apple.com/us/app/istb/id1497473331?platform=mac) |
| Entertainment | Paid | 2 | Console Remote | 6738534883 | $7.99 | PAID | Console remote-play client | Universal iPhone/iPad/Mac | Small rating sample; actively updated in 2026 | [Apple App Store](https://apps.apple.com/us/app/console-remote/id6738534883?platform=mac) |
| Entertainment | Paid | 3 | MKStreamer | 1510144108 | Paid; exact USD pending | PAID | Media streaming and casting | Only for Mac | Local/network media ecosystem rather than content subscription | [Apple App Store](https://apps.apple.com/us/app/mkstreamer/id1510144108?mt=12) |
| Entertainment | Paid | 4 | UnPlay | 6450034641 | Paid; exact USD pending | PAID | DLNA receiver, clock and weather display | Mac-compatible | Local-network receiver; hardware/display utility hybrid | [Apple App Store](https://apps.apple.com/us/app/unplay/id6450034641?platform=mac) |
| Entertainment | Paid | 5 | Reelo - Media Hub | 6764665158 | Paid; exact USD pending | PAID | Local and network media hub | Mac-compatible | New product with low public rating evidence | [Apple App Store](https://apps.apple.com/us/app/reelo-media-hub/id6764665158?platform=mac) |
| Finance | Free | 1 | Webull: Advanced Trading | 1334590352 | Free | FREE/FINANCIAL-SERVICE | Brokerage, stocks, ETFs and options | Only for Mac | Revenue comes from brokerage activity, not App Store purchase | [Apple App Store](https://apps.apple.com/us/app/webull-advanced-trading/id1334590352?mt=12) |
| Finance | Free | 2 | Trading Charts View & Insights | 6787918970 | Free + IAP | FREEMIUM/SUB | Stock, crypto and forex charting | Only for Mac | Recently indexed charting product; likely subscription conversion model | [Apple App Store](https://apps.apple.com/us/app/trading-charts-view-insights/id6787918970?mt=12) |
| Finance | Free | 3 | Copilot: Track & Budget Money | 1447330651 | Free + subscription | FREEMIUM/SUB | Budgeting, net worth and account aggregation | Mac-compatible | Account connections and recurring service drive value | [Apple App Store](https://apps.apple.com/us/app/copilot-track-budget-money/id1447330651?platform=mac) |
| Finance | Free | 4 | Ledger Wallet™ crypto app | 1361671700 | Free | FREE/HARDWARE-SERVICE | Crypto wallet and Ledger hardware management | Mac-compatible | Demand is attached to hardware and crypto ecosystem | [Apple App Store](https://apps.apple.com/us/app/ledger-wallet-crypto-app/id1361671700?platform=mac) |
| Finance | Free | 5 | 同花顺-股票炒股软件 | 1247341465 | Free + service | FREE/FINANCIAL-SERVICE | Chinese stock market and trading client | Only for Mac | Local-language financial terminal can rank in US Mac chart | [Apple App Store](https://apps.apple.com/us/app/%E5%90%8C%E8%8A%B1%E9%A1%BA-%E8%82%A1%E7%A5%A8%E7%82%92%E8%82%A1%E8%BD%AF%E4%BB%B6/id1247341465?mt=12) |
| Finance | Paid | 1 | Money Pro: Personal Finance | 972572731 | $0.99 + subscriptions | PAID+SUB | Budget, bills, accounts and banking sync | Only for Mac | PLUS $4.99/month; GOLD $9.99/month; developer claims 2M worldwide downloads across product ecosystem | [Apple App Store](https://apps.apple.com/us/app/money-pro-personal-finance/id972572731?mt=12) |
| Finance | Paid | 2 | Simple Register | 6789787443 | Paid; exact USD pending | PAID/LIFE | Simple checkbook register | Mac-compatible | Very new narrow finance tool reached #2 paid | [Apple App Store](https://apps.apple.com/us/app/simple-register/id6789787443?platform=mac) |
| Finance | Paid | 3 | Moneydance 2024 | 538911179 | Paid; exact USD pending | PAID/LIFE | Private personal-finance management | Only for Mac | Privacy/local-management positioning against subscription aggregators | [Apple App Store](https://apps.apple.com/us/app/moneydance-2024/id538911179?mt=12) |
| Finance | Paid | 4 | Percentage Expert | 1639700335 | Paid; exact USD pending | PAID/LIFE | Percentage, VAT and margin calculations | Mac-compatible | Single-purpose calculator can enter paid Top 5 | [Apple App Store](https://apps.apple.com/us/app/percentage-expert/id1639700335?platform=mac) |
| Finance | Paid | 5 | SEE Finance 3 | 6755652042 | Paid; exact USD pending | PAID/LIFE | Personal finance, budgets and investments | Only for Mac | New major-version SKU; legacy-version data should remain separate | [Apple App Store](https://apps.apple.com/us/app/see-finance-3/id6755652042?mt=12) |
| Health & Fitness | Free | 1 | Portal - Escape Into Nature | 1436994560 | Free + subscription | FREEMIUM/SUB | Focus, sleep and immersive nature sounds | Universal Apple-platform app | Editors’ Choice; Mac rating smaller than generic total | [Apple App Store](https://apps.apple.com/us/app/portal-escape-into-nature/id1436994560?platform=mac) |
| Health & Fitness | Free | 2 | Diarly: Diary, Private Journal | 1387167765 | Free + subscription | FREEMIUM/SUB | Encrypted journal, mood and notes | Universal iPhone/iPad/Mac/Watch | 7-day trial; subscription unlocks sync, unlimited journals and AI | [Apple App Store](https://apps.apple.com/us/app/diarly-diary-private-journal/id1387167765?platform=mac) |
| Health & Fitness | Free | 3 | SmartGym: Gym & Home Workouts | 922744883 | Free + subscription | FREEMIUM/SUB | Workout planning and tracking | Universal Apple-platform app | Health data and cross-device ecosystem; Mac-specific demand unknown | [Apple App Store](https://apps.apple.com/us/app/smartgym-gym-home-workouts/id922744883?platform=mac) |
| Health & Fitness | Free | 4 | Endel: Focus & Sleep Sounds | 1346247457 | Free + subscription | FREEMIUM/SUB | Adaptive soundscapes for sleep and focus | Universal Apple-platform app | Recurring content/service model | [Apple App Store](https://apps.apple.com/us/app/endel-focus-sleep-sounds/id1346247457?platform=mac) |
| Health & Fitness | Free | 5 | stoic. journal & mental health | 1312926037 | Free + subscription | FREEMIUM/SUB | Mental-health journal and reflection | Universal Apple-platform app | Sensitive-data category; privacy and AI processing are core evaluation points | [Apple App Store](https://apps.apple.com/us/app/stoic-journal-mental-health/id1312926037?platform=mac) |
| Health & Fitness | Paid | 1 | Streaks | 963034692 | $5.99 | PAID/LIFE | Habit tracker | Universal Apple-platform app | 4.8 with large universal rating base; platform-specific share unknown | [Apple App Store](https://apps.apple.com/us/app/streaks/id963034692?platform=mac) |
| Health & Fitness | Paid | 2 | Health Data AI Analyzer | 6749297170 | Paid; exact USD pending | PAID+AI | Apple Health export and AI analysis | Mac-compatible | Health-data privacy and model processing are high-stakes differentiators | [Apple App Store](https://apps.apple.com/us/app/health-data-ai-analyzer/id6749297170?platform=mac) |
| Health & Fitness | Paid | 3 | Calm and Confident | 1541093309 | Paid; exact USD pending | PAID/LIFE | Relaxation and guided confidence exercises | Mac-compatible | Narrow guided-wellness product | [Apple App Store](https://apps.apple.com/us/app/calm-and-confident/id1541093309?platform=mac) |
| Health & Fitness | Paid | 4 | White Noise | 415139197 | Paid; exact USD pending | PAID/LIFE | Sleep and ambient noise generator | Only for Mac | Long-running offline-friendly utility | [Apple App Store](https://apps.apple.com/us/app/white-noise/id415139197?mt=12) |
| Health & Fitness | Paid | 5 | SymptomLog: Symptom Journal | 6760401211 | Paid; exact USD pending | PAID/LIFE | Symptoms, medication and trigger journal | Mac-compatible | New specialist tracker reached Top 5 with limited public rating history | [Apple App Store](https://apps.apple.com/us/app/symptomlog-symptom-journal/id6760401211?platform=mac) |
| Lifestyle | Free | 1 | Save to Pinterest | 6473649042 | Free | FREE/SERVICE | Safari save-to-Pinterest extension | Only for Mac | 2.7 rating observed previously; chart leadership despite complaints suggests weak competition | [Apple App Store](https://apps.apple.com/us/app/save-to-pinterest/id6473649042?mt=12) |
| Lifestyle | Free | 2 | Streaming Master | 6502647917 | Free + IAP | FREEMIUM | Multi-service streaming wrapper | Only for Mac | Entertainment functionality charted under Lifestyle | [Apple App Store](https://apps.apple.com/us/app/streaming-master/id6502647917?mt=12) |
| Lifestyle | Free | 3 | App for YouTube • | 6463126936 | Free + IAP | FREEMIUM | YouTube desktop wrapper | Only for Mac | Same ID also appeared in Utilities chart; cross-category duplication preserved | [Apple App Store](https://apps.apple.com/us/app/app-for-youtube/id6463126936?mt=12) |
| Lifestyle | Free | 4 | PayPal Honey for Safari | 1472777122 | Free | FREE/SERVICE | Shopping coupons and price assistance | Only for Mac | Revenue is affiliate/service based rather than App Store IAP | [Apple App Store](https://apps.apple.com/us/app/paypal-honey-for-safari/id1472777122?mt=12) |
| Lifestyle | Free | 5 | Planner 5D - AI Home Design | 1310584536 | Free + subscription/IAP | FREEMIUM/SUB | 2D/3D interior and home design | Only for Mac | Asset catalogue and AI features support recurring monetization | [Apple App Store](https://apps.apple.com/us/app/planner-5d-ai-home-design/id1310584536?mt=12) |
| Lifestyle | Paid | 1 | Paprika Recipe Manager 3 | 1303222628 | $29.99 | PAID/LIFE | Recipe manager, meal planner and grocery list | Only for Mac | Separate platform purchase; offline/local-first value | [Apple App Store](https://apps.apple.com/us/app/paprika-recipe-manager-3/id1303222628?mt=12) |
| Lifestyle | Paid | 2 | Cloud Baby Monitor | 517602535 | Paid; exact USD pending | PAID | Baby-camera monitoring between devices | Only for Mac | Requires paired camera/device and network | [Apple App Store](https://apps.apple.com/us/app/cloud-baby-monitor/id517602535?mt=12) |
| Lifestyle | Paid | 3 | Audiobook Builder 2 | 1437681957 | Paid; exact USD pending | PAID/LIFE | Create chaptered audiobooks | Only for Mac | Local media-production niche | [Apple App Store](https://apps.apple.com/us/app/audiobook-builder-2/id1437681957?mt=12) |
| Lifestyle | Paid | 4 | AudioBo • Audiobook Maker | 6754019673 | Paid; exact USD pending | PAID/LIFE | Create M4B audiobooks from MP3 | Only for Mac | Newer competitor to established audiobook builder niche | [Apple App Store](https://apps.apple.com/us/app/audiobo-audiobook-maker/id6754019673?mt=12) |
| Lifestyle | Paid | 5 | HomeCam for HomeKit | 1292995895 | Paid; exact USD pending | PAID/LIFE | Multi-camera HomeKit viewer | Universal/Mac-compatible | Value tied to HomeKit hardware ecosystem | [Apple App Store](https://apps.apple.com/us/app/homecam-for-homekit/id1292995895?platform=mac) |

## Faz 4D kategori sonuçları

- **Education:** Free Top 5’in dört kaydı AI chatbot/wrapper. Eğitim değeri yerine model markası ve abonelik paywall’ı üzerinden rekabet eden çok yoğun, düşük güvenli bir alan.
- **Education paid:** Logic game, phonics, typing ve memory gibi dar eğitim araçları $2–$11.99 ve tek seferlik ödeme ile chart’a girebiliyor.
- **Entertainment free:** Prime Video dışındaki ilk 5’in çoğu streaming wrapper/browser. Resmî servis istemcilerindeki masaüstü boşlukları üçüncü taraf uygulamalara alan açıyor.
- **Entertainment paid:** IPTV, console remote, DLNA ve yerel medya hub’ları baskın. Kullanıcı içerik için ayrıca servis/sağlayıcıya ihtiyaç duyuyor.
- **Finance free:** İlk 5’in tamamı brokerage, charting, account aggregation veya crypto hizmeti. App Store geliri yerine finansal hizmet, subscription veya donanım ekosistemi öne çıkıyor.
- **Finance paid:** Basit checkbook ve percentage calculator gibi tek amaçlı araçlar, tam kapsamlı Moneydance/SEE Finance ürünleriyle aynı Top 5 içinde bulunuyor; kategori rekabeti parçalı.
- **Health free:** İlk 5’in tamamı freemium/subscription; journal, workout ve adaptive-sound ürünleri universal rating avantajı taşıyor.
- **Health paid:** Streaks haricindeki ürünlerde rating hacmi sınırlı. Apple Health analiz, symptom journal ve offline white-noise gibi dar nişler chart’a girebiliyor.
- **Lifestyle free:** Safari extensions, streaming/YouTube wrappers, affiliate shopping ve home-design subscription ürünleri birbirinden çok farklı gelir modelleriyle aynı kategoriye düşüyor.
- **Lifestyle paid:** Offline recipe manager, baby monitor, audiobook builder ve HomeKit camera gibi donanım/yerel dosya iş akışına bağlı kalıcı lisanslar güçlü.

## Kimlik ve kalite riskleri

- Animal Typing’in Mac ve mobil için farklı Apple kimlikleri bulundu; chart’ın bağlandığı `796608673` korundu.
- App for YouTube aynı Apple kimliğiyle Utilities ve Lifestyle chart’larında görünebilir; bu duplicate uygulama değil, duplicate placement’tır.
- AI chatbot ürünlerinde isim ve model sürümü sık değişir; `trackId` olmadan tarihsel analiz güvenilir değildir.
- Finance ve Health ürünlerindeki şirket çapında indirme/kullanıcı iddiaları Mac App Store kullanımı olarak yorumlanmadı.
- Streaming wrapper’larda marka ilişkisi, telif, servis değişiklikleri ve App Review sürdürülebilirliği ayrıca risk puanına eklenmelidir.

## Faz 4E kuyruğu

1. Medical, Music, News, Photo & Video ve Reference kategorilerinde Top 5 Free + Paid.
2. Social Networking, Sports, Travel ve Weather ile kalan kategori kapsamı.
3. Eksik exact price, rating, sürüm ve minimum macOS için ikinci metadata turu.
4. İlk demand proxy: chart rank + Mac rating + update recency + monetization clarity + platform fit.
5. İlk fırsat skoru: talep / rekabet / geliştirme maliyeti / destek riski / App Review riski.

**Sürüm:** 4D — 2 Ağustos 2026

# Faz 4E — Üçüncü Beş Kategoride İlk 5 Free + İlk 5 Paid

**Gözlem ve yeniden doğrulama tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kategoriler:** Medical, Music, News, Photo & Video, Reference  
**Yeni zenginleştirilen chart pozisyonu:** 50  
**Faz 4C–4E kümülatif Top 5 kapsamı:** 15 kategori / 150 pozisyon

> [!IMPORTANT]
> Faz 4E sıralamaları eski Faz 2 snapshot’ından kopyalanmadı; 2 Ağustos 2026’da Apple chart sayfalarından yeniden doğrulandı. Chart değiştiğinde yeni sıralama korunur ve tarih alanı zorunludur.

## Kapsam özeti

| Ölçü | Sonuç |
|---|---:|
| Tamamlanan yeni kategori | 5 |
| Free pozisyon | 25 |
| Paid pozisyon | 25 |
| Toplam yeni pozisyon | 50 |
| Normal uygulama | 49 |
| App bundle | 1 |
| Kesin USD peşin fiyatı bulunan kayıt | 22 |
| Kesin fiyat medyanı | $11.49 |
| Kesin fiyat aralığı | $0.99–$299.99 |

## Faz 4E ayrıntılı envanter

| Kategori | Liste | # | Uygulama | Nesne | Apple ID | Geliştirici | Fiyat | Model | Niş | Dağıtım | Doğrulama / not | Kaynak |
|---|---|---:|---|---|---:|---|---|---|---|---|---|---|
| Medical | Free | 1 | Epic Hyperspace | APP | 6472198304 | Epic | Free | FREE/ENTERPRISE-SERVICE | Hospital EHR and clinical workflow client | Only for Mac | Version 100.2606.5 observed; macOS 14+; enterprise Epic environment required; insufficient public rating overview. | [Apple App Store](https://apps.apple.com/us/app/epic-hyperspace/id6472198304?mt=12) |
| Medical | Free | 2 | Complete Anatomy | APP | 1141323850 | 3D4Medical from Elsevier | Free + IAP | FREE-TRIAL/SUB | Professional interactive 3D anatomy platform | Only for Mac | Three-day Premium trial followed by annual subscription; works best on macOS 11+; downloaded anatomy assets may be used locally. | [Apple App Store](https://apps.apple.com/us/app/complete-anatomy/id1141323850?mt=12) |
| Medical | Free | 3 | Bee DICOM Viewer | APP | 1590273176 | SinoUnion Healthcare | Free | FREE | Clinical DICOM image viewer | Only for Mac | Professional local medical-image viewer; insufficient ratings for an overview. | [Apple App Store](https://apps.apple.com/us/app/bee-dicom-viewer/id1590273176?mt=12) |
| Medical | Free | 4 | AHA eBook Reader | APP | 1439086329 | American Heart Association | Free | FREE/CONTENT-SERVICE | AHA clinical and emergency-care ebook reader | Only for Mac | AHA account and purchased content required; downloaded books can be read offline; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/aha-ebook-reader/id1439086329?mt=12) |
| Medical | Free | 5 | Anatomy 3D Atlas | APP | 1038133000 | Catfish Animation Studio | Free + IAP | FREEMIUM/IAP | Interactive human-anatomy atlas | Only for Mac | Free acquisition with anatomy-content unlocks; local 3D reference workflow. | [Apple App Store](https://apps.apple.com/us/app/anatomy-3d-atlas/id1038133000?mt=12) |
| Medical | Paid | 1 | 3D Human Anatomy Atlas 2026 | APP | 1239927097 | Visible Body Apps | $24.99 + IAP | PAID+IAP | Gross anatomy atlas with optional physiology and dental modules | Only for Mac | One-time base purchase plus optional modules; insufficient public rating overview. | [Apple App Store](https://apps.apple.com/us/app/3d-human-anatomy-atlas-2026/id1239927097?mt=12) |
| Medical | Paid | 2 | Anatomy & Physiology | APP | 666460498 | Visible Body Apps | $34.99 | PAID/LIFE | Anatomy and physiology course/reference | Only for Mac | 1.4 GB specialist education product; insufficient public rating overview. | [Apple App Store](https://apps.apple.com/us/app/anatomy-physiology/id666460498?mt=12) |
| Medical | Paid | 3 | Surgical Anatomy - Premium Edition | APP | 465029402 | Luke Allen | $0.99 | PAID/LIFE | Historical surgical-anatomy reference | Only for Mac | Observed at a 90% sale price; built around historical 1859 anatomical material. | [Apple App Store](https://apps.apple.com/us/app/surgical-anatomy-premium-edition/id465029402?mt=12) |
| Medical | Paid | 4 | 3D Heart Anatomy | APP | 6450390626 | XR Anatomy LTD | $6.99 | PAID/LIFE | Interactive 3D cardiac anatomy | Universal iPhone/iPad/Mac | Offline access; 150+ structures; only one public US rating observed, so demand evidence remains thin. | [Apple App Store](https://apps.apple.com/us/app/3d-heart-anatomy/id6450390626) |
| Medical | Paid | 5 | DICOM Quicklook by OsiriX | APP | 1440819115 | Pixmeo SARL | $5.99 | PAID/LIFE | Finder Quick Look for DICOM files | Only for Mac | Focused local utility; macOS 15+; no-data-collected disclosure; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/dicom-quicklook-by-osirix/id1440819115?mt=12) |
| Music | Free | 1 | VinylPod - Music Widget | APP | 6443989711 | 裕涛 兰 | Free + IAP | FREEMIUM/LIFE | Now-playing widgets and vinyl-style music display | Universal iPhone/iPad/Mac | About 4.6/14K universal ratings; macOS 13+; Premium $3.99; listing says no data collected. | [Apple App Store](https://apps.apple.com/us/app/vinylpod-music-widget/id6443989711?platform=mac) |
| Music | Free | 2 | Logic Pro: Make Music | APP | 1615087040 | Apple | Free download | FREE-TRIAL/SUB | Professional DAW under Apple Creator Studio model | Mac-compatible Apple product | Separate Apple ID from perpetual Logic Pro 634148309; ratings and revenue must never be merged. | [Apple App Store](https://apps.apple.com/us/app/logic-pro-make-music/id1615087040?platform=mac) |
| Music | Free | 3 | Silicio: Widgets + Mini Player | APP | 933627574 | Developer not parsed | Free | FREE | Desktop mini-player and music widgets | Only for Mac | Local playback-control utility; depends on supported music services/apps for content. | [Apple App Store](https://apps.apple.com/us/app/silicio-widgets-mini-player/id933627574?mt=12) |
| Music | Free | 4 | djay - DJ App & AI Mixer | APP | 450527929 | Algoriddim GmbH | Free + IAP | FREEMIUM/SUB | DJ mixing, streaming catalogues and AI tools | Universal Apple-platform app | Core app free; professional features and content integrations use subscriptions/IAP. | [Apple App Store](https://apps.apple.com/us/app/djay-dj-app-ai-mixer/id450527929?platform=mac) |
| Music | Free | 5 | PlaylistPort：Playlist Transfer | APP | 6749790210 | Developer not parsed | Free + IAP | FREEMIUM/SERVICE | Playlist migration between music services | Mac-compatible listing | Requires third-party music accounts and network access; service/API changes are a support risk. | [Apple App Store](https://apps.apple.com/us/app/playlistport-playlist-transfer/id6749790210?platform=mac) |
| Music | Paid | 1 | Logic Pro | APP | 634148309 | Apple | $199.99 | PAID/LIFE | Professional music production and audio workstation | Only for Mac | Legacy perpetual SKU; keep separate from free/subscription Logic Pro product. | [Apple App Store](https://apps.apple.com/us/app/logic-pro/id634148309?mt=12) |
| Music | Paid | 2 | MainStage | APP | 634159523 | Apple | $29.99 | PAID/LIFE | Live-performance instrument and effects host | Only for Mac | Professional Apple music product with one-time purchase. | [Apple App Store](https://apps.apple.com/us/app/mainstage/id634159523?mt=12) |
| Music | Paid | 3 | FL Studio Mobile | APP | 432850619 | Image Line Software | $14.99 + IAP | PAID+IAP | Mobile/universal music production studio | Universal iPhone/iPad/Mac | About 4.5/18 observed on Mac-filtered context; rating remains small relative to mobile reach. | [Apple App Store](https://apps.apple.com/us/app/fl-studio-mobile/id432850619?platform=mac) |
| Music | Paid | 4 | forScore | APP | 363738376 | forScore, LLC | $24.99 + optional Pro | PAID+OPTIONAL-SUB | Digital sheet-music library and performance reader | Universal Apple-platform app | About 4.8/42K universal ratings; optional annual Pro layer supplements the base purchase. | [Apple App Store](https://apps.apple.com/us/app/forscore/id363738376?platform=mac) |
| Music | Paid | 5 | Mp3tag | APP | 1532597159 | Florian Heidenreich | $24.99 | PAID/LIFE | Audio metadata and batch tag editor | Only for Mac | Focused professional file utility with one-time purchase. | [Apple App Store](https://apps.apple.com/us/app/mp3tag/id1532597159?mt=12) |
| News | Free | 1 | Ground News | APP | 1324203419 | Snapwise Inc. | Free + IAP | FREEMIUM/SUB | News aggregation, bias and ownership comparison | Universal iPhone/iPad/Mac | Mac page about 3.5/15; macOS 12+; subscriptions from $3.99 monthly to higher Vantage tiers; 40K sources is product scale, not users. | [Apple App Store](https://apps.apple.com/us/app/ground-news/id1324203419?platform=mac) |
| News | Free | 2 | Instapaper | APP | 288545208 | Instant Paper, Inc. | Free + subscription | FREEMIUM/SUB | Read-later and article highlighting | Universal Apple-platform app | Cloud account and sync required for full cross-device workflow. | [Apple App Store](https://apps.apple.com/us/app/instapaper/id288545208?platform=mac) |
| News | Free | 3 | Reeder. | APP | 6475002485 | Silvio Rizzi | Free + subscription/service | FREEMIUM/SUB | Feed, read-later and information inbox | Universal Apple-platform app | Separate product from paid Reeder Classic; ID-level history must remain separate. | [Apple App Store](https://apps.apple.com/us/app/reeder/id6475002485?platform=mac) |
| News | Free | 4 | FireShot: Web Page Screenshots | APP | 1541862561 | Developer not parsed | Free + IAP | FREEMIUM | Full-page browser screenshot and export | Only for Mac | Official functionality is a browser utility despite News chart placement; preserve both chart and official category fields. | [Apple App Store](https://apps.apple.com/us/app/fireshot-web-page-screenshots/id1541862561?mt=12) |
| News | Free | 5 | NYTE: Breaking & Live News | APP | 6786680574 | Developer not parsed | Free + service/IAP pending | FREEMIUM/SERVICE | Breaking-news and live-news reader | Mac-compatible listing | Very recent product; rating and retention evidence remain limited. | [Apple App Store](https://apps.apple.com/us/app/nyte-breaking-live-news/id6786680574?platform=mac) |
| News | Paid | 1 | GoodLinks | APP | 1474335294 | Ngoc Luu | $9.99 + IAP | PAID+OPTIONAL-IAP | Private read-later and bookmark manager | Universal iPhone/iPad/Mac | About 4.4/169 in the current page; no account; iCloud sync; optional feature-upgrade/tip layer. | [Apple App Store](https://apps.apple.com/us/app/goodlinks/id1474335294) |
| News | Paid | 2 | Current - RSS Feed Reader | APP | 6758530974 | Developer not parsed | $9.99 | PAID/LIFE | Native RSS reader | Universal Apple-platform app | About 4.1/37; one-time purchase and local feed workflow. | [Apple App Store](https://apps.apple.com/us/app/current-rss-feed-reader/id6758530974) |
| News | Paid | 3 | Reeder Classic. | APP | 1529448980 | Silvio Rizzi | $9.99 | PAID/LIFE | Classic RSS and read-later client | Only for Mac | Editors’ Choice signal; separate SKU from the newer free/subscription Reeder. | [Apple App Store](https://apps.apple.com/us/app/reeder-classic/id1529448980?mt=12) |
| News | Paid | 4 | Downcast | APP | 668429425 | Jamawkinaw Enterprises LLC | $4.99 | PAID/LIFE | Podcast subscription and playback client | Only for Mac | One-time paid podcast utility positioned inside News. | [Apple App Store](https://apps.apple.com/us/app/downcast/id668429425?mt=12) |
| News | Paid | 5 | RSS Button for Safari | APP | 1437501942 | Developer not parsed | $0.99 | PAID/LIFE | Safari RSS-subscription extension | Only for Mac | A single-purpose browser extension can remain in paid Top 5 at a $0.99 price. | [Apple App Store](https://apps.apple.com/us/app/rss-button-for-safari/id1437501942?mt=12) |
| Photo & Video | Free | 1 | Canva: AI Video & Photo Editor | APP | 897446215 | Canva | Free + IAP | FREEMIUM/SUB | Design, photo, video, templates and AI creation | Universal iPhone/iPad/Mac | Mac-filtered page about 4.8/27K; version 1.123.1 observed one day before research; Editors’ Choice. | [Apple App Store](https://apps.apple.com/us/app/canva-ai-video-photo-editor/id897446215?platform=mac) |
| Photo & Video | Free | 2 | CapCut: Photo & Video Editor | APP | 1500855883 | Bytedance Pte. Ltd | Free + IAP | FREEMIUM/SUB | Video editing, templates and AI tools | Universal iPhone/iPad/Mac | Mac-filtered rating about 26K versus roughly 1.1M generic ratings; platform segmentation is essential. | [Apple App Store](https://apps.apple.com/us/app/capcut-photo-video-editor/id1500855883?platform=mac) |
| Photo & Video | Free | 3 | Apple Creator Studio | APP_BUNDLE | 1868448255 | Apple | Free bundle download | FREE-TRIAL/SUB/BUNDLE | Bundle of Apple professional creative applications | Mac App Bundle | This is an app-bundle ID, not a normal application track ID; never count it as one standalone app. | [Apple App Store](https://apps.apple.com/us/app-bundle/apple-creator-studio/id1868448255) |
| Photo & Video | Free | 4 | Adobe Lightroom: Photo Editor | APP | 1451544217 | Adobe Inc. | Free + IAP | FREEMIUM/SUB | RAW photo editing, cloud library and AI tools | Mac-compatible Adobe product | Free acquisition with Creative Cloud/premium subscription layer. | [Apple App Store](https://apps.apple.com/us/app/adobe-lightroom-photo-editor/id1451544217?platform=mac) |
| Photo & Video | Free | 5 | DaVinci Resolve | APP | 571213070 | Blackmagic Design Inc. | Free | FREE | Professional editing, color, audio and VFX | Only for Mac | Full free professional product; DaVinci Resolve Studio is a separate paid SKU. | [Apple App Store](https://apps.apple.com/us/app/davinci-resolve/id571213070?mt=12) |
| Photo & Video | Paid | 1 | Final Cut Pro | APP | 424389933 | Apple | $299.99 | PAID/LIFE | Professional video editing | Only for Mac | Legacy perpetual SKU; highest base price in this phase. | [Apple App Store](https://apps.apple.com/us/app/final-cut-pro/id424389933?mt=12) |
| Photo & Video | Paid | 2 | PhotoSweeper | APP | 463362050 | Maksym Cherniaiev | $14.99 | PAID/LIFE | Duplicate and similar-photo cleanup | Only for Mac | Version 5.5.5 observed Jul 11; macOS 10.15+; no data collected; active 2026 updates and Apple Photos/Lightroom integration. | [Apple App Store](https://apps.apple.com/us/app/photosweeper/id463362050?mt=12) |
| Photo & Video | Paid | 3 | Upscayl | APP | 6468265473 | Mayank Sharma | $12.99 | PAID/LIFE | Local/open-source AI image upscaling | Only for Mac | macOS 12+; 571.5 MB; batch upscaling and local image workflow. | [Apple App Store](https://apps.apple.com/us/app/upscayl/id6468265473?mt=12) |
| Photo & Video | Paid | 4 | Helper for GoPro Files | APP | 1039466529 | Marvin Wagner | $1.99 | PAID/LIFE | Sort, rename and clean GoPro media files | Only for Mac | macOS 10.15+; only 278 KB; no data collected; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/helper-for-gopro-files/id1039466529?mt=12) |
| Photo & Video | Paid | 5 | ShutterCount | APP | 720123827 | DIRE Studio | $9.99 + IAP | PAID+IAP | Camera shutter-count and lifecycle diagnostics | Only for Mac | macOS 12.4+; optional Plus $7 and Live View $5 packs; developer claims 250K+ customers across the product family, not Mac App Store installs. | [Apple App Store](https://apps.apple.com/us/app/shuttercount/id720123827?mt=12) |
| Reference | Free | 1 | LookUp: English Dictionary App | APP | 872564448 | Squircle Apps LLP | Free + IAP | FREEMIUM/HYBRID | Dictionary, vocabulary and language learning | Universal iPhone/iPad/Mac | About 4.5/657; macOS 15+; version 12.1.2 observed two days before research; $2.99 monthly, $29.99 yearly, $59.99 lifetime. | [Apple App Store](https://apps.apple.com/us/app/lookup-english-dictionary-app/id872564448?platform=mac) |
| Reference | Free | 2 | Bible Study | APP | 472790630 | Gospel Technologies LLC | Free + IAP | FREEMIUM/CONTENT-IAP | Bible study, notes and licensed reference content | Only for Mac | Core app free; translations and resources sold separately, including several $9.99 items. | [Apple App Store](https://apps.apple.com/us/app/bible-study/id472790630?mt=12) |
| Reference | Free | 3 | ManualsPlus | APP | 6758109805 | Developer not parsed | Free/service | FREE/SERVICE | Search and read product manuals | Mac-compatible listing | Internet catalogue dependency; service breadth rather than local content drives value. | [Apple App Store](https://apps.apple.com/us/app/manualsplus/id6758109805?platform=mac) |
| Reference | Free | 4 | Translate Now - AI Translator | APP | 1348028646 | Air Apps Systems | Free + IAP | FREEMIUM/SUB | Text, voice, image and AI translation | Universal Apple-platform app | Network/cloud translation and subscription model; generic ratings are not Mac-only. | [Apple App Store](https://apps.apple.com/us/app/translate-now-ai-translator/id1348028646?platform=mac) |
| Reference | Free | 5 | Youdao Translate | APP | 491854842 | NetEase Youdao | Free + service/IAP | FREE/SERVICE | Chinese-focused dictionary and translation | Mac-compatible listing | Strong language/ecosystem specialization; cloud translation services required. | [Apple App Store](https://apps.apple.com/us/app/youdao-translate/id491854842?platform=mac) |
| Reference | Paid | 1 | e-Sword X: Bible Study Extreme | APP | 968437868 | Rick Meyers | $9.99 | PAID/LIFE | Offline Bible study and reference library | Only for Mac | Strong specialist one-time-price model; optional resources may be downloadable. | [Apple App Store](https://apps.apple.com/us/app/e-sword-x-bible-study-extreme/id968437868?mt=12) |
| Reference | Paid | 2 | HolyBible K.J.V. Pro | APP | 393131384 | Developer not parsed | Paid; exact USD pending | PAID/LIFE | Advertisement-free King James Bible | Universal iPhone/iPad/Mac | Premium companion to the free KJV product; exact current US price not reliably exposed. | [Apple App Store](https://apps.apple.com/us/app/holybible-k-j-v-pro/id393131384) |
| Reference | Paid | 3 | Webster’s 1828 Dictionary | APP | 6476927020 | Developer not parsed | Paid; exact USD pending | PAID/LIFE | Historical American English dictionary | Universal iPhone/iPad/Mac | One purchase unlocks supported Apple devices; exact US price not reliably exposed. | [Apple App Store](https://apps.apple.com/us/app/websters-1828-dictionary/id6476927020) |
| Reference | Paid | 4 | BibleDesk | APP | 6754764564 | Developer not parsed | Paid; exact USD pending | PAID/AI | Bible reading, study and Apple Intelligence assistant | Universal iPhone/iPad/Mac | AI-assisted scripture study; exact price pending rather than estimated. | [Apple App Store](https://apps.apple.com/us/app/bibledesk/id6754764564?platform=mac) |
| Reference | Paid | 5 | Movie Explorer Pro | APP | 1096514088 | Ron Elemans | $22.99 | PAID/LIFE | Local movie, disc and TV-show catalogue | Only for Mac | Native Apple-silicon app; local/network indexing, barcode scanning, Trakt sync; no data collected; one-time alternative to subscription edition. | [Apple App Store](https://apps.apple.com/us/app/movie-explorer-pro/id1096514088?mt=12) |

## Faz 4E chart değişikliği notu

- Medical paid Top 5 artık dört anatomy/reference ürünü ve bir DICOM Quick Look aracından oluşuyor.
- Photo & Video free chart’ında Canva, CapCut’ın önüne geçmiş; üçüncü sırada normal bir uygulama değil Apple Creator Studio `APP_BUNDLE` bulunuyor.
- Reference ücretsiz lideri LookUp; ücretli ilk 5’in üçü Bible study/reading ürünleri.
- Bu değişiklikler, tek seferlik chart snapshot’ının kalıcı pazar payı gibi yorumlanmaması gerektiğini gösteriyor.

## Faz 4E kategori sonuçları

- **Medical free:** Enterprise EHR, anatomy subscription, DICOM viewer ve lisanslı ebook hizmetleri aynı listede. Dağıtım gücü tüketici pazarlamasından çok kurum, okul ve içerik ekosistemine bağlı.
- **Medical paid:** Kesin fiyatlar $0.99–$34.99. Anatomy içeriği yüksek fiyat alabilirken DICOM Quick Look gibi tek amaçlı klinik yardımcılar $5.99 seviyesinde chart’a girebiliyor.
- **Music free:** Widget, yeni subscription Logic SKU’su, mini-player, DJ ve playlist migration ürünleri birbirinden farklı gelir modelleriyle ilk 5’te.
- **Music paid:** $14.99–$199.99 arasında profesyonel üretim ve performans araçları baskın. Kalıcı lisans, optional Pro ve IAP modelleri birlikte var.
- **News free:** Subscription news intelligence, read-later, modern Reeder ve yanlış kategorilenmiş screenshot utility aynı chart’ta bulunuyor.
- **News paid:** İlk 5’in tamamı read-later, RSS, podcast veya Safari feed yardımcılarından oluşuyor; fiyat aralığı $0.99–$9.99.
- **Photo & Video free:** Büyük platformlar, cloud/subscription ve profesyonel ücretsiz DaVinci Resolve edinimi domine ediyor.
- **Photo & Video paid:** $299.99 profesyonel editörden $1.99 GoPro dosya düzenleyiciye kadar çok geniş bir fiyat merdiveni var. PhotoSweeper ve ShutterCount donanım/yerel kütüphane sorunlarını çözen güçlü Mac-native örnekler.
- **Reference free:** Dictionary, Bible, manuals ve translation servisleri öne çıkıyor; içerik ve dil ekosistemi uygulama ekonomisini belirliyor.
- **Reference paid:** Dini içerik yoğunluğu yüksek. Movie Explorer Pro ise local-first catalogue ve bir defalık $22.99 ile subscription sürümüne alternatif oluşturuyor.

## Kimlik ve nesne türü riskleri

- Logic Pro ücretsiz/subscription ürünü `1615087040`; perpetual Logic Pro `634148309`.
- Reeder. `6475002485`; Reeder Classic `1529448980`. Aynı marka fakat ayrı ürün ekonomileri.
- Apple Creator Studio `1868448255` bir `APP_BUNDLE`; normal uygulama olarak sayılmamalı.
- DaVinci Resolve ücretsiz ürün ile DaVinci Resolve Studio ayrı SKU’lardır.
- Universal ürünlerin rating toplamı Mac’e özel talep değildir.
- Şirket tarafından açıklanan ShutterCount 250K+ müşteri sayısı ürün ailesi/genel müşteri sinyalidir; Mac App Store indirmesi değildir.

## Faz 4F kuyruğu

1. Games, Social Networking, Sports, Travel ve Weather kategorilerinde Top 5 Free + Paid.
2. Böylece 20 kategorinin tamamında 200 Top-5 chart pozisyonunun tamamlanması.
3. Eksik exact price, rating, sürüm ve minimum macOS alanları için ikinci doğrulama turu.
4. Chart değişim hızını ölçmek için Faz 2 snapshot’ı ile 2 Ağustos 2026 yeniden doğrulamasını karşılaştırma.
5. Demand proxy ve fırsat skorunun ilk sayısal sürümü.

**Sürüm:** 4E — 2 Ağustos 2026

# Faz 4F — Kalan Beş Kategori ve Top-5 Kapsamının Tamamlanması

**Gözlem ve doğrulama tarihi:** 2 Ağustos 2026  
**Storefront:** United States  
**Kategoriler:** Games, Social Networking, Sports, Travel, Weather  
**Yeni zenginleştirilen chart pozisyonu:** 50  
**Faz 4C–4F kümülatif Top-5 kapsamı:** 20 kategori / 200 pozisyon

> [!IMPORTANT]
> Apple’ın Mac chart’ında görünen her ürün native veya doğrulanmış bir Mac uygulaması değildir. Geometry Dash, MiLB ve Dive Log gibi ürünlerde chart placement ile ürün sayfasındaki platform bilgisi çelişmektedir. Bu kayıtlar çıkarılmadı; `platform inconsistency` olarak işaretlendi.

## Kapsam özeti

| Ölçü | Sonuç |
|---|---:|
| Tamamlanan yeni kategori | 5 |
| Free pozisyon | 25 |
| Paid pozisyon | 25 |
| Toplam yeni pozisyon | 50 |
| Faz 4 toplam kategori kapsamı | **20 / 20** |
| Faz 4 toplam Top-5 pozisyonu | **200 / 200** |
| Kesin USD paid fiyatı | 25 / 25 |
| Paid fiyat medyanı | $4.99 |
| Paid fiyat ortalaması | $10.23 |
| Paid fiyat aralığı | $0.99–$30.99 |

## Faz 4F ayrıntılı envanter

| Kategori | Liste | # | Uygulama | Apple ID | Fiyat | Model | Niş | Dağıtım | Doğrulama / not | Kaynak |
|---|---|---:|---|---:|---|---|---|---|---|---|
| Games | Free | 1 | Steam Link | 1246969117 | Free | FREE/SERVICE | Stream games from a Steam host computer | Universal Apple-platform app | About 2.9/349 ratings; macOS 10.13+; requires Steam host and network; v1.3.32 observed 2026-07-14. | [Apple App Store](https://apps.apple.com/us/app/steam-link/id1246969117?platform=mac) |
| Games | Free | 2 | Asphalt Legends: Racing Game | 1491129197 | Free + IAP | FREEMIUM/IAP | Free-to-play arcade racing | Only for Mac | Large 8.5 GB game; IAP/service economy; exact Mac rating evidence pending. | [Apple App Store](https://apps.apple.com/us/app/asphalt-legends-racing-game/id1491129197?mt=12) |
| Games | Free | 3 | Asphalt 8: Airborne | 610391947 | Free + IAP | FREEMIUM/IAP | Free-to-play arcade racing | Universal Apple-platform app | About 4.7/23K ratings; developer cites 470M players across the franchise/product ecosystem, not Mac installs. | [Apple App Store](https://apps.apple.com/us/app/asphalt-8-airborne/id610391947?platform=mac) |
| Games | Free | 4 | Solitaire Epic | 972224785 | Free | FREE | Offline solitaire card game | Only for Mac | Genuinely free local game; insufficient public rating overview. | [Apple App Store](https://apps.apple.com/us/app/solitaire-epic/id972224785?mt=12) |
| Games | Free | 5 | Resident Evil 4 | 6462360082 | Free demo + IAP | FREE-DEMO/PAID-UNLOCK | AAA survival-horror game | Universal iPhone/iPad/Mac | About 4.2/744 ratings; 62.6 GB download and roughly 70 GB storage; full game unlocked by IAP. | [Apple App Store](https://apps.apple.com/us/app/resident-evil-4/id6462360082?platform=mac) |
| Games | Paid | 1 | Palworld | 6503918400 | $29.99 | PAID/LIFE | Open-world survival and creature-collection game | Only for Mac / Apple silicon | 33.3 GB; hardware requirements materially narrow addressable Mac base. | [Apple App Store](https://apps.apple.com/us/app/palworld/id6503918400?mt=12) |
| Games | Paid | 2 | Geometry Dash | 625334537 | $3.99 | PAID/LIFE | Rhythm-based platform game | Designed for iPad; Mac chart placement | About 4.3/366 ratings; Apple page did not verify macOS compatibility despite #2 Mac Games paid placement. | [Apple App Store](https://apps.apple.com/us/app/geometry-dash/id625334537) |
| Games | Paid | 3 | Quiplash | 1002623276 | $9.99 | PAID/LIFE | Local/online party game | Only for Mac | Players use phones or browsers as controllers; insufficient Mac rating overview. | [Apple App Store](https://apps.apple.com/us/app/quiplash/id1002623276?mt=12) |
| Games | Paid | 4 | The Sims 2: Super Collection | 883782620 | $29.99 | PAID/LIFE | Life-simulation game collection | Only for Mac | 7.5 GB Aspyr Mac port; one-time purchase. | [Apple App Store](https://apps.apple.com/us/app/the-sims-2-super-collection/id883782620?mt=12) |
| Games | Paid | 5 | The Jackbox Party Pack 3 | 1156513849 | $24.99 | PAID/LIFE | Party-game collection | Only for Mac | One-time purchase; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/the-jackbox-party-pack-3/id1156513849?mt=12) |
| Social Networking | Free | 1 | WhatsApp Messenger | 310633997 | Free | FREE/SERVICE | Messaging, calling and communities | Universal Apple-platform app | Mac-filtered page about 4.7/123K; macOS 12.1+; WhatsApp's 2B+ user claim is all-platform, not Mac installs. | [Apple App Store](https://apps.apple.com/us/app/whatsapp-messenger/id310633997?platform=mac) |
| Social Networking | Free | 2 | Telegram | 747648890 | Free + IAP | FREE/SERVICE+IAP | Messaging, channels and communities | Only for Mac | Developer cites 500M active users across platforms; exact Mac installs unavailable. | [Apple App Store](https://apps.apple.com/us/app/telegram/id747648890?mt=12) |
| Social Networking | Free | 3 | WeChat | 836500024 | Free | FREE/SERVICE | Messaging, calls and social services | Only for Mac | Tencent service client; insufficient Mac rating overview. | [Apple App Store](https://apps.apple.com/us/app/wechat/id836500024?mt=12) |
| Social Networking | Free | 4 | Social App for Instagram ® | 6778116535 | Free + IAP | FREEMIUM/WRAPPER | Third-party Instagram desktop client | Only for Mac | Independent product not affiliated with Meta; premium multi-account/features. | [Apple App Store](https://apps.apple.com/us/app/social-app-for-instagram/id6778116535?mt=12) |
| Social Networking | Free | 5 | App for Facebook ® | 6762982925 | Free + IAP | FREEMIUM/WRAPPER | Third-party Facebook desktop client | Only for Mac | Independent wrapper; brand dependence and App Review sustainability risk. | [Apple App Store](https://apps.apple.com/us/app/app-for-facebook/id6762982925?mt=12) |
| Social Networking | Paid | 1 | Unite - GroupMe app | 1152517150 | $7.99 | PAID/LIFE | Native GroupMe client | Only for Mac | Paid native client fills an official-desktop experience gap. | [Apple App Store](https://apps.apple.com/us/app/unite-groupme-app/id1152517150?mt=12) |
| Social Networking | Paid | 2 | IRC Client: getIRC | 1250410012 | $4.99 | PAID/LIFE | IRC chat client | Only for Mac | Traditional protocol client with one-time purchase. | [Apple App Store](https://apps.apple.com/us/app/irc-client-getirc/id1250410012?mt=12) |
| Social Networking | Paid | 3 | Mango IRC | 431058916 | $12.99 | PAID/LIFE | IRCv3 chat client | Universal iPhone/iPad/Mac | One purchase across supported Apple devices. | [Apple App Store](https://apps.apple.com/us/app/mango-irc/id431058916) |
| Social Networking | Paid | 4 | IPYNB Reader Pro | 6661026035 | $1.99 | PAID/LIFE | Jupyter Notebook viewer | Only for Mac | Official functionality is developer/document viewing, not social networking; last observed update 2024-09-05; no data collected. | [Apple App Store](https://apps.apple.com/us/app/ipynb-reader-pro/id6661026035?mt=12) |
| Social Networking | Paid | 5 | YMailTab | 969085518 | $0.99 | PAID/LIFE | Third-party Yahoo Mail menu-bar client | Only for Mac | Single-purpose wrapper; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/ymailtab/id969085518?mt=12) |
| Sports | Free | 1 | TwiTracker : Stream Tracker | 6766197443 | Free + IAP | FREEMIUM/HYBRID | Streaming-channel analytics and tracking | Only for Mac | macOS 12.4+; insufficient ratings; IAP list shows weekly $4.99, monthly $8.99, yearly $29.99 and lifetime $49.99; pricing copy is internally inconsistent. | [Apple App Store](https://apps.apple.com/us/app/twitracker-stream-tracker/id6766197443?mt=12) |
| Sports | Free | 2 | MiLB | 508217833 | Free + IAP | FREE/SERVICE+SUB | Minor League Baseball scores and streaming | Designed for iPad; not verified for macOS | Appears #2 in Mac Sports chart despite Apple's product page saying not verified for macOS; about 3.5/23 ratings. | [Apple App Store](https://apps.apple.com/us/app/milb/id508217833) |
| Sports | Free | 3 | KOMA FOOTBALL | 6760620183 | Free + IAP | FREEMIUM/SERVICE | Football scores, fixtures and content | Mac-compatible listing | Recently indexed sports-service product; exact Mac rating evidence pending. | [Apple App Store](https://apps.apple.com/us/app/koma-football/id6760620183?platform=mac) |
| Sports | Free | 4 | Sleeper Sports | 987367543 | Free + service/IAP | FREE/SERVICE | Fantasy sports and social leagues | Mac-compatible listing | Revenue tied to fantasy/gaming service rather than Mac App Store purchase. | [Apple App Store](https://apps.apple.com/us/app/sleeper-sports/id987367543?platform=mac) |
| Sports | Free | 5 | SwingVision: Tennis Pickleball | 989461317 | Free + subscription | FREEMIUM/SUB | AI sports recording, scoring and analytics | Mac-compatible Apple-platform product | Camera/AI and sports-subscription ecosystem; Mac-specific demand unknown. | [Apple App Store](https://apps.apple.com/us/app/swingvision-tennis-pickleball/id989461317?platform=mac) |
| Sports | Paid | 1 | Competition Manager Tournament | 6738065604 | $2.99 | PAID/LIFE | Tournament and league manager | Only for Mac | Ten competition modes; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/competition-manager-tournament/id6738065604?mt=12) |
| Sports | Paid | 2 | KMZ Map Snapper | 1536694975 | $1.99 | PAID/LIFE | KMZ/KML map snapshot utility | Only for Mac | Official functionality is mapping rather than sports; category-noise signal. | [Apple App Store](https://apps.apple.com/us/app/kmz-map-snapper/id1536694975?mt=12) |
| Sports | Paid | 3 | Tournament Bracket Generator | 1380547373 | $2.99 | PAID/LIFE | Single-elimination bracket generator | Only for Mac | Supports up to 32 teams; narrow utility with chart visibility. | [Apple App Store](https://apps.apple.com/us/app/tournament-bracket-generator/id1380547373?mt=12) |
| Sports | Paid | 4 | Race Monitor | 539772389 | $4.99 | PAID/LIFE | RMonitor race timing client | Only for Mac | Requires compatible race-timing server; insufficient ratings and review-level stability concerns on Apple silicon. | [Apple App Store](https://apps.apple.com/us/app/race-monitor/id539772389?mt=12) |
| Sports | Paid | 5 | Dive Log | 301049600 | $14.99 + IAP | PAID+IAP | Scuba diving logbook | Designed for iPad; Mac chart placement | Apple page does not verify a Mac distribution despite #5 paid Mac Sports placement. | [Apple App Store](https://apps.apple.com/us/app/dive-log/id301049600) |
| Travel | Free | 1 | App For Google Maps | 6780524604 | Free + IAP | FREEMIUM/WRAPPER | Third-party Google Maps desktop client | Only for Mac | macOS 14.6+; weekly $4.99, monthly $14.99, yearly $39.99, lifetime $59.99; no-data-collected claim. | [Apple App Store](https://apps.apple.com/us/app/app-for-google-maps/id6780524604?mt=12) |
| Travel | Free | 2 | Flighty | 1358823008 | Free + subscription | FREEMIUM/SUB | Flight tracking and travel alerts | Universal Apple-platform app | About 4.8/11K ratings; Editors’ Choice; substantial free tier plus Pro. | [Apple App Store](https://apps.apple.com/us/app/flighty/id1358823008?platform=mac) |
| Travel | Free | 3 | App for Google Maps ° | 6783680900 | Free + IAP | FREEMIUM/WRAPPER | Third-party Google Maps client | Only for Mac | Near-duplicate naming; track ID required for reliable historical analysis. | [Apple App Store](https://apps.apple.com/us/app/app-for-google-maps/id6783680900?mt=12) |
| Travel | Free | 4 | Points Path | 6743861719 | Free + IAP/service | FREEMIUM/SERVICE | Travel rewards and points-path planning | Mac-compatible listing | Value depends on external travel loyalty and flight data. | [Apple App Store](https://apps.apple.com/us/app/points-path/id6743861719?platform=mac) |
| Travel | Free | 5 | Smart App for Google Maps | 6776244102 | Free + IAP | FREEMIUM/WRAPPER | Third-party Google Maps desktop client | Only for Mac | Three of the free Top 5 are unofficial map wrappers, indicating demand plus heavy naming saturation. | [Apple App Store](https://apps.apple.com/us/app/smart-app-for-google-maps/id6776244102?mt=12) |
| Travel | Paid | 1 | Road Trip Planner | 805071244 | $3.99 | PAID/LIFE | Road-trip route and itinerary planning | Only for Mac | Explicit no-subscription positioning; separate Lite acquisition funnel. | [Apple App Store](https://apps.apple.com/us/app/road-trip-planner/id805071244?mt=12) |
| Travel | Paid | 2 | GPX Viewer | 920631838 | $0.99 | PAID/LIFE | GPX route and track viewing | Only for Mac | Single-purpose local file viewer at the lowest paid-travel price. | [Apple App Store](https://apps.apple.com/us/app/gpx-viewer/id920631838?mt=12) |
| Travel | Paid | 3 | GPX Editor | 924782627 | $4.99 | PAID/LIFE | GPX route and waypoint editing | Only for Mac | Local specialist file editor. | [Apple App Store](https://apps.apple.com/us/app/gpx-editor/id924782627?mt=12) |
| Travel | Paid | 4 | Passport Photo - An ID App | 449746087 | $4.99 | PAID/LIFE | Passport and identity-photo preparation | Only for Mac | One-time local document/photo utility. | [Apple App Store](https://apps.apple.com/us/app/passport-photo-an-id-app/id449746087?mt=12) |
| Travel | Paid | 5 | myTracks | 403100976 | $17.99 | PAID/LIFE | GPS track management and photo geotagging | Only for Mac | 50+ logger presets, iCloud sync and professional local track workflow. | [Apple App Store](https://apps.apple.com/us/app/mytracks/id403100976?mt=12) |
| Weather | Free | 1 | RAD Weather | 6758575355 | Free + IAP | FREEMIUM/HYBRID | Weather forecasts, radar and alerts | Universal Apple-platform app | About 5.0/4 ratings; v7.6.8 observed 2026-07-11; optional subscription/lifetime; no-tracking claim. | [Apple App Store](https://apps.apple.com/us/app/rad-weather/id6758575355?platform=mac) |
| Weather | Free | 2 | Weather Dock: Desktop forecast | 886290397 | Free + IAP | FREEMIUM | Desktop and dock weather forecast | Only for Mac | About 4.5/7.6K ratings; strong evidence for a narrow Mac-native utility. | [Apple App Store](https://apps.apple.com/us/app/weather-dock-desktop-forecast/id886290397?mt=12) |
| Weather | Free | 3 | Mercury Weather | 1621800675 | Free + IAP | FREEMIUM/SUB | Native forecast and weather-history app | Universal Apple-platform app | Subscription/service layer; Mac-specific rating evidence pending. | [Apple App Store](https://apps.apple.com/us/app/mercury-weather/id1621800675?platform=mac) |
| Weather | Free | 4 | Moonlitt | 6444718902 | Free + IAP | FREEMIUM | Moon, sky and weather information | Mac-compatible listing | Specialist astronomy/weather hybrid. | [Apple App Store](https://apps.apple.com/us/app/moonlitt/id6444718902?platform=mac) |
| Weather | Free | 5 | Weather Widget Live | 1235020875 | Free + IAP | FREEMIUM | Desktop weather widget and forecast | Only for Mac | Classic Mac desktop-widget niche; exact current rating metadata pending. | [Apple App Store](https://apps.apple.com/us/app/weather-widget-live/id1235020875?mt=12) |
| Weather | Paid | 1 | RadarScope | 288419283 | $9.99 + subscriptions | PAID+SUB | Professional weather radar | Universal Apple-platform app | About 4.2/150 Mac-filtered ratings; upfront purchase plus professional radar-data tiers. | [Apple App Store](https://apps.apple.com/us/app/radarscope/id288419283?platform=mac) |
| Weather | Paid | 2 | Weather-Display | 1517712358 | $30.99 | PAID/LIFE | Personal weather-station monitoring and publishing | Only for Mac | Highest weather price; broad hardware integrations; dated-UI and compatibility complaints are support-risk signals. | [Apple App Store](https://apps.apple.com/us/app/weather-display/id1517712358?mt=12) |
| Weather | Paid | 3 | Living Weather & Wallpaper Pro | 572356996 | $5.99 | PAID/LIFE | Animated desktop weather and wallpaper | Only for Mac | Desktop ambience niche; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/living-weather-wallpaper-pro/id572356996?mt=12) |
| Weather | Paid | 4 | CARROT Weather | 993487541 | $14.99 + IAP | PAID+SUB | Personality-driven forecast and premium weather data | Only for Mac product page | Editors’ Choice; one-time base plus recurring tiers; insufficient current Mac rating overview. | [Apple App Store](https://apps.apple.com/us/app/carrot-weather/id993487541?mt=12) |
| Weather | Paid | 5 | Weather Dock+ | 571197687 | $4.99 | PAID/LIFE | Desktop/dock weather application | Only for Mac | One-time companion to free Weather Dock; insufficient rating overview. | [Apple App Store](https://apps.apple.com/us/app/weather-dock/id571197687?mt=12) |

## Platform tutarsızlıkları

| Uygulama | Mac chart konumu | Apple ürün sayfası | Sonuç |
|---|---|---|---|
| Geometry Dash | Games Paid #2 | Designed for iPad; Mac doğrulaması görünmüyor | Native Mac talebi sayılmamalı |
| MiLB | Sports Free #2 | Designed for iPad; `Not verified for macOS` | Mac chart placement ile platform metadata çelişiyor |
| Dive Log | Sports Paid #5 | Designed for iPad; Mac platformu doğrulanmıyor | Mac-native fırsat analizinden ayrı tutulmalı |

## Kategori kalite ve sınıflandırma sorunları

- IPYNB Reader Pro, işlev olarak Jupyter Notebook görüntüleyici olmasına rağmen Social Networking Paid #4.
- KMZ Map Snapper, bir harita aracı olmasına rağmen Sports Paid #2.
- App for YouTube önceki fazlarda hem Utilities hem Lifestyle chart’ında aynı kimlikle göründü; placement sayısı uygulama sayısı değildir.
- Travel Free Top 5’in üçü birbirine çok benzeyen üçüncü taraf Google Maps wrapper’ları.
- Wrapper ve yanlış kategorilenmiş uygulamalar chart talebini gösterir fakat sürdürülebilir ürün fırsatı, marka ve App Review riskleri nedeniyle ayrıca cezalandırılmalıdır.

## Faz 4F kategori sonuçları

- **Games free:** Free-to-play, service streaming ve demo-to-unlock modelleri baskın. Gerçekten ücretsiz Solitaire Epic istisna.
- **Games paid:** $3.99–$29.99 aralığında indie, party ve büyük oyunlar birlikte bulunuyor; depolama ve Apple-silicon gereksinimi erişilebilir pazarı önemli ölçüde etkiliyor.
- **Social free:** WhatsApp, Telegram ve WeChat gibi resmî servisler edinimi domine ediyor; üçüncü taraf Instagram/Facebook wrappers kalan boşluğu dolduruyor.
- **Social paid:** Native GroupMe ve IRC istemcileri kalıcı lisansla satılıyor. Kategori içi yanlış sınıflandırma, rekabet ölçümünü bozuyor.
- **Sports:** En zayıf ve gürültülü kategorilerden biri. Düşük rating hacimli yeni ürünler lider olabiliyor; platform tutarsızlıkları ve alakasız harita araçları bulunuyor.
- **Travel free:** Üç Google Maps wrapper’ı chart’a girmiş. Bu talep olduğunu gösterse de isim benzerliği, hizmet bağımlılığı ve marka riski yüksek.
- **Travel paid:** GPX, road-trip, passport photo ve GPS-track araçları $0.99–$17.99 kalıcı lisansla satılıyor; local-first masaüstü iş akışına güçlü örnek.
- **Weather free:** Subscription/hybrid ürünler ile binlerce Mac rating’i bulunan klasik Weather Dock aynı listede.
- **Weather paid:** Profesyonel radar ve kişisel hava istasyonu ürünleri daha yüksek fiyat alabilir; Weather-Display $30.99 ile kategori tavanı.

## Talep verisinin sınırları

- Hiçbir Faz 4F ürünü için kamuya açık doğrulanmış **Mac’e özel kesin download veya MAU** sayısı bulunmadı.
- Telegram’ın 500M aktif kullanıcı ve Asphalt 8’in 470M oyuncu açıklaması tüm platformları/ürün ekosistemini kapsar.
- Rating sayıları yalnızca demand proxy’dir; universal ürünlerde Mac payı bilinmez.
- Chart rank zaman damgalı bir görünüm olup kalıcı pazar payı değildir.

## Faz 4 tamamlanma özeti

| Alt faz | Kategori | Pozisyon |
|---|---:|---:|
| 4C | 5 | 50 |
| 4D | 5 | 50 |
| 4E | 5 | 50 |
| 4F | 5 | 50 |
| **Toplam** | **20 / 20** | **200 / 200** |

## Sıradaki çalışma — Faz 5A

1. Chart rank, Mac rating, rating güveni ve update recency’den demand proxy score.
2. Paid price, IAP/subscription netliği ve lifetime seçeneğinden monetization score.
3. Platform tutarlılığı, marka bağımlılığı, App Review ve maintenance risk score.
4. Geliştirme maliyeti, support yükü ve offline yapılabilirlik skoru.
5. 200 chart pozisyonu ile 739 chart-dışı uygulamadan en iyi fırsatların kısa listesi.

**Sürüm:** 4F — 2 Ağustos 2026

# Faz 5A — Fırsat Skorlama Modeli ve İlk Kısa Liste

**Analiz tarihi:** 2 Ağustos 2026  
**Temel veri:** 739 chart-dışı kayıt + 200 Top-5 chart pozisyonu  
**Doğrudan kaynak bağlantılı ayrıştırılan ürün satırı:** 904  
**Ayrıştırılan benzersiz Apple kimliği:** 864  
**Puanlanan fırsat kümesi:** 30

> [!IMPORTANT]
> Ham skor doğrudan “bu uygulamayı yap” kararı değildir. Skor önce pazar sinyalini ölçer; ardından regülasyon, güvenlik, ücretsiz incumbent, marka bağımlılığı, sandbox ve destek maliyeti için `kill-filter` uygulanır.

## 1. Skor modeli — 100 puan

| Bileşen | Maksimum | Hesaplama mantığı |
|---|---:|---|
| Talep kanıtı | 25 | Top-5 rank ağırlığı, chart-dışı ürün yoğunluğu, yerel storefront chart ve dış benchmark sinyali |
| Monetizasyon | 20 | Paid chart, doğrulanmış fiyatlar, lifetime/IAP/subscription varlığı |
| Rekabet boşluğu | 15 | Benzersiz rakip yoğunluğunun ters skoru ve güçlü dış incumbent cezası |
| Yapılabilirlik | 15 | Solo/native Mac geliştirme zorluğu, teknoloji ve test yükü |
| Offline/native uyum | 10 | İnternetsiz değer, yerel veri ve masaüstüne doğal uyum |
| Mac App Store uyumu | 15 | Sandbox, marka/telif, regülasyon, gizlilik ve review riski |
| **Toplam** | **100** | Ham fırsat skoru |

## 2. Kill-filter

Ham skorun ardından aşağıdaki kırmızı bayraklar uygulanır:

1. Sağlık, tıp, finans veya password-security güven sorumluluğu.
2. Ücretsiz ve güçlü açık kaynak incumbent.
3. Üçüncü taraf marka/wrapper bağımlılığı.
4. Çok yüksek rakip yoğunluğu ve kolay kopyalanan özellik seti.
5. Mac App Store sandbox ile çelişen geniş dosya veya background erişimi.
6. Lisanslı içerik/corpus üretim maliyeti.
7. Cihaz, protokol veya dış hizmet destek matrisinin sürekli büyümesi.

## 3. Tüm fırsat kümeleri

| # | Fırsat kümesi | Ham skor | Talep /25 | Monetizasyon /20 | Boşluk /15 | Build /15 | Offline /10 | MAS /15 | Benzersiz rakip | Top-5 placement | Paid placement | Yerel chart | Medyan fiyat | Karar |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | Native RSS / Read-Later | **78.9** | 25.0 | 17.8 | 3.1 | 12 | 7 | 14 | 13 | 6 | 4 | 0 | $9.99 | C — Defer |
| 2 | Local Personal Finance / Checkbook | **76.0** | 25.0 | 19.0 | 2.0 | 9 | 9 | 12 | 19 | 5 | 4 | 0 | $20.49 | C — Defer |
| 3 | GPX & Photo Geotagging Toolkit | **72.2** | 17.8 | 13.6 | 4.8 | 12 | 10 | 14 | 7 | 3 | 3 | 0 | $4.99 | A — Flagship deep dive |
| 4 | Tournament & League Manager | **70.5** | 10.2 | 10.6 | 10.7 | 14 | 10 | 15 | 2 | 2 | 2 | 0 | $2.99 | A — Quick-win deep dive |
| 5 | Medical Anatomy Reference | **68.0** | 23.1 | 18.7 | 4.2 | 5 | 9 | 8 | 6 | 6 | 4 | 0 | $15.99 | C — Reject now |
| 6 | Recipe & Meal Planner | **67.7** | 15.4 | 13.5 | 2.9 | 11 | 10 | 15 | 14 | 1 | 1 | 0 | $19.99 | C — Defer |
| 7 | Offline Specialist Dictionary | **65.9** | 19.4 | 9.2 | 3.2 | 11 | 10 | 13 | 18 | 3 | 1 | 0 | — | C — Defer |
| 8 | Local Photo Deduper | **63.8** | 6.6 | 11.2 | 10.9 | 11 | 10 | 14 | 1 | 1 | 1 | 0 | $14.99 | A — Flagship deep dive |
| 9 | Mac Launcher / Switcher | **62.6** | 15.2 | 8.4 | 2.0 | 13 | 10 | 14 | 23 | 0 | 0 | 2 | $9.99 | C — Defer |
| 10 | Audiobook Builder | **62.3** | 8.8 | 7.8 | 8.7 | 13 | 10 | 14 | 2 | 2 | 2 | 0 | — | A — Flagship deep dive |
| 11 | Camera Metadata & Shutter Utility | **61.9** | 5.4 | 11.7 | 9.7 | 11 | 10 | 14 | 2 | 2 | 2 | 0 | $5.99 | A — Flagship deep dive |
| 12 | Text Expansion & Team Snippets | **60.7** | 12.7 | 8.5 | 3.5 | 13 | 10 | 13 | 16 | 0 | 0 | 1 | $14.99 | C — Defer |
| 13 | Passport / ID Photo Maker | **60.5** | 3.3 | 9.3 | 11.9 | 12 | 10 | 14 | 1 | 1 | 1 | 0 | $4.99 | A — Quick-revenue deep dive |
| 14 | App Store Screenshot & Localization Studio | **59.3** | 8.6 | 8.6 | 6.1 | 12 | 9 | 15 | 13 | 0 | 0 | 0 | $6.99 | B — Validate |
| 15 | Local Meeting Transcriber | **58.7** | 17.7 | 9.0 | 2.0 | 8 | 9 | 13 | 33 | 0 | 0 | 1 | $12.99 | C — Defer |
| 16 | Offline OCR Menu-Bar Capture | **57.7** | 10.5 | 9.0 | 4.2 | 11 | 10 | 13 | 18 | 0 | 0 | 0 | $15.49 | B — Validate |
| 17 | Local Translation Overlay | **57.6** | 18.0 | 8.5 | 2.0 | 9 | 8 | 12 | 25 | 3 | 0 | 0 | $9.99 | C — Defer |
| 18 | Mac–Android Local File Transfer | **56.9** | 15.8 | 3.7 | 3.4 | 11 | 10 | 13 | 8 | 0 | 0 | 1 | — | C — Defer monetization |
| 19 | Weather Station Dashboard | **56.4** | 8.9 | 13.8 | 9.7 | 7 | 5 | 12 | 2 | 2 | 2 | 0 | $30.99 | C — Specialist only |
| 20 | Academic Reference & BibTeX Manager | **56.3** | 9.4 | 9.6 | 5.3 | 9 | 9 | 14 | 12 | 0 | 0 | 0 | $9.99 | B — Validate |
| 21 | Local-First Personal CRM | **54.1** | 8.6 | 3.4 | 6.2 | 12 | 10 | 14 | 6 | 0 | 0 | 0 | — | A — Flagship deep dive |
| 22 | DICOM Quick Look / Viewer | **53.4** | 6.2 | 9.6 | 9.7 | 7 | 10 | 11 | 2 | 2 | 1 | 0 | $5.99 | B — Expert-only validate |
| 23 | Encrypted Notes & File Vault | **53.3** | 8.2 | 7.5 | 5.5 | 10 | 10 | 12 | 11 | 0 | 0 | 0 | $8.49 | C — Defer |
| 24 | Symptom & Medication Journal | **52.0** | 3.1 | 7.2 | 10.7 | 11 | 10 | 10 | 2 | 2 | 1 | 0 | — | B — Specialist validate |
| 25 | Screenshot Annotation | **51.8** | 6.2 | 0.0 | 7.6 | 13 | 10 | 15 | 5 | 0 | 0 | 0 | — | B — Validate |
| 26 | Secure Password / KeePass Client | **51.2** | 12.1 | 10.1 | 2.1 | 8 | 9 | 10 | 13 | 0 | 0 | 1 | $24.99 | C — Reject now |
| 27 | Shortcuts Event Automation | **50.9** | 5.0 | 0.0 | 9.9 | 13 | 10 | 13 | 1 | 0 | 0 | 0 | — | B — Validate |
| 28 | UYAP/UDF Legal Document Studio | **47.3** | 9.7 | 0.0 | 9.6 | 8 | 9 | 11 | 5 | 0 | 0 | 1 | — | B — Validate |
| 29 | HomeKit Camera Dashboard | **46.7** | 2.1 | 5.7 | 10.9 | 8 | 7 | 13 | 1 | 1 | 1 | 0 | — | B — Specialist validate |
| 30 | Finder Watched-Folder Automation | **41.9** | 8.2 | 0.0 | 7.7 | 10 | 10 | 6 | 2 | 0 | 0 | 0 | — | C — Direct-distribution candidate |

## 4. Faz 5A deep-dive kısa listesi

### Flagship adayları

| Öncelik | Ürün yönü | Neden kısa listede? | Dünya-klası farklılaşma | İlk fiyat hipotezi |
|---:|---|---|---|---|
| 1 | **GPX & Photo Geotagging Toolkit** | Paid chart’ta üç ayrı doğrulama, profesyonel masaüstü işi ve kontrollü rakip yoğunluğu. | GPX repair + photo/video geotag + privacy scrub + Apple Photos/Lightroom export + offline map workspace. | $19.99–29.99 lifetime; optional paid major upgrades. |
| 2 | **Local Photo Deduper** | $14.99 paid-chart kanıtı, tek ana eşleşen rakip ve yüksek local-first değer. | RAW/sidecar/burst-aware similarity, reversible cleanup, iCloud Photos-safe review and storage savings preview. | $19.99–29.99 lifetime; free scan, paid cleanup. |
| 3 | **Audiobook Builder** | İki ücretli Top-5 ürün, düşük yoğunluk ve yaşlanan klasik iş akışını modernleştirme fırsatı. | Local chapter detection, M4B validation, loudness normalization, cover/metadata, batch jobs and transcript-assisted chapters. | $19.99–29.99 lifetime. |
| 4 | **Camera Metadata & Shutter Utility** | İki ücretli Top-5 ürün; fotoğrafçıların net ve pahalı zaman kaybını çözüyor. | Camera health report + shutter count + card ingest + safe rename + sidecar/EXIF audit + GoPro workflow. | $14.99–24.99 lifetime; optional camera-family packs only if necessary. |
| 5 | **Local-First Personal CRM** | Rakip sayısı düşük; privacy-first, no-account ürün için geniş özellik ve fiyat alanı. | No account, on-device relationship timeline, follow-up engine, contacts/calendar imports and local AI summaries. | Free limited tier + $29.99–49.99 lifetime; optional team subscription later. |

### Hızlı gelir / daha küçük MVP adayları

| Öncelik | Ürün yönü | Kullanım | Farklılaşma | Fiyat hipotezi |
|---:|---|---|---|---|
| 1 | **Passport / ID Photo Maker** | Global, tekrarlanan ve kolay anlatılan problem | On-device background correction, country-rule database, family batch, print sheets and biometric validation. | $9.99–14.99 lifetime or pay-per-export packs. |
| 2 | **Tournament & League Manager** | Küçük fakat düşük rekabetli paid-chart pazarı | Flexible brackets/leagues, offline venue mode, live display, print/PDF export and season statistics. | $7.99–14.99 lifetime. |

### İkinci doğrulama kuyruğu

| Ürün yönü | Gerekli kanıt |
|---|---|
| App Store Screenshot & Localization Studio | Rakip yorumlarında localization/export/automation şikâyetleri ve geliştirici ödeme isteği |
| Offline OCR Menu-Bar Capture | OCR doğruluğu değil, kullanıcıların hangi post-processing ve automation için ödeme yaptığı |
| Shortcuts Event Automation | Shortery kullanıcılarının eksik gördüğü trigger, condition, logging ve debugging ihtiyaçları |
| UYAP/UDF Legal Document Studio | Avukat sayısı, aktif Mac kullanımı, UDF hacmi, e-imza teknik gereksinimleri ve yerel fiyat |
| Academic Reference & BibTeX Manager | Zotero/Bookends/Papers kullanıcılarının en ağır günlük sürtünmeleri |

## 5. Ham skoru yüksek olup elenen alanlar

| Alan | Ham skor | Neden şimdi yapılmıyor? |
|---|---:|---|
| Native RSS / Read-Later | 78.9 | Talep güçlü fakat 13 rakip, yerleşik markalar ve çevrim içi içerik bağımlılığı |
| Local Personal Finance / Checkbook | 76.0 | Güçlü ödeme sinyali fakat 19 rakip, finans verisi güveni ve sürekli destek yükü |
| Medical Anatomy Reference | 68.0 | İçerik üretimi/lisans, 3D maliyeti ve tıbbi kalite sorumluluğu |
| Recipe & Meal Planner | 67.7 | Talep var; Paprika gibi güçlü incumbent ve 14 rakip |
| Mac Launcher / Switcher | 62.6 | 23 rakip ve kolay kopyalanan özellikler |
| Local Meeting Transcriber | 58.7 | 33 rakip; MacWhisper çok gelişmiş local/offline özellik setine sahip |
| Mac–Android Local File Transfer | 56.9 | LocalSend ücretsiz, açık kaynak ve çok platformlu; gelir alanı zayıf |
| Finder Watched-Folder Automation | 41.9 | Hazel ödeme isteğini doğruluyor ancak App Store sandbox tam kapsamlı rakibi zorlaştırıyor |

## 6. Dış benchmark doğrulaması

- **Hazel 6:** Tek kullanıcı lisansı $42, aile lisansı $65 ve upgrade $20. Bu, dosya otomasyonunda ödeme isteğini doğruluyor; ancak ürün Mac App Store dışı geniş sistem erişimiyle avantajlı. [Resmî Hazel FAQ](https://www.noodlesoft.com/kb/hazel-6-faq/)
- **MacWhisper:** Yerel modeller, offline çalışma, speaker recognition, 100+ dil, batch processing ve transcript search sunuyor. Basit Whisper wrapper ile rekabet etmek mantıklı değil. [Resmî MacWhisper](https://www.macwhisper.com/)
- **LocalSend:** Tamamen ücretsiz/açık kaynak; macOS, Windows, Linux, Android ve iOS arasında internetsiz, şifreli LAN aktarımı yapıyor. [Resmî LocalSend](https://localsend.org/)
- **HoudahGeo 7:** Fotoğraf/video geotagging alanında aktif uzman incumbent; lisans kalıcı ve 12 aylık update dönemi kullanıyor, v7 upgrade $21. [Resmî HoudahGeo pricing](https://www.houdah.com/houdahGeo/buy.html)
- **Shortery:** Uygulama, ses, calendar, camera, device, folder, network, power, screen ve uyku gibi geniş trigger seti sunuyor. Yeni ürün yalnızca birkaç trigger ekleyerek farklılaşamaz. [Apple ürün sayfası](https://apps.apple.com/us/app/shortery/id1594183810?mt=12)
- **Contacts Journal:** Mac/iOS’ta free-to-try, hesap zorunluluğu olmadan contact history ve follow-up işi sunuyor. Personal CRM adayında privacy ve kullanım kolaylığı çıtası buradan başlamalı. [Resmî Contacts Journal](https://www.contactsjournal.com/)
- **Audiobook Builder 2:** Klasik ürün hâlâ güncelleniyor; modern rakip salt MP3→M4B dönüşümünden fazlasını sunmalı. [Resmî ürün sayfası](https://www.splasm.com/audiobookbuilder/index.html)

## 7. Faz 5A kararı

**Henüz tek uygulama seçilmedi.** Faz 5A’nın amacı, yüksek skorla iyi proje arasındaki farkı ortaya çıkarmaktı.

Bir sonraki derin araştırma sırası:

1. GPX & Photo Geotagging Toolkit
2. Local Photo Deduper
3. Audiobook Builder
4. Camera Metadata & Shutter Utility
5. Local-First Personal CRM
6. Passport / ID Photo Maker
7. Tournament & League Manager

## Faz 5B sonraki çalışma

1. İlk 7 aday için App Store yorum ve şikâyet madenciliği.
2. App Store dışı doğrudan satış rakiplerinin fiyat, özellik ve update modeli.
3. Her aday için gerçek MVP kapsamı, teknik risk ve 6–12 aylık destek yükü.
4. Arama talebi, topluluk konuşmaları ve satın alma niyeti kanıtı.
5. Yedi adayı üç finaliste indiren ikinci sayısal model.

**Sürüm:** 5A — 2 Ağustos 2026

# Faz 5B — Kullanıcı Şikâyeti Madenciliği ve Üç Finalist

**Araştırma tarihi:** 2 Ağustos 2026  
**İncelenen aday:** 7  
**Finalist:** 3  
**Kaynak türleri:** Apple ürün/review sayfaları, geliştirici resmî siteleri, güncel fiyat sayfaları, Reddit ve bağımsız ürün incelemeleri

> [!IMPORTANT]
> Kamuya açık kesin Mac indirme/MAU verisi bulunmadığı için karar; chart görünürlüğü, rating/review içeriği, doğrulanmış fiyat, rakip yoğunluğu, ürün savunması ve teknik destek yükünün birleşimine dayanır.

## 1. Faz 5B yeniden puanlama modeli

| Bileşen | Maksimum | Açıklama |
|---|---:|---|
| Doğrulanmış talep | 25 | Chart, rating, problem tekrar sıklığı ve kullanım bağlamı |
| Ödeme isteği | 20 | Doğrulanmış fiyatlar, lifetime/subscription ve rakip gelir modeli |
| Kullanıcı şikâyeti boşluğu | 20 | Rakiplerin çözemediği tekrarlanan sorunlar |
| Teknik yapılabilirlik | 15 | Solo native Mac ekibiyle kaliteye ulaşma olasılığı |
| 12 aylık bakım avantajı | 10 | Dış API, format, cihaz ve regülasyon yükünün düşüklüğü |
| Stratejik Mac uyumu | 10 | Offline/local-first, desktop workflow ve premium marka potansiyeli |
| **Toplam** | **100** | Kanıt sonrası finalist skoru |

## 2. Yedi adayın sonuç tablosu

| # | Aday | Skor | Talep | Ödeme | Şikâyet boşluğu | Build | Bakım | Mac uyumu | Karar | Güven |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 1 | **Local Photo Deduper** | **85** | 23 | 17 | 14 | 13 | 8 | 10 | FINALIST | Yüksek |
| 2 | **GPX & Photo Geotagging Toolkit** | **80** | 20 | 17 | 16 | 11 | 7 | 9 | FINALIST | Orta-Yüksek |
| 3 | **Local-First Personal CRM** | **76** | 19 | 16 | 15 | 10 | 6 | 10 | FINALIST | Orta |
| 4 | **Passport / ID Photo Maker** | **71** | 18 | 15 | 13 | 12 | 5 | 8 | YEDEK / QUICK REVENUE | Orta |
| 5 | **Audiobook Builder** | **67** | 13 | 12 | 14 | 13 | 8 | 7 | YEDEK | Orta |
| 6 | **Tournament & League Manager** | **66** | 12 | 10 | 14 | 14 | 9 | 7 | QUICK WIN, FLAGSHIP DEĞİL | Orta |
| 7 | **Camera Metadata & Shutter Utility** | **56** | 14 | 11 | 10 | 9 | 4 | 8 | ELENDİ | Orta-Yüksek |

## 3. Finalistler

### Finalist 1 — Local Photo Deduper

**Neden birinci:** Problem çok geniş, kullanıcı açısından finansal ve duygusal maliyeti yüksek, tamamen cihaz üzerinde çözülebiliyor ve hiçbir üçüncü taraf hizmete bağlı değil.

**Kanıtlar:**

- PhotoSweeper Mac App Store’da $14.99 ve Apple Photos, Lightroom Classic, Capture One, klasörler ve harici diskleri destekliyor. [Apple](https://apps.apple.com/us/app/photosweeper/id463362050?mt=12)
- Bir kullanıcı 140.000 fotoğraflık, yaklaşık 0,5 TB arşivde ürünü başarıyla kullanmış; ancak doğrulamayı parçalara bölme yöntemini geliştiriciye sormak zorunda kalmış. [Apple reviews](https://apps.apple.com/nl/app/photosweeper/id463362050)
- Başka bir kullanıcı ürünün 15.000 civarında duplicate/küçük fotoğrafı temizlediğini fakat zaman zaman crash yaşadığını bildiriyor. [Apple reviews](https://apps.apple.com/us/app/photosweeper/id463362050?mt=12&platform=mac&see-all=reviews)
- Duplicate Photos Fixer incelemelerinde close match’lerin duplicate sayılması ve yanlış seçimden kaçınmak için sensitivity ayarı ihtiyacı öne çıkıyor. [Apple reviews](https://apps.apple.com/us/app/duplicate-photos-fixer-pro/id963642514?mt=12&platform=mac&see-all=reviews)
- Gemini 2 hızlı ve güçlü bulunuyor; ancak daha fazla filtre, scheduling ve App Store/Setapp sürüm netliği isteniyor. [Macworld review](https://www.macworld.com/article/2434914/gemini-2-duplicate-file-finder-review.html)

**Kazandıracak farklılaşma:**

1. RAW + JPEG + sidecar dosyalarını tek çekim grubu olarak anlama.
2. Burst, Live Photo, edited original ve exported copy ilişkilerini açıklama.
3. `Silmeden önce ne olacak?` simülasyonu ve geri alınabilir karantina.
4. Büyük arşivlerde scan oturumu kaydetme ve günler sonra devam etme.
5. Her otomatik seçimin nedenini açıkça gösterme.
6. iCloud Photos için “indiriliyor/optimize edilmiş/orijinal erişilemiyor” güven kontrolleri.

**12 aylık teknik risk:** Orta. En büyük risk algoritma değil, güvenli silme ve farklı photo-library durumlarıdır.

### Finalist 2 — GPX & Photo Geotagging Toolkit

**Neden ikinci:** Profesyonel kullanıcıların kalıcı lisansa ödeme yaptığı doğrulanmış; iş akışı Mac’e doğal oturuyor ve mevcut ürünler güçlü olsa da parçalı.

**Kanıtlar:**

- HoudahGeo’nun güncel başlangıç fiyatı yaklaşık $39 ve ürün kalıcı lisans modeli kullanıyor. [Resmî fiyat](https://www.houdah.com/houdahGeo/buy.html)
- HoudahGeo GPX/KML/NMEA, EXIF/XMP/IPTC ve Apple Photos iş akışlarını destekleyen olgun incumbent. [Resmî ürün](https://www.houdah.com/houdahGeo/)
- Bağımsız inceleme, ürünün Apple Photos ile entegrasyonunu överken mobil companion eksikliğine dikkat çekiyor. [Macworld](https://www.macworld.com/article/234182/houdahgeo-6-review.html)
- Ücretsiz GeoTag, harita üzerinden konum seçme ve ExifTool ile metadata yazma işini karşılıyor; dolayısıyla ücretli ürün yalnızca manuel pinleme olamaz. [Apple](https://apps.apple.com/us/app/geotag/id1465180184?mt=12)

**Kazandıracak farklılaşma:**

1. Bozuk/eksik GPX rotasını görsel olarak tamir etme.
2. Kamera saati drift ve timezone sorunlarını otomatik tahmin etme.
3. Fotoğrafın yanında video ve sidecar metadata desteği.
4. Yayınlamadan önce konum mahremiyeti temizliği.
5. Apple Photos ve Lightroom’a kayıpsız, geri alınabilir export.
6. Hatalı timestamp/location eşleşmesini güven puanıyla işaretleme.

**12 aylık teknik risk:** Orta-yüksek. Format çeşitliliği ve metadata güvenliği ciddi test matrisi gerektirir; dış servis bağımlılığı düşük tutulabilir.

### Finalist 3 — Local-First Personal CRM

**Neden üçüncü:** En geniş uzun vadeli ürün vizyonuna sahip aday. Kullanıcı ürüne yıllarca veri eklediği için retention ve fiyat gücü yüksek olabilir; privacy-first konumlandırma güçlü.

**Kanıtlar:**

- Contacts Journal hesap açmadan, kişinin Apple cihazlarında ve iCloud’unda çalışan personal CRM sunuyor. [Resmî site](https://www.contactsjournal.com/)
- Güncel başlangıç rehberi, Mac ve iOS uygulamalarının ücretsiz indirildiğini; sınırsız kullanım için Unlimited Personal Plan gerektiğini belirtiyor. [Resmî yardım](https://contactsjournal.zendesk.com/hc/en-us/articles/360014701851-Getting-Started-with-Contacts-Journal)
- Bir App Store kullanıcısı ürünün faydasını kabul ederken yaklaşık £60 peşin fiyatı yüksek buluyor ve yıllık seçenek istiyor; map popup’larından şikâyet ediyor. [Apple reviews](https://apps.apple.com/gb/app/916377538?platform=mac&see-all=reviews)
- Başka kullanıcılar tek seferlik $25 civarı kişisel planın pahalı CRM aboneliklerine göre önemli değer sunduğunu belirtiyor. [Apple](https://apps.apple.com/us/app/contacts-journal-crm/id327685977)
- Reddit kullanıcıları iPhone, iPad ve Mac arasında sync’in çalıştığını ve ürünü satın aldıktan sonra ihtiyaçlarını karşıladığını bildiriyor. [Reddit](https://www.reddit.com/r/macapps/comments/18k6mqr/contacts_journal_crm/)

**Kazandıracak farklılaşma:**

1. Geleneksel CRM dashboard’u yerine günlük `Kimle ilgilenmeliyim?` inbox’ı.
2. Relationship timeline ve görüşme/not bağlamını local AI ile özetleme.
3. Hesapsız çalışma, açık JSON/CSV export ve vendor lock-in olmaması.
4. Kullanıcının kontrol ettiği iCloud private database.
5. Kişi sayısı arttıkça bozulan tag/import karmaşasını akıllı collection’larla çözme.
6. Daha ulaşılabilir lifetime fiyat ve isteğe bağlı yıllık major-upgrade modeli.

**12 aylık teknik risk:** Yüksek. Sync çatışması, veri migration, izinler ve kullanıcının yıllarca sakladığı kişisel veriye güven kritik.

## 4. Elenen/yedek adaylar

### Passport / ID Photo Maker — hızlı gelir için güçlü, flagship için riskli

- Pazar net: fiziksel passport fotoğrafı genellikle $7–17; kullanıcı yazılımla doğrudan para tasarrufu görebiliyor. [PhotoAiD cost guide](https://photoaid.com/blog/passport-photos-how-much/)
- Ürünler 100 ülke için template, background replacement ve print sheet sunuyor. [Apple](https://apps.apple.com/us/app/passport-photo-id-photo/id917389447)
- Kritik şikâyet: bazı uygulamalar dosyayı aşırı küçültüp resmî başvuruda kabul edilmeyecek kaliteye indirebiliyor. [Apple reviews](https://apps.apple.com/us/app/id-photo-passport-photo-app/id1599080641?platform=mac&see-all=reviews)
- Ülke ve belge kuralları sürekli değişir; reddedilen fotoğraf support ve itibar maliyeti yaratır.

### Audiobook Builder — temiz niş, fakat pazar/fiyat tavanı düşük

- Audiobook Builder 2 Mac App Store’da $9.99; major-version lisansı ve aboneliksiz model kullanıyor. [Resmî site](https://www.splasm.com/audiobookbuilder/)
- Kullanıcılar kolay kullanım ve “just works” deneyimini övüyor; diğerleri tutarlı export hataları ve CD metadata sorunları bildiriyor. [Apple reviews](https://apps.apple.com/us/app/audiobook-builder-2/id1437681957?mt=12&platform=mac&see-all=reviews)
- Rakibi yenmek mümkün fakat premium fiyatı yükseltmek için transcript/chapter/loudness gibi daha büyük kapsam gerekiyor.

### Tournament Manager — iyi quick win, küçük tavan

- Kullanıcılar arbitrary participant count ve otomatik bye eksikliğini gerçek etkinlikleri engelleyen kritik kusur olarak görüyor. [Apple reviews](https://apps.apple.com/gb/app/tournament-maker-bracket-app/id6677026679)
- Duplicate teams, existing tournament edit crash ve tek seferlik reklamsız seçenek eksikliği raporlanıyor. [Apple reviews](https://apps.apple.com/us/app/tournament-mgr/id1139864823)
- Teknik olarak yapılabilir ve ücretli satış mümkün; ancak toplam Mac pazarı flagship hedefi için küçük.

### Camera Metadata & Shutter Utility — destek matrisi öldürüyor

- ShutterCount Mac sürümü $9.99, Pro sürümü $19.99. [Resmî fiyat](https://www.direstudio.com/shuttercount/)
- Kullanıcılar doğru çalışmasını övse de yalnızca shutter count için fiyatı yüksek bulabiliyor. [Apple reviews](https://apps.apple.com/us/app/shuttercount/id720123827?mt=12&platform=mac&see-all=reviews)
- 2026’da çok sayıda ücretsiz online shutter-count aracı mevcut; ücretli ürün kamera bağlantısı ve model desteğini sürekli güncellemek zorunda. [ShutterCount.net](https://shuttercount.net/)

## 5. Finalist karşılaştırması

| Kriter | Photo Deduper | GPX/Geotagging | Personal CRM |
|---|---:|---:|---:|
| Problem sıklığı | Çok yüksek | Orta | Yüksek |
| Acı/zarar seviyesi | Yüksek | Yüksek profesyonel | Orta-yüksek |
| Kanıtlanmış ödeme | Güçlü | Güçlü | Güçlü fakat fiyat hassas |
| Rakip savunması | Orta-güçlü | Güçlü | Orta |
| Offline yapılabilirlik | Tam | Çok yüksek | Çok yüksek |
| App Store uygunluğu | Yüksek | Yüksek | Yüksek |
| Teknik karmaşıklık | Orta | Orta-yüksek | Yüksek |
| 12 aylık support | Orta | Orta-yüksek | Yüksek |
| Global pazar | Çok geniş | Profesyonel niş | Geniş |
| Premium marka potansiyeli | Çok yüksek | Çok yüksek | Çok yüksek |
| İlk gelir süresi | En hızlı | Orta | En yavaş |
| Uzun vadeli genişleme | Yüksek | Orta-yüksek | En yüksek |

## 6. Faz 5B kararı

### Mevcut sıralama

1. **Local Photo Deduper — en iyi risk/getiri dengesi**
2. **GPX & Photo Geotagging Toolkit — en güçlü profesyonel niş**
3. **Local-First Personal CRM — en büyük uzun vadeli vizyon**

Bu aşamada tek ürün seçilmedi. Bir sonraki turda üç finalist için:

1. 100+ kullanıcı şikâyetinin tema haritası.
2. Feature-by-feature rakip matrisi.
3. App Store keyword ve arama niyeti haritası.
4. 8 haftalık MVP ve 12 aylık dünya-klası roadmap.
5. Birim ekonomi, fiyat testi ve gerçekçi satış senaryosu.
6. Son seçim için `Winning Product Score`.

## Faz 5C sonraki çalışma

**Photo Deduper vs GPX/Geotagging vs Personal CRM** arasında derin finalist savaşı ve tek ürün seçimi.

**Sürüm:** 5B — 2 Ağustos 2026

# Faz 5C — Üç Finalist Savaşı ve Tek Ürün Seçimi

**Karar tarihi:** 2 Ağustos 2026  
**Finalistler:** Local Photo Deduper, GPX & Photo Geotagging Toolkit, Local-First Personal CRM  
**Kazanan:** **Local Photo Library Triage**  
**Çalışma adı:** `Photo Triage` — nihai marka adı değildir  
**Ürün sınıfı:** Local-first, privacy-first, native macOS photo library cleanup and review

> [!IMPORTANT]
> Seçilen ürün basit bir “duplicate finder” değildir. Apple Photos zaten Duplicates koleksiyonu sunuyor; PhotoSweeper ve Gemini 2 de olgun rakiplerdir. Kazanan tez, kullanıcının büyük ve karmaşık arşivini **güvenle incelemesi, kararları anlaması ve hiçbir anıyı yanlışlıkla kaybetmeden temizlemesi** üzerine kuruludur.

## 1. Final Winning Product Score

| Kriter | Ağırlık | Photo Library Triage | GPX / Geotagging | Personal CRM |
|---|---:|---:|---:|---:|
| Pazar genişliği | 20 | **18** | 12 | 16 |
| Doğrulanmış ödeme isteği | 15 | **14** | 14 | 13 |
| Kullanıcı acısı ve açık ürün boşluğu | 15 | **13** | 14 | 12 |
| Solo/native Mac yapılabilirliği | 15 | **13** | 11 | 8 |
| 12 aylık bakım avantajı | 10 | **9** | 7 | 5 |
| Mac App Store uygunluğu | 10 | **10** | 9 | 9 |
| İlk gelir hızı | 5 | **5** | 4 | 2 |
| Uzun vadeli genişleme | 10 | **9** | 8 | 10 |
| **Toplam** | **100** | **91** | **79** | **75** |

### Sonuç

1. **Local Photo Library Triage — 91/100**
2. **GPX & Photo Geotagging Toolkit — 79/100**
3. **Local-First Personal CRM — 75/100**

Photo ürününün avantajı yalnızca daha geniş pazar değildir. Üç kritik özellik aynı anda bulunmaktadır:

- İlk değer dakikalar içinde gösterilebilir.
- Temel ürün tamamen cihaz üzerinde çalışabilir.
- Her yeni kullanıcı kendi fotoğraf kütüphanesiyle doğal biçimde bir “yüksek değerli veri seti” getirir; ayrı içerik, hesap veya dış servis gerekmez.

## 2. Neden Photo Deduper değil, Photo Library Triage?

Apple Photos, Mac’te Duplicates koleksiyonundan duplicate fotoğraf ve videoları birleştirebiliyor. Birleştirilen kopyalar Recently Deleted’a taşınıyor ve 30 gün kurtarılabiliyor. Ancak çözüm Photos kütüphanesiyle sınırlı, kullanıcıya özel tarama kuralları sunmuyor ve kullanıcı tarafından başlatılan açık bir yeniden tarama kontrolü belgelenmiyor.

Kaynaklar:

- [Apple — Remove duplicate photos and videos on Mac](https://support.apple.com/guide/photos/remove-duplicates-pht5a3157c1d/mac)
- [Apple Community — No exposed way to force a duplicates scan](https://discussions.apple.com/thread/255127994)

Dolayısıyla yanlış ürün tezi:

> “Apple’ın bulamadığı duplicate’leri bul.”

Doğru ürün tezi:

> **“Arşivindeki karmaşayı açıkla, en iyi kareleri güvenle seç, hiçbir şeyi yanlışlıkla kaybetme.”**

Bu ürün, duplicate temizliğini aşağıdaki daha büyük işin giriş noktası olarak kullanır:

- Exact duplicate
- Near duplicate
- Burst ve seri çekim
- RAW + JPEG çiftleri
- Edited original / exported copy
- Live Photo ilişkileri
- Screenshot ve disposable image grupları
- Büyük video ve storage hotspot’ları
- Boş/bozuk thumbnail ve erişilemeyen iCloud asset’leri
- Klasör, harici disk ve Photos library arasında tekrarlar

## 3. Rakip savunması — gerçek durum

### Apple Photos

| Alan | Apple Photos |
|---|---|
| Fiyat | macOS ile ücretsiz |
| Kapsam | Photos system library |
| Güç | Metadata birleştirme, sistem seviyesinde güven, Recently Deleted |
| Zayıflık | Folder/external drive yok; custom rules yok; detaylı açıklama yok; kullanıcı kontrollü scan session yok |
| Tehdit seviyesi | **Yüksek**, exact/basic duplicate alanını metalaştırıyor |

### PhotoSweeper

PhotoSweeper güncel Mac App Store fiyatında **$14.99**, yalnızca Mac için sunuluyor ve macOS 10.15+ destekliyor. Apple Photos, Lightroom Classic, Capture One, klasörler ve harici diskleri tarayabiliyor. 2026 sürümleri AI Quality Score, açıklamalı Auto Mark, XMP sidecar, DNG ve Lightroom preview iyileştirmeleri ekledi. Geliştirici App Store privacy beyanında veri toplamadığını belirtiyor.

Kaynaklar:

- [Apple — PhotoSweeper product page](https://apps.apple.com/us/app/photosweeper/id463362050?mt=12)
- [PhotoSweeper official site](https://overmacs.com/)

**Savunması güçlüdür.** Yeni ürün, “daha iyi similarity slider” ile kazanamaz.

### Gemini 2

Gemini 2 fotoğraf dışında müzik, belge, klasör, external drive ve network volume duplicate’lerini de tarıyor. Duplicates Monitor ve Smart Cleanup sunuyor. App Store sürümü yearly access kullanıyor; resmî site fiyatı aylık eşdeğerde yaklaşık $1.95’ten başlıyor.

Kaynaklar:

- [Apple — Gemini 2](https://apps.apple.com/us/app/gemini-2-the-duplicate-finder/id1090488118?mt=12)
- [MacPaw — Gemini 2 pricing](https://macpaw.com/gemini)

**Savunması geniş sistem temizliğidir; fotoğraf profesyonelliği değildir.**

## 4. Kullanıcı şikâyeti tema haritası

Apple review sayfaları tam bir export sağlamadığı için aşağıdaki harita erişilebilen App Store yorumları, Reddit tartışmaları ve bağımsız incelemelerden kodlanan temaları gösterir. Frekanslar nüfus tahmini değil, tekrarlanan sinyal yoğunluğudur.

### Photo Library Triage temaları

| Tema | Sinyal | Kullanıcı problemi | Ürün gereksinimi |
|---|---|---|---|
| Yanlış pozitif korkusu | Çok yüksek | Benzer fakat değerli karelerin silinmesi | Kalıcı silme yok; açıklanabilir confidence ve review |
| Büyük kütüphane | Çok yüksek | 15K–144K+ fotoğrafta uzun tarama | Checkpoint, pause/resume, incremental index |
| Sonuç kalabalığı | Yüksek | Binlerce grup tek seferde incelenemiyor | Year/source/type bazında review queues |
| Otomatik seçime güvensizlik | Yüksek | “En iyi” kararı kullanıcıya göre değişiyor | Rule builder + her seçimin nedeni |
| Filtre eksikliği | Yüksek | Küçük resolution, thumbnail ve edited copy’yi ayırmak zor | Cross-group filters ve saved presets |
| Crash / yarım kalan iş | Orta-yüksek | Saatler süren tarama kaybolabiliyor | Transactional session state |
| iCloud belirsizliği | Orta-yüksek | Optimize edilmiş asset’in aslı yerelde olmayabilir | Availability preflight ve download state |
| RAW / sidecar ilişkisi | Orta | Sidecar silinirse düzenleme zinciri bozulabilir | Asset-family graph |
| Burst / seri çekim | Orta | Benzerlik duplicate değildir | “Best shot” review, duplicate’den ayrı |
| Fiyat modeli güvensizliği | Orta | Subscription ve sürüm farkları kafa karıştırıyor | Net lifetime fiyat ve paid-major-upgrade sözü |
| Folder + Photos karışıklığı | Orta | Aynı fotoğraf birden fazla yerde olabilir | Cross-source identity map |
| Geri alma | Kritik | Kullanıcı yıllarca sakladığı veriyi riske atıyor | Quarantine + audit manifest + Recently Deleted |

Başlıca kaynaklar:

- [PhotoSweeper reviews](https://apps.apple.com/us/app/photosweeper/id463362050?mt=12&platform=mac&see-all=reviews)
- [Duplicate Photos Fixer reviews](https://apps.apple.com/us/app/duplicate-photos-fixer-pro/id963642514?mt=12&platform=mac&see-all=reviews)
- [Gemini 2 App Store reviews](https://apps.apple.com/us/app/gemini-2-the-duplicate-finder/id1090488118?mt=12)
- [Reddit — duplicate finder discussion](https://www.reddit.com/r/MacOS/comments/18imtmn/best_duplicate_finder/)
- [Reddit — Gemini monitor complaint](https://www.reddit.com/r/MacOS/comments/y9lvlj/good_file_duplicate_finder/)

### GPX / Geotagging temaları

| Tema | Sinyal | Kullanıcı problemi |
|---|---|---|
| Kamera saat farkı / timezone | Çok yüksek | GPX ile fotoğraf eşleşmiyor |
| Yanlış konum atama | Yüksek | Bir grup fotoğraf aynı veya kilometrelerce yanlış konuma yazılabiliyor |
| Çoklu GPX state bug’ı | Orta | Önceki track yeni session’a sızabiliyor |
| Manuel map search zayıflığı | Orta | POI veya landmark bulunamıyor |
| Workflow öğrenme eğrisi | Yüksek | Track kaydı, camera clock ve export zinciri karmaşık |
| Mobile logger ihtiyacı | Orta | Mac ürününün companion’ı eksik |
| Metadata güvenliği | Kritik | EXIF/XMP yazımı geri dönüşü zor olabilir |
| Seyrek kullanım | Orta-yüksek | Kullanıcı ürünü yalnızca seyahat/çekim sonrası açıyor |

Kaynaklar:

- [GeoTag reviews](https://apps.apple.com/us/app/geotag/id1465180184?mt=12&platform=mac&see-all=reviews)
- [myTracks reviews](https://apps.apple.com/us/app/mytracks/id403100976?mt=12&platform=mac&see-all=reviews)
- [Macworld — HoudahGeo review](https://www.macworld.com/article/234182/houdahgeo-6-review.html)
- [Reddit — geotag workflow friction](https://www.reddit.com/r/photography/comments/1fusldg/do_you_geotag_your_photos/)

### Personal CRM temaları

| Tema | Sinyal | Kullanıcı problemi |
|---|---|---|
| Manuel veri giriş disiplini | Çok yüksek | CRM değer üretmeden önce kullanıcı sürekli log girmeli |
| Sync ve migration güveni | Kritik | Yılların ilişki verisi kaybolmamalı |
| Fiyat hassasiyeti | Yüksek | Lifetime fiyat yüksek, subscription istenmeyebilir |
| Tag / import karmaşası | Orta-yüksek | Kişi sayısı büyüdükçe organizasyon bozuluyor |
| Email/activity capture | Yüksek | Manuel logging zaman alıyor |
| Custom view ihtiyacı | Orta | İş ve kişisel contact listeleri farklı kolon ister |
| Privacy ve data ownership | Yüksek | Cloud CRM’lere karşı temel satın alma nedeni |
| Uzun onboarding | Yüksek | “Kurunca mükemmel” fakat ilk değere ulaşmak yavaş |
| İzin ve entegrasyon | Orta-yüksek | Contacts, Calendar, Mail ve call log sınırları |
| Destek bağımlılığı | Yüksek | Sync ve veri problemleri bire bir destek gerektirir |

Kaynaklar:

- [Contacts Journal product and reviews](https://apps.apple.com/gb/app/contacts-journal-crm/id327685977)
- [BusyContacts product and reviews](https://apps.apple.com/us/app/busycontacts/id964258399?mt=12&platform=mac&see-all=reviews)
- [Contacts Journal Reddit discussion](https://www.reddit.com/r/macapps/comments/18k6mqr/contacts_journal_crm/)

## 5. Üç finalist feature/market karşılaştırması

| Kriter | Photo Library Triage | GPX / Geotagging | Personal CRM |
|---|---|---|---|
| Kullanıcı kitlesi | Her büyük fotoğraf arşivi sahibi | Fotoğrafçı, gezgin, saha çalışanı | Freelancer, satış, danışman, network-heavy kullanıcı |
| Problem sıklığı | Sürekli büyür | Çekim/seyahat dönemsel | Günlük |
| İlk değer | 1–5 dakika | GPX ve dosya hazırlığı gerekir | Import ve kullanım disiplini gerekir |
| Offline çekirdek | %100 mümkün | %90+ mümkün | %95 mümkün |
| Dış API bağımlılığı | Yok | Map/geocoding opsiyonel | Entegrasyon genişledikçe artar |
| Veri hassasiyeti | Yüksek | Orta | Çok yüksek |
| Yanlış işlem maliyeti | Fotoğraf kaybı | Metadata bozulması | İlişki/veri kaybı |
| MVP süresi | En kısa | Orta | En uzun |
| QA matrisi | Format/library | Format/metadata/map | Sync/account/permissions |
| Support yükü | Orta | Orta-yüksek | Yüksek |
| Fiyat gücü | $20–30 | $25–40 | $30–50 |
| Rakip yoğunluğu | Orta | Düşük-orta | Düşük-orta |
| Güçlü incumbent | Apple + PhotoSweeper + Gemini | HoudahGeo | Contacts Journal + BusyContacts |
| Uzun vadeli vizyon | Library health platform | Photographer metadata suite | Relationship operating system |
| İlk yıl riski | En düşük | Orta | En yüksek |

## 6. Kazanan ürün tanımı

### Tek cümlelik değer önerisi

**Photo Triage, Mac’inizdeki fotoğraf karmaşasını cihazdan çıkarmadan analiz eder; hangi karelerin neden tutulması gerektiğini açıklar ve hiçbir şeyi geri dönüşsüz silmeden güvenli bir temizlik planı oluşturur.**

### Ürünün temel sözü

> **Clean the clutter. Keep the memories. Every decision explained.**

### Hedef kullanıcılar

1. 20.000+ fotoğraflı Apple Photos kullanıcıları.
2. DSLR/mirrorless RAW + JPEG arşivi olan fotoğrafçılar.
3. iPhone, WhatsApp, kamera ve scanner kaynaklarını birleştirmiş aile arşivleri.
4. Harici disklerde yıllara yayılmış klasörleri bulunan kullanıcılar.
5. Lightroom/Capture One ve Apple Photos’u birlikte kullanan prosumer kullanıcılar.
6. Depolama alanı satın almadan önce arşivini güvenli biçimde küçültmek isteyenler.

### Ürün dışında bırakılacaklar

İlk sürümde yapılmayacak:

- Genel Mac duplicate file cleaner
- Cloud photo storage
- Fotoğraf editörü
- Yüz tanıma tabanlı kişi yönetimi
- Otomatik kalıcı silme
- Tam Lightroom catalogue editor
- “AI ile kötü fotoğrafları tek tıkla sil” modu

## 7. Dünya-klası farklılaşma

### A. Asset Family Graph

Her dosya bağımsız fotoğraf gibi değerlendirilmez. Sistem ilişkileri çıkarır:

- RAW ↔ JPEG
- RAW ↔ XMP sidecar
- Live Photo image ↔ video component
- Original ↔ edited export
- Burst members
- Screenshot crop variants
- Same image at different resolution/compression
- Photos library asset ↔ Finder/export copy

Bu graph, rakiplerin en riskli problemi olan “yanlış dosyayı tutma” sorununu azaltır.

### B. Explainable Keep Engine

Her öneri açık nedenlerle gösterilir:

- Daha yüksek çözünürlük
- RAW mevcut
- Daha az sıkıştırma
- Favori / albüm üyeliği
- Düzenleme metadata’sı
- Daha iyi focus/face quality
- Daha yeni veya daha eski tercih
- Kullanıcının özel preset’i

“AI en iyisini seçti” tek başına kabul edilmez.

### C. Safety Plan

Temizleme işlemi üç aşamalıdır:

1. **Plan:** Ne tutulacak, ne karantinaya alınacak?
2. **Review:** Grup veya rule bazında kullanıcı onayı.
3. **Commit:** Photos için sistem confirmation; Finder için Trash/quarantine.

Her işlem JSON/SQLite audit manifest’i üretir. Oturum geri açılabilir, yarıda kalabilir ve tekrar devam edebilir.

### D. Large Library Engine

- Incremental fingerprint database
- Background-safe checkpoint
- Pause/resume
- Thumbnail cache budget
- External drive reconnect handling
- Scan only changed assets
- Low-power / performance mode
- 250K+ asset benchmark hedefi

### E. Review Queues

Kullanıcı 10.000 sonucu tek listede görmez:

- Exact duplicates
- Best of burst
- Lower-resolution copies
- Screenshots and downloads
- Edited/exported copies
- Large videos
- RAW/JPEG pairs
- “Needs human decision”
- High-confidence safe cleanup

## 8. Teknik uygulanabilirlik

Apple PhotoKit, photo-library asset’lerini oluşturma, değiştirme ve silme için `PHAssetChangeRequest` sunuyor. Vision framework image feature prints üretip iki görsel arasındaki mesafeyi hesaplayabiliyor.

Resmî kaynaklar:

- [Apple Developer — PHAssetChangeRequest](https://developer.apple.com/documentation/photos/phassetchangerequest)
- [Apple Developer — Requesting changes to the photo library](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library)
- [Apple Developer — Analyzing image similarity with feature print](https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print)
- [Apple Developer — Feature print distance](https://developer.apple.com/documentation/vision/featureprintobservation/distance%28to%3A%29)

### Önerilen teknoloji

| Katman | Teknoloji |
|---|---|
| UI | SwiftUI + gerektiğinde AppKit |
| Photo library | PhotoKit |
| Finder/external drives | Security-scoped bookmarks + FileManager |
| Exact duplicate | BLAKE3/SHA-256 staged hash |
| Perceptual similarity | Vision feature prints + pHash/dHash ensemble |
| Quality signals | Vision face capture quality, blur/exposure heuristics |
| Metadata | ImageIO, AVFoundation, Core Image |
| Index | SQLite/Core Data; versioned schema |
| Concurrency | Swift structured concurrency |
| Purchase | StoreKit 2 |
| Crash/performance | MetricKit + privacy-preserving optional diagnostics |
| Minimum target | macOS 13+; Intel + Apple silicon |
| Data policy | No cloud account, no image upload, no ad SDK |

### Güvenlik ve veri politikası

- Fotoğraflar cihazdan çıkmaz.
- Analytics varsayılan olarak kapalı veya yalnızca anonim teknik event’ler.
- Kullanıcı asset thumbnail’ları analytics’e girmez.
- Cleanup engine doğrudan “delete all” çalıştırmaz.
- Security-scoped erişimler görünür biçimde yönetilir.
- Tam disk erişimi zorunlu tutulmaz; kullanıcı klasör seçer.
- PhotoKit sistem confirmation akışları korunur.

## 9. Sekiz haftalık validation MVP

Bu takvim **dünya-klası final ürün değil**, ödeme ve güven davranışını doğrulayacak çalışan MVP içindir. Tek deneyimli macOS geliştiricisi varsayılır.

| Hafta | Teslimat |
|---:|---|
| 1 | SwiftUI shell, permissions, folder/Photos source model, benchmark corpus |
| 2 | Exact hash engine, incremental SQLite index, pause/resume |
| 3 | Vision feature-print similarity, clustering ve threshold test harness |
| 4 | Duplicate group review UI, keyboard navigation, image inspector |
| 5 | Keep rules, explanation engine ve storage-savings preview |
| 6 | Quarantine/Trash/PhotoKit commit, audit manifest ve undo flow |
| 7 | Free scan + StoreKit unlock, onboarding, accessibility ve error states |
| 8 | 10K/50K/100K library QA, TestFlight, App Store metadata ve private beta |

### MVP kabul kriterleri

- Exact duplicate detection: byte-identical dosyalarda hedef %100 precision.
- Near-duplicate: otomatik kalıcı silme yok.
- Crash sonrası scan session geri yüklenir.
- 100K asset taramasında UI responsive kalır.
- Kullanıcı tüm önerilerin nedenini görebilir.
- Temizleme öncesi ve sonrası manifest üretir.
- Photos ve Finder kaynakları ayrı safety adapter kullanır.
- Uygulama internet bağlantısı olmadan çekirdek görevini tamamlar.

## 10. On iki aylık dünya-klası roadmap

### Ay 1–3 — Trustworthy Cleanup v1

- Exact + near duplicate
- Photos/folder/external drive
- Explainable keep rules
- Pause/resume
- Audit + quarantine
- Lifetime purchase

### Ay 4–6 — Pro Photo Relationships

- RAW/JPEG/sidecar graph
- Live Photo ve burst awareness
- Edited/export copy detection
- Lightroom/Capture One import adapters
- Rule presets for photographers
- Side-by-side metadata diff

### Ay 7–9 — Library Health

- Screenshot/download cleanup
- Large video review
- Blur, exposure ve accidental-shot queues
- Storage trend report
- Scheduled read-only health scans
- Smart collections and saved review queues

### Ay 10–12 — Ecosystem and Moat

- Optional iPhone companion for capture cleanup handoff
- Shared Family Library safety
- Multi-library catalogue
- Signed cleanup reports for professional archivists
- Plugin/export API
- Paid major upgrade or optional Pro workflow pack
- Localization: English, German, Japanese, French, Spanish, Turkish

## 11. Fiyatlandırma kararı

### Önerilen model

- Uygulama ücretsiz indirilir.
- Scan ve ilk 100 önerinin review’u ücretsiz.
- Temizleme commit, unlimited groups ve Pro rules için **$24.99 lifetime**.
- İlk 14 gün launch price: **$19.99**.
- Family Sharing etkin.
- Abonelik yok.
- Büyük v2 yükseltmesi 18–30 ay sonra isteğe bağlı ücretli major upgrade olabilir.
- Mevcut kullanıcı v1’i süresiz kullanır.

### Neden subscription değil?

- Kullanım sürekli olsa da ödeme anı genellikle proje bazlıdır.
- Rakip PhotoSweeper $14.99 peşin fiyatla güçlü bir anchor oluşturuyor.
- Kullanıcı fotoğraf erişimi veren üründe güven ve fiyat şeffaflığı arıyor.
- Subscription, Gemini 2’ye karşı farklılaşmayı zayıflatır.
- Lifetime fiyat premium fakat “tek kullanımlık utility” itirazını azaltmak için library-health roadmap’i gerekir.

## 12. Birinci yıl gelir senaryoları

Aşağıdaki rakamlar tahmin değil, birim ekonomi senaryosudur. Ortalama gerçekleşen satış fiyatı launch indirimi ve tam fiyat karışımı için **$22.49** varsayılmıştır. Apple Small Business Program’a hak kazanıldığı ve %15 komisyon uygulandığı varsayılır; vergi, refund, reklam, destek ve geliştirme giderleri dahil değildir.

Apple’ın programı, qualifying paid apps ve IAP işlemlerinde %15 komisyon oranı sunar:

- [Apple Developer — Small Business Program](https://developer.apple.com/app-store/small-business-program/)

| Senaryo | İlk yıl ücretli kullanıcı | Brüt gelir | %15 komisyon sonrası yaklaşık gelir |
|---|---:|---:|---:|
| Temkinli | 1.500 | $33.735 | $28.675 |
| Baz | 4.000 | $89.960 | $76.466 |
| Güçlü | 10.000 | $224.900 | $191.165 |

### Dönüşüm modeli örneği

| Senaryo | Ücretsiz indirme | Paid conversion | Paid kullanıcı |
|---|---:|---:|---:|
| Temkinli | 30.000 | %5 | 1.500 |
| Baz | 57.000 | %7 | 3.990 |
| Güçlü | 125.000 | %8 | 10.000 |

Bu indirme sayıları kamuya açık Mac download verisinden türetilmemiştir; launch planı için test edilecek varsayımlardır.

## 13. App Store konumlandırması

### Kategori

**Primary:** Photo & Video  
**Secondary:** Utilities değerlendirilebilir, fakat Photo & Video daha doğru kullanıcı niyeti taşır.

### Arama niyeti kümeleri

- duplicate photos
- similar photos
- photo cleaner
- clean photo library
- remove screenshots
- photo organizer
- find duplicate images
- photo storage cleaner
- RAW duplicate finder
- Apple Photos cleaner
- Lightroom duplicate photos
- burst photo cleaner

### Screenshot hikâyesi

1. “Your library is bigger than it looks.”
2. “See exact, similar and burst groups.”
3. “Every keep recommendation is explained.”
4. “Review 50,000 photos without losing your place.”
5. “Nothing is deleted without a safety plan.”
6. “Works with Photos, folders and external drives.”
7. “100% on-device. No uploads. No account.”
8. “Recover space. Keep the memories.”

## 14. Rakibi kopyalamamak için ürün sınırları

### PhotoSweeper’dan farklı

- Temel farklılık daha fazla similarity ayarı değildir.
- Ana değer: session-based triage, explainability, asset-family graph ve safety.
- Profesyonel kütüphane için audit trail.
- Cleanup sonucu “neden” ve “geri dönüş” odaklı.

### Gemini 2’den farklı

- Genel disk temizliği yapılmaz.
- Monitor/background clutter marketing’i yok.
- Fotoğraf ve video ilişkileri derin ele alınır.
- Subscription zorunluluğu yok.

### Apple Photos’tan farklı

- Folder, external drive ve birden fazla library.
- Custom review rules.
- User-controlled scan session.
- Cross-source duplicates.
- RAW/sidecar ve professional asset relationships.
- Detailed storage and safety plan.

## 15. En büyük riskler ve önlemler

| Risk | Seviye | Önlem |
|---|---|---|
| Yanlış fotoğraf silme | Kritik | No auto-delete, quarantine, system confirmation, manifest |
| PhotoSweeper’ın aktif gelişimi | Yüksek | Feature yarışına değil trust/workflow moat’a yatırım |
| Apple Photos özelliğinin genişlemesi | Yüksek | Cross-source, pro formats, explainability ve audit |
| 100K+ library performansı | Yüksek | Incremental index, batch thumbnail, benchmark gate |
| iCloud optimized originals | Orta-yüksek | Availability check, explicit download state |
| Vision threshold değişimi | Orta | Versioned similarity models ve test corpus |
| Review fatigue | Orta-yüksek | Queues, smart presets, keyboard-first UX |
| “Bir kez kullanıp silme” | Orta | Scheduled health scan ve library-health roadmap |
| App Store sandbox | Orta | User-selected folders, security-scoped bookmarks |
| Refund due to fear | Orta | Free scan, transparent preview, no surprise paywall |

## 16. Nihai karar

### Yapılacak uygulama

# **Local Photo Library Triage for Mac**

Bu ürün:

- Offline çalışacak.
- Hesap gerektirmeyecek.
- Fotoğraf yüklemeyecek.
- Subscription zorunluluğu kullanmayacak.
- Apple Photos’un ücretsiz duplicate özelliğini kopyalamayacak.
- Kullanıcı güvenini ana ürün özelliği yapacak.
- Büyük arşivlerde yarıda kalmadan devam edecek.
- RAW, sidecar, burst ve edited-copy ilişkilerini anlayacak.
- Premium, native ve “pahalı” hisseden bir Mac deneyimi sunacak.

### Neden diğer iki finalist değil?

**GPX/Geotagging**, daha savunulabilir profesyonel bir niştir fakat kullanım sıklığı ve toplam kullanıcı tabanı daha küçüktür. İkinci ürün olarak güçlü kalır.

**Personal CRM**, en büyük uzun vadeli şirket vizyonuna sahiptir; ancak sync, migration, permissions ve yıllarca saklanan hassas veri nedeniyle ilk üründe risk ve destek yükü fazladır.

**Photo Library Triage**, talep, ilk gelir hızı, local-first yapı, premium Mac uyumu ve solo geliştirici yapılabilirliği açısından en dengeli seçimdir.

## Faz 5D sonraki çalışma

1. Kazanan ürünün gerçek isim ve domain araştırması.
2. 30–50 rakipte full feature matrix.
3. Apple Photos/PhotoKit teknik spike planı.
4. 100K+ fotoğraf benchmark dataset tasarımı.
5. Information architecture, ekranlar ve premium UI sistemi.
6. Exact MVP backlog, acceptance criteria ve Codex/Xcode geliştirme planı.
7. App Store listing, fiyat testi ve beta kullanıcı edinim planı.

**Sürüm:** 5C — 2 Ağustos 2026

# Faz 5D — Ürünleştirme Planı

**Tarih:** 2 Ağustos 2026  
**Kazanan ürün:** Local Photo Library Triage for Mac  
**Çalışma markası:** **Cullora**  
**App Store açıklayıcı adı:** `Cullora — Photo Library Triage`  
**Marka durumu:** Ön web/App Store çatışma taramasında doğrudan aynı isimli fotoğraf yazılımı bulunmadı; hukukî marka ve alan adı müsaitliği kesinleşmiş sayılmaz.

> [!CAUTION]
> “Cullora” yalnızca çalışma markasıdır. Yayın öncesinde USPTO, EUIPO, WIPO, TÜRKPATENT, Apple App Store isim rezervasyonu ve akredite registrar/RDAP üzerinden bağımsız hukukî ve alan adı kontrolü yapılmalıdır.

## 1. Marka araştırması

### 1.1 Elenen isimler

| İsim | Karar | Neden |
|---|---|---|
| Photo Triage | Elendi | Snapling ve Sift gibi ürünler açıklamalarında doğrudan “Photo Triage” kullanıyor; jenerik ve savunmasız |
| TidyLens | Elendi | Aktif photo/video cleaner App Store ürünü |
| LumaKeep | Elendi | Aktif App Store photo manager ve ayrı web sitesi |
| LumaSift | Elendi | Aktif App Store photo cleaner |
| PhotoAudit | Elendi | Aktif Mac photo-review ürünü |
| PhotoProof | Elendi | Birden fazla fotoğraf doğrulama, task-proof ve image-forensics ürünü |
| Keepsake | Elendi | Çok sayıda photo memory/sharing ürünü |
| Framewise | Elendi | Birden fazla aktif ürün ve AI uygulaması |
| ClearFrame | Elendi | Aktif photo cleaner |
| Photo Sifter | Elendi | Aktif App Store uygulaması |
| KeepWise | Elendi | Aktif finans uygulaması |
| FrameKeep | Elendi | Aktif gallery/illustration workflow ürünleri |
| PhotoVerge | Elendi | Fotoğraf yayıncılığı/marka kullanımı |
| Frameful | Elendi | Gallery planner ve fotoğraf markaları |
| PhotoSure | Elendi | Aktif passport-photo ürünü |
| ArchiveLight | Zayıf | Çok jenerik; güçlü ürün çağrışımı ve korunabilirlik düşük |

### 1.2 Çalışma markası: Cullora

**Köken:** Photography’de “cull”, çekimden tutulacak kareleri seçme işidir. `-ora` eki daha yumuşak, premium ve uluslararası telaffuza uygun bir marka sesi oluşturur.

**Artıları:**

- 7 harf, kısa ve görsel olarak dengeli.
- Fotoğraf profesyonellerine anlamlı; genel kullanıcıya tamamen teknik gelmiyor.
- “Cleaner”, “duplicate” veya “AI” kelimelerine bağlı olmadığı için ürün büyüyebilir.
- Library health, screenshots, video review ve archive audit özelliklerini taşıyabilir.
- İlk web aramasında aynı isimli aktif fotoğraf uygulaması görünmedi.

**Riskleri:**

- İngilizce konuşmayan kullanıcılar `cull` anlamını bilmeyebilir.
- “Cull” kelimesi sert/silme çağrışımı yapabilir.
- İtalya kökenli bir soyadı olarak kullanımlar bulunuyor.
- Hukukî müsaitlik ve domain sahipliği henüz doğrulanmadı.

### 1.3 Marka mimarisi

| Katman | Öneri |
|---|---|
| Marka | Cullora |
| App Store adı | Cullora — Photo Library Triage |
| Subtitle | Clean safely. Keep what matters. |
| Menü çubuğu kısa adı | Cullora |
| Pro ürün | Cullora Pro |
| Tarama motoru | Cullora Index |
| Öneri motoru | Keep Engine |
| İlişki modeli | Asset Families |
| Güvenli işlem | Safety Plan |
| Oturum ekranı | Review Studio |
| Periyodik rapor | Library Health |

### 1.4 Domain adayları

Kesin müsaitlik doğrulanmadı. Registrar kontrol sırası:

1. `cullora.app`
2. `getcullora.com`
3. `cullora.com`
4. `cullora.photo`
5. `cullora.co`
6. `trycullora.com`

**Kural:** Domain müsaitliği doğrulanmadan logo, App Store rezervasyonu veya şirket ismi kesinleştirilmemeli.

## 2. 2026 rekabet çevresi — 36 ürün

Rakipler dört gruba ayrıldı:

- Doğrudan duplicate/similar cleaner
- Apple Photos library yönetimi
- Profesyonel culling/organizing
- Yeni mobile-first swipe/AI cleaners

### 2.1 Rekabet matrisi

| # | Ürün | Platform | Model | Ana güç | Cullora için tehdit | Cullora boşluğu |
|---:|---|---|---|---|---|---|
| 1 | Apple Photos Duplicates | macOS | Sistemle ücretsiz | Güven, metadata merge, Recently Deleted | Çok yüksek | Cross-source, custom rules, session control, açıklama |
| 2 | PhotoSweeper | Mac | $14.99 lifetime | Similarity kontrolü, Photos/Lightroom/Capture One, external drives | Çok yüksek | Asset-family graph, audit trail, resumable triage |
| 3 | Gemini 2 | Mac | Abonelik/plan | Genel dosya duplicate’leri, Smart Cleanup, monitor | Yüksek | Fotoğraf derinliği, lifetime, explanation |
| 4 | PowerPhotos | Mac | ~$39.95 lifetime | Birden fazla Photos library, merge/split, duplicate | Yüksek | Folder + pro asset relationships + modern triage |
| 5 | Duplicate Photos Fixer Pro | Mac/iOS | Paid/IAP | Kolay similarity cleanup | Orta | Daha düşük false-positive, source relationships |
| 6 | Photos Duplicate Cleaner | Mac | Free/paid | Basit duplicate grupları | Düşük-orta | Büyük library, professional formats, trust |
| 7 | Cisdem Duplicate Finder | Mac | Paid | Geniş file-type tarama | Orta | Photos-specific intelligence |
| 8 | Easy Duplicate Finder | Mac/Windows | Paid/sub | Genel duplicate, undo | Orta | Mac-native photo workflow |
| 9 | Duplicate Photo Cleaner | Mac/Windows | Paid | Similar-photo visual comparison | Orta | Photos/RAW integration ve audit |
| 10 | dupeGuru | Mac/Win/Linux | Free/open source | Ücretsiz ve cross-platform | Orta | Premium UX, Photos integration, safety |
| 11 | CleanMyMac Duplicates | Mac | Subscription | Büyük marka, suite bundling | Yüksek | Fotoğraf uzmanlığı ve lifetime |
| 12 | Nektony Duplicate File Finder | Mac | Freemium | Genel disk duplicate temizliği | Orta | Photo family/quality workflow |
| 13 | CleverFiles Duplicate Finder | Mac | Free/paid ecosystem | Disk utility dağıtımı | Düşük-orta | Photo intelligence |
| 14 | Photo Cleaner | Mac/iOS | Freemium | Basit kamera-roll cleanup | Orta | Desktop pro workflow |
| 15 | TidyLens | iOS/iPad-on-Mac | Freemium | Privacy-first duplicate/video cleanup | Orta | Native Mac, external disks, pro files |
| 16 | LumaKeep | iOS/iPad-on-Mac | Freemium | Cleanup, sensitive scan, vault, compression | Orta | Trust without feature sprawl |
| 17 | LumaSift | iOS/iPad-on-Mac | Freemium | Storage/photo cleaner | Düşük-orta | Native desktop and asset graph |
| 18 | ClearFrame | iOS/iPad-on-Mac | Freemium | Duplicates, burst, screenshots, video cleanup | Orta | No tracking, Mac-native, explanation |
| 19 | Snapling | iOS/iPad-on-Mac | Freemium | Swipe-based photo triage | Orta | Large-library automation and source breadth |
| 20 | PhotoAudit | Mac/iOS | Freemium | Monthly manual audit, resume progress | Orta | Similarity engine and storage impact |
| 21 | Photo Sifter | Apple platforms | Freemium | Discovery/sift workflow | Düşük | Cleanup safety and duplicates |
| 22 | Sift / swipe cleaners | Mobile | Freemium/sub | Basit swipe habit | Orta | Professional Mac differentiation |
| 23 | ZeroShots | Mobile/web | Freemium | Screenshot triage | Düşük | Broader library health |
| 24 | Adobe Lightroom Classic | Mac/Win | Subscription | Catalog, flags, stacks, RAW workflows | Yüksek dolaylı | No catalog migration, simpler cleanup |
| 25 | Capture One Pro | Mac/Win | Subscription/perpetual | Pro culling, RAW, sessions | Yüksek dolaylı | Family/archive users, Photos integration |
| 26 | Photo Mechanic Plus | Mac/Win | Paid | Çok hızlı ingest ve culling | Yüksek pro | Duplicate/family archive cleanup |
| 27 | FastRawViewer | Mac/Win | Paid | Hızlı RAW review | Orta pro | Library-wide relationships and safety |
| 28 | Narrative Select | Mac | Freemium/sub | AI-assisted professional culling | Orta pro | Archive cleanup, local ownership |
| 29 | AfterShoot | Mac/Win | Subscription | AI culling/editing | Orta pro | No cloud/service dependence |
| 30 | FilterPixel | Mac/Win | Subscription | AI culling | Orta pro | Family/archive and explainability |
| 31 | Optyx | Mac | Paid/sub | AI photo selection | Düşük-orta | Library health, duplicates |
| 32 | Excire Foto | Mac/Win | ~$189 lifetime | Local AI search, culling and face/object organization | Yüksek long-term | Lower price, cleanup-specific trust |
| 33 | Mylio Photos | Multi-platform | Subscription | Private multi-device library and dedupe | Yüksek long-term | No new library/cloud ecosystem |
| 34 | Peakto | Mac | Subscription/lifetime variants | Multi-catalog photo meta-library | Orta-high | Cleanup-focused simpler product |
| 35 | NeoFinder | Mac | Paid | Disk/media cataloguing | Düşük-orta | Visual similarity and Photos operations |
| 36 | Adobe Bridge | Mac/Win | Free | Metadata, files, review | Orta | Automated relationships and safe cleanup |

### 2.2 2026 rekabet güncellemesi

2026’da pazara giren veya görünür hâle gelen TidyLens, LumaKeep, LumaSift, Snapling ve PhotoAudit şu temel özellikleri artık farklılaştırıcı olmaktan çıkardı:

- “Privacy-first”
- “On-device”
- Duplicate detection
- Screenshot cleanup
- Large-video cleanup
- Swipe-to-delete
- No account
- Resume progress

Bu nedenle Cullora’nın korunabilir farkları:

1. **Asset Family Graph**
2. **Explainable Keep Engine**
3. **Transactional Safety Plan**
4. **100K–250K library performance**
5. **Photos + folders + external drives**
6. **RAW/sidecar/Live Photo/burst awareness**
7. **Cross-source identity**
8. **Audit and recovery manifest**

## 3. Ürün kapsamı ve bilgi mimarisi

### 3.1 Ana navigasyon

| Bölüm | Amaç |
|---|---|
| Home | Library Health özeti ve kaldığın yer |
| Sources | Photos library, folders, external disks |
| Scan | Kaynak, kapsam ve performans ayarı |
| Review Studio | Kuyruklar ve karar akışı |
| Safety Plan | Yapılacak değişikliklerin ön izlemesi |
| History | Scan, review ve cleanup manifestleri |
| Rules | Keep rules ve preset’ler |
| Settings | Privacy, cache, performance, purchase |

### 3.2 Home ekranı

**Üst alan:**

- Library Health Score
- Son tarama
- Yeni/değişen asset sayısı
- Kurtarılabilir alan
- Tamamlanmamış review session

**Ana kartlar:**

1. Safe Duplicates
2. Similar Sets
3. Burst Review
4. Lower-Quality Copies
5. Screenshots & Downloads
6. Large Videos
7. RAW/JPEG Pairs
8. Needs Your Decision

**Alt alan:**

- Sources health
- iCloud originals status
- External drive status
- Privacy badge: `Everything stays on this Mac`

### 3.3 Scan Wizard

1. **Source:** Photos, folder, external drive veya kombinasyon.
2. **Goal:** Free space, organize archive, photo shoot review, screenshots.
3. **Depth:** Exact only, balanced, deep visual analysis.
4. **Safety:** Read-only scan; Photos availability preflight.
5. **Estimate:** Asset count, süre aralığı ve cache alanı.
6. **Start:** Scan session kimliği oluştur.

### 3.4 Review Studio

Üç kolonlu native Mac yapı:

- Sol: Kuyruklar, filtreler, progress
- Orta: Grup/grid veya compare canvas
- Sağ: Metadata, ilişkiler, keep rationale, actions

**Klavye:**

| Tuş | İşlem |
|---|---|
| Space | Quick Look |
| K | Keep |
| Q | Quarantine |
| S | Skip |
| 1–5 | Rating |
| F | Favorite |
| Command–Z | Son kararı geri al |
| J/K veya oklar | Önceki/sonraki |
| Shift–K | Grubun önerilen seçimini kabul et |

### 3.5 Safety Plan

Commit öncesi zorunlu ekran:

- Tutulacak asset
- Karantinaya/Trash’e gidecek asset
- Photos Recently Deleted’a gidecek asset
- Boşalacak alan
- Offline/iCloud erişilemeyen asset
- Sidecar veya Live Photo ilişki uyarısı
- Geri dönüş yöntemi
- Manifest export seçeneği

## 4. Premium UI sistemi

### 4.1 Görsel yön

**Karakter:** Sessiz, profesyonel, güven veren; “cleaner utility” neon estetiğinden uzak.

**Ana metafor:** Karanlık bir arşiv odasında korunan baskılar ve ışıklı inceleme masası.

**Arayüz ilkeleri:**

- Fotoğraf her zaman başrol.
- Büyük boşluklar ve sakin yoğunluk.
- Kırmızı yalnızca geri dönüşü zor risklerde.
- Yeşil “sil” anlamına gelmez; “güvenli plan” anlamına gelir.
- Her AI/heuristic önerisinin yanında kanıt.
- Animasyon temizlik heyecanı değil, güven ve devamlılık hissi verir.

### 4.2 Tasarım token’ları

| Token | Light | Dark | Kullanım |
|---|---|---|---|
| Canvas | System background | System background | Ana zemin |
| Archive Surface | Hafif sıcak nötr | Soğuk koyu nötr | Sidebar/kart |
| Accent | Amber-bronze | Açık amber | Seçim ve progress |
| Safe | System mint | System mint | Geri alınabilir/güvenli |
| Warning | System orange | System orange | Eksik original/sidecar |
| Destructive | System red | System red | Permanent-risk |
| Photo Border | %12 black | %18 white | Görsel ayrımı |
| Radius S | 8 | 8 | Chip/button |
| Radius M | 12 | 12 | Card |
| Radius L | 18 | 18 | Hero panel |
| Motion | 160–240 ms | 160–240 ms | Native ease-out |

Renk değerleri SwiftUI semantic colors üzerinden uygulanmalı; sabit hex değerlerine bağımlı olmamalıdır.

### 4.3 Tipografi

- UI: SF Pro
- Metadata: SF Mono
- Hero metrics: SF Pro Display
- Dynamic Type ve macOS accessibility sizes
- Minimum metadata boyutu 12 pt; ana UI 13–15 pt

### 4.4 Mikro-etkileşimler

- Scan progress sürekli dönen spinner yerine gerçek iş göstergeleri verir: hashing, preview, feature print, clustering.
- Grup kararı sonrası görseller yok olmaz; “Safety Plan” katmanına yumuşak geçer.
- Undo toast, session boyunca kalıcı history ile desteklenir.
- External disk çıkarılırsa session bozulmaz; kaynak “Paused — drive missing” olur.
- App quit sırasında state kaydı görünür fakat engelleyici olmayan bir durumla tamamlanır.

## 5. Teknik spike planı

### 5.1 Spike A — PhotoKit erişim ve değişiklik

**Amaç:** Photos library’den 10K–100K asset fetch, thumbnail ve metadata erişiminin gerçek maliyetini ölçmek.

**Kanıtlanacaklar:**

- Authorization akışı
- Limited/full erişim durumları
- iCloud optimized asset durumu
- `PHPhotoLibrary` change observation
- Batch delete/change request davranışı
- Recently Deleted ve system confirmation
- Live Photo component ilişkisi
- Burst identifier ve favorite/album metadata

**Çıkış kriteri:** 50K asset library’de index işlemi UI thread’i bloklamaz.

### 5.2 Spike B — Exact duplicate pipeline

Pipeline:

1. File size + UTType
2. Fast prefix/suffix hash
3. Full BLAKE3/SHA-256
4. Metadata check
5. Cross-source identity
6. Asset family relation

**Hedef:** Byte-identical dosyalarda sıfır false positive.

### 5.3 Spike C — Near-duplicate pipeline

- Vision feature prints
- pHash/dHash
- Aspect ratio/resolution normalization
- Crop/rotate variants
- Edited-copy signals
- Burst/time proximity
- EXIF capture metadata
- Confidence calibration

**Kural:** Near-duplicate hiçbir zaman otomatik kalıcı silmeye uygun değildir.

### 5.4 Spike D — App Sandbox

Klasör ve disk erişimi:

- `NSOpenPanel`
- Security-scoped bookmark
- Stale bookmark recovery
- External volume reconnect
- Permission revocation
- App relaunch persistence

Apple’ın macOS App Sandbox belgeleri, kullanıcının seçtiği kaynak için explicit security scope içeren URL bookmark’ın saklanabileceğini belirtiyor.

### 5.5 Spike E — Session recovery

Simüle edilecek kesintiler:

- Force quit
- Mac sleep
- Low disk
- External disk çıkarma
- Photos library değişikliği
- iCloud download timeout
- Version/schema migration
- StoreKit state change

**Çıkış kriteri:** Son doğrulanmış checkpoint’e veri kaybı olmadan dönülür.

## 6. Veri modeli

### 6.1 Temel entity’ler

| Entity | Önemli alanlar |
|---|---|
| Source | type, bookmark, Photos ID, volume UUID, status |
| Asset | stable ID, path/localIdentifier, media type, dimensions, dates |
| Fingerprint | exact hash, pHash, feature print version, model version |
| AssetFamily | relation type, canonical asset, members |
| ComparisonGroup | algorithm, threshold, confidence, state |
| Decision | keep/quarantine/skip, reason, user/engine |
| Rule | conditions, priority, scope, enabled |
| ScanSession | state, progress, checkpoints, source snapshot |
| CleanupPlan | operations, estimated bytes, warnings |
| Manifest | committed operations, recovery references, app/schema version |

### 6.2 Versionleme

- Fingerprint model version zorunlu.
- Vision/heuristic sürümü değiştiğinde eski sonuçlar sessizce yeniden yorumlanmaz.
- Database migration testleri fixture üzerinden çalışır.
- Manifest insan tarafından okunabilir JSON export sunar.

## 7. 100K+ benchmark tasarımı

Gerçek kullanıcı fotoğrafları paylaşılmayacağı için sentetik ve lisanslı test corpus’u gerekir.

### 7.1 Dataset katmanları

| Katman | Asset | İçerik |
|---|---:|---|
| Smoke | 1.000 | Exact, resize, rotate, crop ve basit burst |
| Standard | 10.000 | HEIC/JPEG/PNG/TIFF, Live Photo, video |
| Large | 50.000 | Birden fazla kaynak ve external disk |
| Stress | 100.000 | 10+ yıl, screenshot, messenger, RAW/JPEG |
| Extreme | 250.000 | Incremental scan ve low-memory test |

### 7.2 Ground truth grupları

- Exact duplicates
- Re-encoded copies
- Cropped variants
- Rotated variants
- Watermarked exports
- Edited color variants
- Burst sequences
- RAW/JPEG pairs
- XMP sidecars
- Live Photo components
- Same event but not duplicate
- Similar faces but distinct moments
- Screenshots with small text changes
- Video transcodes

### 7.3 Performans hedefleri

| Ölçü | Hedef |
|---|---|
| App launch | <1.5 s warm |
| 10K exact index | <5 dk Intel baseline; daha hızlı Apple silicon |
| 100K resume | <10 s |
| Review navigation | 60 fps hissi, thumbnail gecikmesi <150 ms |
| Peak memory | Standard scan <2 GB; adaptive budget |
| Crash recovery | Son checkpoint ≤60 s iş kaybı |
| Incremental scan | Yalnızca eklenen/değişen asset |
| Idle CPU | Review ekranında düşük |
| Network | Core feature için 0 byte |

Süre hedefleri spike sonucuna göre yeniden kalibre edilir; pazarlama vaadi olarak kullanılmaz.

## 8. Exact MVP backlog

### Epic 0 — Foundation

| ID | İş | Kabul kriteri |
|---|---|---|
| FND-01 | Xcode project ve modüler yapı | App, Core, Index, PhotosAdapter, FileAdapter, Store modülleri |
| FND-02 | SwiftLint/format ve CI | Pull request’te build/test çalışır |
| FND-03 | App sandbox entitlements | Yalnızca gerekli entitlement’lar |
| FND-04 | Privacy manifest | Kullanılan API ve veri akışı belgeli |
| FND-05 | Crash-safe logging | Dosya adı/fotoğraf içeriği log’a girmez |

### Epic 1 — Sources

| ID | İş | Kabul kriteri |
|---|---|---|
| SRC-01 | Photos permission onboarding | Kullanıcı neden erişim gerektiğini prompt öncesi görür |
| SRC-02 | Photos fetch adapter | Stable localIdentifier ile pagination |
| SRC-03 | Folder picker | Security-scoped erişim relaunch sonrası sürer |
| SRC-04 | External drive state | Disk çıkarıldığında session pause |
| SRC-05 | Source health | Permission, missing, stale bookmark durumları görünür |

### Epic 2 — Index

| ID | İş | Kabul kriteri |
|---|---|---|
| IDX-01 | SQLite schema | Versioned migration testleri |
| IDX-02 | Exact hash | Known corpus’ta %100 precision |
| IDX-03 | Thumbnail cache | LRU, disk-budget ve purge |
| IDX-04 | Incremental scan | Değişmeyen asset yeniden hash edilmez |
| IDX-05 | Checkpoint | Force quit sonrası devam |

### Epic 3 — Similarity

| ID | İş | Kabul kriteri |
|---|---|---|
| SIM-01 | Vision feature print | Model version saklanır |
| SIM-02 | pHash/dHash ensemble | Crop/resize corpus testleri |
| SIM-03 | Candidate blocking | O(n²) tam karşılaştırma yapılmaz |
| SIM-04 | Clustering | Deterministic sonuç |
| SIM-05 | Confidence | UI’da high/medium/needs review |

### Epic 4 — Asset Families

| ID | İş | Kabul kriteri |
|---|---|---|
| FAM-01 | RAW/JPEG relation | Aynı çekim çiftleri group olarak görünür |
| FAM-02 | XMP relation | Sidecar orphan yaratılmaz |
| FAM-03 | Live Photo | Image/video component birlikte tutulur |
| FAM-04 | Burst | Duplicate değil “best of burst” kuyruğu |
| FAM-05 | Edited copy | Original ve export ilişkisi açıklanır |

### Epic 5 — Review Studio

| ID | İş | Kabul kriteri |
|---|---|---|
| REV-01 | Group list/grid | 10K sonuçta responsive |
| REV-02 | Compare canvas | Zoom/pan sync |
| REV-03 | Metadata diff | Resolution, file, dates, source ve relationships |
| REV-04 | Keyboard workflow | Mouse olmadan temel review tamamlanır |
| REV-05 | Explainable keep | Her engine seçimi için neden |
| REV-06 | Filter/preset | Saved filters |
| REV-07 | Session progress | Kuyruk bazında tamamlanma |

### Epic 6 — Safety

| ID | İş | Kabul kriteri |
|---|---|---|
| SAF-01 | Read-only default | Scan hiçbir dosyayı değiştirmez |
| SAF-02 | Cleanup plan | İşlem öncesi tam liste |
| SAF-03 | Finder quarantine | Same-volume safe move mümkünse kullanılır |
| SAF-04 | Photos commit | PhotoKit system authorization korunur |
| SAF-05 | Manifest | JSON ve app history |
| SAF-06 | Undo guidance | Photos Recently Deleted ve Finder recovery görünür |
| SAF-07 | Risk blockers | Missing original/sidecar uyarısı commit’i engelleyebilir |

### Epic 7 — Monetization

| ID | İş | Kabul kriteri |
|---|---|---|
| PAY-01 | Free scan | Bütün library taranabilir |
| PAY-02 | Free review limit | İlk 100 grup veya demo session |
| PAY-03 | Lifetime unlock | Non-consumable StoreKit 2 |
| PAY-04 | Restore purchases | Offline cache + App Store doğrulama |
| PAY-05 | Family Sharing | Ürün ayarları uygun |
| PAY-06 | Paywall | Scan sonucundan önce sürpriz engel yok |

### Epic 8 — Quality

| ID | İş | Kabul kriteri |
|---|---|---|
| QLT-01 | VoiceOver | Ana review akışı erişilebilir |
| QLT-02 | Keyboard navigation | Tüm ana aksiyonlar |
| QLT-03 | Reduced Motion | Animasyonlar uyumlu |
| QLT-04 | Dark/light | Fotoğraf renkleri değişmez |
| QLT-05 | Localization | String catalogue; layout expansion |
| QLT-06 | Error recovery | Actionable, veri kaybetmeyen errors |

## 9. Definition of Done

Bir build MVP-ready sayılmaz, şu koşulların tamamı sağlanmadan:

- 100K test corpus’unda scan tamamlanır.
- Force quit sonrası session geri yüklenir.
- Exact duplicate yanlış pozitif üretmez.
- Near-duplicate hiçbir zaman otomatik commit edilmez.
- RAW/XMP ve Live Photo ilişkisi bozulmaz.
- Kullanıcı cleanup öncesinde dosya ve alan etkisini görür.
- Uygulama fotoğraf yüklemez ve hesap istemez.
- StoreKit restore çalışır.
- Network kapalıyken core feature tamamlanır.
- App Review demo steps ve test source hazırlanır.
- Privacy policy uygulama içinden erişilebilir.
- Analytics photo metadata veya path toplamaz.
- En az Intel ve iki Apple-silicon sınıfında test edilir.

## 10. App Store planı

### 10.1 Metadata

**Name:** Cullora — Photo Library Triage  
**Subtitle:** Clean safely. Keep what matters.

**Promotional text:**

> Review duplicates, bursts, RAW pairs, screenshots and large media with every recommendation explained. Everything stays on your Mac.

**Keywords taslağı:**

`duplicate photos,similar photos,photo cleaner,photo library,burst,raw,jpeg,screenshot,storage,organizer`

Keyword alanında marka isimleri, “Apple Photos”, “Lightroom” gibi üçüncü taraf ticari adlar hukukî/ASO incelemesinden geçmeden kullanılmamalı.

### 10.2 App Store kategorisi

- Primary: Photo & Video
- Secondary: Utilities ancak yalnızca gerçek işlevle uyumluysa
- Age rating: 4+
- Sign-in: Yok
- Data collection: İdeal hedef `Data Not Collected`
- In-app purchase: Lifetime Pro Unlock

### 10.3 App Review notları

Review ekibine:

1. Uygulama hiçbir fotoğrafı otomatik silmez.
2. Demo folder link’i veya bundled synthetic sample sağlanır.
3. Photos izni reddedilirse folder mode çalışır.
4. Cleanup yalnızca kullanıcı onayından sonra.
5. Network çekirdek özellik için gerekli değil.
6. StoreKit test hesabıyla restore adımları.
7. External folder erişiminin `NSOpenPanel` ile verildiği açıklanır.
8. Background daemon/helper yok.
9. Tam disk erişimi istenmez.
10. “AI” ifadeleri yerel Vision/heuristic kapsamıyla doğru biçimde açıklanır.

## 11. Beta planı

### 11.1 Kullanıcı kohortları

| Kohort | Kişi | Arşiv |
|---|---:|---|
| Aile/iPhone kullanıcıları | 20 | 10K–50K Photos library |
| Fotoğrafçılar | 15 | RAW/JPEG, Lightroom/Capture One |
| Büyük arşiv sahipleri | 10 | 100K+ |
| External-drive kullanıcıları | 10 | Folder/NAS export |
| Accessibility/keyboard | 5 | VoiceOver ve keyboard |
| Toplam ilk beta | 60 | — |

### 11.2 Beta görevleri

- İlk scan’i tamamla.
- En az üç queue review et.
- Bir keep rule oluştur.
- Uygulamayı scan ortasında kapat/aç.
- External disk’i çıkar/tak.
- Cleanup plan oluştur fakat ilk turda commit etme.
- İkinci turda test folder üzerinde commit/restore.
- “Bu öneriye neden güvendin/güvenmedin?” yanıtı.
- Paywall netliği ve fiyat kabulü.

### 11.3 Başarı eşikleri

| Metrik | Go eşiği |
|---|---:|
| Scan tamamlanma | ≥%95 |
| Session recovery | ≥%99 test |
| Review’a geçen kullanıcı | ≥%70 |
| En az 50 karar | ≥%50 |
| Safety Plan anlayışı | ≥%85 |
| “Fotoğrafımı yanlış silebilir” endişesi | Beta sonu ≤%20 |
| Pro satın alma niyeti $24.99 | ≥%12 |
| Crash-free sessions | ≥%99.5 |
| Support blocker | Kohortun <%10’u |
| NPS benzeri öneri | ≥40 hedef |

## 12. Go / no-go kapıları

### Gate 1 — Teknik

- 100K index yapılabiliyor mu?
- iCloud optimized asset state güvenilir mi?
- PhotoKit commit ve folder quarantine ayrı adapter’larda güvenli mi?
- Vision similarity yeniden üretilebilir mi?

Başarısızsa: yalnızca folder/external-drive MVP’ye daralt.

### Gate 2 — Güven

- Kullanıcı önerinin nedenini anlıyor mu?
- Cleanup plan kaygıyı azaltıyor mu?
- Oturum ve manifest gerçekten güven oluşturuyor mu?

Başarısızsa: similarity yerine exact duplicates + screenshots ile başla.

### Gate 3 — Monetizasyon

- $24.99 lifetime için en az %12 güçlü satın alma niyeti var mı?
- Kullanıcı ürünü Apple Photos’un ücretsiz özelliğinden farklı görüyor mu?

Başarısızsa: Pro photographer segmentine daralt veya fiyatı $19.99 yap.

### Gate 4 — Retention

- İlk cleanup sonrası Library Health’a dönme nedeni var mı?
- Incremental scan ve screenshot queue aylık kullanım yaratıyor mu?

Başarısızsa: “one-shot utility” ekonomisine göre CAC ve fiyat yeniden hesaplanır.

## 13. Xcode/Codex proje yapısı

```text
Cullora/
├── App/
│   ├── CulloraApp.swift
│   ├── AppState.swift
│   └── Navigation/
├── Features/
│   ├── Home/
│   ├── Sources/
│   ├── Scan/
│   ├── ReviewStudio/
│   ├── SafetyPlan/
│   ├── History/
│   ├── Rules/
│   └── Settings/
├── Core/
│   ├── Models/
│   ├── Database/
│   ├── Fingerprints/
│   ├── Clustering/
│   ├── AssetFamilies/
│   ├── Rules/
│   └── Manifests/
├── Adapters/
│   ├── PhotoKitAdapter/
│   ├── FileSystemAdapter/
│   ├── SecurityScope/
│   └── StoreKitAdapter/
├── DesignSystem/
│   ├── Components/
│   ├── Tokens/
│   ├── Motion/
│   └── Accessibility/
├── Diagnostics/
│   ├── Logging/
│   ├── MetricKit/
│   └── Benchmark/
├── Tests/
│   ├── Unit/
│   ├── Integration/
│   ├── Corpus/
│   ├── Migration/
│   └── Performance/
└── Resources/
    ├── Localizable.xcstrings
    ├── PrivacyInfo.xcprivacy
    └── SampleLibrary/
```

## 14. Mimari kurallar

1. Domain/core katmanı PhotoKit veya SwiftUI tiplerine doğrudan bağımlı olmaz.
2. Tüm destructive işlemler `CleanupOperation` protokolünden geçer.
3. Scan engine UI’dan bağımsız ve resumable olmalıdır.
4. Database ve fingerprint model version’ları ayrı tutulur.
5. Fotoğraf path/name yalnızca cihaz içi debug log’da, açık kullanıcı izniyle ve maskeli görülebilir.
6. Thumbnail/cache her zaman yeniden üretilebilir veri sayılır.
7. Manifest ve user decisions kalıcı kullanıcı verisidir.
8. Similarity engine update, eski kararları sessizce değiştirmez.
9. Feature flag yalnızca development/beta; App Store’da uzaktan kod/özellik yükleme yapılmaz.
10. Third-party analytics SDK başlangıç sürümünde kullanılmaz.

## 15. Faz 5D kararı

### Ürün

**Cullora — Photo Library Triage**

### V1 hedefi

Kullanıcının Apple Photos, klasör ve harici disk arşivini cihaz üzerinde tarayıp:

- Exact duplicate
- Similar set
- Burst
- RAW/JPEG/sidecar family
- Screenshot
- Büyük video
- Edited/export copy

kuyruklarına ayırması; her keep önerisini açıklaması ve kullanıcı onaylı Safety Plan ile geri alınabilir temizlik yapması.

### Savunulabilir avantaj

Ürünün moat’i AI modeli değildir. Moat:

- Yıllar içinde test edilen asset-relationship graph
- Büyük arşiv performance corpus’u
- User trust ve safety UX
- Format/library adapter’ları
- Açıklanabilir selection rules
- Session/audit geçmişi

## Faz 5E sonraki çalışma

1. PhotoKit ve Vision için çalıştırılabilir teknik spike kod planı.
2. Veri tabanı şeması ve clustering algoritmasının ayrıntılı teknik tasarımı.
3. Her ekran için wireframe-level component specification.
4. 250K corpus generation script ve performance test protocol.
5. Codex’in Xcode’da uygulamayı üretmesi için tek, ayrıntılı `BUILD_PLAN.md`.
6. App icon, logo, onboarding ve App Store screenshot asset brief.
7. İlk çalışan proje klasörünün oluşturulması.

**Sürüm:** 5D — 2 Ağustos 2026


# Faz 5E — Teknik Geliştirme Paketi

**Tamamlanma tarihi:** 3 Ağustos 2026  
**Üretilen paket:** `Cullora_Phase_5E.zip`  
**Durum:** Codex/Xcode uygulama geliştirmesine başlanabilecek teknik temel hazır.

## Paket içeriği
- `BUILD_PLAN.md`: mimari, kilometre taşları, sekiz haftalık uygulama sırası ve acceptance gate’leri.
- `TECHNICAL_DESIGN.md`: protokoller, SQLite şeması, candidate blocking, clustering, checkpointing, PhotoKit, sandbox ve StoreKit tasarımı.
- `SCREEN_SPEC.md`: Home, Sources, Scan, Review Studio, Safety Plan, History ve paywall ekranlarının component-level davranışı.
- `CORPUS_AND_PERFORMANCE.md`: 1K–250K corpus katmanları, ground truth ve performans protokolü.
- `StarterProject/`: SwiftUI app shell, domain model, Vision feature-print spike, PhotoKit adapter ve security-scoped bookmark örneği.
- `CorpusTools/generate_corpus.py`: deterministik exact/recompressed/rotated görsel corpus başlangıç üreticisi.

## Resmî API doğrulaması
- PhotoKit değişiklikleri `PHPhotoLibrary.performChanges` içindeki change request’lerle commit edilir.
- `PHAssetChangeRequest.deleteAssets` Photos asset silme talebini temsil eder.
- Vision feature print’leri arasında daha kısa mesafe daha yüksek benzerlik anlamına gelir.
- App Sandbox sonrasında klasör erişimini korumak için security-scoped bookmark çözülmeli ve erişim scope’u başlatılıp bitirilmelidir.
- Lifetime Pro entitlement’ı StoreKit 2 `Transaction.currentEntitlements` üzerinden yenilenir.

## Faz 5E çıkış kriteri
Araştırma artık yalnızca pazar raporu değildir; ürünün ilk çalışan teknik spike’larını ve Xcode uygulama planını içeren teslim edilebilir geliştirme paketine dönüşmüştür. Starter source bir tam `.xcodeproj` değildir; signing/team/bundle ID gerektirdiği için Xcode’da yeni macOS SwiftUI target açılarak source tree eklenmelidir.

## Faz 5F sonraki çalışma
1. Xcode project generator veya gerçek `.xcodeproj` oluşturma.
2. SQLite persistence ve migration kodu.
3. Exact hashing/index vertical slice.
4. Gerçek PhotoKit 10K/50K spike benchmark.
5. Review Studio’nun çalışan premium SwiftUI prototipi.
6. Corpus generator’ın crop, watermark, RAW/XMP ve Live Photo fixture’larıyla genişletilmesi.
7. İlk TestFlight/Mac beta build checklist’i.

**Sürüm:** 5E — 3 Ağustos 2026

# Faz 5F — Çalışan Xcode Projesi ve Exact Duplicate Vertical Slice

**Tamamlanma tarihi:** 3 Ağustos 2026  
**Üretilen paket:** `Cullora_Phase_5F_Calisan_Xcode_Projesi.zip`  
**Durum:** Gerçek `.xcodeproj` ve klasör tabanlı, tamamen yerel, salt-okunur exact duplicate akışı hazır.

## Faz 5F’de eklenenler
- Doğrudan Xcode’da açılabilen `Cullora.xcodeproj` ve paylaşılan `Cullora` scheme’i.
- macOS 13+ SwiftUI hedefi, App Sandbox, user-selected read/write entitlement, Photos kullanım açıklaması, privacy manifest ve StoreKit test konfigürasyonu.
- SQLite WAL veritabanı, şema sürümü 1, migration, scan session checkpoint’leri, asset ve SHA-256 fingerprint tabloları.
- Kullanıcının `NSOpenPanel` ile seçtiği klasörü security-scoped bookmark olarak saklama ve yeniden açılışta çözme.
- Dosyaları parça parça okuyarak CryptoKit SHA-256 hesaplayan exact hasher.
- Klasör keşfi → hash → SQLite index → exact group → Review Studio çalışan dikey dilimi.
- Premium Library Health ana ekranı ve üç bölmeli Review Studio prototipi.
- Exact hasher ve SQLite grouping XCTest dosyaları.
- PhotoKit 50K enumeration benchmark başlangıç kodu; silme adapter’ı UI’dan ve tarama akışından tamamen izole.
- Crop, watermark, resize, rotate, metadata değişimi, RAW/JPEG/XMP ve Live Photo fixture üreten genişletilmiş corpus aracı.
- İlk Mac beta build checklist’i ve Faz 5G uygulama sırası.

## Güvenlik sınırı
Faz 5F’de hiçbir UI yolu dosya taşıyamaz, Trash’e gönderemez veya Photos varlığı silemez. Review kararları yalnız gelecek Safety Plan için niyet işaretidir. Destructive beta öncesinde precommit manifest, canonical asset koruması, sidecar/Live Photo blocker’ları, quarantine restore receipt’i ve zorunlu integration testleri tamamlanacaktır.

## Faz 5G sonraki çalışma
1. Değişmemiş dosyaları size/mtime ile atlayan incremental index ve kayıp dosya pruning.
2. Review kararlarının SQLite’a yazılması ve her exact grupta en az bir canonical asset koruması.
3. Cleanup manifest, immutable precommit JSON, export ve receipt şeması.
4. Aynı volume quarantine, collision-safe hedef, restore ve rollback adapter’ı.
5. RAW/JPEG/XMP, Live Photo ve burst family graph; orphan blocker’ları.
6. Bounded thumbnail cache ve ImageIO/Quick Look downsampling.
7. Photos byte-access ve iCloud availability spike’ı.
8. 10K/50K/100K benchmark, force-quit recovery ve migration test paketi.

**Sürüm:** 5F — 3 Ağustos 2026

# Faz 5G — Incremental Index, Kalıcı Review Kararları ve Geri Alınabilir Safety Plan

**Tamamlanma tarihi:** 3 Ağustos 2026  
**Üretilen paket:** `Cullora_Phase_5G_Calisan_Xcode_Projesi.zip`  
**Uygulama sürümü:** `0.6.0` / build `60`  
**Veritabanı şeması:** `2`  
**Durum:** Klasör tabanlı exact duplicate akışı artık ikinci taramada değişmeyen dosyaları tekrar hash’lemez; review kararlarını kalıcı tutar; her grupta bir keeper korur; kullanıcı onaylı kopyaları imzalı manifest ile quarantine’e taşır ve History’den geri yükler.

## Faz 5G’de tamamlanan dikey dilim

1. **Incremental exact index**
   - `(source_id, stable_key)` üzerinden önceki asset durumu aranır.
   - Byte count ve modification time eşleşiyor, digest mevcut ve asset quarantine’de değilse fingerprint yeniden kullanılır.
   - Yalnız yeni veya değişmiş dosyalar tam SHA-256 akışından geçer.
   - Her görülen dosya `last_seen_scan_id` ile işaretlenir.
   - Tamamlanan taramada görülmeyen aktif dosyalar silinmez; `is_missing=1` ile audit geçmişinde tutulur.

2. **SQLite schema v2 migration**
   - `assets`: `last_seen_scan_id`, `is_missing`, `is_quarantined`.
   - `comparison_groups`: `canonical_asset_id`.
   - `scan_sessions`: `hashed`, `reused`, `missing`.
   - Yeni tablolar: `decisions`, `cleanup_plans`, `cleanup_operations`, `manifests`.
   - Faz 5F veritabanındaki mevcut exact gruplar migration sırasında ilk üyeyi canonical olarak alır ve system keeper kararı oluşturur.

3. **Kalıcı review kararları**
   - `Keep`, `Add to Plan` ve `Skip` kararları SQLite’a yazılır.
   - Exact group kimliği `source_id + full digest + byte count` bileşimidir; grup yeniden oluşturulduğunda aynı kaynak içindeki kararlar geri gelir.
   - Farklı seçilmiş klasörlerdeki byte-identical dosyalar tek cleanup grubunda birleştirilmez.
   - Kullanıcının son explicit keeper seçimi, eski canonical ve deterministic fallback sırasıyla değerlendirilir.

4. **Canonical asset koruması**
   - Her exact grupta en az bir `canonical_asset_id` bulunur.
   - Canonical kart UI’da `Keeper` ve kilit rozetiyle görünür.
   - Canonical dosyada `Add to Plan` ve `Skip` devre dışıdır.
   - Kullanıcı önce başka bir kopyayı keeper seçerse önceki keeper güvenli biçimde tekrar review edilebilir.

5. **Safety Plan önizlemesi**
   - Seçilen dosyaların adı, orijinal klasörü, toplam dosya sayısı ve byte tahmini gösterilir.
   - Plan veritabanına `draft` olarak yazılır.
   - Cancel, draft planı kaldırır.
   - Kullanıcının planı görmeden dosya taşıyabileceği bir UI yolu yoktur.

6. **İmzalı precommit manifest**
   - Manifest ilk file-system mutation’dan **önce** oluşturulur ve Application Support içine atomik yazılır.
   - Canonical JSON sorted-key formatında encode edilir.
   - CryptoKit Curve25519 signing anahtarıyla Ed25519 imzası üretilir.
   - Envelope; payload, signature, public key ve algorithm revision taşır.
   - Local private key sandbox içinde saklanır ve desteklenen sistemlerde owner-only POSIX permission alır.
   - Manifest dosyası yazıldıktan sonra read-only permission uygulanmaya çalışılır.

7. **Aynı kaynak içindeki gizli quarantine**

```text
<Selected Folder>/.Cullora Quarantine/<plan-id>/<original-relative-path>
```

   - Hedef, seçilen root’un altında olduğu için kaynakla aynı volume üzerinde kalır.
   - Scanner hidden directory’yi taramaz.
   - Existing destination üzerine yazılmaz.
   - Orijinal relative path korunur.
   - Bu fazda Finder Trash, unlink, quarantine purge veya permanent delete bulunmaz.

8. **Commit öncesi içerik doğrulaması**
   - Her operation başlamadan source file varlığı kontrol edilir.
   - Full SHA-256 ve byte count manifestteki değerle yeniden karşılaştırılır.
   - Dosya review sonrasında değişmişse yalnız o operation bloklanır.
   - File move başarılı fakat SQLite update başarısız olursa adapter dosyayı orijinal konumuna geri taşımayı dener.

9. **History ve Restore**
   - Durumlar: Draft, Committing, Quarantined, Partially Quarantined, Restored, Partially Restored, Needs Attention.
   - Signed manifest Finder’da gösterilebilir.
   - Restore önce manifest signature’ını ve plan kimliğini doğrular.
   - Quarantine’deki dosyanın digest ve byte count’u tekrar kontrol edilir.
   - Orijinal path doluysa üzerine yazılmaz.
   - Restore sonrası asset aktif hale gelir ve exact groups yeniden oluşturulur.

## Faz 5G güvenlik sınırı

Bu paket kalıcı silme özelliği eklememiştir. Ulaşılabilir en güçlü mutation, kullanıcının açıkça `Add to Plan` seçtiği non-canonical dosyanın seçilmiş klasör içindeki gizli quarantine alanına taşınmasıdır. Photos adapter’ındaki geleceğe dönük mutation spike’ı UI, ScanCoordinator ve Safety Plan ile bağlantısız kalmaya devam eder.

## Faz 5G test paketi

### Xcode/XCTest
- `IncrementalIndexTests.swift`
  - unchanged asset reuse;
  - missing-file lifecycle;
  - canonical ve kararların group rebuild sonrasında korunması.
- `QuarantineCoordinatorTests.swift`
  - signed manifest üretimi;
  - quarantine move;
  - History state;
  - manifest doğrulamalı restore.
- Mevcut exact hasher ve SQLite exact grouping testleri korunmuştur.

### Bu çalışma ortamında geçen doğrulamalar
- Tüm Swift kaynakları `swiftc -frontend -parse` kontrolünden geçti.
- Framework bağımsız model + SQLite katmanı Linux Swift type-check kontrolünden geçti.
- Gerçek `SQLiteDatabase.swift`, Linux SQLite module map ile derlenip çalıştırıldı.
- Schema v2 migration, source-scoped exact grouping, canonical değişimi, persisted decision ve cleanup candidate smoke testi geçti.
- İki ayrı kaynakta aynı digest/size bulunan dosyaların farklı gruplar, karar kümeleri ve özetler üretmesi doğrulandı.
- 253 varlıklı deterministic ilk taramada 253 hash hesaplandı.
- Aynı corpus’un warm scan’inde 0 hash / 253 reuse görüldü.
- Üç değişiklik + iki kaldırma + bir yeni dosya delta testinde 4 hash, 248 reuse ve 2 missing sonucu doğrulandı.
- Ed25519 imzalı manifest ile quarantine + restore cross-platform smoke testi geçti.
- `project.pbxproj`, plist, entitlements, privacy manifest, JSON resources ve Xcode source reference kontrolü geçti.

## Mac üzerinde zorunlu kalan doğrulamalar

- Full macOS SDK type-check ve link.
- SwiftUI/AppKit view compilation.
- CryptoKit signing ve verification XCTest execution.
- App Sandbox içinde gerçek security-scoped bookmark runtime davranışı.
- APFS internal ve external volume quarantine/restore.
- Xcode asset catalog compilation.
- Release archive, signing, notarization ve App Store validation.

Linux doğrulamaları başarılı olsa da Mac `xcodebuild` çalışmadan başarılı macOS binary build iddiası yapılmamaktadır.

## Resmî Apple API dayanakları

- Security-scoped bookmark ile sonraki açılışlarda sandbox erişiminin yeniden kazanılması: Apple, *Accessing files from the macOS App Sandbox*.
- Security-scoped URL kullanılırken `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` çağrılarının dengelenmesi: Apple Foundation URL documentation.
- File movement için Foundation `FileManager.moveItem(at:to:)` kullanımı.
- Faz 5G bilinçli olarak `FileManager.trashItem` kullanmaz; product safety modeli restore edilebilir app-managed quarantine’dir.

## Faz 5H için önceki çalışma planı — tamamlandı

1. RAW/JPEG/XMP, Live Photo, burst ve edited/export asset family graph.
2. Sidecar veya paired component orphan etmeyi bloklayan family-aware Safety Plan validator.
3. ImageIO/Quick Look tabanlı bounded thumbnail cache ve memory budget.
4. Harici disk volume identity, disconnect/reconnect ve file coordination.
5. Force-quit sonrası pending/moved operation reconciliation ekranı.
6. Batch cursor ile gerçek mid-scan resume.
7. PhotoKit original-byte ve iCloud availability spike’ı; Photos deletion yine kapalı.
8. Feature flag arkasında similarity blocking + Vision feature print pipeline.
9. 10K/50K/100K Mac benchmark ve peak RSS sınırları.

**Sürüm:** 5G — 3 Ağustos 2026


# Faz 5H — Asset Family, Bounded Thumbnail, Harici Disk ve Force-Quit Recovery

**Tamamlanma tarihi:** 3 Ağustos 2026  
**Üretilen paket:** `Cullora_Phase_5H_Calisan_Xcode_Projesi.zip`  
**Uygulama sürümü:** `0.7.0` / build `70`  
**Veritabanı şeması:** `3`  
**Manifest şeması:** `2`  
**Durum:** Faz 5G’deki exact duplicate + reversible quarantine dikey dilimi; ilişki bileşenlerini ayırmayan family safety, bounded thumbnail üretimi, fiziksel volume kimliği, gerçek cursor doğrulaması ve açılış reconciliation katmanlarıyla sertleştirildi.

## Faz 5H’de tamamlananlar

### 1. Asset-family graph
- Aynı klasör ve normalize edilmiş dosya gövdesi üzerinden konservatif ilişki üretimi.
- `RAW + JPEG/HEIC/TIFF + XMP` ailesi.
- Aynı stem’e sahip image + MOV Live Photo export çifti.
- XMP ve AAE sidecar bundle.
- Yalnız açık `BURST###` dosya adı sinyali bulunan burst ailesi.
- `edited`, `edit`, `export`, `copy` türevleri.
- Her üye için family ID, family kind, policy ve role SQLite’a yazılır.

### 2. Family-aware Safety Plan
- RAW/sidecar ve Live Photo ilişkileri `allOrNothing` politikasındadır.
- Bu strict ailelerden yalnız bir bölüm seçilirse Safety Plan oluşturulmaz; eksik bileşenler kullanıcıya isimleriyle açıklanır.
- Burst ve edited/export ilişkileri advisory uyarı üretir; kalan dosyalar otomatik silinmez veya taşınmaz.
- Family kind ve member role, Review Studio kartlarında ve Safety Plan operation satırlarında gösterilir.

### 3. SQLite schema v3
- `scan_sessions.cursor_stable_key` ve `source_volume_id`.
- `cleanup_plans.source_volume_id`.
- `cleanup_operations.family_id`, `family_kind`, `family_role`.
- `asset_families` ve `family_members` tabloları.
- Migration; Faz 5G schema v2 verisini yerinde tutar, yeni alanları ve tabloları ekler.

### 4. Gerçek resumable cursor doğrulaması
- Scanner her 100 dosyada durable cursor ve hash/reuse sayaçlarını kaydeder.
- Resume yalnız şu koşullarda yapılır:
  1. cursor hâlâ mevcut;
  2. cursor’a kadarki mevcut dosya sayısı kayıtlı `processed` ile aynı;
  3. prefix’teki her asset aynı scan session tarafından görülmüş;
  4. size ve modification time değişmemiş.
- Prefix’e dosya eklenmiş, prefix’ten dosya kaldırılmış, cursor kaybolmuş veya prefix metadata’sı değişmişse eski session `superseded` olur ve güvenli yeni tarama başlar.
- Böylece force quit sonrası yeni/değişmiş bir dosyanın cursor’ın gerisinde kalıp atlanması engellenir.

### 5. Volume-stable source identity
- `VolumeIdentity`; volume UUID, ad, root path, removable/local bilgisi taşır.
- Source ID artık fiziksel volume stable ID + volume içindeki relative folder path ile üretilir.
- Aynı disk yeniden adlandırılsa veya mount path adı değişse bile aynı alt klasör aynı source ID’yi üretir.
- Farklı fiziksel disk aynı path’e bağlanırsa source availability `replaced` olur ve scan/commit/restore bloklanır.
- Phase 5G’nin path-only geliştirme index’i ilk Phase 5H taramasında bir kez yeniden oluşturulabilir; bu değişim orijinal dosya taşımaz veya silmez.

### 6. File coordination ve operation-level volume kontrolü
- Quarantine ve restore taşıması `NSFileCoordinator` iki-location write coordination ve `.forMoving` niyetiyle yapılır.
- Plan başında ve her operation öncesinde fiziksel volume yeniden doğrulanır.
- Hedef parent hazırlanır; destination collision üzerine yazılmaz.
- Move başarılı fakat veritabanı update’i başarısızsa inverse move compensation denenir.

### 7. Bounded thumbnail cache
- İlk yol ImageIO ile source’tan downsample edilmiş thumbnail üretimidir.
- Format ImageIO ile açılamazsa Quick Look thumbnail fallback’i kullanılır.
- Aynı thumbnail için eşzamanlı istekler tek in-flight task altında birleştirilir.
- `NSCache` bütçesi 96 MiB ve 320 entry olarak sınırlandırılmıştır.
- Review Studio thumbnail yolu artık dosyanın tamamını `Data(contentsOf:)` ile belleğe almaz.

### 8. Force-quit startup reconciliation
Reconciliation yalnız aktif source path’in pending/quarantined operation’larını inceler:

| DB state | Original | Quarantine | Sonuç |
|---|---:|---:|---|
| pending | yok | var | Digest doğruysa DB `quarantined` olarak onarılır |
| pending | var | yok | Move tamamlanmamış kabul edilir; operation failed, dosya yerinde |
| pending | var | var | Ambiguous; iki dosya da korunur, kullanıcı dikkati gerekir |
| pending | yok | yok | Ambiguous/offline; otomatik değişiklik yok |
| quarantined | var | yok | Digest doğruysa interrupted restore onarılır |
| quarantined | yok | var | Normal quarantine durumu |
| quarantined | var | var | Ambiguous; iki dosya da korunur |
| quarantined | yok | yok | Offline/missing; otomatik değişiklik yok |

Yalnız digest ve byte count ile doğrulanmış, tek anlamlı disk durumu otomatik olarak veritabanına yansıtılır. Reconciliation hiçbir iki-copy durumunda dosya seçmez, overwrite etmez veya silmez.

### 9. PhotoKit original-resource spike
- `PHAssetResource.assetResources` üzerinden original/full-size resource seçimi.
- `PHAssetResourceManager.requestData` ile locally readable byte ölçümü.
- Network access varsayılan olarak kapalıdır; iCloud gerektiren asset ayrı availability sonucu üretir.
- Byte counter callback güvenliği için kilitli accumulator kullanılır.
- Photos delete adapter gelecekteki ayrı safety fazı için izole kalır; AppModel, ScanCoordinator ve view katmanına bağlı değildir.

### 10. Feature flags
- Similarity pipeline varsayılan kapalıdır.
- PhotoKit original-byte probe varsayılan kapalıdır.
- Release dikey dilimi yalnız exact hash ve kullanıcı seçilmiş klasör/harici disk akışına dayanır.

## Faz 5H doğrulama paketi

### Kaynak ve proje kontrolleri
- `project.pbxproj`, Info.plist, entitlements ve privacy manifest lint geçti.
- Asset, StoreKit ve localization JSON kaynakları parse edildi.
- Tüm app/test Swift dosyalarının Xcode target referansları doğrulandı.
- Tüm Swift dosyaları parser kontrolünden geçti.

### Gerçek SQLite ve family smoke
- Schema v3 migration.
- Source-scoped exact grouping ve summary.
- Family persistence ve review asset family summary.
- Durable cursor resume ve changed-prefix safe restart.
- Volume rename sonrasında source ID stabilitesi.
- RAW/JPEG/XMP, Live Photo, burst ve edited/export sınıflandırması.

### Deterministic corpus sonucu
- 1.041 sentetik asset.
- 111 exact group ve 222 exact duplicate asset.
- İlk scan: 253 hash / 0 reuse.
- Warm scan: 0 hash / 253 reuse.
- Delta scan: 4 hash / 248 reuse / 2 missing.
- Ed25519 signed quarantine + restore cross-platform simulation geçti.
- Sekiz recovery disk durumu sınıflandırıldı.
- Thumbnail budget: 100.663.296 byte / 320 entry; full-file `Data` load yok.

Bu küçük sentetik sonuçlar gerçek 100K fotoğraf kütüphanesi performans iddiası değildir. 10K/50K/100K, peak RSS ve Quick Look/PhotoKit runtime ölçümleri Mac üzerinde yapılacaktır.

## Faz 5H güvenlik sınırı
- Permanent delete yok.
- Quarantine purge yok.
- Finder Trash yok.
- Photos mutation UI/command yolu yok.
- Strict aile partial move yok.
- Ambiguous recovery state için otomatik dosya seçimi yok.
- Farklı volume aynı path’e gelse bile commit/restore yok.

## Mac üzerinde zorunlu kalan doğrulamalar
- Full macOS SDK type-check, link ve SwiftUI/AppKit compilation.
- QuickLookThumbnailing, PhotoKit, CryptoKit ve `NSFileCoordinator` runtime.
- App Sandbox bookmark relaunch ve gerçek mount rename davranışı.
- APFS internal ve external disk quarantine/restore fault injection.
- XCTest execution, Instruments peak RSS ve UI latency.
- Signing, archive, notarization ve App Store validation.

Linux kaynak/smoke kontrolleri başarılı olsa da `xcodebuild` Mac üzerinde çalışmadan başarılı macOS binary build iddiası yapılmamaktadır.

## Faz 5H sonunda planlanan Faz 5I çalışması — tamamlandı
1. Mac’te full build + XCTest ve SDK-only düzeltmeler.
2. Birden çok active source bookmark ve source seçimine göre recovery.
3. PhotoKit library index, local/iCloud availability ve read-only exact candidate spike.
4. Feature flag arkasında Vision feature-print candidate pipeline.
5. Explainable similarity reason codes ve false-positive ground truth ölçümü.
6. 10K/50K/100K Instruments benchmark ve peak RSS gate’i.
7. Metadata-backed Live Photo/burst ilişkisi ve bir asset’in birden çok relation taşıyabildiği graph modeli.
8. Audit receipt export ve ayrı incelenecek quarantine retention politikası; permanent purge yine kapalı.

**Sürüm:** 5H — 3 Ağustos 2026

# Faz 5I — Perceptual Similarity, Kalibrasyon ve 100K Aday İndeksi

**Tamamlanma tarihi:** 3 Ağustos 2026  
**Üretilen paket:** `Cullora_Phase_5I_Calisan_Xcode_Projesi.zip`  
**Uygulama sürümü:** `0.8.0` / build `80`  
**Veritabanı şeması:** `4`  
**Güvenlik durumu:** Similarity yalnız inceleme önerisidir; exact olmayan hiçbir sonuç cleanup kararı veya Safety Plan operation’ı üretmez.

## Faz 5I’de tamamlananlar

1. Vision `VNGenerateImageFeaturePrintRequest` revision 1’e sabitlendi ve aspect-ratio distortion azaltmak için `scaleFit` kullanıldı.
2. Secure-coding feature print archive, dHash, pixel dimensions, exact-content digest, Vision revision ve pairing revision SQLite’a yazılıyor.
3. Dört normal + sekiz bit döndürülmüş dört ek 16-bit band ile sekiz tabloluk aday indeksi kuruldu.
4. Yeni/değişmiş görseller yeniden feature çıkarır; digest/revision/crop eşleşen kayıtlar reuse edilir. Bozuk veya mevcut runtime tarafından açılamayan tekil dosyalar değiştirilmeden sayılır ve güvenle atlanır; tüm kütüphane analizi durdurulmaz.
5. Vision distance yalnız dHash Hamming filtresinden geçen, asset başına en fazla 400 adaya uygulanır.
6. Labeled positive/negative örneklerden precision ve false-positive-rate hedefli threshold kalibrasyonu eklendi.
7. Yetersiz etiket varsa profil açıkça `uncalibrated bootstrap` kalır; otomatik işlem yetkisi vermez.
8. Benzer gruplar transitive connected-component yerine doğrudan anchor edge’leriyle kurulur; zincirleme yanlış pozitif riski azaltılır.
9. Review Studio’ya ayrı `Similar` modu, progress/cancel, distance kanıtı ve Finder reveal eklendi.
10. Similar kartlarda Keep, Skip, Add to Plan veya quarantine action bulunmaz.

## 100K sentetik aday benchmark sonucu

- Katalog: 100.000 sentetik perceptual hash.
- Teorik all-pairs alanı: 4.999.950.000 çift.
- Aday çift: 29.041.
- Azaltma faktörü: yaklaşık 172.169×.
- Ortalama kabul edilen aday: asset başına 0,5808.
- Maksimum ham bucket birleşimi: 36.
- Yerleştirilmiş yakın çift: 15.000.
- Geri bulunan yakın çift: 14.946.
- Sentetik recall: %99,64.
- Peak Python tracemalloc: 90,11 MiB.
- Build süresi: 6,04 saniye; query süresi: 8,34 saniye.

Bu ölçüm Apple Vision çalıştırmaz ve gerçek fotoğraf dağılımını temsil ettiği iddia edilmez. Vision throughput, enerji, peak RSS ve gerçek precision/recall ölçümleri macOS Apple-silicon cihazda yapılmalıdır.

## Faz 5I güvenlik sınırı

- Yalnız SHA-256 exact gruplar reversible Safety Plan’a girebilir.
- Similarity distance dosyaların değiştirilebilir veya silinebilir olduğunun kanıtı değildir.
- Similar gruplar cleanup decision tablosuna yazılmaz.
- Similar UI’dan quarantine, Trash, Photos mutation veya permanent delete çağrısı yoktur.
- Aile koruması, volume verification, signed manifest ve restore semantiği exact cleanup için aynen korunur.

## Mac üzerinde zorunlu kalan doğrulamalar

- Full Xcode build ve XCTest.
- Feature-print archive/unarchive runtime uyumluluğu.
- Revision 1 distance dağılımı için gerçek, insan etiketli pozitif/negatif çiftler.
- 10K/50K/100K gerçek kütüphane Instruments ölçümü.
- HEIC, RAW, screenshot, crop, brightness, color edit, burst ve unrelated-lookalike hata analizi.
- App Sandbox security-scoped dosyalarda Vision decode ve cancellation davranışı.

## Faz 5J sonraki çalışma

1. Xcode SDK-only düzeltmeler ve gerçek Mac CI.
2. İnsan etiketli calibration paneli ve ground-truth export.
3. Synchronized zoom/pan, metadata difference ve keyboard review.
4. Similarity checkpoint/retry/error inventory.
5. Accessibility, localization, App Store metadata, signing, notarization ve beta QA.
6. Permanent purge yine ayrı güvenlik incelemesi olmadan eklenmeyecek.

**Sürüm:** 5I — 3 Ağustos 2026

