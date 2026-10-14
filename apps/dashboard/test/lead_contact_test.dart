import 'package:dashboard/features/presentation/widgets/lead_detail_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('ContactLinks', () {
    test('local Pakistani numbers become international digits', () {
      expect(ContactLinks.internationalDigits('0300-1234567'), '923001234567');
      expect(ContactLinks.internationalDigits('+92 300 1234567'), '923001234567');
      expect(ContactLinks.internationalDigits('0092 300 1234567'), '923001234567');
    });

    test('junk is rejected instead of producing a broken link', () {
      expect(ContactLinks.internationalDigits(null), isNull);
      expect(ContactLinks.internationalDigits('n/a'), isNull);
      expect(ContactLinks.call('123'), isNull);
    });

    test('call and WhatsApp URIs', () {
      expect(ContactLinks.call('0300 1234567').toString(), 'tel:+923001234567');
      final wa = ContactLinks.whatsApp('0300 1234567', message: 'Hi, about the Civic & price?')!;
      expect(wa.host, 'wa.me');
      expect(wa.path, '/923001234567');
      expect(wa.queryParameters['text'], 'Hi, about the Civic & price?');
    });
  });

  test('the customer app\'s contact email is recovered from lead notes', () {
    const notes = 'Test drive requested for 2026-03-07.\nMessage: hi\nContact email: hina@example.com';
    expect(emailFromNotes(notes), 'hina@example.com');
    expect(emailFromNotes('Walk-in, no email'), isNull);
    expect(emailFromNotes(null), isNull);
  });

  test('stage labels cover every leads.stage value in pipeline order', () {
    expect(leadStageLabels.keys, [
      'new', 'contacted', 'test_drive_scheduled', 'negotiating', 'closed_won', 'closed_lost',
    ]);
  });
}
