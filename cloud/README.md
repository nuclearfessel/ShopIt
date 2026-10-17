# Cloud mailbox

Internet sync is optional. Both devices must have the same household code, which you type in. The code is `mailboxId.secret`.

The snapshot is sealed with the secret (AES-GCM) before it leaves the device. The MQTT topic is `shopit/p/{mailboxId}/{deviceId}`. The secret is not part of the topic, so seeing the topic does not reveal the key.

ShopIt publishes one retained message per device to `broker.hivemq.com` over TLS (port 8883, or secure WebSocket port 8884). There is no unencrypted connection. HiveMQ's public broker is a testing service. It stores the ciphertext. Leaving cloud sync while online publishes an empty retained message, which deletes that device's copy.

| Topic | Use |
| --- | --- |
| `shopit/p/{mailboxId}/{deviceId}` | One device's latest encrypted snapshot |
| `shopit/p/{mailboxId}/+` | Subscribe to every device in the mailbox |

A code from a build that used the whole code as both the topic and the key is ignored.
