//
//  AppDelegate.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItems: [NSStatusItem] = []
    private var clockTimer: Timer?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f
    }()

    let viewModel = ClockViewModel()
    var popover = NSPopover()
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel.onMenuBarChanged = { [weak self] in
            self?.rebuildStatusItems()
        }

        rebuildStatusItems()

        popover.contentSize  = NSSize(width: 300, height: 460)
        popover.behavior     = .transient
        popover.contentViewController =
            NSHostingController(rootView: ClockListView(viewModel: viewModel))

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatusItemTitles()
        }
    }

    private func rebuildStatusItems() {
        for item in statusItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
        
        let clocks = viewModel.menuBarClocks   
        
        if clocks.isEmpty {
            let fallback = makeStatusItem()
            fallback.button?.image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "World Clock"
            )
            statusItems.append(fallback)
            return
        }
        
        let item = makeStatusItem()
        item.button?.title   = mergedTitle(for: clocks)
        item.button?.toolTip = clocks.map { $0.city }.joined(separator: " • ")
        statusItems.append(item)
    }

    private func updateStatusItemTitles() {
        let clocks = viewModel.menuBarClocks
        guard !clocks.isEmpty else { return }
        
        statusItems.first?.button?.title = mergedTitle(for: clocks)
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        return item
    }

    private func dayOffsetSuffix(for clock: ClockEntry, now: Date) -> String {
        let diff = clock.dayOffset(from: now, localTimeZone: TimeZone.current)
        guard diff != 0 else { return "" }
        return diff > 0 ? " (+\(diff))" : " (\(diff))"
    }

    private func mergedTitle(for clocks: [ClockEntry]) -> String {
        let now = Date.now
        timeFormatter.dateFormat = viewModel.menuBarTimeFormat
        let timeStr = clocks.map { clock -> String in
            timeFormatter.timeZone = clock.timeZone
            return "\(viewModel.shortCode(for: clock.city)) \(timeFormatter.string(from: now))"
        }.joined(separator: " · ")
        guard viewModel.showDateInMenuBar else { return timeStr }
        return "\(dateFormatter.string(from: now)) · \(timeStr)"
    }

    @objc func togglePopover() {
        guard let button = statusItems.first?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
