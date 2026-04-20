//
//  ClockListView.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import SwiftUI
import AppKit

struct ClockListView: View {
    
    @ObservedObject var viewModel: ClockViewModel
    
    @State private var now = Date()
    @State private var previewOffset: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var effectiveDate: Date { now.addingTimeInterval(previewOffset) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("World Clock")
                        .font(.headline)
                    Text(localDateString())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            
            if viewModel.clocks.isEmpty {
                Text("No time zones selected.\nOpen Preferences to add some.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.clocks.enumerated()), id: \.element.id) { index, entry in
                        ClockRowView(
                            city: entry.city,
                            timeString: timeString(for: entry.timeZone),
                            gmtOffset: viewModel.gmtOffset(for: entry.timeZone.identifier)
                        )
                        if index < viewModel.clocks.count - 1 {
                            Divider()
                                .opacity(0.5)
                        }
                    }
                }
            }
                        
            Button("Preferences") {
                openPreferences()
            }
            
            Button("Quit World Clock") {
                NSApp.terminate(nil)
            }
            .foregroundColor(.red)
        }
        .padding(16)
        .frame(width: 280)
        .onReceive(timer) { now = $0 }
        .onAppear { previewOffset = 0 }
    }
    
    func localDateString() -> String {
        Self.localDateFormatter.string(from: now)
    }
    
    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f
    }()
    
    func timeString(for tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone   = tz
        f.dateFormat = viewModel.popoverTimeFormat
        return f.string(from: effectiveDate)
    }
    
    func openPreferences() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.popover.performClose(nil)
        }
        
        if let existing = PrefsWindowStore.shared.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            existing.shake()
            return
        }
        
        let vc = NSHostingController(rootView: PreferencesView(viewModel: viewModel))
        let window = NSWindow(contentViewController: vc)
        window.title = "World Clock Preferences"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension NSWindow {
    func shake() {
        let numberOfShakes = 4
        let duration = 0.4
        let amplitude: CGFloat = 8
        
        let frame = self.frame
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.duration = duration
        animation.repeatCount = 1
        animation.autoreverses = false
        
        var values: [NSValue] = []
        for i in 0...numberOfShakes * 2 {
            let x = (i % 2 == 0) ? frame.midX - amplitude : frame.midX + amplitude
            values.append(NSValue(point: NSPoint(x: x, y: frame.midY)))
        }
        values.append(NSValue(point: NSPoint(x: frame.midX, y: frame.midY)))
        animation.values = values
        
        self.animations = ["position": animation]
        self.animator().setFrame(frame, display: true)
    }
}

private struct ClockRowView: View {
    let city: String
    let timeString: String
    let gmtOffset: String

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(city)
                        .foregroundStyle(.primary)
                }
                Text(gmtOffset)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeString)
                .monospacedDigit()
        }
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
