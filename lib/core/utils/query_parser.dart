import 'package:intl/intl.dart';
import '../../features/transactions/data/transaction_repository.dart';

/// Evaluates complex query expressions on transactions.
///
/// Supports:
/// - Prefixes: `cat:`, `category:`, `acc:`, `account:`, `tag:`, `note:`, `type:`, `amount:`, `date:`
/// - Comparison operators on amount and date: `>`, `>=`, `<`, `<=`, `=`
/// - Logical operators: `&&`, `AND`, `||`, `OR`, `-` (NOT)
/// - Quoted string literals: `cat:"Food & Dining"`
/// - Free-text fallback matches title, note, category, or account name
class QueryParser {
  /// Evaluates whether a given transaction matches the query string.
  static bool evaluate(String rawQuery, TransactionWithDetails item) {
    final query = rawQuery.trim();
    if (query.isEmpty) return true;

    // Split query into OR clauses first (lowest precedence)
    final orClauses = _splitByTopLevelOperator(query, '||', 'OR');
    if (orClauses.length > 1) {
      return orClauses.any((clause) => evaluate(clause, item));
    }

    // Split query into AND clauses (higher precedence than OR)
    final andClauses = _splitByTopLevelOperator(query, '&&', 'AND');
    if (andClauses.length > 1) {
      return andClauses.every((clause) => evaluate(clause, item));
    }

    // Tokenize space-separated terms within a single AND clause
    final tokens = _tokenizeTerms(query);
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (!_evaluateToken(token, item)) {
        return false;
      }
    }

