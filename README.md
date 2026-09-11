# Namaz Vakti — macOS Menü Bar Uygulaması

macOS menü barında **bir sonraki namaz vaktine kalan süreyi** canlı geri sayımla gösteren, Dock'ta görünmeyen küçük bir uygulama. Vakitler **[EzanVakti API](https://ezanvakti.emushaf.net/)** üzerinden alınır (Diyanet İşleri Başkanlığı verisi) — **kayıt / giriş / API anahtarı gerekmez.**

## Özellikler

- Menü barında `🌙 İkindi 1:23:45` gibi sıradaki vakit + geri sayım
- Tıklayınca bugünün tüm vakitleri (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı), sıradaki vurgulu
- Ayarlardan **ülke → şehir → ilçe** seçimi (API'den canlı gelir)
- **Türkçe / English** arayüz: Ayarlar'daki Dil bölümünden seçilir, varsayılan Türkçe. İngilizcede vakit adları Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha olur; yer adları API'nin İngilizce karşılıklarıyla gösterilir.
- Aylık vakitler **diske cache**'lenir; internetsizken de geri sayım çalışır
- Dock ikonu yok (menü bar agent'ı, `LSUIElement`)
- Ayarlardan **Girişte başlat** (macOS giriş öğesi, `SMAppService`)
- Kendi ikonu var (gece mavisi zemin, altın hilal). İkon `Scripts/make_icon.swift` ile kodla çizilir.

## Derleme & Çalıştırma

```bash
cd ~/Desktop/NamazVaktiMenuBar
./build_app.sh            # NamazVakti.app + dist/NamazVakti-<sürüm>.dmg üretir
./build_app.sh install    # ayrıca ~/Applications'a kurar ve yeniden başlatır
```

Geliştirme sırasında hızlı çalıştırmak için: `swift run`

### Başkalarıyla paylaşma

`dist/` altındaki DMG'yi gönderin. Açan kişi uygulamayı **Applications** klasörüne sürükler. Uygulama Developer ID ile imzalı ve notarize edilmiş olmadığı için ilk açılışta macOS engeller: **Sistem Ayarları → Gizlilik ve Güvenlik → "Yine de Aç"** ile bir kez izin verilir.

## Kullanım

1. Menü barındaki `🌙 Ayarla…` ögesine tıklayın → **Ayarlar**.
2. Ülke / Şehir / İlçe seçip **Kaydet**.
3. Vakitler çekilir, geri sayım başlar. Hepsi bu — hesap gerekmez.

## Mimari

| Dosya | Görevi |
|------|--------|
| `NamazVaktiApp.swift` | `MenuBarExtra` sahnesi + accessory (Dock'suz) politika |
| `PrayerTimesManager.swift` | Cache, 1 sn'lik geri sayım timer'ı, sıradaki vakit hesabı |
| `EzanVaktiAPI.swift` | EzanVakti REST istemcisi (auth yok) |
| `Models.swift` | API modelleri + diske cache modeli |
| `ContentView.swift` | Menü bar açılır paneli |
| `SettingsView.swift` | Dil ve ülke/şehir/ilçe seçimi |
| `Localization.swift` | `AppLanguage` + `loc("Türkçe", "English")` yardımcısı |

### API uçları (hepsi GET, kimlik doğrulama yok)

- `ulkeler` → `{ UlkeAdi, UlkeID }`
- `sehirler/{UlkeID}` → `{ SehirAdi, SehirID }`
- `ilceler/{SehirID}` → `{ IlceAdi, IlceID }`
- `vakitler/{IlceID}` → aylık liste: `{ Imsak, Gunes, Ogle, Ikindi, Aksam, Yatsi, MiladiTarihKisaIso8601, … }`

## Notlar / bilinen sınırlar

- Vakitler ve `MiladiTarihUzunIso8601` **Türkiye saat dilimine** göredir; Mac'iniz farklı saat dilimindeyse geri sayım kayabilir (Türkiye'de sorun olmaz).
- İnternet yokken son cache'lenen ay üzerinden geri sayım çalışmaya devam eder.
- `vakitler` uçları içinde bulunulan **ayı** döndürür; uygulama gün dönümü/ay sonunda otomatik yeniden çeker.
- Uygulama ad-hoc imzalıdır; ilk açılışta Gatekeeper uyarısı çıkarsa sağ tık → **Aç**.
