//
//  WorldClockTests.swift
//  WorldClockTests
//
//  Created by Teesma M on 16/04/26.
//

import Testing
import Foundation
@testable import WorldClock

struct WorldClockTests {

    @Test func dayOffsetSameDay() {
        let tz = TimeZone(identifier: "Europe/London")!
        let entry = ClockEntry(city: "London", timeZone: tz)
        // noon UTC — same day everywhere near UTC
        let noon = date(year: 2024, month: 6, day: 15, hour: 12, tz: .gmt)
        let diff = entry.dayOffset(from: noon, localTimeZone: .gmt)
        #expect(diff == 0)
    }

    @Test func dayOffsetAucklandAheadOfUTC() {
        let tz = TimeZone(identifier: "Pacific/Auckland")!
        let entry = ClockEntry(city: "Auckland", timeZone: tz)
        // 11pm UTC — Auckland is already into the next day (UTC+12/13)
        let lateUTC = date(year: 2024, month: 6, day: 15, hour: 23, tz: .gmt)
        let diff = entry.dayOffset(from: lateUTC, localTimeZone: .gmt)
        #expect(diff == 1)
    }

    @Test func dayOffsetHonoluluBehindUTC() {
        let tz = TimeZone(identifier: "Pacific/Honolulu")!
        let entry = ClockEntry(city: "Honolulu", timeZone: tz)
        // 1am UTC — Honolulu is still in the previous day (UTC-10)
        let earlyUTC = date(year: 2024, month: 6, day: 15, hour: 1, tz: .gmt)
        let diff = entry.dayOffset(from: earlyUTC, localTimeZone: .gmt)
        #expect(diff == -1)
    }


    @Test func gmtOffsetKolkata() {
        let vm = ClockViewModel()
        let result = vm.gmtOffset(for: "Asia/Kolkata")
        #expect(result == "GMT+5:30")
    }

    @Test func gmtOffsetLondonWinter() {
        let vm = ClockViewModel()
        let result = vm.gmtOffset(for: "Europe/London")
        // In winter UTC+0, in summer BST UTC+1 — just confirm format is valid
        #expect(result == "GMT" || result == "GMT+1")
    }

    @Test func gmtOffsetUTC() {
        let vm = ClockViewModel()
        let result = vm.gmtOffset(for: "UTC")
        #expect(result == "GMT")
    }


    private func date(year: Int, month: Int, day: Int, hour: Int, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = DateComponents(year: year, month: month, day: day, hour: hour)
        return cal.date(from: comps)!
    }
}

private extension TimeZone {
    static let gmt = TimeZone(identifier: "GMT")!
}