    return true;
  }

  static bool _evaluateToken(String token, TransactionWithDetails item) {
    bool isNegated = false;
    String cleanToken = token;

    if (token.startsWith('-') && token.length > 1) {
      isNegated = true;
      cleanToken = token.substring(1);
    } else if (token.toUpperCase().startsWith('NOT ') && token.length > 4) {
      isNegated = true;
      cleanToken = token.substring(4).trim();
    }

    final result = _evaluatePositiveToken(cleanToken, item);
    return isNegated ? !result : result;
  }

  static bool _evaluatePositiveToken(String token, TransactionWithDetails item) {
    final tx = item.transaction;
    final catName = item.category?.name ?? '';
    final accName = item.account.name;
    final toAccName = item.toAccount?.name ?? '';

    // Prefix: cat: / category:
    if (token.startsWith('cat:') || token.startsWith('category:')) {
      final value = _extractPrefixValue(token);
      return catName.toLowerCase().contains(value.toLowerCase()) ||
          item.splits.any((s) => s.category.name.toLowerCase().contains(value.toLowerCase()));
    }

    // Prefix: acc: / account:
    if (token.startsWith('acc:') || token.startsWith('account:')) {
      final value = _extractPrefixValue(token);
      return accName.toLowerCase().contains(value.toLowerCase()) ||
          toAccName.toLowerCase().contains(value.toLowerCase());
    }

    // Prefix: tag:
    if (token.startsWith('tag:')) {
      final value = _extractPrefixValue(token).toLowerCase();
      final tags = tx.tags?.toLowerCase() ?? '';
      return tags.split(',').map((t) => t.trim()).contains(value) || tags.contains(value);
    }

    // Prefix: note:
    if (token.startsWith('note:')) {
      final value = _extractPrefixValue(token).toLowerCase();
      return (tx.note ?? '').toLowerCase().contains(value);
    }

    // Prefix: type:
    if (token.startsWith('type:')) {
      final value = _extractPrefixValue(token).toLowerCase();
      return tx.type.toLowerCase() == value;
    }

    // Prefix: amount: or standalone comparison (e.g. >50, <=100)
    if (token.startsWith('amount:') || _isComparisonOperator(token)) {
      final compStr = token.startsWith('amount:') ? token.substring(7).trim() : token.trim();
      return _evaluateNumericComparison(compStr, tx.amount);
    }

    // Prefix: date: (e.g. date:2026-08, date:>2026-08-01)
    if (token.startsWith('date:')) {
      final value = _extractPrefixValue(token);
      return _evaluateDateComparison(value, tx.date);
    }

    // Free text match (title, note, category name, account name, tags)
    final lower = token.toLowerCase();
    return tx.title.toLowerCase().contains(lower) ||
        (tx.note ?? '').toLowerCase().contains(lower) ||
        (tx.tags ?? '').toLowerCase().contains(lower) ||
        catName.toLowerCase().contains(lower) ||
        accName.toLowerCase().contains(lower) ||
        toAccName.toLowerCase().contains(lower) ||
        item.splits.any((s) => s.category.name.toLowerCase().contains(lower));
  }

  static String _extractPrefixValue(String token) {
    final colonIdx = token.indexOf(':');
    if (colonIdx == -1) return '';
    var val = token.substring(colonIdx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      if (val.length >= 2) {
        val = val.substring(1, val.length - 1);
      }
    }
    return val;
  }

  static bool _isComparisonOperator(String str) {
    return str.startsWith('>=') ||
        str.startsWith('<=') ||
        str.startsWith('>') ||
        str.startsWith('<') ||
        str.startsWith('=');
  }

  static bool _evaluateNumericComparison(String compStr, double actualValue) {
    String op = '=';
    String numStr = compStr;

    if (compStr.startsWith('>=') || compStr.startsWith('<=')) {
      op = compStr.substring(0, 2);
      numStr = compStr.substring(2);
    } else if (compStr.startsWith('>') || compStr.startsWith('<') || compStr.startsWith('=')) {
      op = compStr.substring(0, 1);
      numStr = compStr.substring(1);
    }

    final target = double.tryParse(numStr.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (target == null) return true;

    switch (op) {
      case '>=':
        return actualValue >= target;
      case '<=':
        return actualValue <= target;
      case '>':
        return actualValue > target;
      case '<':
        return actualValue < target;
      case '=':
      default:
        return (actualValue - target).abs() < 0.01;
    }
  }

  static bool _evaluateDateComparison(String dateQuery, DateTime actualDate) {
    String op = '=';
    String dateStr = dateQuery.trim();

    if (dateStr.startsWith('>=') || dateStr.startsWith('<=')) {
      op = dateStr.substring(0, 2);
      dateStr = dateStr.substring(2).trim();
    } else if (dateStr.startsWith('>') || dateStr.startsWith('<') || dateStr.startsWith('=')) {
      op = dateStr.substring(0, 1);
      dateStr = dateStr.substring(1).trim();
    }

    try {
      if (dateStr.length == 7) {
        // YYYY-MM format
        final parts = dateStr.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        if (op == '=') {
          return actualDate.year == year && actualDate.month == month;
        }
      }

      final target = DateTime.parse(dateStr);
      final actualNormalized = DateTime(actualDate.year, actualDate.month, actualDate.day);
      final targetNormalized = DateTime(target.year, target.month, target.day);

      switch (op) {
        case '>=':
          return actualNormalized.isAfter(targetNormalized) || actualNormalized.isAtSameMomentAs(targetNormalized);
        case '<=':
          return actualNormalized.isBefore(targetNormalized) || actualNormalized.isAtSameMomentAs(targetNormalized);
        case '>':
          return actualNormalized.isAfter(targetNormalized);
        case '<':
          return actualNormalized.isBefore(targetNormalized);
        case '=':
        default:
          return actualNormalized.isAtSameMomentAs(targetNormalized);
      }
    } catch (_) {
      final formatted = DateFormat('yyyy-MM-dd').format(actualDate);
      return formatted.contains(dateStr);
    }
  }

  static List<String> _splitByTopLevelOperator(String query, String op1, String op2) {
    final results = <String>[];
    int depth = 0;
    bool inQuote = false;
    int lastSplit = 0;

    for (int i = 0; i < query.length; i++) {
      final char = query[i];
      if (char == '"' || char == "'") {
        inQuote = !inQuote;
      } else if (!inQuote) {
        if (char == '(') {
          depth++;
        } else if (char == ')') {
          depth--;
        } else if (depth == 0) {
          if (query.substring(i).startsWith(op1)) {
            results.add(query.substring(lastSplit, i).trim());
            i += op1.length - 1;
            lastSplit = i + 1;
          } else if (query.substring(i).toUpperCase().startsWith(' $op2 ') ||
              query.substring(i).toUpperCase().startsWith('$op2 ')) {
            results.add(query.substring(lastSplit, i).trim());
            i += op2.length;
            lastSplit = i + 1;
          }
        }
      }
    }
    results.add(query.substring(lastSplit).trim());
    return results.where((s) => s.isNotEmpty).toList();
  }

  static List<String> _tokenizeTerms(String query) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;

    for (int i = 0; i < query.length; i++) {
      final char = query[i];
      if (char == '"' || char == "'") {
        inQuote = !inQuote;
        buffer.write(char);
      } else if (char == ' ' && !inQuote) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }
}
