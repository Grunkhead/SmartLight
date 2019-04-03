#include <PubSubClient.h> // Include the MQTT library
#include <FastLED.h>
#include <WiFi.h>

WiFiClient espClient;

#define LED_PIN     2
#define COLOR_ORDER GRB
#define CHIPSET     WS2812
#define NUM_LEDS    144
#define FRAMES_PER_SECOND 60

int brightness = 200;
CRGB leds[NUM_LEDS];

// Broker address, currently connecting to CloudMQTT
IPAddress brokerAddress(0, 0, 0, 0);
const int brokerPort = ;

// clientID must be unique per client.
const char* clientID       = "";
const char* ssid           = "";
const char* password       = "";
const char* brokerUsername = "";
const char* brokerPassword = "";

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.printf("Message recieved on topic: %s!\r\n", topic);

  for (int i = 0; i < length; i++) {
    char iteratedChar = (char) payload[i];

    Serial.print(iteratedChar);

    if (iteratedChar == '0') {
      for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CRGB::White;
        FastLED.show();
      }
    }

    if (iteratedChar == '1') {
      for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CRGB::Black;
        FastLED.show();
      }
    }

    if (iteratedChar == '2') {
      sendData();
    }
  }
}

PubSubClient client(brokerAddress, brokerPort, callback, espClient);

void setup() {
//  delay(3000); // Sanity delay
  FastLED.addLeds<CHIPSET, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(brightness);
  testLED();

  // Start the serial communication to send messages via USB.
  Serial.begin(115200);
}

void testLED() {
  for (int i = 0; i < NUM_LEDS; i++) {
    if (i % 2 == 0) {
      leds[i] = CRGB::Red;
      continue;
    }

    leds[i] = CRGB::Orange;
  }
}

void connectToWiFi() {
  WiFi.begin(ssid, password);
  Serial.printf("Connecting to Wi-Fi network: %s.", ssid);

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }

  Serial.println("\nConnection with Wi-Fi established!");
  Serial.printf("IP address: %s\n", (char*) WiFi.localIP().toString().c_str());
}

void connectToBroker() {
  Serial.println("Connecting to MQTT..");

  if (client.connect(clientID, brokerUsername, brokerPassword)) {
    Serial.println("Successfully connected with the broker!");
  } else {
    Serial.println("Failed to connect with the broker, current state: ");
    Serial.println(client.state());
    delay(2000);
  }
}

void subscribeToTopic(char* topic) {
  if (client.subscribe(topic)) {
    Serial.printf("Successfully subscribed to topic: %s!\n", topic);
  } else {
    Serial.printf("Failed subscribing to topic: %s\n", topic);
    subscribeToTopic(topic);
  }
}

void maintainConnection() {
  while (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
    if (WiFi.status() == WL_CONNECTED) {
      while (!client.connected()) {
        connectToBroker();
        if (client.connected()) {
          subscribeToTopic("/lights");
          subscribeToTopic("/derp");
        }
      }
    }
  }
}

void loop() {
  // ESP32 dropped connection after a while.
  maintainConnection();

  // Set brightness if changed.
  FastLED.setBrightness(brightness);

  // Check for incoming data / messages from MQTT and process it.
  client.loop();
}

// Used for publishing data back to the channel.
void sendData() {}
