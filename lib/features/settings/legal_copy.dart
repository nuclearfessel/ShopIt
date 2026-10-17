/// Shown from Settings → About. Matches docs/privacy.md.
const shopItPrivacyNotice = '''
ShopIt stores your lists on this device. There is no ShopIt account.

Sharing is off until you turn it on. Create a code on one device and type that same code on the other. The code has two parts. The part after the dot is the key. ShopIt encrypts list contents with that key before they leave the device. The key is not sent over Wi-Fi and is not written into the cloud topic.

On the same Wi-Fi, the other ShopIt receives only that encrypted copy, and only if it presents the same key. Over the internet, ShopIt publishes the encrypted copy to HiveMQ's public broker at broker.hivemq.com, using an encrypted connection. The topic contains a random mailbox id, which is the part of the code before the dot. HiveMQ and anyone who learns that id can download the encrypted copy. They cannot read the lists without the key. HiveMQ offers that broker for testing, not as private storage.

Leave cloud sync while online to delete this device's stored copy. If the device is offline, the copy can remain until you leave again while online. Deleting the app does not by itself delete a copy already stored at the broker.

Use my location sends coordinates only when you tap it. The default place-name service is OpenStreetMap Nominatim. You can change that host in the tax settings. A US tax lookup also sends the location to ZipTax when you have saved your own ZipTax key. Location is not read in the background.

Scanning an unknown barcode sends that number to Open Food Facts. Known names stay on the device.

ShopIt does not show ads and does not include an analytics service.

Delete lists in the app. Nominatim, ZipTax, and Open Food Facts receive one-time requests. ShopIt cannot delete those requests afterward.

Source code: https://github.com/nuclearfessel/ShopIt
''';

/// Licenses for ShopIt and the third-party pieces shipped with it.
const shopItLicenses = '''
ShopIt
Copyright (c) 2026 Fes Naqvi
Released under the MIT License. The full text is in the LICENSE file in the source repository.

Keyline Icons
The icons are from Keyline Icons (https://keylineicons.com, https://github.com/keyline-icons/keyline-icons), rounded stroke style, version 1.7.0.
Keyline Icons is licensed under the MIT License:
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the software, and to permit persons to whom the software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the software.
The software is provided "as is", without warranty of any kind.

Roboto
The Roboto font is licensed under the Apache License, Version 2.0. The license text is in assets/fonts/roboto_license.txt.

Open Food Facts
Product names looked up from a barcode come from Open Food Facts (https://world.openfoodfacts.org). That database is under the Open Database License. Product data is separate from ShopIt's MIT license. Credit: Open Food Facts contributors.

OpenStreetMap
Place names come from OpenStreetMap through Nominatim unless you choose another host. Place names © OpenStreetMap contributors. Nominatim's usage policy is at https://operations.osmfoundation.org/policies/nominatim/
''';
