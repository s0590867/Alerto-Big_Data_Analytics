//
//  BLEManager.swift
//  Alerto
//
//  Created by Tobias Lindhorst on 24.03.25.
//

import Foundation
import CoreBluetooth
import UserNotifications
import SwiftUI
import AudioToolbox  // Für Vibration

// Struktur zur Speicherung eines empfangenen Geräuschs
struct SoundRecord: Identifiable {
    let id = UUID()
    let sound: String
    let timestamp: Date
}

class BLEManager: NSObject, ObservableObject {
    @Published var recognizedSound: String = "hört zu"
    @Published var serviceRunning: Bool = false  // Status des BLE-Services
    @Published var soundHistory: [SoundRecord] = []  // Liste der empfangenen Geräusche
    @Published var shouldAnimate: Bool = false       // Wird hier nicht mehr direkt genutzt
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var resetTimer: Timer?  // Timer, der nach 10 Sekunden das Signal zurücksetzt
    
    private var lastValidSound: String?  // Speichert den zuletzt gültigen Sound

    // UUIDs – passe diese ggf. an
    private let soundServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789ABCDEF0")
    private let soundCharacteristicUUID = CBUUID(string: "87654321-4321-6789-4321-0FEDCBA98765")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        requestNotificationAuthorization()
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Fehler bei Benachrichtigungsberechtigung: \(error)")
            }
        }
    }
    
    private func sendLocalNotification(for sound: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔊 \(sound) 🔊"
        content.body = "Es wurde ein neues Geräusch erkannt."
        content.sound = .defaultCritical  // Kritischer Standardton
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // BLE-Service starten
    func startService() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [soundServiceUUID], options: nil)
            serviceRunning = true
            shouldAnimate = true
            recognizedSound = "hört zu"
            resetTimer?.invalidate()
            resetTimer = nil
            print("BLE-Service gestartet")
        } else {
            print("Bluetooth ist nicht eingeschaltet oder nicht verfügbar")
        }
    }
    
    // BLE-Service stoppen
    func stopService() {
        centralManager.stopScan()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
        serviceRunning = false
        shouldAnimate = false
        resetTimer?.invalidate()
        resetTimer = nil
        recognizedSound = "hört nicht zu"
        print("BLE-Service gestoppt")
    }
}

extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if serviceRunning {
                centralManager.scanForPeripherals(withServices: [soundServiceUUID], options: nil)
            }
        default:
            print("Bluetooth ist nicht verfügbar. (State: \(central.state.rawValue))")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([soundServiceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == soundServiceUUID {
                peripheral.discoverCharacteristics([soundCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics where characteristic.uuid == soundCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == soundCharacteristicUUID,
              let data = characteristic.value,
              let soundDetected = String(data: data, encoding: .utf8) else {
            return
        }
        
        DispatchQueue.main.async {
            // Für den Fall, dass "rauschen" empfangen wird, setze recognizedSound auf "hört zu"
            if soundDetected.lowercased() == "rauschen" {
                self.resetTimer?.invalidate()
                self.recognizedSound = "hört zu"
                // Kein Timer wird gestartet, solange der Dienst aktiv ist
                return
            }
            
            // Für alle anderen gültigen Signale:
            self.resetTimer?.invalidate()
            self.resetTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
                self.resetTimer = nil
                if self.serviceRunning {
                    self.recognizedSound = "hört zu"
                } else {
                    self.recognizedSound = "hört nicht zu"
                }
            }
            
            self.lastValidSound = soundDetected
            self.recognizedSound = soundDetected
            // Die Animation bleibt aktiv, solange der Dienst läuft
            self.shouldAnimate = self.serviceRunning
            
            // Gerät vibrieren lassen
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            
            // Kritische Benachrichtigung versenden
            self.sendLocalNotification(for: soundDetected)
        }
    }
}
