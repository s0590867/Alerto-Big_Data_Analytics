/* Prototypen */
void indicateRecording(bool isActive);
void setLEDColor(uint32_t color);
void clearLEDs(void);

/* Includes ---------------------------------------------------------------- */
#include <PDM.h>                  
#include <Alerto2_inferencing.h>   
#include <ArduinoBLE.h>
#include <Adafruit_NeoPixel.h>

/* Zusätzlicher Parameter: Detection Threshold */
#define DETECTION_THRESHOLD 0.95

/** LED-Konfiguration (WS2813/NeoPixel an Pin 11, 20 LEDs) */
#define LED_PIN 11
#define NUM_LEDS 20
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

/** BLE-Konfiguration */
#define SOUND_SERVICE_UUID         "12345678-1234-5678-1234-56789ABCDEF0"
#define SOUND_CHARACTERISTIC_UUID  "87654321-4321-6789-4321-0FEDCBA98765"
BLEService soundService(SOUND_SERVICE_UUID);
BLEStringCharacteristic soundCharacteristic(SOUND_CHARACTERISTIC_UUID, BLERead | BLENotify, 20);

/** Audio-Puffer-Struktur wie im Edge Impulse Beispiel */
typedef struct {
    signed short *buffers[2];
    unsigned char buf_select;
    unsigned char buf_ready;
    unsigned int buf_count;
    unsigned int n_samples;
} inference_t;

static inference_t inference;
static bool record_ready = false;
static signed short *sampleBuffer;
static bool debug_nn = false; // Debug-Ausgaben deaktiviert
static int print_results = -(EI_CLASSIFIER_SLICES_PER_MODEL_WINDOW);

/* Timer für BLE-Signale */
unsigned long lastSignalTime = 0;
const unsigned long signalCooldown = 3000; // 3000 ms = 3 Sekunden

/* Neue globale Variablen für LED-Management */
// Speichert die aktuell aktive Kategorie (z. B. "Tuerklingel", "Rauchmelder", "Klopfen")
// Ist der String leer, so ist keine LED-Aktivierung aktiv.
char activeCategory[32] = "";
// Zeitpunkt (millis), bis zu dem die LED leuchten soll
unsigned long ledTimeout = 0;

/* Implementierung der LED-Funktionen */
void setLEDColor(uint32_t color) {
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, color);
  }
  strip.show();
}

void clearLEDs(void) {
  setLEDColor(0);
}

/* Die Funktion indicateRecording schaltet alle LEDs auf Weiß, wenn aktiv, oder löscht sie */
void indicateRecording(bool isActive) {
  if (isActive) {
    setLEDColor(strip.Color(100, 100, 100));
  } else {
    clearLEDs();
  }
}

/* PDM-Callback: Liest Daten in den Inferenz-Puffer */
static void pdm_data_ready_inference_callback(void)
{
    int bytesAvailable = PDM.available();
    int bytesRead = PDM.read((char *)&sampleBuffer[0], bytesAvailable);

    if (record_ready == true) {
        // 2 Byte pro Sample
        int samplesReadNow = bytesRead >> 1;
        for (int i = 0; i < samplesReadNow; i++) {
            inference.buffers[inference.buf_select][inference.buf_count++] = sampleBuffer[i];
            if (inference.buf_count >= inference.n_samples) {
                inference.buf_select ^= 1; // Buffer wechseln
                inference.buf_count = 0;
                inference.buf_ready = 1;
            }
        }
    }
}

/* Initialisiert Audio-Inferencing und startet PDM.
   Verwendet EI_CLASSIFIER_SLICE_SIZE aus der exportierten Library */
