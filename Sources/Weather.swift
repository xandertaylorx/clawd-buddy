import Cocoa

final class WeatherState {
    var lat: Double? = UserDefaults.standard.object(forKey: "wxLat") as? Double
    var lon: Double? = UserDefaults.standard.object(forKey: "wxLon") as? Double
    var city: String = UserDefaults.standard.string(forKey: "wxCity") ?? ""
    var temp: Double?
    var code = 0
    var isDay = true
    var kind = Weather.none
    var lastFetch = 0.0
    var fetching = false
}

extension Pet {
    // MARK: day / night

    var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 21 || h < 6
    }

    func dayString() -> String { DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) }

    /// Good morning, bedtime nudges. Called about once a second.
    func dayNightChecks() {
        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour, from: now), m = cal.component(.minute, from: now)
        let d = UserDefaults.standard
        if h >= 5 && h < 12 && d.string(forKey: "greetedDay") != dayString() && !userIdle && mode == .desk && !isQuiet {
            d.set(dayString(), forKey: "greetedDay")
            brain.start(.wave)
            say(["Good morning!", "Morning! Coffee time?", "Rise and shine!"].randomElement()!, hold: 3)
        }
        guard on("bedtime"), !isQuiet else { return }
        let mins = h * 60 + m
        if mins >= 23 * 60 + 30 && mins < 24 * 60 && d.string(forKey: "bedtimeA") != dayString() {
            d.set(dayString(), forKey: "bedtimeA")
            alert("It's getting late. Bedtime soon? 🌙", hold: 7, sound: "x")
        } else if mins >= 30 && mins < 120 && d.string(forKey: "bedtimeB") != dayString() {
            d.set(dayString(), forKey: "bedtimeB")
            alert("It's really late. Go to sleep!", hold: 7, sound: "x")
        }
    }

    // MARK: weather (Open-Meteo, no key)

    func weatherKind(code: Int, temp: Double, isDay: Bool) -> Weather {
        if [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].contains(code) { return .rain }
        if [71, 73, 75, 77, 85, 86].contains(code) { return .snow }
        if temp >= 27 && isDay { return .hot }
        if temp <= 4 { return .cold }
        return .none
    }

    func weatherSummary() -> String {
        guard wx.lat != nil else { return "Weather: set a city in my menu" }
        guard let t = wx.temp else { return "Weather: loading…" }
        let names: [Weather: String] = [.rain: "rain", .snow: "snow", .hot: "hot", .cold: "cold", .none: "mild"]
        return "\(wx.city): \(Int(t.rounded()))°C, \(names[wx.kind] ?? "")"
    }

    @objc func setWeatherCity() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Where's your weather?"
        alert.informativeText = "Type a city. I'll dress for it (umbrella, shades, scarf…). Uses open-meteo.com, no account."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "e.g. Manchester"
        field.stringValue = wx.city
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let q = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(enc)&count=1") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let r = (j["results"] as? [[String: Any]])?.first,
                      let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else {
                    self.say("I couldn't find \"\(q)\".", hold: 3)
                    return
                }
                self.wx.lat = lat
                self.wx.lon = lon
                self.wx.city = r["name"] as? String ?? q
                let d = UserDefaults.standard
                d.set(lat, forKey: "wxLat"); d.set(lon, forKey: "wxLon"); d.set(self.wx.city, forKey: "wxCity")
                self.say("Got it: \(self.wx.city).", hold: 2)
                self.fetchWeather(announce: true)
            }
        }.resume()
    }

    func fetchWeather(announce: Bool = false) {
        guard let lat = wx.lat, let lon = wx.lon, !wx.fetching,
              let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,is_day") else { return }
        wx.fetching = true
        wx.lastFetch = CACurrentMediaTime()
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.wx.fetching = false
                guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let cur = j["current"] as? [String: Any],
                      let t = cur["temperature_2m"] as? Double, let code = cur["weather_code"] as? Int else { return }
                let isDay = (cur["is_day"] as? Int ?? 1) == 1
                let old = self.wx.kind
                self.wx.temp = t
                self.wx.code = code
                self.wx.isDay = isDay
                self.wx.kind = self.weatherKind(code: code, temp: t, isDay: isDay)
                if (announce || old != self.wx.kind) && !self.isQuiet {
                    let line: [Weather: String] = [.rain: "It's raining. Umbrella time! ☂", .snow: "Snow! ❄",
                                                   .hot: "Hot out. Shades on. 😎", .cold: "Brr! Scarf on.",
                                                   .none: "Nice and mild out there."]
                    if let l = self.wx.kind == .none && !announce ? nil : line[self.wx.kind] {
                        self.say(l, hold: 4)
                    }
                }
            }
        }.resume()
    }
}
