# Cloud mailbox

Internet sync is optional. Both devices must have the same household code, which you type in or pass with the QR code. The code is `mailboxId.secret`.

Creating, joining, or showing that code turns Share on this Wi-Fi on, including on Windows, so the devices can also meet on the local network. The mailbox still syncs over the internet when they are not on that network.

The snapshot is sealed with the secret (AES-GCM) before it leaves the device. The MQTT topic is `shopit/p/{mailboxId}/{deviceId}`. The secret is not part of the topic, so seeing the topic does not reveal the key.

ShopIt publishes one retained message per device to public MQTT brokers over TLS only (`broker.hivemq.com` on 8883/8884, and `broker.emqx.io` on 8883/8084). Those brokers are shared testing services. They store the ciphertext. Each sync listens for peer snapshots before subscribing, waits for the broker to acknowledge the retained upload, and repeats that on every broker that answers so two devices still meet when a network blocks one host. Leaving cloud sync while online publishes an empty retained message, which deletes that device's copy.

| Topic | Use |
| --- | --- |
| `shopit/p/{mailboxId}/{deviceId}` | One device's latest encrypted snapshot |
| `shopit/p/{mailboxId}/+` | Subscribe to every device in the mailbox |

A code from a build that used the whole code as both the topic and the key is ignored.
