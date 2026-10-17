import 'cloud_mailbox.dart';

/// Prefix so a grocery barcode is never treated as a sync code.
const syncQrPrefix = 'shopit:';

/// Text stored in the QR code the computer shows.
String syncQrPayload(String code) =>
    '$syncQrPrefix${code.trim().toLowerCase()}';

/// Household code inside a scan, or null when it is not a ShopIt sync code.
String? householdFromQr(String raw) {
  final text = raw.trim();
  final body = text.toLowerCase().startsWith(syncQrPrefix)
      ? text.substring(syncQrPrefix.length)
      : text;
  final code = body.trim().toLowerCase();
  return isHouseholdCode(code) ? code : null;
}
