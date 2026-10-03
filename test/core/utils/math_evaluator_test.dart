import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/utils/math_evaluator.dart';

void main() {
  group('MathEvaluator', () {
    test('evaluates simple addition and subtraction', () {
      expect(MathEvaluator.evaluate('100 + 50'), equals(150.0));
      expect(MathEvaluator.evaluate('100 - 35'), equals(65.0));
      expect(MathEvaluator.evaluate('120 + 35 - 15'), equals(140.0));
    });

    test('evaluates multiplication and division with BODMAS operator precedence', () {
      // Multiplication before addition: 10 + (5 * 2) = 20 (NOT 30)
      expect(MathEvaluator.evaluate('10 + 5 * 2'), equals(20.0));
      // Division before subtraction: 100 - (20 / 4) = 95
      expect(MathEvaluator.evaluate('100 - 20 / 4'), equals(95.0));
      // Unicode symbols: 10 + 5 × 2
      expect(MathEvaluator.evaluate('10 + 5 × 2'), equals(20.0));
      // Unicode division: 100 − 20 ÷ 4
      expect(MathEvaluator.evaluate('100 − 20 ÷ 4'), equals(95.0));
    });

    test('handles decimal values accurately', () {
      expect(MathEvaluator.evaluate('12.50 + 2.75'), equals(15.25));
      expect(MathEvaluator.evaluate('10.5 * 3'), equals(31.5));
    });

    test('detects division by zero and returns null', () {
      expect(MathEvaluator.evaluate('100 / 0'), isNull);
      expect(MathEvaluator.evaluate('100 ÷ 0'), isNull);
    });

    test('evaluateLivePreview strips trailing operators gracefully', () {
      expect(MathEvaluator.evaluateLivePreview('120 + '), equals(120.0));
      expect(MathEvaluator.evaluateLivePreview('120 + 35 × '), equals(155.0));
      expect(MathEvaluator.evaluateLivePreview('120 + 35'), equals(155.0));
    });

    test('hasMathOperators detects presence of arithmetic operators', () {
      expect(MathEvaluator.hasMathOperators('120'), isFalse);
      expect(MathEvaluator.hasMathOperators('120.50'), isFalse);
      expect(MathEvaluator.hasMathOperators('120 + 35'), isTrue);
      expect(MathEvaluator.hasMathOperators('120 - 35'), isTrue);
      expect(MathEvaluator.hasMathOperators('120 × 2'), isTrue);
      expect(MathEvaluator.hasMathOperators('120 ÷ 2'), isTrue);
    });

    test('formatResult formats numbers cleanly', () {
      expect(MathEvaluator.formatResult(150.0), equals('150'));
      expect(MathEvaluator.formatResult(150.50), equals('150.50'));
      expect(MathEvaluator.formatResult(150.25), equals('150.25'));
    });
  });
}
