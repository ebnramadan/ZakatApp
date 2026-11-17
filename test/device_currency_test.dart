import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/platform/device_currency.dart';
import 'package:zakat_app/core/models/user_profile.dart';

void main() {
  test('local timezone wins over an English US language preference', () {
    expect(
        currencyForDeviceRegion(timeZone: 'Africa/Cairo', locales: ['en-US']),
        'EGP');
    expect(currencyForDeviceRegion(timeZone: 'Asia/Dubai', locales: ['en-US']),
        'AED');
    expect(
        currencyForDeviceRegion(
            timeZone: 'America/Toronto', locales: ['ar-EG']),
        'CAD');
  });
  test(
      'explicit device region works without a recognized timezone; language alone never guesses a country',
      () {
    expect(currencyForDeviceRegion(timeZone: 'UTC', locales: ['ar-SA']), 'SAR');
    expect(currencyForDeviceRegion(locales: ['en-GB']), 'GBP');
    expect(currencyForDeviceRegion(locales: ['zh-Hans-CN']), 'CNY');
    expect(currencyForDeviceRegion(locales: ['ar', 'en']), 'EGP');
    expect(currencyForDeviceRegion(timeZone: 'Unknown', locales: ['xx-ZZ']),
        'EGP');
    expect(currencyForDeviceRegion(), 'EGP');
  });
  test(
      'missing currency falls back to EGP without replacing an existing choice',
      () {
    expect(UserProfile(uid: 'u', displayName: '', email: '').currency, 'EGP');
    expect(UserProfile.fromMap('u', {}).currency, 'EGP');
    expect(UserProfile.fromMap('u', {'currency': 'USD'}).currency, 'USD');
  });
}
