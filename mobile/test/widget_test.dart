import 'package:flutter_test/flutter_test.dart';
import 'package:scheme_mitra/l10n.dart';
import 'package:scheme_mitra/main.dart';
import 'package:scheme_mitra/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fails closed when an API origin was not configured', (tester) async {
    await tester.pumpWidget(const SchemeMitraApp());
    await tester.pumpAndSettle();

    expect(find.text('Set API_BASE_URL at build time. Release builds require the production HTTPS API origin.'), findsOneWidget);
  });

  test('eligibility labels stay explicit and deterministic', () {
    expect(AppCopy.eligibilityLabel('en', 'LIKELY_ELIGIBLE'), 'Likely Eligible');
    expect(AppCopy.eligibilityLabel('en', 'POTENTIALLY_ELIGIBLE'), 'Potentially Eligible — verification required');
    expect(AppCopy.eligibilityLabel('en', 'NOT_ELIGIBLE'), 'Not Eligible based on available information');
    expect(AppCopy.eligibilityLabel('en', 'INSUFFICIENT_INFORMATION'), 'Insufficient Information');
  });

  test('scheme model uses evaluation-provided, self-reported checklist states', () {
    final scheme = SchemeRecord.fromJson({
      'slug': 'sample-scheme',
      'name': 'Sample scheme',
      'department': 'Agriculture Department',
      'category': 'Irrigation',
      'level': 'State',
      'summary': 'A sample record for model testing.',
      'benefit_summary': 'Benefits require confirmation.',
      'source_name': 'Official portal',
      'source_url': 'https://example.gov.in/scheme',
      'application_url': 'https://example.gov.in/apply',
      'source_checked_at': '2026-10-01',
      'evaluation': {
        'status': 'INSUFFICIENT_INFORMATION',
        'eligibility_rules': [],
        'documents': [
          {'id': 'land_7_12', 'label': '7/12 extract', 'state': 'needs_verification', 'validated': false},
        ],
      },
      'document_items': [],
      'document_review_note': 'Confirm component-specific documents on the linked official source.',
      'application_process': ['Open the official portal.'],
    });

    expect(scheme.slug, 'sample-scheme');
    expect(scheme.sourceCheckedAt, '2026-10-01');
    expect(scheme.documents.single['state'], 'needs_verification');
    expect(scheme.documentReviewNote, 'Confirm component-specific documents on the linked official source.');
    expect(scheme.eligibilityStatus, 'INSUFFICIENT_INFORMATION');
  });
}
