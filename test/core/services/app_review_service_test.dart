import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/services/app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppReviewService reviewService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reviewService = AppReviewService();
  });

  test('AppReviewService records goal completions in SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('review_goals_completed_count'), null);

    await reviewService.recordGoalCompleted();
    expect(prefs.getInt('review_goals_completed_count'), 1);

    await reviewService.recordGoalCompleted();
    expect(prefs.getInt('review_goals_completed_count'), 2);
  });

  test('AppReviewService records logged transactions count', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('review_tx_logged_count'), null);

    for (int i = 1; i <= 15; i++) {
      await reviewService.recordTransactionLogged();
    }
    expect(prefs.getInt('review_tx_logged_count'), 15);
  });

  test('AppReviewService records manual backup completion milestone', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('review_backup_completed'), null);

    await reviewService.recordBackupCompleted();
    expect(prefs.getBool('review_backup_completed'), true);
  });
}
