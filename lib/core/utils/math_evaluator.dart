/// Lightweight, zero-dependency arithmetic expression evaluator for financial math.
/// Supports standard operator precedence (BODMAS: ×/÷ before +/-), decimals,
/// resilient live preview calculation, and division-by-zero protection.
class MathEvaluator {
  /// Evaluates an arithmetic expression string (e.g. "120 + 35.50 * 2").
  /// Returns `null` if the expression is invalid or encounters division by zero.
  static double? evaluate(String expression) {
    final sanitized = _sanitize(expression);
    if (sanitized.isEmpty) return null;

    try {
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) return null;

      final parser = _Parser(tokens);
      final result = parser.parseExpression();

      if (result.isInfinite || result.isNaN) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Live preview evaluation: ignores trailing operators if user is in the middle of typing
  /// (e.g. "120 +" evaluates as 120.0).
  static double? evaluateLivePreview(String expression) {
    var sanitized = _sanitize(expression);
    if (sanitized.isEmpty) return null;

    // Strip trailing incomplete operators (e.g. "120 + " -> "120")
    while (sanitized.isNotEmpty && _isOperator(sanitized[sanitized.length - 1])) {
      sanitized = sanitized.substring(0, sanitized.length - 1).trim();
    }

    if (sanitized.isEmpty) return null;
    return evaluate(sanitized);
  }

  /// Returns true if the string contains any arithmetic operator (+, -, ×, ÷, etc.).
  static bool hasMathOperators(String expression) {
    return RegExp(r'[+\-−*×/÷]').hasMatch(expression);
  }

  /// Formats a calculated numeric value cleanly for display (e.g. 150 or 155.50).
  static String formatResult(double value) {
    if (value.isInfinite || value.isNaN) return '0';
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    // Limit to 2 decimal places for currency
    final formatted = value.toStringAsFixed(2);
    // Remove trailing .00 if redundant
    if (formatted.endsWith('.00')) {
      return formatted.substring(0, formatted.length - 3);
    }
    return formatted;
  }

  static String _sanitize(String expr) {
    return expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .trim();
  }

  static bool _isOperator(String ch) {
    return ch == '+' || ch == '-' || ch == '*' || ch == '/';
  }

  static List<String> _tokenize(String expr) {
    final List<String> tokens = [];
    int i = 0;
    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ' || ch == '\t') {
        i++;
        continue;
      }

      if (_isOperator(ch)) {
        // Handle unary minus: if at start or immediately following another operator
        if (ch == '-' && (tokens.isEmpty || _isOperator(tokens.last))) {
          // Read number following unary minus
          final buffer = StringBuffer('-');
          i++;
          while (i < expr.length && (RegExp(r'[0-9.]').hasMatch(expr[i]))) {
            buffer.write(expr[i]);
            i++;
          }
          final numStr = buffer.toString();
          if (numStr == '-') throw const FormatException('Trailing unary minus');
          tokens.add(numStr);
          continue;
        }

        tokens.add(ch);
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final buffer = StringBuffer();
        while (i < expr.length && RegExp(r'[0-9.]').hasMatch(expr[i])) {
          buffer.write(expr[i]);
          i++;
        }
        tokens.add(buffer.toString());
      } else {
        // Unknown character
        throw FormatException('Unexpected token: $ch');
      }
    }
    return tokens;
  }
}

class _Parser {
  final List<String> tokens;
  int _pos = 0;

  _Parser(this.tokens);

  String? get _current => _pos < tokens.length ? tokens[_pos] : null;

  void _consume() {
    _pos++;
  }

  /// expression = term ( ('+' | '-') term )*
  double parseExpression() {
    double value = _parseTerm();

    while (_current == '+' || _current == '-') {
      final op = _current!;
      _consume();
      final right = _parseTerm();
      if (op == '+') {
        value += right;
      } else {
        value -= right;
      }
    }

    if (_pos < tokens.length) {
      throw FormatException('Unparsed token remaining: $_current');
    }

    return value;
  }

  /// term = factor ( ('*' | '/') factor )*
  double _parseTerm() {
    double value = _parseFactor();

    while (_current == '*' || _current == '/') {
      final op = _current!;
      _consume();
      final right = _parseFactor();
      if (op == '*') {
        value *= right;
      } else {
        if (right == 0.0) {
          throw UnsupportedError('Division by zero');
        }
        value /= right;
      }
    }

    return value;
  }

  /// factor = number
  double _parseFactor() {
    final token = _current;
    if (token == null) {
      throw const FormatException('Unexpected end of expression');
    }

    final numVal = double.tryParse(token);
    if (numVal == null) {
      throw FormatException('Invalid number token: $token');
    }

    _consume();
    return numVal;
  }
}
