import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/services/tax_lookup.dart';

void main() {
  group('parseZiptaxPercent', () {
    test('converts the fraction rate to a percent', () {
      final p = parseZiptaxPercent({
        'metadata': {
          'response': {'code': 100, 'name': 'RESPONSE_CODE_SUCCESS'}
        },
        'taxSummaries': [
          {'rate': 0.0775, 'taxType': 'SALES_TAX'}
        ],
      });
      expect(p, 7.75);
    });

    test('a 0% jurisdiction is a valid result', () {
      final p = parseZiptaxPercent({
        'metadata': {
          'response': {'code': 100}
        },
        'taxSummaries': [
          {'rate': 0}
        ],
      });
      expect(p, 0);
    });

    test('a rate already above 1 is treated as a percent', () {
      final p = parseZiptaxPercent({
        'metadata': {
          'response': {'code': 100}
        },
        'taxSummaries': [
          {'rate': 8.25}
        ],
      });
      expect(p, 8.25);
    });

    test('error codes become readable messages', () {
      LookupException failureFor(int code) {
        try {
          parseZiptaxPercent({
            'metadata': {
              'response': {'code': code}
            },
          });
        } on LookupException catch (e) {
          return e;
        }
        fail('expected a LookupException for $code');
      }

      expect(failureFor(101).message, contains('API key'));
      expect(failureFor(108).message, contains('Too many'));
      expect(failureFor(110).message, contains('could not find'));
      expect(failureFor(999).message, contains('999'));
    });

    test('success with no summaries is an error, not a zero rate', () {
      expect(
          () => parseZiptaxPercent({
                'metadata': {
                  'response': {'code': 100}
                },
                'taxSummaries': [],
              }),
          throwsA(isA<LookupException>()));
    });
  });

  group('parseNominatim', () {
    test('uses city and state, and flags the US', () {
      final p = parseNominatim({
        'address': {
          'city': 'Irvine',
          'state': 'California',
          'country': 'United States',
          'country_code': 'us',
        }
      })!;
      expect(p.label, 'Irvine, California');
      expect(p.isUs, isTrue);
    });

    test('falls back to town/county and non-US countries', () {
      final p = parseNominatim({
        'address': {
          'town': 'Banff',
          'province': 'Alberta',
          'country': 'Canada',
          'country_code': 'ca',
        }
      })!;
      expect(p.label, 'Banff, Alberta');
      expect(p.isUs, isFalse);
      expect(
          parseNominatim({
            'address': {'country': 'Iceland', 'country_code': 'is'}
          })!
              .label,
          'Iceland');
    });

    test('no address means no place', () {
      expect(parseNominatim({}), isNull);
      expect(parseNominatim({'address': {}}), isNull);
    });
  });
}
