//
//  PreferencesView.swift
//  WorldClock
//
//  Created by Teesma M on 17/04/26.
//

import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var selectedTab = 0
 

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Menu Bar").tag(0)
                Text("Clock List").tag(1)
                Text("Display").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
 
            Divider()

            if selectedTab == 0 {
                MenuBarZonesPane(viewModel: viewModel)
            } else if selectedTab == 1 {
                ClockListZonesPane(viewModel: viewModel)
            } else {
                DisplayPane(viewModel: viewModel)
            }
        }
        .frame(width: 700, height: 500)
        .background(WindowAccessor())
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            PrefsWindowStore.shared.window = v.window
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            PrefsWindowStore.shared.window = nsView.window
        }
    }
}
 
final class PrefsWindowStore {
    static let shared = PrefsWindowStore()
    weak var window: NSWindow?
    private init() {}
    func close() { window?.close() }
}

private func friendlyName(_ zone: String) -> String {
    let parts = zone.split(separator: "/")
    guard parts.count >= 2 else { return zone }
    let city   = parts.last!.replacingOccurrences(of: "_", with: " ")
    let region = parts.first!.replacingOccurrences(of: "_", with: " ")
    return "\(city), \(region)"
}

struct CursorSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
 
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.focusRingType = .exterior
        field.refusesFirstResponder = false
        return field
    }
 
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }
 
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ obj: Notification) {
            if let f = obj.object as? NSSearchField { text = f.stringValue }
        }
    }
}

private struct CityRowContent: View {
    let zone: String
    let isSelected: Bool
    let isDisabled: Bool
    let showCheckmark: Bool
 
    var body: some View {
        HStack(spacing: 0) {
            Text(friendlyName(zone))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(rowForeground)
            Text(gmtOffset(zone))
                .frame(width: 80, alignment: .leading)
                .font(.caption)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 4))
        .opacity(isDisabled ? 0.38 : 1.0)
        .contentShape(Rectangle())
    }
 
    private var rowForeground: Color {
        isSelected ? .white : .primary
    }
 
    private func gmtOffset(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "GMT" }
        let s = tz.secondsFromGMT()
        if s == 0 { return "GMT" }
        let h = s / 3600; let m = abs((s % 3600) / 60)
        return m == 0 ? String(format: "GMT%+d", h) : String(format: "GMT%+d:%02d", h, m)
    }
}
  
private struct SelectedZoneRow: View {
    let zone: String
    var settingsBinding: Binding<MenuBarZoneSettings>?
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var draftLabel = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.body)
            if isEditing, let binding = settingsBinding {
                TextField("Custom label", text: Binding(
                    get: { draftLabel },
                    set: { draftLabel = String($0.prefix(24)) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .onSubmit { commitLabel(binding) }
                Button(action: { commitLabel(binding) }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help("Save label")
            } else {
                Text(displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(gmtOffset(zone))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                    .font(.caption)
                if settingsBinding != nil {
                    Button(action: beginEditing) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Rename")
                }
            }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var displayName: String {
        let trimmed = settingsBinding?.wrappedValue.clockLabel
            .trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? friendlyName(zone) : trimmed
    }

    private func beginEditing() {
        draftLabel = settingsBinding?.wrappedValue.clockLabel
            .trimmingCharacters(in: .whitespaces) ?? ""
        isEditing = true
    }

    private func commitLabel(_ binding: Binding<MenuBarZoneSettings>) {
        var s = binding.wrappedValue
        s.clockLabel = draftLabel.trimmingCharacters(in: .whitespaces)
        binding.wrappedValue = s
        isEditing = false
    }

    private func gmtOffset(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "GMT" }
        let s = tz.secondsFromGMT()
        if s == 0 { return "GMT" }
        let h = s / 3600; let m = abs((s % 3600) / 60)
        return m == 0 ? String(format: "GMT%+d", h) : String(format: "GMT%+d:%02d", h, m)
    }
}
  
private struct LabeledToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 6))
                .foregroundStyle(Color.accentColor)
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct AboutBlock: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "World Clock"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("\(appName) \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Created by Teeshma")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Link("LinkedIn ↗", destination: URL(string: "https://www.linkedin.com/in/teesma/")!)
                    .font(.caption)
                Link("Email ↗", destination: URL(string: "mailto:teeshmateeshu@gmail.com")!)
                    .font(.caption)
            }
        }
        .padding(.top, 8)
    }
}

