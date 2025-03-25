//
//  ContentView.swift
//  Alerto
//
//  Created by Tobias Lindhorst  on 18.03.25.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var pulse = false
    @State private var flashBackground = false  // State für den orange Flash

    // Hauptfarbe: rgb(28, 74, 173)
    let primaryColor = Color(red: 28/255, green: 74/255, blue: 173/255)
    // Helle Variante für den Farbverlauf
    let secondaryColor = Color(red: 60/255, green: 100/255, blue: 210/255)
    
    var body: some View {
        ZStack {
            // Hintergrund mit Farbverlauf
            LinearGradient(gradient: Gradient(colors: [primaryColor, secondaryColor]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            // Orange Overlay, das über den Hintergrund gelegt wird
            Color.orange
                .edgesIgnoringSafeArea(.all)
                .opacity(flashBackground ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: flashBackground)
            
            VStack(spacing: 40) {
                // Logo (PNG-Datei, im Asset Catalog unter "Logo" hinterlegt)
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .padding(.top, 0)
                
                // App-Titel mit der Schriftart Fredoka
                Text("Alerto")
                    .font(.custom("Fredoka-Bold", size: 80))
                    .foregroundColor(.white)
                    .padding(.top, -40)
                    .padding(.bottom, 50)
                
                // Anzeige des erkannten Sounds in einer abgerundeten, pulsierenden Karte
                ZStack {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 300, height: 150)
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
                    // Pulsanimation auslösen, wenn sich der Sound ändert
                    pulse.toggle()
                    
                    // Hintergrund-Flash: kurz auf Orange wechseln und nach ca. 1 s wieder ausblenden
                    withAnimation(.easeIn(duration: 0.3)) {
                        flashBackground = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            flashBackground = false
                        }
                    }
                }
                .onAppear {
                    pulse = true
                }
                
                // Button zum Starten/Stoppen des BLE-Service
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
                
                Text("Verbinde deinen Arduino Nano 33 BLE Sense, um Geräusche zu erkennen.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
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