static bool microphone_inference_start(uint32_t n_samples)
{
    inference.buffers[0] = (signed short *)malloc(n_samples * sizeof(signed short));
    if (inference.buffers[0] == NULL) return false;

    inference.buffers[1] = (signed short *)malloc(n_samples * sizeof(signed short));
    if (inference.buffers[1] == NULL) {
        free(inference.buffers[0]);
        return false;
    }

    // Zusätzlicher Zwischenpuffer (Hälfte von n_samples)
    sampleBuffer = (signed short *)malloc((n_samples >> 1) * sizeof(signed short));
    if (sampleBuffer == NULL) {
        free(inference.buffers[0]);
        free(inference.buffers[1]);
        return false;
    }

    inference.buf_select = 0;
    inference.buf_count  = 0;
    inference.n_samples  = n_samples;
    inference.buf_ready  = 0;

    PDM.onReceive(&pdm_data_ready_inference_callback);
    PDM.setBufferSize((n_samples >> 1) * sizeof(int16_t));

    // Starte PDM: 1 Kanal (Mono) mit der im Modell vorgegebenen Frequenz
    if (!PDM.begin(1, EI_CLASSIFIER_FREQUENCY)) {
        ei_printf("Failed to start PDM!\r\n");
        return false;
    }

    PDM.setGain(127);
    record_ready = true;
    return true;
}

/* Blockierendes Warten auf neue Audio-Daten */
static bool microphone_inference_record(void)
{
    bool ret = true;

    if (inference.buf_ready == 1) {
        ei_printf("Error: sample buffer overrun. Decrease EI_CLASSIFIER_SLICES_PER_MODEL_WINDOW\n");
        ret = false;
    }

    while (inference.buf_ready == 0) {
        delay(1);
    }
    inference.buf_ready = 0;
    return ret;
}

/* Konvertiert int16 -> float für den Klassifikator */
static int microphone_audio_signal_get_data(size_t offset, size_t length, float *out_ptr)
{
    numpy::int16_to_float(&inference.buffers[inference.buf_select ^ 1][offset], out_ptr, length);
    return 0;
}

/* Stoppt PDM und gibt den belegten Speicher frei */
static void microphone_inference_end(void)
{
    PDM.end();
    free(inference.buffers[0]);
    free(inference.buffers[1]);
    free(sampleBuffer);
}

/* Arduino Setup */
void setup()
{
    Serial.begin(115200);
    while (!Serial);

    ei_printf("Edge Impulse Inferencing Demo\r\n");
    ei_printf("Inferencing settings:\r\n");
    ei_printf("\tInterval: %.2f ms.\r\n", (float)EI_CLASSIFIER_INTERVAL_MS);
    ei_printf("\tFrame size: %d\r\n", EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE);
    ei_printf("\tSample length: %d ms.\r\n", EI_CLASSIFIER_RAW_SAMPLE_COUNT / (EI_CLASSIFIER_FREQUENCY / 1000));
    ei_printf("\tNo. of classes: %d\r\n",
              sizeof(ei_classifier_inferencing_categories) / sizeof(ei_classifier_inferencing_categories[0]));

    run_classifier_init();

    // Starte Audio-Inferenz mit EI_CLASSIFIER_SLICE_SIZE (vom Modell)
    if (!microphone_inference_start(EI_CLASSIFIER_SLICE_SIZE)) {
        ei_printf("ERR: Could not allocate audio buffer (size %d)\r\n", EI_CLASSIFIER_SLICE_SIZE);
        return;
    }

    /* --- BLE Setup --- */
    if (!BLE.begin()) {
        ei_printf("BLE konnte nicht gestartet werden!\r\n");
        while (1);
    }
    BLE.setLocalName("ArduinoSound");
    BLE.setAdvertisedService(soundService);
    soundService.addCharacteristic(soundCharacteristic);
    BLE.addService(soundService);
    soundCharacteristic.writeValue("Kein Signal");
    BLE.advertise();
    ei_printf("BLE advertising started.\r\n");

    /* --- LED Setup --- */
    strip.begin();
    clearLEDs(); // Alle LEDs ausschalten
}

