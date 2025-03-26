import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var pulse = false
    @State private var currentDate = Date()  // Aktualisiert jede Sekunde
    
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
    
    var body: some View {
        ZStack {
            backgroundGradient
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Obere Sektion: Logo und Titel
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                    Text("Alerto")
                        .font(.custom("Fredoka-Bold", size: 80))
                        .foregroundColor(.white)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Mittlere Sektion: Anzeige des aktuellen Signals und History
                VStack(spacing: 20) {
                    // Anzeige des aktuellen Signals (im Kasten)
                    ZStack {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 300, height: 100)
                            .shadow(radius: 10)
                            .scaleEffect(pulse ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                        
                        Text(bleManager.recognizedSound)
                            .font(.custom("Fredoka-Bold", size: 40))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .onChange(of: bleManager.recognizedSound) { _ in
                        pulse.toggle()
                    }
                    .onAppear {
                        pulse = true
                    }
                    
                    // History-Liste der zuletzt erkannten Geräusche
                    if !bleManager.soundHistory.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Letzte Geräusche:")
                                .font(.custom("Fredoka-Bold", size: 20))
                                .foregroundColor(.white)
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
                        .padding(.horizontal)
                    }
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
                .padding(.bottom, 20)
            }
            .padding()
        }
        // Aktualisiere currentDate jede Sekunde, um die History-Liste dynamisch zu aktualisieren
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            currentDate = now
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEManager())
    }
}
