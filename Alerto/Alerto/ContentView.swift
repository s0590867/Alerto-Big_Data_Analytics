import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var pulse: Bool = false
    @State private var currentDate = Date()  // Aktualisiert jede Sekunde für die History
    @State private var showInfo = false      // Zum Anzeigen des Info-Sheets
    @State private var listeningDots: Int = 0  // Für die Animation der Ladeanzeige
    
    // Standard-Hauptfarben (Blau)
    let primaryColor = Color(red: 28/255, green: 74/255, blue: 173/255)
    let secondaryColor = Color(red: 60/255, green: 100/255, blue: 210/255)
    
    // Dynamischer Hintergrund, abhängig vom aktuell angezeigten Signal
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
    
    // Hilfsfunktion, die den Zeitunterschied als String zurückgibt
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
    
    // Computed Property für die anzuzeigende Nachricht:
    // Wenn recognizedSound "hört zu" ist, wird der Text mit animierten Punkten angezeigt.
    var displayText: String {
        if bleManager.recognizedSound == "hört zu" {
            return "hört zu" + String(repeating: ".", count: listeningDots)
        } else {
            return bleManager.recognizedSound
        }
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Obere Sektion: Zentriertes Logo, Titel und Info-Button
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        // Pulsierende Animation beim aktiven Dienst
                        .scaleEffect(bleManager.serviceRunning ? (pulse ? 1.05 : 1.0) : 1.0)
                        .animation(bleManager.serviceRunning ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none, value: pulse)
                    
                    Text("Alerto")
                        .font(.custom("Fredoka-Bold", size: 80))
                        .foregroundColor(.white)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Mittlere Sektion: Anzeige des aktuellen Signals und History-Liste
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 300, height: 100)
                            .shadow(radius: 10)
                            // Rechteck pulsiert, solange der Dienst aktiv ist
                            .scaleEffect(bleManager.serviceRunning ? (pulse ? 1.05 : 1.0) : 1.0)
                            .animation(bleManager.serviceRunning ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none, value: pulse)
                        Text(displayText)
                            .font(.custom("Fredoka-Bold", size: 40))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .onChange(of: bleManager.recognizedSound) { newValue in
                        // Es erfolgt keine Steuerung der Pulsation hier; diese ist an bleManager.serviceRunning gekoppelt.
                    }
                    
                    // History-Tabelle – dauerhaft sichtbar
                    VStack(alignment: .center, spacing: 8) {
                        Text("Letzte Geräusche:")
                            .font(.custom("Fredoka-Bold", size: 20))
                            .foregroundColor(.white)
                        if bleManager.soundHistory.isEmpty {
                            Text("Noch keine Einträge")
                                .font(.custom("Fredoka-Bold", size: 18))
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            ScrollView {
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
                            .frame(maxHeight: 150)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Untere Sektion: Start/Stop-Button
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
                .padding(.bottom, 20)
            }
            .padding()
            
            // Overlay: Info-Button oben rechts
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showInfo.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        // Timer: Aktualisiert currentDate und animiert bei "hört zu" die Punkte
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Falls der Dienst nicht läuft, wird die Pulsation zurückgesetzt
            if !bleManager.serviceRunning {
                pulse = false
            }
            if bleManager.recognizedSound == "hört zu" {
                listeningDots = (listeningDots + 1) % 4
            }
            currentDate = Date()
        }
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
    }
}

struct InfoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Alerto")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Version 1.0.0")
                    .font(.title2)
                Text("Diese App erkennt Geräusche über BLE und zeigt sie an.\n\nEntwickelt von Tobias Lindhorst.")
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { }
                }
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEManager())
    }
}
