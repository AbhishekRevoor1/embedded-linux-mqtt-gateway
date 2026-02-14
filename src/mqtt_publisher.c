#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <mosquitto.h>

#define MQTT_HOST       "localhost"
#define MQTT_PORT       1883
#define SLEEP_INTERVAL  5
#define LOG_DIR         "/data/logs"
#define LOG_FILE        "/data/logs/esp32_data.log"

// ─────────────────────────────────────────
// Get current timestamp string
// ─────────────────────────────────────────
void get_timestamp(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", t);
}

// ─────────────────────────────────────────
// Log ESP32 data to file
// ─────────────────────────────────────────
void log_to_file(const char *topic, const char *message) {
    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    FILE *fp = fopen(LOG_FILE, "a");
    if (fp) {
        fprintf(fp, "[%s] %s: %s\n", timestamp, topic, message);
        fclose(fp);
    }
}

// ─────────────────────────────────────────
// MQTT Message Callback
// ─────────────────────────────────────────
void on_message(struct mosquitto *mosq, void *userdata,
                const struct mosquitto_message *msg) {
    char payload[256] = {0};
    snprintf(payload, sizeof(payload), "%.*s",
             msg->payloadlen, (char *)msg->payload);

    printf("📨 [%s] %s\n", msg->topic, payload);

    // Log ESP32 data to file
    if (strncmp(msg->topic, "esp32/", 6) == 0) {
        log_to_file(msg->topic, payload);
    }
}

// ─────────────────────────────────────────
// Read Sensor Data
// ─────────────────────────────────────────
void read_cpu_temp(char *buffer) {
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (fp) {
        fscanf(fp, "%s", buffer);
        fclose(fp);
    }
}

void read_memory(char *buffer) {
    FILE *fp = popen("free -m | grep Mem | awk '{print $3}'", "r");
    if (fp) {
        fgets(buffer, 32, fp);
        buffer[strcspn(buffer, "\n")] = 0;
        pclose(fp);
    }
}

void read_uptime(char *buffer) {
    FILE *fp = popen("uptime", "r");
    if (fp) {
        fgets(buffer, 128, fp);
        buffer[strcspn(buffer, "\n")] = 0;
        pclose(fp);
    }
}

// ─────────────────────────────────────────
// Main
// ─────────────────────────────────────────
int main() {
    struct mosquitto *mosq;
    char cpu_temp[32], memory[32], uptime_str[128];

    // Create log directory
    system("mkdir -p " LOG_DIR);

    mosquitto_lib_init();
    mosq = mosquitto_new("rpi_gateway", true, NULL);

    if (!mosq) {
        fprintf(stderr, "Error: Out of memory.\n");
        return 1;
    }

    // Set message callback
    mosquitto_message_callback_set(mosq, on_message);

    if (mosquitto_connect(mosq, MQTT_HOST, MQTT_PORT, 60) != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "Unable to connect to MQTT broker.\n");
        return 1;
    }

    // Subscribe to ESP32 topics
    mosquitto_subscribe(mosq, NULL, "esp32/#", 0);
    printf("✅ Connected to MQTT broker\n");
    printf("📡 Subscribed to esp32/# topics\n");
    printf("📝 Logging ESP32 data to %s\n", LOG_FILE);
    printf("🔄 Publishing RPi data every %d seconds\n\n", SLEEP_INTERVAL);

    // Start network loop in background thread
    mosquitto_loop_start(mosq);

    while (1) {
        // Read RPi sensor data
        read_cpu_temp(cpu_temp);
        read_memory(memory);
        read_uptime(uptime_str);

        // Publish RPi data
        mosquitto_publish(mosq, NULL, "rpi/sensor/cpu_temp",
                         strlen(cpu_temp), cpu_temp, 0, false);
        mosquitto_publish(mosq, NULL, "rpi/sensor/memory",
                         strlen(memory), memory, 0, false);
        mosquitto_publish(mosq, NULL, "rpi/sensor/uptime",
                         strlen(uptime_str), uptime_str, 0, false);

        printf("📤 Published → CPU: %s | Mem: %s MB\n", cpu_temp, memory);

        sleep(SLEEP_INTERVAL);
    }

    mosquitto_loop_stop(mosq, true);
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 0;
}
