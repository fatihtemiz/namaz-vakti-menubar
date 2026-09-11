import Foundation

enum APIError: LocalizedError {
    case http(Int)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .http(let code): return loc("Sunucu hatası (HTTP \(code))", "Server error (HTTP \(code))")
        case .emptyData: return loc("Sunucudan boş cevap geldi", "Server returned an empty response")
        }
    }
}

/// EzanVakti API istemcisi — Diyanet verisi, kimlik doğrulama GEREKMEZ.
/// https://ezanvakti.emushaf.net/
struct EzanVaktiAPI {
    static let baseURL = URL(string: "https://ezanvakti.emushaf.net/")!

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    func countries() async throws -> [Place] {
        try await get("ulkeler")
    }

    func cities(countryId: Int) async throws -> [Place] {
        try await get("sehirler/\(countryId)")
    }

    func districts(cityId: Int) async throws -> [Place] {
        try await get("ilceler/\(cityId)")
    }

    /// Seçilen ilçe için bir aylık vakit listesi.
    func prayerTimes(districtId: Int) async throws -> [PrayerDay] {
        try await get("vakitler/\(districtId)")
    }

    // MARK: Helper

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = Self.baseURL.appendingPathComponent(path)
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
