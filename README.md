# Big Data Analytics Projekt - Alerto 
Ein Projekt für das Modul Big Data Analytics an der HTW Berlin, erstellt von: 
Tobias Lindhorst, Leander Piepenbring und Maximilian Berthold

## 1. Produktbeschreibung
Bei Alerto handelt es sich um ein Projekt, mit dem Ziel Personen mit Hörbeeinträchtigungen zu unterstützen Geräusche im alltäglichen Leben (speziell im Haushalt) besser wahrnehmen zu können. 
Hierfür wird der Arduino Nano 33 BLE Sense verwendet, um die Geräuschdaten über den Mikrophonsensor erkennen zu können. Für dieses Projekt haben wir uns auf 3 spezielle Geräusche fokussiert, welche im Haushalt wiederzufinden sind: 
- Rauchmelder
- Türklingel
- Klopfen (an der Tür)
  
Die Klassifizierung der Daten und das Trainieren des Modells wurde in [Edge Impulse](https://edgeimpulse.com/) gemacht, hierbei dient die Platform speziell dafür TinyML Modelle zu trainieren und optimieren.
Die letztendlichen Ergebnisse wurde dann mithilfe von [ArduinoBLE](https://docs.arduino.cc/libraries/arduinoble/) auf den Arduino geflasht und in einer in xCode programmierten mobilen Anwendung für iOS dargestellt.
Dazu haben wir eine Art physischen Prototypen in Form eines LED-Rings gebaut, welcher die Geräusche farblich wiedergibt, um einen zusätzlichen Alert zu geben.

## 2. Verwendete Hardware
Es folgt eine Auflistung der im Projekt verwendeten Hardware:

### 2.1 Arduino Nano BLe 33 Sense
Der Arduino Nano 33 BLE Sense ist das Herzstück unseres Projekts. Er besitzt integrierte Sensoren – darunter ein Mikrophon –, die ideal für Anwendungen im Bereich TinyML geeignet sind. Durch den verbauten Cortex-M4-Prozessor mit Bluetooth Low Energy Unterstützung kann das trainierte Modell direkt auf dem Mikrocontroller laufen und gleichzeitig eine Verbindung zur App aufbauen.
### 2.2 LED-Ring (WS2813)
Zur visuellen Rückmeldung der erkannten Geräusche verwenden wir einen programmierbaren LED-Ring vom Typ WS2813. Jede erkannte Geräuschklasse wird durch eine individuelle Farbe dargestellt, um dem Nutzer eine schnelle und intuitive Rückmeldung zu ermöglichen.
- Rauchmelder = rot
- Türklingel = gelb
- Klopfen = grün

  
### 2.3 Powerbank
Um die Mobilität des Systems sicherzustellen, wird der Arduino über eine handelsübliche Powerbank betrieben. Dadurch kann das System flexibel im Haushalt platziert werden, ohne an eine feste Stromquelle gebunden zu sein.

### 2.4 Iphone
Für die Entwicklung und Demonstration der mobilen Anwendung wurde ein iPhone verwendet. Die App empfängt die erkannten Signale via Bluetooth und zeigt diese in einer benutzerfreundlichen Oberfläche an. Wir haben uns für eine iOS basierte App-Entwicklung entschieden, da wir gute Erfahrungen mit der BLE-Integration gemacht haben. 

## 3. Verwendete Software
Zur Realisierung des Projekts wurde eine Kombination aus spezialisierter Entwicklungsumgebungen und Plattformen eingesetzt, die optimal auf die Anforderungen im Bereich Embedded Machine Learning abgestimmt sind.

### 3.1 Edge Impulse
Edge Impulse ist eine cloudbasierte Plattform zur Entwicklung, Schulung und Optimierung von Machine-Learning-Modellen für Embedded Devices. In unserem Projekt fungierte sie als zentrale Umgebung zur Datenerfassung, Annotation sowie zum Trainieren des Klassifikationsmodells für akustische Signale.
Wir haben zunächst für jede Geräuschklasse (Rauchmelder, Türklingel, Klopfen) etwa 100 Audiosamples aufgenommen und eingespielt (mit einer Samplingrate von 16 kHz und einer Dauer von 4 Sekunden pro Sample). Mithilfe des integrierten Classifiers sowie des EON Tuners konnten wir verschiedene Modellvarianten analysieren und bewerten.
Als besonders geeignet hat sich die MFE-Variante (Mel Filterbank Energy) herausgestellt, die eine Modellgenauigkeit von 93 % erzielte. Dieses Feature-Set passt optimal zu unserem Use Case, da es ressourcenschonend arbeitet und sich gut für Geräuscherkennung auf Geräten mit begrenztem Speicher eignet. Alternative Methoden wie Spectrogramme waren aufgrund des höheren Speicherbedarfs nicht praktikabel, und MFCCs (Mel Frequency Cepstral Coefficients) sind eher für sprachbasierte Anwendungen optimiert.

### 2.2 Arduino IDE
Die Arduino IDE wurde verwendet, um den Mikrocontroller zu programmieren und das in Edge Impulse trainierte Modell auf das Gerät zu übertragen. Zusätzlich integrierten wir die ArduinoBLE Bibliothek, um eine stabile Bluetooth-Kommunikation zwischen dem Arduino und der iOS-App zu ermöglichen. Die IDE war zudem hilfreich beim Testen und Debuggen des Gesamtsystems.

### 2.3 xCode
Für die Entwicklung der mobilen iOS-Anwendung kam Xcode zum Einsatz. Mit Hilfe von Swift und der CoreBluetooth-API wurde eine App erstellt, die die Signale des Arduinos über BLE empfängt und dem Nutzer eine visuelle Rückmeldung in Form einer klar strukturierten Benutzeroberfläche bietet. Xcode ermöglichte uns eine effiziente Entwicklung und eine reibungslose Integration mit Apple-Geräten. Gerade durch das Live-Testing und einsteigerfreundlichen Programmierung können wir die Umgebung für kurzweilige Projekte nur empfehlen. 

## 4. Ordnerstruktur des Repositories
Das Repository ist in mehrere Hauptbereiche unterteilt, die jeweils unterschiedliche Teile des Projekts abbilden. Dies sorgt für eine klare Trennung zwischen Hardware- und Softwarekomponenten:

**bigdata_analytics/
├── Alerto/               → iOS-App mit Xcode-Projektdateien
│   ├── Alerto.xcodeproj  → Projektdateien für Xcode
│   ├── Alerto/           → Hauptordner mit Swift-Code der App
│   ├── AlertoTests/      → Unit Tests für die iOS-App
│   ├── AlertoUITests/    → UI Tests für die iOS-App
│   └── .DS_Store         → Automatisch generierte macOS-Systemdatei
│
├── Arduino/              → Arduino-Code für das Mikrocontroller-Modul
│   ├── alerto_final/     → Finales Arduino-Skript inklusive BLE-Logik und LED-Steuerung
│   ├── libraries/        → Zusätzliche Bibliotheken für den Arduino-Sketch
│   └── .DS_Store         → Automatisch generierte macOS-Systemdatei
│
├── README.md             → Projektbeschreibung und Dokumentation
└── .DS_Store             → Automatisch generierte macOS-Systemdatei**

Hinweis:
Die Datei .DS_Store wird automatisch von macOS erstellt und enthält keine relevanten Projektdaten. Sie kann bei Bedarf ignoriert oder aus dem Repository entfernt werden.

## 5. Zusätzliche Dateien

## 6. Quellen
