import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/features/transactions/presentation/widgets/receipt_attachment_widget.dart';

void main() {
  group('ReceiptAttachmentWidget Tests', () {
    testWidgets('renders empty state CTA properly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReceiptAttachmentWidget(
                receiptPath: null,
                onReceiptChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Scan Bill or Attach Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    });

    testWidgets('tapping empty state opens capture options bottom sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReceiptAttachmentWidget(
                receiptPath: null,
                onReceiptChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap to open options
      await tester.tap(find.text('Scan Bill or Attach Receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Attach or Scan Receipt'), findsOneWidget);
      expect(find.text('Attach Image Only (No OCR)'), findsOneWidget);
    });

    testWidgets('renders attached state when receiptPath is present', (tester) async {
      bool removeTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReceiptAttachmentWidget(
                receiptPath: 'receipts/mock_receipt.jpg',
                onReceiptChanged: (val) {
                  if (val == null) removeTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Receipt Attached'), findsOneWidget);
      expect(find.text('Tap to view / zoom receipt'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(removeTriggered, isTrue);
    });
  });
}
