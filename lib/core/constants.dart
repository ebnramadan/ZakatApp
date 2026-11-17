import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double kNisabGrams = 85.0;
const double kZakatRate = 0.025;
const double kTroyOzToGrams = 31.1035;

const Color kPrimaryGreen = Color(0xFF146356);
const Color kLightGreen = Color(0xFF4CAF50);
const Color kGold = Color(0xFFFFB300);
const Color kSurface = Color(0xFFFBF5E9);

const Map<int, double> kGoldPurity = {
  24: 1.0,
  21: 21 / 24,
  18: 18 / 24,
};

/// ISO 4217 currency list (code → name)
const Map<String, String> kCurrencies = {
  'AED': 'UAE Dirham',
  'AUD': 'Australian Dollar',
  'BDT': 'Bangladeshi Taka',
  'BHD': 'Bahraini Dinar',
  'BRL': 'Brazilian Real',
  'CAD': 'Canadian Dollar',
  'CHF': 'Swiss Franc',
  'CNY': 'Chinese Yuan',
  'DZD': 'Algerian Dinar',
  'EGP': 'Egyptian Pound',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'IDR': 'Indonesian Rupiah',
  'INR': 'Indian Rupee',
  'IQD': 'Iraqi Dinar',
  'IRR': 'Iranian Rial',
  'JOD': 'Jordanian Dinar',
  'JPY': 'Japanese Yen',
  'KWD': 'Kuwaiti Dinar',
  'LBP': 'Lebanese Pound',
  'LYD': 'Libyan Dinar',
  'MAD': 'Moroccan Dirham',
  'MYR': 'Malaysian Ringgit',
  'NGN': 'Nigerian Naira',
  'OMR': 'Omani Rial',
  'PKR': 'Pakistani Rupee',
  'QAR': 'Qatari Riyal',
  'SAR': 'Saudi Riyal',
  'SDG': 'Sudanese Pound',
  'SGD': 'Singapore Dollar',
  'SYP': 'Syrian Pound',
  'TND': 'Tunisian Dinar',
  'TRY': 'Turkish Lira',
  'USD': 'US Dollar',
  'YER': 'Yemeni Rial',
  'ZAR': 'South African Rand',
};

String currencySymbol(String code) {
  const Map<String, String> symbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'SAR': '﷼',
    'AED': 'د.إ',
    'KWD': 'KD',
    'QAR': 'QR',
    'BHD': 'BD',
    'OMR': 'OMR',
    'EGP': 'EGP',
    'INR': '₹',
    'PKR': '₨',
    'TRY': '₺',
    'JPY': '¥',
    'CNY': '¥',
    'IDR': 'Rp',
    'MYR': 'RM',
  };
  return symbols[code] ?? code;
}

int currencyDecimals(String code) =>
    NumberFormat.currency(name: code).decimalDigits ?? 2;
