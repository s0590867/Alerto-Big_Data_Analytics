import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var pulse = false
    @State private var currentDate = Date()  // Wird zur History-Aktualisierung genutzt
    @State private var dotCount = 0          // Für die Animation der Punkte
    @State private var showInfo = false      // Steuert die Anzeige des Info-Sheets

    // Standard-Hauptfarben (Blau)
    let primaryColor = Color(red: 28/255, green: 74/255, blue: 173/255)
    let secondaryColor = Color(red: 60/255, green: 100/255, blue: 210/255)

    // Dynamischer Hintergrund, abhängig vom aktuell angezeigten Geräusch
    var backgroundGradient: LinearGradient {
        let gradient: Gradient
        switch bleManager.recognizedSound {
        case "Rauchmelder":
            gradient = Gradient(colors: [Color.red, Color(red: 1.0, green: 0.5, blue: 0.5)])
        case "Tuerklingel":
            gradient = Gradient(colors: [Color.yellow, Color.orange])
        case "Klopfen":
            gradient = Gradient(colors: [Color.green, Color.green.opacity(0.7)])
        default:
            gradient = Gradient(colors: [primaryColor, secondaryColor])
        }
        return LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Berechnet den Zeitunterschied als String
    func timeAgoString(from date: Date) -> String {
        let interval = currentDate.timeIntervalSince(date)
        if interval < 60 {
            return String(format: "vor %.0f Sek.", interval)
        } else if interval < 3600 {
            return String(format: "vor %.0f Min.", interval / 60)
        } else {
            return String(format: "vor %.0f Std.", interval / 3600)
        }
    }

    // Liefert den anzuzeigenden Text:
    // - Service inaktiv: "höre nicht zu"
    // - Service aktiv und "Kein Geräusch": "höre zu" + animierte Punkte
    // - Andernfalls: Das erkannte Geräusch
    var displayText: String {
        if !bleManager.serviceRunning {
            return "höre nicht zu"
        } else {
            if bleManager.recognizedSound == "Kein Geräusch" {
                return "höre zu" + String(repeating: ".", count: dotCount)
            } else if bleManager.recognizedSound == "Tuerklingel" {
                return "Türklingel"
            } else {
                return bleManager.recognizedSound
            }
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .edgesIgnoringSafeArea(.all)
            VStack {
                // Obere Sektion: Logo und Titel (ohne Infobutton – dieser wird im Overlay platziert)
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                    Text("Alerto")
                        .font(.custom("Fredoka-Bold", size: 80))
                        .foregroundColor(.white)
                        .padding(.top, -20)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)

                Spacer()

                // Mittlere Sektion: Anzeige des aktuellen Signals und History
                VStack(spacing: 20) {
                    // Anzeige des aktuellen Signals (im Kasten)
                    ZStack {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 300, height: 100)
                            .shadow(radius: 10)
                            // Pulsiert nur, wenn der Service aktiv ist
                            .scaleEffect(bleManager.serviceRunning ? (pulse ? 1.05 : 1.0) : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                        Text(displayText)
                            .font(.custom("Fredoka-Bold", size: 40))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .onAppear {
                        pulse = bleManager.serviceRunning
                    }
                    .onChange(of: bleManager.serviceRunning) { newValue in
                        pulse = newValue
                    }

                    // History-Liste der zuletzt erkannten Geräusche
                    VStack(alignment: .center, spacing: 8) {
                        Text("Letzte Geräusche:")
                            .font(.custom("Fredoka-Bold", size: 20))
                            .foregroundColor(.white)
                        ScrollView {
                            if bleManager.soundHistory.isEmpty {
                                Text("Keine Einträge")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                                    .padding()
                            } else {
                                ForEach(bleManager.soundHistory) { record in
                                    HStack {
                                        Text(record.sound)
                                            .font(.custom("Fredoka-Bold", size: 18))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(timeAgoString(from: record.timestamp))
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                        .background(Color.white.opacity(0.5))
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Untere Sektion: Button zum Starten/Stoppen des BLE-Service
                Button(action: {
                    if bleManager.serviceRunning {
                        bleManager.stopService()
                    } else {
                        bleManager.startService()
                    }
                }) {
                    Text(bleManager.serviceRunning ? "Erkennung stoppen" : "Erkennung starten")
                        .font(.custom("Fredoka-Bold", size: 20))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220)
                        .background(bleManager.serviceRunning ? Color.red : Color.green)
                        .cornerRadius(10)
                }
                .padding(.bottom, 0)
            }
            .padding()
        }
        // Overlay für den Infobutton
        .overlay(
            Button(action: { showInfo = true }) {
                Image(systemName: "info.circle")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .padding(8)
            }
            .padding(.top, 10)
            .padding(.trailing, 16)
            , alignment: .topTrailing
        )
        // Gemeinsamer Timer, der alle 0,5 Sekunden aktualisiert:
        // • Aktualisiert currentDate (wenn sich die Sekunde ändert) für die History
        // • Aktualisiert dotCount für die Punkte-Animation
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            if bleManager.serviceRunning && bleManager.recognizedSound == "Kein Geräusch" {
                dotCount = (dotCount + 1) % 4
            } else {
                dotCount = 0
            }
            let newSec = Calendar.current.component(.second, from: now)
            let oldSec = Calendar.current.component(.second, from: currentDate)
            if newSec != oldSec {
                currentDate = now
            }
        }
        // Info-Sheet
        .sheet(isPresented: $showInfo) {
            InfoView(showInfo: $showInfo)
        }
    }
}

struct InfoView: View {
    @Binding var showInfo: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Text("Alerto App")
                    .font(.title)
                    .padding(.top)
                Text("Version 0.1")
                    .font(.headline)
                Text("Diese App identifiziert Geräusche mithilfe eines Arduino Nano 33 BLE Sense und informiert dich in Echtzeit.")
                    .multilineTextAlignment(.center)
                Text("Bitte schließe den Arduino Nano 33 BLE Sense an den Strom an und warte einen Moment, damit sich die Verbindung herstellen kann.")
                    .multilineTextAlignment(.center)
                Text("entwickelt von Maximilian Berthold, Leander Piepenbring & Tobias Lindhorst.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            }
            .navigationBarTitle("Info", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                showInfo = false
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEManager())
    }
}
