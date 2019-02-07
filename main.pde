#include <ESP8266WiFi.h>  // Include the Wi-Fi library
#include <PubSubClient.h> // Include the MQTT library
#include <Ticker.h>       // Include timer library
#include <DHT.h>          // Include humidity and temperature library

Ticker secondTick;
WiFiClient espClient;

// Define pins
const int light     = 4;
const int pirSensor = 5;
const int dhtSensor = 2;

// Broker address, currently connecting to CloudMQTT
IPAddress brokerAddress(.., .., .., ..);
const int brokerPort = ..;

// Overwrite watchdog CPU counter so it can reset
volatile int watchdogCount = 0;

// clientID must be unique per client
const char* clientID       = "..";
const char* ssid           = "..";
const char* password       = "..";
const char* brokerUsername = "..";
const char* brokerPassword = "..";

// Alternative variables
bool messagePublished = false;

// Create DHT object
DHT dht(dhtSensor, DHT11);

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.printf("Message recieved on topic: %s!\r\n", topic);

  for (int i = 0; i < length; i++) {

    char iteratedChar = (char) payload[i];

    Serial.print(iteratedChar);

    if (iteratedChar == '1') {
      digitalWrite(light, HIGH);
    }

    if (iteratedChar == '0') {
      digitalWrite(light, LOW);
    }

    if (iteratedChar == '2') {
      sendData();
    }
  }
}

PubSubClient client(brokerAddress, brokerPort, callback, espClient);

void sendData() {
  char result[8]; // Buffer big enough for 7-character float
  client.publish("/temperature", dtostrf(dht.readTemperature(), 6, 2, result));
  client.publish("/humidity", dtostrf(dht.readHumidity(), 6, 2, result));
}

void setup() {

  // Start the Serial communication to send messages to the computer
  Serial.begin(115200);

  // Set the watchdog bite checker
  secondTick.attach(1, ISRwatchdog);
  delay(10);

  dht.begin();

  // Connect with WiFi, if failed retry
  while (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }

  // Connect with broker, if failed retry
  while (!client.connected()) {
    connectToBroker(clientID, brokerUsername, brokerPassword);
  }

  subscribeToTopic("/lights");

  // Set pin modes
  pinMode(light, OUTPUT);
  pinMode(pirSensor, INPUT);

}

void connectToWiFi() {
  feedWatchdog();

  WiFi.begin(ssid, password);
  Serial.printf("Connecting to Wi-Fi network: %s ", ssid);

  while (WiFi.status() != WL_CONNECTED) {
    feedWatchdog();
    delay(1000);
    Serial.print(".");
  }

  Serial.println("\nConnection with Wi-Fi established!");
  Serial.printf("IP address: %s\n", (char*) WiFi.localIP().toString().c_str());
}

void connectToBroker(const char* clientID, const char* brokerUsername, const char* brokerPassword) {
  feedWatchdog();

  Serial.println("Connecting to MQTT..");

  if (client.connect(clientID, brokerUsername, brokerPassword)) {
    Serial.println("Succesfully connected with broker!");
  } else {
    Serial.println("Failed to connect with the broker, current state: ");
    Serial.println(client.state());
    delay(2000);
  }
}

void subscribeToTopic(char* topic) {
  feedWatchdog();

  Serial.printf("Subscribing to topic: %s ..\r\n", topic);
  if (client.subscribe(topic)) {
    Serial.printf("Successfully subscribed to topic: %s!", topic);
  } else {
    Serial.printf("Failed subscribing to topic: %s", topic);
    subscribeToTopic(topic);
  }
}

void loop() {
  feedWatchdog();

  // Check for incoming message and process them
  client.loop();

  int pirVal = digitalRead(pirSensor);

  if (pirVal == LOW && messagePublished == true) {
    client.publish("/lights", "0");
    messagePublished = false;
  }

  if (pirVal == HIGH && messagePublished == false) {
    client.publish("/lights", "1");
    messagePublished = true;
  }

}

//void startPartyMode() {
//
//}
//
//void stopPartyMode() {
//
//}

void ISRwatchdog() {
  watchdogCount++;
  if (watchdogCount > 5) {
    Serial.println();
    Serial.println("The watchdog bites!");
    ESP.reset();
  }
}

void feedWatchdog() {
  watchdogCount = 0;
}
