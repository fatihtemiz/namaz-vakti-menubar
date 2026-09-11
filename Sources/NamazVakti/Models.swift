import Foundation

// MARK: - Place (ülke / şehir / ilçe — hepsi {…Adi, …ID} biçiminde)

struct Place: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let nameEn: String?

    /// Seçili dile göre ad ("HOLLANDA" / "NETHERLANDS").
    var displayName: String {
        AppLanguage.current == .en ? (nameEn ?? name) : name
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        var foundId: Int?
        var foundName: String?
        var foundNameEn: String?
        for key in c.allKeys {
            let k = key.stringValue
            if k.hasSuffix("ID") {
                if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { foundId = v }
                else if let v = try? c.decode(Int.self, forKey: key) { foundId = v }
            } else if k.hasSuffix("AdiEn") {          // "UlkeAdiEn"
                foundNameEn = try? c.decode(String.self, forKey: key)
            } else if k.hasSuffix("Adi") {            // "UlkeAdi"
                foundName = try? c.decode(String.self, forKey: key)
            }
        }
        guard let id = foundId, let name = foundName else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Place alanları bulunamadı"))
        }
        self.id = id
        self.name = name
        self.nameEn = (foundNameEn?.isEmpty ?? true) ? nil : foundNameEn
    }
}

// MARK: - Prayer times (EzanVakti API — ezanvakti.emushaf.net)

/// /vakitler/{ilceId} bir aylık listede her gün için bir kayıt döner.
struct PrayerDay: Decodable {
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String
    let tarihKisa: String?   // "05.07.2026"  (dd.MM.yyyy — isimde Iso8601 geçse de bu biçimde)

    enum CodingKeys: String, CodingKey {
        case imsak = "Imsak"
        case gunes = "Gunes"
        case ogle = "Ogle"
        case ikindi = "Ikindi"
        case aksam = "Aksam"
        case yatsi = "Yatsi"
        case tarihKisa = "MiladiTarihKisaIso8601"
    }

    static let trDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Günün takvim tarihi (saat bileşeni olmadan, cihaz saat diliminde).
    var day: Date? {
        guard let s = tarihKisa else { return nil }
        return Self.trDateFormatter.date(from: s)
    }
}

// MARK: - Vakitler

enum Prayer: CaseIterable {
    case imsak, gunes, ogle, ikindi, aksam, yatsi

    /// Seçili dile göre tam ya da kısaltılmış vakit adı (ör. "İkindi"/"İkn", "Asr"/"Asr").
    func name(abbreviated: Bool) -> String {
        switch self {
        case .imsak:  return abbreviated ? loc("İms", "Fjr") : loc("İmsak", "Fajr")
        case .gunes:  return abbreviated ? loc("Gün", "Sun") : loc("Güneş", "Sunrise")
        case .ogle:   return abbreviated ? loc("Öğl", "Dhr") : loc("Öğle", "Dhuhr")
        case .ikindi: return abbreviated ? loc("İkn", "Asr") : loc("İkindi", "Asr")
        case .aksam:  return abbreviated ? loc("Akş", "Mgh") : loc("Akşam", "Maghrib")
        case .yatsi:  return abbreviated ? loc("Yat", "Ish") : loc("Yatsı", "Isha")
        }
    }
}

// MARK: - Disk cache

struct CachedTimes: Codable {
    var cityId: Int
    var cityName: String
    var fetchedAt: Date
    var days: [CachedDay]
}

struct CachedDay: Codable {
    var dateISO: String     // "yyyy-MM-dd"
    var imsak: String
    var gunes: String
    var ogle: String
    var ikindi: String
    var aksam: String
    var yatsi: String

    var vakitler: [(prayer: Prayer, time: String)] {
        [
            (.imsak, imsak),
            (.gunes, gunes),
            (.ogle, ogle),
            (.ikindi, ikindi),
            (.aksam, aksam),
            (.yatsi, yatsi),
        ]
    }

    var day: Date? { PrayerDay.isoDateFormatter.date(from: dateISO) }
}
