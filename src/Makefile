# Cross-compilation Makefile for MQTT Publisher
# Usage: make BUILDROOT_PATH=/path/to/buildroot-2024.02.9

BUILDROOT_PATH ?= ../../buildroot-projects/buildroot-2024.02.9
CC = $(BUILDROOT_PATH)/output/host/bin/arm-buildroot-linux-gnueabihf-gcc
CFLAGS = -Wall -O2
INCLUDES = -I$(BUILDROOT_PATH)/output/staging/usr/include
LDFLAGS = -L$(BUILDROOT_PATH)/output/staging/usr/lib
LIBS = -lmosquitto -lpthread

TARGET = mqtt_publisher
SOURCES = mqtt_publisher.c
OBJECTS = $(SOURCES:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(TARGET) $(OBJECTS)

deploy: $(TARGET)
	@echo "Deploying to Raspberry Pi..."
	scp $(TARGET) root@192.168.0.114:/data/
	@echo "Restarting service..."
	ssh root@192.168.0.114 "killall mqtt_publisher 2>/dev/null; /data/mqtt_service.sh &"

.PHONY: all clean deploy
