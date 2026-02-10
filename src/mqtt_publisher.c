#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mosquitto.h>

#define MQTT_HOST "localhost"
#define MQTT_PORT 1883
#define SLEEP_INTERVAL 5

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
        buffer[strcspn(buffer, "\n")] = 0; // Remove newline
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

int main() {
    struct mosquitto *mosq;
    char cpu_temp[32], memory[32], uptime[128];
    
    mosquitto_lib_init();
    mosq = mosquitto_new("rpi_publisher", true, NULL);
    
    if (!mosq) {
        fprintf(stderr, "Error: Out of memory.\n");
        return 1;
    }
    
    if (mosquitto_connect(mosq, MQTT_HOST, MQTT_PORT, 60) != MOSQ_ERR_SUCCESS) {
        fprintf(stderr, "Unable to connect to MQTT broker.\n");
        return 1;
    }
    
    printf("Connected to MQTT broker. Publishing data every %d seconds...\n", SLEEP_INTERVAL);
    
    while (1) {
        // Read sensor data
        read_cpu_temp(cpu_temp);
        read_memory(memory);
        read_uptime(uptime);
        
        // Publish to MQTT
        mosquitto_publish(mosq, NULL, "sensor/cpu_temp", strlen(cpu_temp), cpu_temp, 0, false);
        mosquitto_publish(mosq, NULL, "sensor/memory", strlen(memory), memory, 0, false);
        mosquitto_publish(mosq, NULL, "sensor/uptime", strlen(uptime), uptime, 0, false);
        
        printf("Published: temp=%s, mem=%s MB\n", cpu_temp, memory);
        
        sleep(SLEEP_INTERVAL);
    }
    
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 0;
}
