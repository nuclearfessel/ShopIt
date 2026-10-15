# Cloud mailbox

Shop-it stores each paired device's list snapshot in a shared household
mailbox so the phone and the computer can sync without being on the same
Wi-Fi.

The app talks to a free key/value host by default
(`keyvalue.immanuel.co`). The eight-character household code is the secret
path. No Shop-it account is required.

If that host is ever unavailable, point `CloudMailbox(baseUrl: …)` at any
compatible GetValue/UpdateValue endpoint, or deploy a small Worker of your
own that implements the same two routes.
