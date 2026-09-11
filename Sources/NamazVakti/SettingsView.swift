import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: PrayerTimesManager

    @State private var countries: [Place] = []
    @State private var cities: [Place] = []
    @State private var districts: [Place] = []

    @State private var selectedCountry: Int = 0
    @State private var selectedCity: Int = 0
    @State private var selectedDistrict: Int = 0

    @State private var busy = false
    @State private var message = ""

    private let api = EzanVaktiAPI()

    var body: some View {
        Form {
            Section(loc("Dil", "Language")) {
                Picker(loc("Arayüz dili", "Interface language"), selection: $manager.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section(loc("Konum Seçimi", "Location")) {
                Picker(loc("Ülke", "Country"), selection: $selectedCountry) {
                    Text(loc("Seçin", "Select")).tag(0)
                    ForEach(countries) { Text($0.displayName).tag($0.id) }
                }
                .onChange(of: selectedCountry) { _, id in Task { await loadCities(id) } }

                Picker(loc("Şehir", "City"), selection: $selectedCity) {
                    Text(loc("Seçin", "Select")).tag(0)
                    ForEach(cities) { Text($0.displayName).tag($0.id) }
                }
                .onChange(of: selectedCity) { _, id in Task { await loadDistricts(id) } }
                .disabled(cities.isEmpty)

                Picker(loc("İlçe", "District"), selection: $selectedDistrict) {
                    Text(loc("Seçin", "Select")).tag(0)
                    ForEach(districts) { Text($0.displayName).tag($0.id) }
                }
                .disabled(districts.isEmpty)

                if busy { HStack { ProgressView().controlSize(.small); Text(loc("Yükleniyor…", "Loading…")).font(.caption) } }
            }

            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button(loc("Kaydet", "Save")) { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedDistrict == 0)
                    Spacer()
                    if manager.cityId != 0 {
                        Text(loc("Kayıtlı: ", "Saved: ") + manager.displayCityName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text(loc("Veri kaynağı: ezanvakti.emushaf.net (Diyanet verisi). Kayıt/giriş gerekmez.",
                         "Data source: ezanvakti.emushaf.net (Diyanet data). No sign-up or login needed."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 470)
        .task { await loadCountries() }
    }

    // MARK: Yükleme

    private func loadCountries() async {
        guard countries.isEmpty else { return }
        busy = true; defer { busy = false }
        do { countries = try await api.countries() }
        catch { message = loc("Ülkeler alınamadı: ", "Couldn't load countries: ") + error.localizedDescription }
    }

    private func loadCities(_ countryId: Int) async {
        guard countryId != 0 else { return }
        cities = []; districts = []; selectedCity = 0; selectedDistrict = 0
        busy = true; defer { busy = false }
        do { cities = try await api.cities(countryId: countryId) }
        catch { message = loc("Şehirler alınamadı: ", "Couldn't load cities: ") + error.localizedDescription }
    }

    private func loadDistricts(_ cityId: Int) async {
        guard cityId != 0 else { return }
        districts = []; selectedDistrict = 0
        busy = true; defer { busy = false }
        do { districts = try await api.districts(cityId: cityId) }
        catch { message = loc("İlçeler alınamadı: ", "Couldn't load districts: ") + error.localizedDescription }
    }

    private func save() {
        guard selectedDistrict != 0 else { return }
        let district = districts.first { $0.id == selectedDistrict }
        manager.cityId = selectedDistrict
        manager.cityName = district?.name ?? ""
        manager.cityNameEn = district?.nameEn ?? ""
        message = loc("Kaydedildi.", "Saved.")
        Task { await manager.refresh() }
    }
}
