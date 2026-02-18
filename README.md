# 🌙 LumaPause

> Minimal, sakin ve göz sağlığı odaklı bir macOS menubar uygulaması.

LumaPause, belirli aralıklarla ekranı kısa süreliğine karartarak gözlerin dinlenmesini sağlar.  
Tamamen menü çubuğunda çalışır, Dock’ta görünmez ve dikkat dağıtmaz.

---

## 🚀 Özellikler

- 🟣 Menubar-only mimari (Dock icon yok)
- ⏱ Varsayılan 20 dakika aralık (değiştirilebilir)
- ⚠️ Son 5 saniyede geri sayım popover uyarısı
- ⏭ Döngüyü atla
- ➕ 1 dakika uzat
- 🌑 Sabit %90 opacity ekran karartma
- 📊 Menüde canlı “Next dim in MM:SS” göstergesi
- ✔ Seçili ayarlarda ✓ tik işareti
- 🔐 Screen Lock uyumlu:
  - Kilitlenince sıfırlar ve durur
  - Unlock olunca 20 dakikadan yeniden başlar
- 🚀 Launch at Login desteği

---

## 🧠 Çalışma Mantığı

1. Menüden **Start** seçilir.
2. Seçilen süre geri saymaya başlar.
3. Son 5 saniyede küçük bir popover uyarısı çıkar.
4. Süre dolunca ekran belirlenen süre boyunca karartılır.
5. Döngü otomatik olarak yeniden başlar.

---

## 🔐 Lock Screen Davranışı

- Aktif geri sayım iptal edilir.
- Sayaç sıfırlanır.
- Uygulama durur.
- Unlock sonrası 20 dakikalık yeni döngü başlar.

Arka planda takılma veya donma yaşanmaz.

---

## ⚙️ Menü Seçenekleri

### ▶ Start  
Zamanlayıcıyı başlatır.

### ⏹ Stop  
Zamanlayıcıyı durdurur.

### ⏱ Interval
- 5 dk
- 10 dk
- 20 dk
- 30 dk
- Custom (dinamik gösterim)

### 🌑 Dim Duration
- 10 sn
- 20 sn
- 30 sn
- 60 sn
- Custom (dinamik gösterim)

### 🚀 Launch at Login
Mac açıldığında otomatik başlatır.

---

## 🖥 Sistem Gereksinimleri

- macOS 12+
- Swift / SwiftUI
- Xcode 13+

---

## 📦 Kurulum

### 1️⃣ Kaynak Koddan Çalıştırma

```bash
git clone https://github.com/efetunca/LumaPause.git
cd LumaPause
```

Xcode ile projeyi aç:

```
open LumaPause.xcodeproj
```

Ardından:

- `Product > Build`
- veya `Product > Run`

---

### 2️⃣ .app Dosyası Oluşturma

#### Hızlı Yöntem

- `Product > Build`
- `Products` altında `.app` dosyasını bul
- `/Applications` klasörüne taşı

#### Release (Önerilen)

- `Product > Archive`
- `Distribute App`
- `Copy App`
- Export edilen `.app` dosyasını `/Applications` içine taşı

---

## 🛠 Teknik Detaylar

- `NSStatusBar` tabanlı menubar uygulama
- `NSPopover` ile geri sayım arayüzü
- `NSWindow` overlay ile ekran karartma
- `DistributedNotificationCenter` ile screen lock takibi
- `LaunchAgent` ile login başlatma
- Event-driven timer lifecycle

---

## 📁 Proje Yapısı (Özet)

```
LumaPause/
│
├── AppDelegate.swift
├── TimerManager.swift
├── WarningPopoverView.swift
├── StatusPopover.swift
└── Assets.xcassets
```

---

## 🤝 Katkı

Katkı yapmak istersen:

1. Fork al
2. Feature branch oluştur
3. Commit yap
4. Pull Request gönder

---

## 📄 Lisans

Bu proje MIT lisansı ile lisanslanmıştır.  
Detaylar için `LICENSE` dosyasına bakınız.

---

## 🎯 Amaç

Minimal.  
Sakin.  
Dikkat dağıtmayan.  
Göz sağlığı odaklı.

---

Gözlerini koru. Odakta kal. 🌙
