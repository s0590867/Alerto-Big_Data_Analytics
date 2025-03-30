//
//  AlertoApp.swift
//  Alerto
//
//  Created by Tobias Lindhorst, Maximilian Berthold & Leander Piepenbring  on 18.03.25.
//

import SwiftUI

@main
struct AlertoApp: App {
    @StateObject private var bleManager = BLEManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
        }
    }
}
