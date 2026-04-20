//
//  ClockEntry.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import Foundation

struct ClockEntry: Identifiable {
    let id = UUID()
    let city: String
    let timeZone: TimeZone
    func dayOffset(from date: Date, localTimeZone: TimeZone) -> Int {
        var localCal = Calendar.current
        localCal.timeZone = localTimeZone
        var zoneCal = Calendar.current
        zoneCal.timeZone = timeZone
        // Extract y/m/d in each timezone, then compare as plain dates so offsets cancel out
        let localComponents = localCal.dateComponents([.year, .month, .day], from: date)
        let zoneComponents  = zoneCal.dateComponents([.year, .month, .day], from: date)
        var refCal = Calendar(identifier: .gregorian)
        refCal.timeZone = TimeZone(identifier: "GMT")!
        guard let localDay = refCal.date(from: localComponents),
              let zoneDay  = refCal.date(from: zoneComponents) else { return 0 }
        return refCal.dateComponents([.day], from: localDay, to: zoneDay).day ?? 0
    }
}
