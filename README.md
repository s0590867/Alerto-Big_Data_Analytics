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

### 2.2 LED-Ring (WS2813)

### 2.3 Powerbank

### 2.4 Iphone

## 3. Verwendete Software
Die für das Projekt verwendete Software: 

### 3.1 Edge Impulse

### 2.2 Arduino IDE

### 2.3 xCode

## 4. Ordnerstruktur des Repositories

## 5. Zusätzliche Dateien

## 6. Quellen
