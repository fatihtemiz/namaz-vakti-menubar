import Foundation
import SwiftUI

@MainActor
final class PrayerTimesManager: ObservableObject {
    // Ayarlar — seçilen ilçe
    @AppStorage("cityId") var cityId: Int = 0
    @AppStorage("cityName") var cityName: String = ""
    @AppStorage("cityNameEn") var cityNameEn: String = ""
    // Vakit adlarını kısaltarak göster (ör. "İkindi" → "İkn")
    @AppStorage("useAbbreviations") var useAbbreviations: Bool = false {
        didSet { recompute() }
    }
    // Menü barında saniyeleri göster (kapalıyken saat:dakika, son 5 dakikada yine saniye)
    @AppStorage("showSeconds") var showSeconds: Bool = true {
        didSet { recompute() }
    }
    // Arayüz dili (Türkçe / English)
    @AppStorage(AppLanguage.storageKey) var language: AppLanguage = .tr {
        didSet { recompute() }
    }

    /// Seçili dile göre kayıtlı ilçe adı.
    var displayCityName: String {
        language == .en && !cityNameEn.isEmpty ? cityNameEn : cityName
    }

    // Menü barında görünen kısa metin, ör. "İkindi 1:23:45"
    @Published var menuTitle: String = loc("Namaz Vakti", "Prayer Times")
    // Popover durumu
    @Published var nextName: String = ""
    @Published var nextTime: String = ""
    @Published var remaining: String = ""
    @Published var todayRows: [(name: String, time: String, isNext: Bool)] = []
    // Yatsı'dan sonra liste yarının vakitlerini gösterir
    @Published var listIsTomorrow: Bool = false
    @Published var status: String = ""
    @Published var isLoading: Bool = false

    private var cache: CachedTimes?
    private var tickTimer: Timer?
    private var maintenanceTimer: Timer?
    private let api = EzanVaktiAPI()

    var isConfigured: Bool { cityId != 0 }

    // MARK: Lifecycle

    func start() {
        cache = Self.loadCache()
        recompute()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
        // Cache tazeliğini periyodik kontrol et (gün dönümü / ay bitişi için).
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.ensureFreshData() }
        }
        Task { await ensureFreshData() }
    }

    // MARK: Veri tazeliği

    /// Cache yarını kapsamıyorsa veya şehir değiştiyse yeniden çek.
    func ensureFreshData() async {
        guard isConfigured else {
            recompute()   // menü barında "Ayarla…" göster
            return
        }
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        let coversTomorrow = cache?.days.contains {
            ($0.day.map { cal.startOfDay(for: $0) }) == tomorrow
        } ?? false
        let sameCity = cache?.cityId == cityId
        if coversTomorrow && sameCity { return }
        await refresh()
    }

    /// API'den ayı çek ve cache'le.
    func refresh() async {
        guard isConfigured else {
            status = loc("Önce ayarlardan şehir/ilçe seçin.", "Choose a city/district in Settings first.")
            return
        }
        isLoading = true
        status = loc("Vakitler alınıyor…", "Fetching prayer times…")
        defer { isLoading = false }
        do {
            let days = try await api.prayerTimes(districtId: cityId)
            let cached = CachedTimes(
                cityId: cityId,
                cityName: cityName,
                fetchedAt: Date(),
                days: days.compactMap { Self.toCachedDay($0) }
            )
            self.cache = cached
            Self.saveCache(cached)
            status = ""
            recompute()
        } catch {
            status = loc("Hata: ", "Error: ") + error.localizedDescription
        }
    }

    // MARK: Geri sayım hesabı

    private func recompute() {
        guard let cache, !cache.days.isEmpty else {
            todayRows = []
            if isConfigured {
                menuTitle = isLoading ? loc("Yükleniyor…", "Loading…") : loc("Namaz Vakti", "Prayer Times")
            } else {
                menuTitle = loc("Ayarla…", "Set up…")
            }
            return
        }

        let now = Date()
        let cal = Calendar.current

        // Tüm günlerin tüm vakitlerini tam Date olarak düzleştir.
        var events: [(prayer: Prayer, date: Date)] = []
        for day in cache.days {
            guard let base = day.day else { continue }
            for v in day.vakitler {
                if let d = Self.combine(day: base, time: v.time, calendar: cal) {
                    events.append((v.prayer, d))
                }
            }
        }
        events.sort { $0.date < $1.date }

        guard let next = events.first(where: { $0.date > now }) else {
            menuTitle = displayCityName.isEmpty ? loc("Namaz Vakti", "Prayer Times") : displayCityName
            return
        }

        nextName = next.prayer.name(abbreviated: useAbbreviations)
        nextTime = Self.hhmm.string(from: next.date)
        let interval = next.date.timeIntervalSince(now)
        remaining = Self.formatRemaining(interval)
        // Saniyeler kapalıysa bar sadece dakika değişince güncellenir.
        let barTitle = "\(nextName): \(Self.formatBar(interval, withSeconds: showSeconds))"
        if menuTitle != barTitle { menuTitle = barTitle }

        // Liste sıradaki vaktin gününü gösterir (Yatsı'dan sonra yarın); sıradaki vakit işaretlenir.
        let listDay = cal.startOfDay(for: next.date)
        listIsTomorrow = !cal.isDate(listDay, inSameDayAs: now)
        if let day = cache.days.first(where: { $0.day.map { cal.startOfDay(for: $0) } == listDay }) {
            todayRows = day.vakitler.map { v in
                (v.prayer.name(abbreviated: useAbbreviations), v.time, v.prayer == next.prayer)
            }
        }
    }

    // MARK: Yardımcılar

    private static func combine(day: Date, time: String, calendar: Calendar) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var dc = calendar.dateComponents([.year, .month, .day], from: day)
        dc.hour = h
        dc.minute = m
        return calendar.date(from: dc)
    }

    private static func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// Menü barı metni: saniyeler açıksa "1:23:45"; kapalıysa "1:23", son 5 dakikada yine "0:04:59".
    /// Yukarı yuvarlanır, böylece "0:00" hiç görünmez.
    private static func formatBar(_ interval: TimeInterval, withSeconds: Bool) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        if withSeconds || seconds <= 5 * 60 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        let minutes = Int((interval / 60).rounded(.up))
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private static let hhmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func toCachedDay(_ d: PrayerDay) -> CachedDay? {
        guard let day = d.day else { return nil }
        return CachedDay(
            dateISO: PrayerDay.isoDateFormatter.string(from: day),
            imsak: d.imsak, gunes: d.gunes, ogle: d.ogle,
            ikindi: d.ikindi, aksam: d.aksam, yatsi: d.yatsi
        )
    }

    // MARK: Cache (Application Support)

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NamazVaktiMenuBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("prayertimes.json")
    }

    private static func loadCache() -> CachedTimes? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(CachedTimes.self, from: data)
    }

    private static func saveCache(_ c: CachedTimes) {
        if let data = try? JSONEncoder().encode(c) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
