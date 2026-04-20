//
//  ClockViewModel.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import Foundation
import SwiftUI
import ServiceManagement

struct MenuBarZoneSettings: Codable, Equatable {
    var showInMenuBar: Bool = true
    var clockLabel: String = ""
}

class ClockViewModel: ObservableObject {

    @Published var selectedTimeZones: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedTimeZones, forKey: "zones")
        }
    }

    @Published var menuBarZones: [String] = [] {
        didSet {
            UserDefaults.standard.set(menuBarZones, forKey: "menuBarZones")
            notifyMenuBarChanged()
        }
    }

    @Published var menuBarZoneSettings: [String: MenuBarZoneSettings] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(menuBarZoneSettings) {
                UserDefaults.standard.set(encoded, forKey: "menuBarZoneSettings")
            }
            notifyMenuBarChanged()
        }
    }

    @Published var use24HourClock: Bool = ClockViewModel.systemPrefers24Hour() {
        didSet {
            UserDefaults.standard.set(use24HourClock, forKey: "use24HourClock")
            notifyMenuBarChanged()
        }
    }

    @Published var showSecondsInMenuBar: Bool = false {
        didSet {
            UserDefaults.standard.set(showSecondsInMenuBar, forKey: "showSecondsInMenuBar")
            notifyMenuBarChanged()
        }
    }

    @Published var showDateInMenuBar: Bool = false {
        didSet {
            UserDefaults.standard.set(showDateInMenuBar, forKey: "showDateInMenuBar")
            notifyMenuBarChanged()
        }
    }

    @Published var launchAtLogin: Bool = false {
        didSet {
            applyLaunchAtLogin()
        }
    }

    let maxListZones  = 4
    let maxMenuBarZones = 2

    var onMenuBarChanged: (() -> Void)?

    init() {
        if let saved = UserDefaults.standard.array(forKey: "zones") as? [String] {
            selectedTimeZones = saved
        } else {
            selectedTimeZones = ["Asia/Kolkata", "America/New_York", "Europe/London"]
        }

        if let saved = UserDefaults.standard.array(forKey: "menuBarZones") as? [String] {
            menuBarZones = saved
        } else {
            menuBarZones = ["Europe/London"]
        }

        if let data = UserDefaults.standard.data(forKey: "menuBarZoneSettings"),
           let decoded = try? JSONDecoder().decode([String: MenuBarZoneSettings].self, from: data) {
            menuBarZoneSettings = decoded
        }

        if UserDefaults.standard.object(forKey: "use24HourClock") != nil {
            use24HourClock = UserDefaults.standard.bool(forKey: "use24HourClock")
        }

        if UserDefaults.standard.object(forKey: "showSecondsInMenuBar") != nil {
            showSecondsInMenuBar = UserDefaults.standard.bool(forKey: "showSecondsInMenuBar")
        }

        if UserDefaults.standard.object(forKey: "showDateInMenuBar") != nil {
            showDateInMenuBar = UserDefaults.standard.bool(forKey: "showDateInMenuBar")
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var clocks: [ClockEntry] {
        selectedTimeZones.compactMap {
            guard let tz = TimeZone(identifier: $0) else { return nil }
            let settings = menuBarZoneSettings[$0, default: MenuBarZoneSettings()]
            let trimmed  = settings.clockLabel.trimmingCharacters(in: .whitespaces)
            let label    = trimmed.isEmpty ? cityName(from: $0) : trimmed
            return ClockEntry(city: label, timeZone: tz)
        }
    }

    var menuBarClocks: [ClockEntry] {
        menuBarZones.compactMap { zone in
            let s = menuBarZoneSettings[zone, default: MenuBarZoneSettings()]
            guard s.showInMenuBar, let tz = TimeZone(identifier: zone) else { return nil }
            let label = s.clockLabel.isEmpty ? cityName(from: zone) : s.clockLabel
            return ClockEntry(city: label, timeZone: tz)
        }
    }

    var allTimeZones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    func settingsBinding(for zone: String) -> Binding<MenuBarZoneSettings> {
        Binding(
            get: { self.menuBarZoneSettings[zone, default: MenuBarZoneSettings()] },
            set: { self.menuBarZoneSettings[zone] = $0 }
        )
    }

    func toggleListZone(zone: String) {
        if selectedTimeZones.contains(zone) {
            selectedTimeZones.removeAll { $0 == zone }
        } else {
            guard selectedTimeZones.count < maxListZones else { return }
            selectedTimeZones.append(zone)
        }
    }

    func toggleMenuBarZone(zone: String) {
        if menuBarZones.contains(zone) {
            menuBarZones.removeAll { $0 == zone }
        } else {
            guard menuBarZones.count < maxMenuBarZones else { return }
            menuBarZones.append(zone)
        }
    }

    func moveMenuBarZones(from source: IndexSet, to destination: Int) {
        menuBarZones.move(fromOffsets: source, toOffset: destination)
    }

    func applyMenuBarVisibility() {
        notifyMenuBarChanged()
    }

    func cityName(from zone: String) -> String {
        zone.split(separator: "/").last?
            .replacingOccurrences(of: "_", with: " ") ?? zone
    }

    var menuBarTimeFormat: String {
        switch (use24HourClock, showSecondsInMenuBar) {
        case (true,  true):  return "HH:mm:ss"
        case (true,  false): return "HH:mm"
        case (false, true):  return "h:mm:ss a"
        case (false, false): return "h:mm a"
        }
    }
    var popoverTimeFormat: String { use24HourClock ? "HH:mm:ss" : "h:mm:ss a" }

    private static func systemPrefers24Hour() -> Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return !template.contains("a")
    }

    func shortCode(for city: String) -> String {
        let folded  = city.folding(options: .diacriticInsensitive, locale: .current)
        let letters = folded.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let code    = String(String.UnicodeScalarView(letters.prefix(3)))
        return code.isEmpty ? "•" : code.uppercased()
    }

    func gmtOffset(for identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "GMT" }
        let seconds = tz.secondsFromGMT()
        if seconds == 0 { return "GMT" }
        let hours   = seconds / 3600
        let minutes = abs((seconds % 3600) / 60)
        return minutes == 0
            ? String(format: "GMT%+d", hours)
            : String(format: "GMT%+d:%02d", hours, minutes)
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // User may have disabled login items system-wide; ignore silently
        }
    }

    private func notifyMenuBarChanged() {
        DispatchQueue.main.async { self.onMenuBarChanged?() }
    }
}
