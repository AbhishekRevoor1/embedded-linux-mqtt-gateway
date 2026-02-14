// ESP32 MQTT IoT Gateway Client
// Connects to Raspberry Pi MQTT broker
// Publishes DHT11 sensor data
// Subscribes to RPi sensor data
//
// Hardware:
// - ESP32 Dev Module
// - DHT11 sensor on GPIO 4
//
// Dependencies:
// - PubSubClient by Nick O'Leary
// - DHT sensor library by Adafruit
// - Adafruit Unified Sensor

#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* MQTT_BROKER   = "192.168.0.114";
const int   MQTT_PORT     = 1883;
const char* DEVICE_ID     = "esp32-01";

#define DHT_PIN  4
#define DHT_TYPE DHT11
DHT dht(DHT_PIN, DHT_TYPE);

const char* TOPIC_TEMP     = "esp32/sensor/temperature";
const char* TOPIC_HUMIDITY = "esp32/sensor/humidity";
const char* TOPIC_STATUS   = "esp32/status/online";
const char* TOPIC_RPI_CPU    = "rpi/sensor/cpu_temp";
const char* TOPIC_RPI_MEMORY = "rpi/sensor/memory";
const char* TOPIC_RPI_UPTIME = "rpi/sensor/uptime";

const long PUBLISH_INTERVAL = 5000;
unsigned long lastPublishTime = 0;

WiFiClient espClient;
PubSubClient mqttClient(espClient);

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message = "";
    for (int i = 0; i < length; i++) message += (char)payload[i];

    if (String(topic) == TOPIC_RPI_CPU) {
        float temp_c = message.toFloat() / 1000.0;
        Serial.printf("RPi CPU Temp: %.1f C\n", temp_c);
    } else if (String(topic) == TOPIC_RPI_MEMORY) {
        Serial.printf("RPi Memory: %s MB\n", message.c_str());
    } else if (String(topic) == TOPIC_RPI_UPTIME) {
        Serial.printf("RPi Uptime: %s\n", message.c_str());
    }
}

void connectWiFi() {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    while (WiFi.status() != WL_CONNECTED) { delay(500); }
}

void connectMQTT() {
    while (!mqttClient.connected()) {
        if (mqttClient.connect(DEVICE_ID)) {
            mqttClient.publish(TOPIC_STATUS, "online", true);
            mqttClient.subscribe(TOPIC_RPI_CPU);
            mqttClient.subscribe(TOPIC_RPI_MEMORY);
            mqttClient.subscribe(TOPIC_RPI_UPTIME);
        } else {
            delay(5000);
        }
    }
}

void setup() {
    Serial.begin(115200);
    dht.begin();
    connectWiFi();
    mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    connectMQTT();
}

void loop() {
    if (WiFi.status() != WL_CONNECTED) connectWiFi();
    if (!mqttClient.connected()) connectMQTT();
    mqttClient.loop();

    unsigned long now = millis();
    if (now - lastPublishTime >= PUBLISH_INTERVAL) {
        lastPublishTime = now;
        float humidity    = dht.readHumidity();
        float temperature = dht.readTemperature();
        if (!isnan(humidity) && !isnan(temperature)) {
            char temp_str[10], hum_str[10];
            dtostrf(temperature, 4, 1, temp_str);
            dtostrf(humidity,    4, 1, hum_str);
            mqttClient.publish(TOPIC_TEMP,     temp_str);
            mqttClient.publish(TOPIC_HUMIDITY, hum_str);
        }
    }
}
