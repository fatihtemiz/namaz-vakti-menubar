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
            Section("Konum Seçimi") {
                Picker("Ülke", selection: $selectedCountry) {
                    Text("Seçin").tag(0)
                    ForEach(countries) { Text($0.name).tag($0.id) }
                }
                .onChange(of: selectedCountry) { _, id in Task { await loadCities(id) } }

                Picker("Şehir", selection: $selectedCity) {
                    Text("Seçin").tag(0)
                    ForEach(cities) { Text($0.name).tag($0.id) }
                }
                .onChange(of: selectedCity) { _, id in Task { await loadDistricts(id) } }
                .disabled(cities.isEmpty)

                Picker("İlçe", selection: $selectedDistrict) {
                    Text("Seçin").tag(0)
                    ForEach(districts) { Text($0.name).tag($0.id) }
                }
                .disabled(districts.isEmpty)

                if busy { HStack { ProgressView().controlSize(.small); Text("Yükleniyor…").font(.caption) } }
            }

            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Kaydet") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedDistrict == 0)
                    Spacer()
                    if manager.cityId != 0 {
                        Text("Kayıtlı: \(manager.cityName)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Veri kaynağı: ezanvakti.emushaf.net (Diyanet verisi). Kayıt/giriş gerekmez.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 400)
        .task { await loadCountries() }
    }

    // MARK: Yükleme

    private func loadCountries() async {
        guard countries.isEmpty else { return }
        busy = true; defer { busy = false }
        do { countries = try await api.countries() }
        catch { message = "Ülkeler alınamadı: \(error.localizedDescription)" }
    }

    private func loadCities(_ countryId: Int) async {
        guard countryId != 0 else { return }
        cities = []; districts = []; selectedCity = 0; selectedDistrict = 0
        busy = true; defer { busy = false }
        do { cities = try await api.cities(countryId: countryId) }
        catch { message = "Şehirler alınamadı: \(error.localizedDescription)" }
    }

    private func loadDistricts(_ cityId: Int) async {
        guard cityId != 0 else { return }
        districts = []; selectedDistrict = 0
        busy = true; defer { busy = false }
        do { districts = try await api.districts(cityId: cityId) }
        catch { message = "İlçeler alınamadı: \(error.localizedDescription)" }
    }

    private func save() {
        guard selectedDistrict != 0 else { return }
        manager.cityId = selectedDistrict
        manager.cityName = districts.first { $0.id == selectedDistrict }?.name ?? ""
        message = "Kaydedildi."
        Task { await manager.refresh() }
    }
}