/* Arduino Loop */
void loop()
{
    // BLE Polling
    BLE.poll();

    // Prüfe, ob der LED-Countdown abgelaufen ist
    if (activeCategory[0] != '\0' && millis() > ledTimeout) {
        clearLEDs();
        activeCategory[0] = '\0';
    }

    // Auf neue Audio-Daten warten
    if (!microphone_inference_record()) {
        ei_printf("ERR: Failed to record audio...\r\n");
        return;
    }

    // Signal-Objekt für den Klassifikator (vom Modell)
    signal_t signal;
    signal.total_length = EI_CLASSIFIER_SLICE_SIZE;
    signal.get_data = &microphone_audio_signal_get_data;

    ei_impulse_result_t result = { 0 };

    // Kontinuierliche Klassifikation mittels run_classifier_continuous()
    EI_IMPULSE_ERROR r = run_classifier_continuous(&signal, &result, debug_nn);
    if (r != EI_IMPULSE_OK) {
        ei_printf("ERR: Failed to run classifier (%d)\r\n", r);
        clearLEDs();
        return;
    }

    // Verarbeite das Ergebnis nach einer Anzahl von Slices
    if (++print_results >= EI_CLASSIFIER_SLICES_PER_MODEL_WINDOW) {
        float maxScore = 0.0f;
        size_t maxIndex = 0;
        for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
            if (result.classification[i].value > maxScore) {
                maxScore = result.classification[i].value;
                maxIndex = i;
            }
        }

        // Ausgabe nur, wenn der Score den Schwellenwert überschreitet
        if (maxScore >= DETECTION_THRESHOLD) {
            char predictedLabel[32];
            snprintf(predictedLabel, sizeof(predictedLabel), "%s", result.classification[maxIndex].label);
            ei_printf("Predicted: %s (Confidence: %.5f)\r\n", predictedLabel, maxScore);
            ei_printf("(DSP: %d ms, Classification: %d ms)\r\n",
                      result.timing.dsp, result.timing.classification);
#if EI_CLASSIFIER_HAS_ANOMALY == 1
            ei_printf("Anomaly score: %.3f\r\n", result.anomaly);
#endif

            /* LED-Logik:
               - Bei einem erkannten Signal, das **nicht** "Rauschen" ist,
                 wird die LED in der entsprechenden Farbe aktiviert und der 10-Sekunden-Countdown gestartet.
               - Erhält man als nächstes "Rauschen", bleibt die LED in der aktuell gewählten Farbe,
                 bis der Countdown abläuft.
               - Wird während eines aktiven Countdowns ein anderes Signal erkannt,
                 wird die LED auf die neue Farbe umgestellt und der Countdown neu gestartet.
            */
            if (strcmp(predictedLabel, "Rauschen") != 0) {
                // Neues Event (oder erneutes Signal) – LED-Farbe setzen und Countdown (10 s) neu starten
                strcpy(activeCategory, predictedLabel);
                ledTimeout = millis() + 10000;  // 10.000 ms = 10 Sekunden

                if (strcmp(predictedLabel, "Tuerklingel") == 0) {
                    setLEDColor(strip.Color(0, 0, 255));  // Blau
                }
                else if (strcmp(predictedLabel, "Rauchmelder") == 0) {
                    setLEDColor(strip.Color(255, 0, 0));  // Rot
                }
                else if (strcmp(predictedLabel, "Klopfen") == 0) {
                    setLEDColor(strip.Color(0, 255, 0));  // Grün
                }
            }
            else {
                // "Rauschen" erkannt:
                // Wenn bereits ein aktives Event besteht, bleibt die LED in der gewählten Farbe,
                // der Countdown wird **nicht** zurückgesetzt.
                if (activeCategory[0] == '\0') {
                    // Falls noch kein Event aktiv ist, schalte die LEDs aus
                    clearLEDs();
                }
            }

            // Senden per BLE, falls gewünschtes Label erkannt
            if ((strcmp(predictedLabel, "Tuerklingel") == 0 ||
                 strcmp(predictedLabel, "Rauchmelder") == 0 ||
                 strcmp(predictedLabel, "Rauschen") == 0 ||
                 strcmp(predictedLabel, "Klopfen") == 0)) {

                if (millis() - lastSignalTime > signalCooldown) {
                    BLEDevice central = BLE.central();
                    if (central) {
                        soundCharacteristic.writeValue(predictedLabel);
                        ei_printf("BLE signal sent: %s\r\n", predictedLabel);
                        lastSignalTime = millis();
                    }
                }
            }
        }
        // Den Zähler zurücksetzen
        print_results = 0;
    }
}

#if !defined(EI_CLASSIFIER_SENSOR) || EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_MICROPHONE
  #error "Invalid model for current sensor."
#endif
