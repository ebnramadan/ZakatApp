import 'dart:ui' show PlatformDispatcher;
import 'device_timezone_stub.dart'
    if (dart.library.html) 'device_timezone_web.dart' as platform;

/// A suggestion from device settings, not GPS. Never overrides a saved choice.
String suggestedDeviceCurrency() => currencyForDeviceRegion(
    timeZone: platform.deviceTimeZone(),
    locales: PlatformDispatcher.instance.locales.map((l) => l.toLanguageTag()));

String currencyForDeviceRegion(
    {String? timeZone, Iterable<String> locales = const []}) {
  for (final entry in _zones.entries) {
    if (entry.value.contains(timeZone)) return entry.key;
  }
  for (final locale in locales) {
    final parts = locale.replaceAll('_', '-').split('-').skip(1);
    for (final part in parts) {
      if (part.length == 1) break; // BCP-47 extensions are not country codes.
      final currency = _countries[part.toUpperCase()];
      if (currency != null) return currency;
    }
  }
  return 'EGP';
}

const _countries = {
  'EG': 'EGP',
  'US': 'USD',
  'GB': 'GBP',
  'CA': 'CAD',
  'AU': 'AUD',
  'SA': 'SAR',
  'AE': 'AED',
  'QA': 'QAR',
  'KW': 'KWD',
  'BH': 'BHD',
  'OM': 'OMR',
  'JO': 'JOD',
  'LB': 'LBP',
  'IQ': 'IQD',
  'IR': 'IRR',
  'SY': 'SYP',
  'YE': 'YER',
  'SD': 'SDG',
  'LY': 'LYD',
  'TN': 'TND',
  'DZ': 'DZD',
  'MA': 'MAD',
  'TR': 'TRY',
  'PK': 'PKR',
  'IN': 'INR',
  'BD': 'BDT',
  'MY': 'MYR',
  'ID': 'IDR',
  'SG': 'SGD',
  'CN': 'CNY',
  'JP': 'JPY',
  'NG': 'NGN',
  'ZA': 'ZAR',
  'CH': 'CHF',
  'LI': 'CHF',
  'BR': 'BRL',
  'DE': 'EUR',
  'FR': 'EUR',
  'IT': 'EUR',
  'ES': 'EUR',
  'PT': 'EUR',
  'NL': 'EUR',
  'BE': 'EUR',
  'AT': 'EUR',
  'IE': 'EUR',
  'GR': 'EUR',
  'FI': 'EUR',
  'LU': 'EUR',
  'MT': 'EUR',
  'CY': 'EUR',
  'SK': 'EUR',
  'SI': 'EUR',
  'EE': 'EUR',
  'LV': 'EUR',
  'LT': 'EUR',
  'HR': 'EUR',
};
const _zones = {
  'EGP': ['Africa/Cairo', 'Egypt'],
  'SAR': ['Asia/Riyadh'],
  'AED': ['Asia/Dubai'],
  'QAR': ['Asia/Qatar'],
  'KWD': ['Asia/Kuwait'],
  'BHD': ['Asia/Bahrain'],
  'OMR': ['Asia/Muscat'],
  'JOD': ['Asia/Amman'],
  'LBP': ['Asia/Beirut'],
  'IQD': ['Asia/Baghdad'],
  'IRR': ['Asia/Tehran', 'Iran'],
  'SYP': ['Asia/Damascus'],
  'YER': ['Asia/Aden'],
  'SDG': ['Africa/Khartoum'],
  'LYD': ['Africa/Tripoli', 'Libya'],
  'TND': ['Africa/Tunis'],
  'DZD': ['Africa/Algiers'],
  'MAD': ['Africa/Casablanca', 'Africa/El_Aaiun'],
  'GBP': ['Europe/London', 'Europe/Belfast', 'GB', 'GB-Eire'],
  'EUR': [
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/Rome',
    'Europe/Madrid',
    'Europe/Lisbon',
    'Europe/Amsterdam',
    'Europe/Brussels',
    'Europe/Vienna',
    'Europe/Dublin',
    'Europe/Athens',
    'Europe/Helsinki',
    'Europe/Luxembourg',
    'Europe/Malta',
    'Asia/Nicosia',
    'Europe/Bratislava',
    'Europe/Ljubljana',
    'Europe/Tallinn',
    'Europe/Riga',
    'Europe/Vilnius',
    'Europe/Zagreb',
    'Atlantic/Canary',
    'Atlantic/Madeira',
    'Atlantic/Azores'
  ],
  'USD': [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Phoenix',
    'America/Anchorage',
    'America/Detroit',
    'America/Indiana/Indianapolis',
    'America/Indianapolis',
    'America/Kentucky/Louisville',
    'America/Boise',
    'Pacific/Honolulu',
    'US/Eastern',
    'US/Central',
    'US/Mountain',
    'US/Pacific',
    'US/Alaska',
    'US/Hawaii'
  ],
  'CAD': [
    'America/Toronto',
    'America/Vancouver',
    'America/Edmonton',
    'America/Winnipeg',
    'America/Halifax',
    'America/St_Johns',
    'America/Regina',
    'America/Montreal',
    'Canada/Eastern',
    'Canada/Pacific'
  ],
  'AUD': [
    'Australia/Sydney',
    'Australia/Melbourne',
    'Australia/Brisbane',
    'Australia/Perth',
    'Australia/Adelaide',
    'Australia/Darwin',
    'Australia/Hobart'
  ],
  'CHF': ['Europe/Zurich', 'Europe/Vaduz'],
  'TRY': ['Europe/Istanbul', 'Asia/Istanbul', 'Turkey'],
  'PKR': ['Asia/Karachi'],
  'INR': ['Asia/Kolkata', 'Asia/Calcutta'],
  'BDT': ['Asia/Dhaka', 'Asia/Dacca'],
  'MYR': ['Asia/Kuala_Lumpur', 'Asia/Kuching'],
  'IDR': ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura', 'Asia/Pontianak'],
  'SGD': ['Asia/Singapore', 'Singapore'],
  'CNY': ['Asia/Shanghai', 'Asia/Urumqi', 'PRC'],
  'JPY': ['Asia/Tokyo', 'Japan'],
  'NGN': ['Africa/Lagos'],
  'ZAR': ['Africa/Johannesburg'],
  'BRL': [
    'America/Sao_Paulo',
    'America/Manaus',
    'America/Recife',
    'America/Bahia',
    'America/Fortaleza',
    'America/Belem',
    'America/Cuiaba',
    'America/Porto_Velho',
    'America/Rio_Branco',
    'America/Noronha'
  ],
};
