# ShopIt privacy

ShopIt stores your lists on the device. There is no ShopIt account.

## Sharing

Sharing is off until you turn it on. Create a code on one device and type that same code on the other. The code has two parts. The part after the dot is the key. ShopIt encrypts list contents with that key before they leave the device. The key is not sent over Wi-Fi and is not written into the cloud topic.

On the same Wi-Fi, the other ShopIt receives only that encrypted copy, and only if it presents the same key.

Over the internet, ShopIt publishes the encrypted copy to HiveMQ's public broker at `broker.hivemq.com`, using an encrypted connection. The topic contains a random mailbox id, which is the part of the code before the dot. HiveMQ and anyone who learns that id can download the encrypted copy. They cannot read the lists without the key. HiveMQ offers that broker for testing, not as private storage.

Leave cloud sync while online to delete this device's stored copy. If the device is offline, the copy can remain until you leave again while online. Deleting the app does not by itself delete a copy already stored at the broker.

## Location

**Use my location** sends coordinates only when you tap it. The default place-name service is OpenStreetMap Nominatim. You can change that host under the tax settings without installing a new version. A US tax lookup also sends the location to ZipTax when you have saved your own ZipTax key. Location is not read in the background. Place names are © OpenStreetMap contributors.

## Barcodes

Scanning an unknown barcode sends that number to Open Food Facts. Product data from Open Food Facts is separate from ShopIt's code license. Known names stay on the device.

## What ShopIt does not do

ShopIt does not show ads and does not include an analytics service.

## Deleting data

Delete lists in the app. Leave cloud sync while online to delete this device's stored snapshot. Nominatim, ZipTax, and Open Food Facts receive one-time requests. ShopIt cannot delete those requests afterward.

Source code: https://github.com/nuclearfessel/ShopIt
