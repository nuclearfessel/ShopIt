# Cloud mailbox

Shop-it stores each paired device's latest list snapshot as a retained MQTT
message so the phone and the computer can sync without being on the same
Wi-Fi, and without being online at the same moment.

The default broker is the public HiveMQ endpoint (`broker.hivemq.com` on
port 8883). The eight-character household code is part of the topic path.
No Shop-it account is required.

Topic layout:

- `shopit/1/{code}/{deviceId}` — retained snapshot for one device
- subscribers use `shopit/1/{code}/+` to collect every device in the household
