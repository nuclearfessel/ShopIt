# Cloud mailbox

Cloud sync stores each device’s latest list snapshot so the phone and computer can stay in sync without sharing a Wi-Fi network, and without both being online at once.

Shop-it publishes a retained MQTT message per device on the public HiveMQ broker (`broker.hivemq.com`, port 8883). The household code is part of the topic. No Shop-it account is required.

## Topics

| Topic | Purpose |
| --- | --- |
| `shopit/1/{code}/{deviceId}` | Retained snapshot for one device |
| `shopit/1/{code}/+` | Subscribe to every device in the household |
