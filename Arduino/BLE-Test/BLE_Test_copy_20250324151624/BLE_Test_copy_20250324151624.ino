#include <ArduinoBLE.h>
#include <Adafruit_NeoPixel.h>

// LED-Konfiguration für WS2813
#define LED_PIN 11      // Prüfe, ob Pin 11 als Digital-Pin genutzt werden kann!
#define NUM_LEDS 20

Adafruit_NeoPixel strip = Adafruit_NeoPixel(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Ersetze die folgenden UUIDs mit den in deiner iOS-App verwendeten Werten
#define SOUND_SERVICE_UUID         "12345678-1234-5678-1234-56789ABCDEF0"
#define SOUND_CHARACTERISTIC_UUID  "87654321-4321-6789-4321-0FEDCBA98765"

// Definiere einen BLE-Service und eine BLE-Characteristic
BLEService soundService(SOUND_SERVICE_UUID);
BLEStringCharacteristic soundCharacteristic(SOUND_CHARACTERISTIC_UUID, BLERead | BLENotify, 20);

// Array mit Test-Geräusch-Strings
const char* sounds[] = {"Klatschen", "Klopfen", "Hupen"};
const int numSounds = sizeof(sounds) / sizeof(sounds[0]);

unsigned long previousMillis = 0;
const unsigned long interval = 5000; // 5 Sekunden
int soundIndex = 0;

void setup() {
  Serial.begin(9600);
  while (!Serial);  // Warte, bis der serielle Monitor geöffnet ist

  // LED-Strip initialisieren
  strip.begin();
  strip.show(); // Alle LEDs ausschalten

  // BLE initialisieren
  if (!BLE.begin()) {
    Serial.println("BLE konnte nicht gestartet werden!");
    while (1);
  }
  
  // Lokaler Name und beworbener Service
  BLE.setLocalName("ArduinoSound");
  BLE.setAdvertisedService(soundService);
  
  // Service und Characteristic zum BLE-Stack hinzufügen
  soundService.addCharacteristic(soundCharacteristic);
  BLE.addService(soundService);
  
  // Initialen Wert setzen
  soundCharacteristic.writeValue("Kein Signal");
  
  // Starte die Werbung
  BLE.advertise();
  Serial.println("BLE Sound Device: Werbung gestartet");
}

void loop() {
  // Überprüfe, ob ein zentrales Gerät verbunden ist
  BLEDevice central = BLE.central();
  
  if (central) {
    Serial.print("Verbunden mit zentralem Gerät: ");
    Serial.println(central.address());
    
    // Solange die Verbindung besteht, sende periodisch einen neuen Test-String
    while (central.connected()) {
      unsigned long currentMillis = millis();
      if (currentMillis - previousMillis >= interval) {
        previousMillis = currentMillis;
        
        // Wähle den nächsten Test-String aus
        soundIndex = (soundIndex + 1) % numSounds;
        const char* soundToSend = sounds[soundIndex];
        Serial.print("Sende: ");
        Serial.println(soundToSend);
        
        // Aktualisiere den Wert der Characteristic und benachrichtige den zentralen Client
        soundCharacteristic.writeValue(soundToSend);
        
        // Lasse den LED-Streifen leicht pulsieren (max. Helligkeit 60)
        pulseLEDs();
      }
    }
    
    Serial.print("Verbindung getrennt von: ");
    Serial.println(central.address());
  }
}

// Funktion, die den LED-Streifen sanft pulsieren lässt
void pulseLEDs() {
  const uint8_t maxBrightness = 60;  // maximale Helligkeit
  const int steps = 20;              // Anzahl der Schritte für einen sanften Übergang
  const int delayTime = 10;          // Verzögerung pro Schritt in Millisekunden
  
  // Fade-in: Helligkeit hochfahren
  for (int i = 0; i <= steps; i++) {
    uint8_t brightness = (maxBrightness * i) / steps;
    for (int j = 0; j < NUM_LEDS; j++) {
      strip.setPixelColor(j, strip.Color(brightness, brightness, brightness));
    }
    strip.show();
    delay(delayTime);
  }
  // Fade-out: Helligkeit runterfahren
  for (int i = steps; i >= 0; i--) {
    uint8_t brightness = (maxBrightness * i) / steps;
    for (int j = 0; j < NUM_LEDS; j++) {
      strip.setPixelColor(j, strip.Color(brightness, brightness, brightness));
    }
    strip.show();
    delay(delayTime);
  }
}
