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
import AudioToolbox

// Struktur zur Speicherung eines empfangenen Geräuschs
struct SoundRecord: Identifiable {
    let id = UUID()
    let sound: String
    let timestamp: Date
}

class BLEManager: NSObject, ObservableObject {
    @Published var recognizedSound: String = "Kein Geräusch"
    @Published var serviceRunning: Bool = false  // Status des BLE-Services
    @Published var soundHistory: [SoundRecord] = []  // Liste der empfangenen Geräusche

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var resetTimer: Timer?

    // UUIDs
    private let soundServiceUUID = CBUUID(string: "fa71f9aa-e22e-42a7-a530-109d9416f179")
    private let soundCharacteristicUUID = CBUUID(string: "bcfd9054-1b04-46a4-a2a4-856ae18c455e")
    
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
            // Wenn das empfangene Signal "Rauschen" ist, ignoriere es
            if soundDetected.lowercased() == "rauschen" {
                if self.resetTimer == nil {
                    self.resetTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
                        self.resetTimer = nil
                        self.recognizedSound = "Kein Geräusch"
                    }
                }
                return
            }
            
            // Für alle anderen Signale:
            self.resetTimer?.invalidate()
            self.recognizedSound = soundDetected
            
            // Gerät vibrieren lassen
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            
            // Kritische Benachrichtigung versenden
            self.sendLocalNotification(for: soundDetected)
            
            // Starte den Timer: Nach 10 Sekunden wird das Signal der History hinzugefügt und zurückgesetzt
            self.resetTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
                let record = SoundRecord(sound: soundDetected, timestamp: Date())
                self.soundHistory.insert(record, at: 0)
                self.recognizedSound = "Kein Geräusch"
                self.resetTimer = nil
            }
        }
    }
}
