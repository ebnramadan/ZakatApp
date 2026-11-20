import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/localization/duaa.dart';

void main() {
  const english =
      'O Allah, grant us a compassionate heart and open the doors of goodness for us.';
  const arabic = 'اللهم ارزقنا قلبًا رحيمًا، ويسّر لنا أبواب الخير.';

  test('new and legacy prayers follow the selected language without duplicates',
      () {
    for (final stored in [english, arabic, '$english\n\n$arabic']) {
      expect(notificationDuaaText(stored, 'en'), '$english\n\n$arabic');
      expect(notificationDuaaText(stored, 'ar'), arabic);
    }
    const prefix = 'Sarah is waiting for your kindness.\n';
    expect(notificationDuaaText('$prefix$english', 'en'),
        '$prefix$english\n\n$arabic');
    expect(notificationDuaaText('Unrelated notification', 'ar'),
        'Unrelated notification');
  });

  test('loading prayers use bilingual English and Arabic-only Arabic', () {
    const prayer =
        'O Allah, accept our giving and bless what You have provided.';
    expect(duaaText(prayer, 'en'), contains('اللهم'));
    expect(duaaText(prayer, 'en'), contains(prayer));
    expect(duaaText(prayer, 'ar'), isNot(contains('O Allah')));
  });
}
