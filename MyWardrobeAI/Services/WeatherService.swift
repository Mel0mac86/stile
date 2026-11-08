import Foundation
import CoreLocation

enum WeatherError: LocalizedError {
    case locationDenied
    case badURL

    var errorDescription: String? {
        switch self {
        case .locationDenied: return "Posizione non autorizzata. Puoi comunque impostare la temperatura a mano."
        case .badURL: return "Indirizzo meteo non valido."
        }
    }
}

/// Meteo gratuito con Open-Meteo (nessuna chiave API). La posizione si chiede solo con il consenso
/// dell'utente e non viene salvata né inviata a nessuno: serve solo a interrogare il meteo.
final class WeatherService: NSObject, CLLocationManagerDelegate {
    /// Condizioni attuali.
    struct Current {
        let temperature: Double
        let humidity: Double
        let precipitation: Double
        let windSpeed: Double
        let weatherCode: Int

        /// Pioggia: da codice meteo (pioggia, rovesci, temporali) o precipitazioni misurate.
        var isRaining: Bool {
            (51...67).contains(weatherCode) || (80...82).contains(weatherCode)
                || (95...99).contains(weatherCode) || precipitation > 0.2
        }
    }

    /// Previsione giornaliera.
    struct Day {
        let date: String
        let maxTemp: Double
        let minTemp: Double
        /// Probabilità di pioggia in percentuale.
        let rainChance: Double
    }

    struct Place: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Meteo di oggi nella posizione dell'utente (chiede il permesso la prima volta).
    func loadCurrentWeather() async throws -> Current {
        let coordinate = try await currentCoordinate()
        let result = try await forecast(latitude: coordinate.latitude, longitude: coordinate.longitude, days: 1)
        return result.current
    }

    /// Posizione attuale, dopo aver chiesto il permesso se serve.
    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        if manager.authorizationStatus == .notDetermined {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                authContinuation = cont
                manager.requestWhenInUseAuthorization()
            }
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw WeatherError.locationDenied
        }
        let location: CLLocation = try await withCheckedThrowingContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
        return location.coordinate
    }

    /// Condizioni attuali e previsioni giornaliere (fino a 16 giorni) per una coordinata.
    func forecast(latitude: Double, longitude: Double, days: Int) async throws -> (current: Current, daily: [Day]) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: String(min(max(days, 1), 16))),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { throw WeatherError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)

        let now = response.current
        let current = Current(
            temperature: now.temperature_2m,
            humidity: now.relative_humidity_2m,
            precipitation: now.precipitation,
            windSpeed: now.wind_speed_10m,
            weatherCode: now.weather_code
        )
        let daily = response.daily
        let count = min(daily.time.count, daily.temperature_2m_max.count, daily.temperature_2m_min.count)
        var forecastDays: [Day] = []
        for i in 0..<count {
            // La probabilità di pioggia può mancare (null): in quel caso vale 0.
            let rain = i < daily.precipitation_probability_max.count ? (daily.precipitation_probability_max[i] ?? 0) : 0
            forecastDays.append(Day(
                date: daily.time[i],
                maxTemp: daily.temperature_2m_max[i],
                minTemp: daily.temperature_2m_min[i],
                rainChance: rain
            ))
        }
        return (current, forecastDays)
    }

    /// Trova una località per nome (es. "Lisbona") per leggerne il meteo.
    func geocode(_ query: String) async throws -> Place? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "it")
        ]
        guard let url = components?.url else { throw WeatherError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Results: Decodable { let results: [Place]? }
        return try JSONDecoder().decode(Results.self, from: data).results?.first
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        authContinuation?.resume()
        authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last { locationContinuation?.resume(returning: last) }
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    /// Risposta dell'API meteo. I nomi seguono il formato JSON di Open-Meteo.
    private struct Response: Decodable {
        struct Now: Decodable {
            let temperature_2m: Double
            let relative_humidity_2m: Double
            let precipitation: Double
            let wind_speed_10m: Double
            let weather_code: Int
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Double?]
        }
        let current: Now
        let daily: Daily
    }
}
