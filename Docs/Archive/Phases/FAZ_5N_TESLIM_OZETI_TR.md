# Keptora Faz 5N Teslim Özeti

**Sürüm:** 0.9.4  
**Build:** 130

## Yeni özellikler

- Aranabilir Safety Plan önizlemesi
- Pending planın JSON olarak dışa aktarılması
- Quarantine işleminden önce zorunlu açık onay
- Dahili güvenli kaynak hariç tutmaları
- Kullanıcı tanımlı klasör ve uzantı hariç tutmaları
- Güncellenmiş fail-closed statik validator ve Mac release gate

## Korunan güvenlik kuralları

- Kalıcı silme yok
- Similar gruplarda otomatik cleanup yok
- Keeper toplu işleme dahil edilmez
- Dosyalar commit öncesi yeniden hash edilir
- Quarantine geri yüklenebilir ve signed manifest ile izlenir

## Gerçek Mac üzerinde kalanlar

Compile/link, XCTest/UI test, VoiceOver, NSSavePanel sandbox testi, 10K plan performansı, code signing, archive, StoreKit sandbox ve App Store Connect yüklemesi.
