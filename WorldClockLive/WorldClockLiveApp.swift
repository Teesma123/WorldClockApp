//
//  WorldClockApp.swift
//  WorldClock
//
//  Created by Teesma M on 16/04/26.
//

import SwiftUI

@main
struct WorldClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
