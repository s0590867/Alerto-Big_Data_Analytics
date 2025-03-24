//
//  BLEManageer.swift
//  Alerto
//
//  Created by Tobias Lindhorst  on 24.03.25.
//
//
//  BLEManager.swift
//  Alerto
//
//  Created by Tobias Lindhorst  on 18.03.25.
//

import Foundation
import CoreBluetooth
import UserNotifications
import SwiftUI

class BLEManager: NSObject, ObservableObject {
    @Published var recognizedSound: String = "Kein Signal"
    @Published var serviceRunning: Bool = false  // Status des BLE-Services

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    
    // Ersetze diese UUIDs mit den in deiner iOS-App verwendeten Werten
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
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // Service starten: Scannen und Verbindung aufbauen
    func startService() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [soundServiceUUID], options: nil)
            serviceRunning = true
            print("BLE-Service gestartet")
        } else {
            print("Bluetooth ist nicht eingeschaltet oder nicht verfügbar")
        }
    }
    
    // Service stoppen: Scannen beenden und ggf. Verbindung trennen
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
            // Starte nur, wenn der Service aktiv sein soll
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
        // Verbindung zum ersten gefundenen Gerät herstellen
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
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
                // Abonniere die Characteristic, um Updates zu erhalten
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
            self.recognizedSound = soundDetected
            self.sendLocalNotification(for: soundDetected)
        }
    }
}

