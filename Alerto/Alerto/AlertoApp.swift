//
//  NoiseNinaApp.swift
//  NoiseNina
//
//  Created by Tobias Lindhorst  on 18.03.25.
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