struct MenuBarZonesPane: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var searchText = ""
    @State private var isDropTargeted = false

    private var selectedSet: Set<String> { Set(viewModel.menuBarZones) }

    var filteredZones: [String] {
        guard !searchText.isEmpty else { return viewModel.allTimeZones }
        let q = searchText.lowercased()
        return viewModel.allTimeZones.filter { $0.lowercased().contains(q) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                
                // LEFT — all cities
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose cities")
                        .font(.headline)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)

                    CursorSearchField(text: $searchText,
                                      placeholder: "Search for city or country")
                    .frame(height: 28)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 18)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    List(filteredZones, id: \.self) { zone in
                        let isSelected = selectedSet.contains(zone)
                        let isAtLimit  = !isSelected && viewModel.menuBarZones.count >= viewModel.maxMenuBarZones
                        
                        CityRowContent(
                            zone: zone,
                            isSelected: isSelected,
                            isDisabled: isAtLimit,
                            showCheckmark: true
                        )
                        .onDrag {
                            NSItemProvider(object: zone as NSString)
                        }
                        .onTapGesture {
                            guard !isAtLimit else { return }
                            viewModel.toggleMenuBarZone(zone: zone)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                            if let zone = item as? String {
                                DispatchQueue.main.async {
                                    viewModel.menuBarZones.removeAll { $0 == zone }
                                }
                            }
                        }
                        return true
                    }
                }
                .frame(maxWidth: .infinity)
            
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 1)

                // RIGHT — selected zones
                VStack(alignment: .leading, spacing: 0) {
                    Text("You can select up to \(viewModel.maxMenuBarZones) cities to show in the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("Menu Item").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 100, alignment: .leading)
                        Spacer().frame(width: 32)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()

                    if viewModel.menuBarZones.isEmpty {
                        VStack {
                            Spacer()
                            Text("Your world clock is empty.\nDrag & drop cities from the left to get started.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.menuBarZones.contains(zone),
                                              viewModel.menuBarZones.count < viewModel.maxMenuBarZones else { return }
                                        viewModel.menuBarZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    } else {
                        List {
                            ForEach(viewModel.menuBarZones, id: \.self) { zone in
                                SelectedZoneRow(
                                    zone: zone,
                                    settingsBinding: viewModel.settingsBinding(for: zone)
                                ) {
                                    viewModel.menuBarZones.removeAll { $0 == zone }
                                }
                                .onDrag { NSItemProvider(object: zone as NSString) }
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { viewModel.moveMenuBarZones(from: $0, to: $1) }
                            .onDelete { viewModel.menuBarZones.remove(atOffsets: $0) }
                        }
                        .listStyle(.plain)
                        
                        .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.menuBarZones.contains(zone),
                                              viewModel.menuBarZones.count < viewModel.maxMenuBarZones else { return }
                                        viewModel.menuBarZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.5 : 0), lineWidth: 1.5)
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
        }
    }
}

struct ClockListZonesPane: View {
    @ObservedObject var viewModel: ClockViewModel
    @State private var searchText = ""
    
    @State private var isDropTargeted = false

    private var selectedSet: Set<String> { Set(viewModel.selectedTimeZones) }
    
    var filteredZones: [String] {
        guard !searchText.isEmpty else { return viewModel.allTimeZones }
        let q = searchText.lowercased()
        return viewModel.allTimeZones.filter { $0.lowercased().contains(q) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                
                // LEFT — all cities
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose cities")
                        .font(.headline)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    
                    CursorSearchField(text: $searchText,
                                      placeholder: "Search for city or country")
                    .frame(height: 28)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 80, alignment: .leading)
                        Spacer().frame(width: 18)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()

                    List(filteredZones, id: \.self) { zone in
                        let isSelected = selectedSet.contains(zone)
                        let isAtLimit  = !isSelected && viewModel.selectedTimeZones.count >= viewModel.maxListZones
                        
                        CityRowContent(
                            zone: zone,
                            isSelected: isSelected,
                            isDisabled: isAtLimit,
                            showCheckmark: true
                        )
                        .onDrag {
                            NSItemProvider(object: zone as NSString)
                        }
                        .onTapGesture {
                            guard !isAtLimit else { return }
                            viewModel.toggleListZone(zone: zone)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                            if let zone = item as? String {
                                DispatchQueue.main.async {
                                    viewModel.selectedTimeZones.removeAll { $0 == zone }
                                }
                            }
                        }
                        return true
                    }
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 1)

                // RIGHT — selected clock list zones
                VStack(alignment: .leading, spacing: 0) {
                    Text("You can add up to \(viewModel.maxListZones) cities to track time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("City").bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("Time Zone").bold().frame(width: 100, alignment: .leading)
                        Spacer().frame(width: 32)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()

                    if viewModel.selectedTimeZones.isEmpty {
                        VStack {
                            Spacer()
                            Text("Your world clock is empty.\nDrag & drop cities from the left to get started.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.selectedTimeZones.contains(zone),
                                              viewModel.selectedTimeZones.count < viewModel.maxListZones else { return }
                                        viewModel.selectedTimeZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    } else {
                        List {
                            ForEach(viewModel.selectedTimeZones, id: \.self) { zone in
                                SelectedZoneRow(
                                    zone: zone,
                                    settingsBinding: viewModel.settingsBinding(for: zone)
                                ) {
                                    viewModel.selectedTimeZones.removeAll { $0 == zone }
                                }
                                .onDrag { NSItemProvider(object: zone as NSString) }
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { viewModel.selectedTimeZones.move(fromOffsets: $0, toOffset: $1) }
                            .onDelete { viewModel.selectedTimeZones.remove(atOffsets: $0) }
                        }
                        .listStyle(.plain)
                        
                        .onDrop(of: [.plainText], isTargeted: $isDropTargeted) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                                if let zone = item as? String {
                                    DispatchQueue.main.async {
                                        guard !viewModel.selectedTimeZones.contains(zone),
                                              viewModel.selectedTimeZones.count < viewModel.maxListZones else { return }
                                        viewModel.selectedTimeZones.append(zone)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.5 : 0), lineWidth: 1.5)
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
        }
    }
}

struct DisplayPane: View {
    @ObservedObject var viewModel: ClockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledToggle(icon: "clock", label: "Use 24-hour time", isOn: $viewModel.use24HourClock)
            LabeledToggle(icon: "timer", label: "Show seconds in menu bar", isOn: $viewModel.showSecondsInMenuBar)
            LabeledToggle(icon: "calendar", label: "Show date in menu bar", isOn: $viewModel.showDateInMenuBar)
            LabeledToggle(icon: "arrow.up.right.square", label: "Launch at login", isOn: $viewModel.launchAtLogin)
            Spacer()
            AboutBlock()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
