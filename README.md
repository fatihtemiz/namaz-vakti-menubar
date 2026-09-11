# Namaz Vakti — macOS Menü Bar Uygulaması

macOS menü barında **bir sonraki namaz vaktine kalan süreyi** canlı geri sayımla gösteren, Dock'ta görünmeyen küçük bir uygulama. Vakitler **[EzanVakti API](https://ezanvakti.emushaf.net/)** üzerinden alınır (Diyanet İşleri Başkanlığı verisi) — **kayıt / giriş / API anahtarı gerekmez.**

## Özellikler

- Menü barında `🌙 İkindi 1:23:45` gibi sıradaki vakit + geri sayım
- Tıklayınca bugünün tüm vakitleri (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı), sıradaki vurgulu
- Ayarlardan **ülke → şehir → ilçe** seçimi (API'den canlı gelir)
- Aylık vakitler **diske cache**'lenir; internetsizken de geri sayım çalışır
- Dock ikonu yok (menü bar agent'ı, `LSUIElement`)

## Derleme & Çalıştırma

```bash
cd ~/Desktop/NamazVaktiMenuBar
./build_app.sh          # NamazVakti.app üretir
open NamazVakti.app     # menü barında başlatır
```

Geliştirme sırasında hızlı çalıştırmak için: `swift run`

### Girişte otomatik başlatma (opsiyonel)

`NamazVakti.app`'i `~/Applications` altına taşıyıp **Sistem Ayarları → Genel → Giriş Öğeleri**'ne ekleyin.

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
| `SettingsView.swift` | Ülke/şehir/ilçe seçimi |

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
