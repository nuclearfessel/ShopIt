# Cloud mailbox

Cloud sync stores each device’s latest list snapshot so the phone and computer can stay in sync without sharing a Wi-Fi network, and without both being online at once.

The snapshot is sealed with the household code (AES-GCM) before it leaves the device. The MQTT broker only stores that ciphertext. It never receives list names, items, or prices. Anyone who can see the topic still cannot read the lists without the code.

ShopIt publishes one retained message per device on `broker.hivemq.com`, port 8883. The household code is part of the topic and is also the key. No ShopIt account is required.

## Topics

| Topic | Purpose |
| --- | --- |
| `shopit/p/{code}/{deviceId}` | Retained encrypted snapshot for one device |
| `shopit/p/{code}/+` | Subscribe to every device in the household |

Payloads start with `enc1:` and are gzipped JSON inside the cipher. Older `shopit/1/` messages were plaintext and are ignored.
