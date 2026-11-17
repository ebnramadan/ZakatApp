import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/platform/device_currency.dart';
import 'package:zakat_app/core/models/user_profile.dart';

void main() {
  test('an explicit detected country maps to currency with EGP fallback', () {
    expect(currencyForCountryCode('EG'), 'EGP');
    expect(currencyForCountryCode('sa'), 'SAR');
    expect(currencyForCountryCode('US'), 'USD');
    expect(currencyForCountryCode(null), 'EGP');
    expect(currencyForCountryCode('ZZ'), 'EGP');
  });
  test('new and missing currency defaults are EGP; saved choices are preserved',
      () {
    expect(UserProfile(uid: 'u', displayName: '', email: '').currency, 'EGP');
    expect(UserProfile.fromMap('u', {}).currency, 'EGP');
    expect(UserProfile.fromMap('u', {'currency': 'USD'}).currency, 'USD');
  });
}
