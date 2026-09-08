import 'package:flutter_riverpod/flutter_riverpod.dart';

final receiptParserServiceProvider = Provider<ReceiptParserService>((ref) {
  return ReceiptParserService();
});

/// Extracted data from receipt OCR text.
class ParsedReceiptData {
  final double? amount;
  final DateTime? date;
  final String? merchantName;
  final String? suggestedCategoryKeyword;
  final String rawText;

  ParsedReceiptData({
    this.amount,
    this.date,
    this.merchantName,
    this.suggestedCategoryKeyword,
    required this.rawText,
  });

  @override
  String toString() {
    return 'ParsedReceiptData(amount: $amount, date: $date, merchant: $merchantName, categoryHint: $suggestedCategoryKeyword)';
  }
}

/// Heuristic parser that processes raw OCR text lines to extract total amount,
/// transaction date, merchant/store title, and suggested category.
class ReceiptParserService {
  /// Regular expression to match currency amounts:
  /// 1. Thousands with optional decimals: 1,452, 24,468, 1,044.12, $1,199.99
  /// 2. Standard decimal amounts: 821.00, 1665.62, 850.00, 12.34
  /// 3. European comma decimals: 12,50, 4,70
  /// 4. Plain integers: 24468, 625, 695
  static final RegExp _amountRegex = RegExp(
    r'(?:[\$€£₹]|(?:Rs\.?|NPR|USD|EUR|GBP)\s*)?([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{2})?|[0-9]+\.[0-9]{2}|[0-9]+,[0-9]{2}|[0-9]+)(?:\s*(?:NPR|USD|EUR|GBP))?(?!\s*%)',
    caseSensitive: false,
  );

  /// High-confidence keywords that explicitly declare the final transaction total
  static final List<String> _tier1TotalKeywords = [
    'grand total',
    'net payable',
    'total payable',
    'balance amount',
    'amount payable',
    'payable',
    'grossamt',
    'gross amt',
    'gross amount',
    'net amount',
    'total amount',
    'total paid',
    'customer paid',
    'sale amount',
    'total npr',
    'total rs',
    'total',
  ];

  /// Lower-confidence keywords (used only if Tier 1 yields no result)
  static final List<String> _tier2TotalKeywords = [
    'amount',
    'balance',
    'net',
  ];

  /// Markers that indicate item counts or quantities, NEVER monetary totals
  static final List<String> _itemCountMarkers = [
    'total item',
    'total items',
    'total qty',
    'total quantity',
    'total pcs',
    'total pc',
    'total piece',
    'total pieces',
    'total count',
    'total unit',
    'total units',
    'total guest',
    'total guests',
    'total cover',
  ];

  /// Table header markers that should NEVER be treated as total amount lines
  static final List<String> _tableHeaderMarkers = [
    'particular',
    'item',
    'qty',
    'quantity',
    'rate',
    'unit price',
    'unit',
    'hscode',
    's.n.',
    'sn.',
    'description',
  ];

  /// Keywords to exclude or treat with lower priority (taxes, tips, change, subtotal)
  static final List<String> _secondaryKeywords = [
    'subtotal',
    'sub total',
    'sub-total',
    'tax',
    'vat',
    'gst',
    'cgst',
    'sgst',
    'change',
    'cash back',
    'discount',
    'savings',
    'tip',
  ];

  /// Metadata labels whose numbers are IDs, timestamps, or trace codes (never transaction amounts)
  static final List<String> _posMetadataIgnoreKeywords = [
    'trace',
    'approval',
    'batch',
    'tid',
    'mid',
    'rrn',
    'bill no',
    'invoice no',
    'invoice number',
    'crm no',
    'vat no',
    'pan no',
    'panno',
    'tpin',
    'hscode',
    'card no',
    'card type',
    'aid:',
    'chip',
    'st#',
    'tel:',
    'phone:',
    'time:',
    'time',
    'date:',
    'date',
    'saving in this bill',
    'discount',
    'tender',
    'refund',
  ];

  static final RegExp _timeRegex = RegExp(r'\b[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:\s*(?:AM|PM))?\b', caseSensitive: false);

  /// Header noise words to skip when identifying merchant title
  static final List<String> _merchantIgnorePatterns = [
    'tax invoice',
    'abbreviated tax invoice',
    'provisional bill',
    'original copy',
    'duplicate copy',
    'customer copy',
    'merchant copy',
    'invoice',
    'receipt',
    'cash receipt',
    'sales receipt',
    'bill',
    'welcome',
    'thank you',
    'order #',
    'order no',
    'table #',
    'tel:',
    'phone:',
    'ph:',
    'fax:',
    'www.',
    'http',
    'email:',
    'gstin',
    'pan no',
    'vat no',
    'tpin',
    'tax id',
    'reg no',
    'date:',
    'time:',
  ];

  /// Parses raw text extracted from an image and returns structured data.
  ParsedReceiptData parse(String text) {
    if (text.trim().isEmpty) {
      return ParsedReceiptData(rawText: text);
    }

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amount = extractAmount(lines);
    final date = extractDate(lines);
    final merchant = extractMerchant(lines);
    final categoryHint = extractCategoryHint(text, merchant);

    return ParsedReceiptData(
      amount: amount,
      date: date,
      merchantName: merchant,
      suggestedCategoryKeyword: categoryHint,
      rawText: text,
    );
  }

  /// Extracts the most probable total amount from receipt lines.
  double? extractAmount(List<String> lines) {
    // 1. Search Tier 1 high-confidence total keywords
    final tier1Amount = _searchKeywords(lines, _tier1TotalKeywords);
    if (tier1Amount != null && tier1Amount > 0) {
      return tier1Amount;
    }

    // 2. Search Tier 2 keywords (e.g., standalone "AMOUNT" on bank POS card slips)
    final tier2Amount = _searchKeywords(lines, _tier2TotalKeywords);
    if (tier2Amount != null && tier2Amount > 0) {
      return tier2Amount;
    }

    // 3. Repeated amount detection: On supermarket invoices, total amount repeats 2-4 times
    final repeatedAmount = _findRepeatedAmount(lines);
    if (repeatedAmount != null && repeatedAmount > 0) {
      return repeatedAmount;
    }

    // 4. Fallback: Collect realistic amounts, ignoring metadata IDs
    return _extractFallbackAmount(lines);
  }

  double? _searchKeywords(List<String> lines, List<String> keywords) {
    final List<double> foundAmounts = [];

    for (int i = 0; i < lines.length; i++) {
      final lineLower = lines[i].toLowerCase();

      // Skip item count lines like "Total Qty : 4", "Total Items : 2"
      if (_isItemCountLine(lineLower)) {
        continue;
      }

      // Skip table header lines like "Particulars Qty Rate Amount"
      if (_isTableHeaderLine(lineLower)) {
        continue;
      }

      // Check if line contains any target keyword
      final matchedKeyword = keywords.firstWhere(
        (kw) => lineLower.contains(kw),
        orElse: () => '',
      );

      if (matchedKeyword.isEmpty) continue;

      // Ensure it's not actually "Subtotal" unless the keyword explicitly matched
      final isSubtotal = _secondaryKeywords.any((sk) => lineLower.contains(sk) && sk.contains('sub'));
      if (isSubtotal && !matchedKeyword.contains('grand')) {
        continue;
      }

      // 1. Extract amount from current line
      final amountInLine = _findAmountInString(lines[i]);
      if (amountInLine != null && amountInLine > 0) {
        foundAmounts.add(amountInLine);
        // Explicit final total phrases (like grand total, net payable, payable, net amount) take immediate priority
        if (lineLower.contains('grand total') ||
            lineLower.contains('net payable') ||
            lineLower.contains('payable') ||
            lineLower.contains('net amount') ||
            lineLower.contains('balance amount')) {
          return amountInLine;
        }
        continue;
      }

      // 2. Or check lookahead (next 1 to 3 lines) for split / two-line prints
      for (int offset = 1; offset <= 3 && (i + offset) < lines.length; offset++) {
        final lookaheadLine = lines[i + offset];
        final lookaheadLower = lookaheadLine.toLowerCase();

        // Skip noise lines, item counts, or words-only amounts
        if (_isNoiseOrMetadataLine(lookaheadLower) || _isItemCountLine(lookaheadLower)) {
          continue;
        }

        // Stop lookahead if we hit another table header
        if (_isTableHeaderLine(lookaheadLower)) {
          break;
        }

        final lookaheadAmount = _findAmountInString(lookaheadLine);
        if (lookaheadAmount != null && lookaheadAmount > 0) {
          foundAmounts.add(lookaheadAmount);
          if (lineLower.contains('grand total') ||
              lineLower.contains('net payable') ||
              lineLower.contains('payable') ||
              lineLower.contains('net amount') ||
              lineLower.contains('balance amount')) {
            return lookaheadAmount;
          }
          break;
        }
      }
    }

    if (foundAmounts.isEmpty) return null;

    // When multiple totals exist (e.g. subtotal Total: 840.00 followed by final Total: 1,044.12),
    // the final bill is at the bottom of the invoice
    return foundAmounts.last;
  }

  bool _isItemCountLine(String lineLower) {
    return _itemCountMarkers.any((m) => lineLower.contains(m));
  }

  bool _isTableHeaderLine(String lineLower) {
    if (lineLower.contains('particular') || lineLower.contains('hscode')) {
      return true;
    }
    int matches = 0;
    for (final marker in _tableHeaderMarkers) {
      if (lineLower.contains(marker)) matches++;
    }
    return matches >= 2;
  }

  bool _isNoiseOrMetadataLine(String lineLower) {
    if (lineLower.contains('only') && (lineLower.contains('hundred') || lineLower.contains('thousand') || lineLower.contains('rupees') || lineLower.contains('paisa'))) {
      return true;
    }
    return _posMetadataIgnoreKeywords.any((kw) => lineLower.contains(kw));
  }

  double? _findRepeatedAmount(List<String> lines) {
    final Map<double, int> counts = {};
    for (final line in lines) {
      final lineLower = line.toLowerCase();
      if (_isNoiseOrMetadataLine(lineLower) || _isTableHeaderLine(lineLower) || _isItemCountLine(lineLower)) {
        continue;
      }

      final val = _findAmountInString(line);
      // Amounts with decimals (like 821.00) that appear repeatedly have highest confidence
      if (val != null && val > 0 && line.contains('.')) {
        counts[val] = (counts[val] ?? 0) + 1;
      }
    }

    double? bestAmount;
    int bestCount = 1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestAmount = entry.key;
      }
    }
    return bestAmount;
  }

  double? _extractFallbackAmount(List<String> lines) {
    final List<double> candidateAmounts = [];

    for (final line in lines) {
      final lineLower = line.toLowerCase();

      // Skip lines with phone numbers, dates, barcodes, metadata IDs, item counts
      if (_isNoiseOrMetadataLine(lineLower) ||
          _isItemCountLine(lineLower) ||
          lineLower.contains('tel') ||
          lineLower.contains('phone') ||
          lineLower.contains('date') ||
          lineLower.contains('time') ||
          lineLower.contains('card') ||
          lineLower.contains('tax id')) {
        continue;
      }

      final val = _findAmountInString(line);
      if (val != null && val > 0 && val < 1000000) {
        // Exclude 4-digit years like 2018 to 2035 if without decimals
        if (val >= 2018 && val <= 2035 && !line.contains('.')) {
          continue;
        }
        candidateAmounts.add(val);
      }
    }

    if (candidateAmounts.isEmpty) return null;

    // Prefer amounts with decimals if available
    final decimalCandidates = candidateAmounts.where((c) => c % 1 != 0 || lines.any((l) => l.contains(c.toStringAsFixed(2)))).toList();
    if (decimalCandidates.isNotEmpty) {
      decimalCandidates.sort();
      return decimalCandidates.last;
    }

    candidateAmounts.sort();
    return candidateAmounts.last;
  }

  double? _findAmountInString(String str) {
    // Strip timestamps like 19:57:10 or 08:56:36 PM before looking for amounts
    var cleanStr = str.replaceAll(_timeRegex, '');
    // Strip parentheses e.g. (1,452)
    cleanStr = cleanStr.replaceAll('(', ' ').replaceAll(')', ' ');

    final matches = _amountRegex.allMatches(cleanStr);
    final List<double> validAmounts = [];

    for (final match in matches) {
      String rawVal = match.group(1) ?? match.group(0) ?? '';
      rawVal = rawVal.replaceAll(RegExp(r'[^0-9.,]'), '');

      // Handle comma decimal separator like 12,50 or thousands like 1,452
      if (rawVal.contains(',') && !rawVal.contains('.')) {
        if (RegExp(r',[0-9]{3}\b').hasMatch(rawVal)) {
          rawVal = rawVal.replaceAll(',', '');
        } else {
          rawVal = rawVal.replaceAll(',', '.');
        }
      } else if (rawVal.contains(',') && rawVal.contains('.')) {
        // Handle thousands separator like 1,250.00
        rawVal = rawVal.replaceAll(',', '');
      }

      final parsed = double.tryParse(rawVal);
      if (parsed != null && parsed > 0) {
        validAmounts.add(parsed);
      }
    }

    if (validAmounts.isEmpty) return null;

    // When multiple numbers appear on the line (e.g. "Total : 2 1,320" or "Total 4 850.00"):
    // A single-digit number <= 9 is an item count, while the larger number is the monetary amount!
    if (validAmounts.length > 1) {
      if (validAmounts.first <= 9 && validAmounts.last >= 10) {
        return validAmounts.last;
      }
      return validAmounts.last;
    }

    return validAmounts.first;
  }

  /// Extracts date from receipt text lines.
  DateTime? extractDate(List<String> lines) {
    // Pattern 1: YYYY-MM-DD or YYYY/MM/DD or YYYY.MM.DD (supports 1980 - 2099, including Nepali BS years like 2075-2085)
    final isoPattern = RegExp(r'\b(19[89][0-9]|20[0-9]{2})[-/.](0[1-9]|1[0-2])[-/.](0[1-9]|[12][0-9]|3[01])\b');

    // Pattern 2: DD/MM/YYYY or MM/DD/YYYY
    final dmyPattern = RegExp(r'\b(0[1-9]|[12][0-9]|3[01])[-/.](0[1-9]|1[0-2])[-/.](19[89][0-9]|20[0-9]{2}|[2-3][0-9])\b');

    // Pattern 3: Textual dates like "14-February-2025", "05/Sep/2026", "07 Sep 2026", "07-Sept-2026"
    final dmyTextPattern = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])[\s\.\-\/]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\.\-\/,]+(19[89][0-9]|20[0-9]{2})\b',
      caseSensitive: false,
    );

    // Pattern 4: Textual dates like "Sunday, September 13, 2020", "Sep 07, 2026"
    final mdyTextPattern = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\.\-\/]+(0?[1-9]|[12][0-9]|3[01])[,\s\.\-\/]+(19[89][0-9]|20[0-9]{2})\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      // Try Pattern 1 (ISO)
      final isoMatch = isoPattern.firstMatch(line);
      if (isoMatch != null) {
        final year = int.tryParse(isoMatch.group(1)!);
        final month = int.tryParse(isoMatch.group(2)!);
        final day = int.tryParse(isoMatch.group(3)!);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }

      // Try Pattern 2 (DMY / MDY numbers)
      final dmyMatch = dmyPattern.firstMatch(line);
      if (dmyMatch != null) {
        var part1 = int.tryParse(dmyMatch.group(1)!);
        var part2 = int.tryParse(dmyMatch.group(2)!);
        var year = int.tryParse(dmyMatch.group(3)!);

        if (year != null && year < 100) {
          year += 2000;
        }

        if (year != null && part1 != null && part2 != null) {
          // Standard heuristic: if part1 > 12, it MUST be day
          if (part1 > 12) {
            return DateTime(year, part2, part1);
          } else {
            // Default to day = part1, month = part2
            return DateTime(year, part2, part1);
          }
        }
      }

      // Try Pattern 3 (Day Month Year textual, including slashes like 05/Sep/2026)
      final dmyTextMatch = dmyTextPattern.firstMatch(line);
      if (dmyTextMatch != null) {
        final day = int.tryParse(dmyTextMatch.group(1)!);
        final month = _monthStringToNum(dmyTextMatch.group(2)!.toLowerCase());
        final year = int.tryParse(dmyTextMatch.group(3)!);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }

      // Try Pattern 4 (Month Day Year textual)
      final mdyTextMatch = mdyTextPattern.firstMatch(line);
      if (mdyTextMatch != null) {
        final month = _monthStringToNum(mdyTextMatch.group(1)!.toLowerCase());
        final day = int.tryParse(mdyTextMatch.group(2)!);
        final year = int.tryParse(mdyTextMatch.group(3)!);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  int? _monthStringToNum(String month) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    for (final entry in months.entries) {
      if (month.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Extracts the merchant name from the top lines of the receipt.
  String? extractMerchant(List<String> lines) {
    // Merchants typically occupy the first 1-6 lines
    final searchLines = lines.take(6).toList();
    String? bankCandidate;

    for (final line in searchLines) {
      final lower = line.toLowerCase();

      // Skip lines that match header noise
      final isNoise = _merchantIgnorePatterns.any((pattern) => lower.contains(pattern));
      if (isNoise) continue;

      // Skip lines that are just numbers, dates, or symbols
      if (RegExp(r'^[^a-zA-Z]*$').hasMatch(line)) continue;

      // Skip lines with common phone numbers, websites, or address locations
      if (lower.contains('@') ||
          lower.contains('.com') ||
          lower.contains('kathmandu') ||
          lower.contains('province') ||
          RegExp(r'\b(street|road|lane|marg|avenue)\b').hasMatch(lower) ||
          lower.contains('sector-') ||
          lower.contains('islamabad')) {
        continue;
      }

      // Clean line
      final cleaned = line.replaceAll(RegExp(r'[*#_~|=+]+'), '').trim();
      if (cleaned.length < 3 || cleaned.length > 40) continue;

      // If line is a bank name (e.g. Global IME Bank on a POS slip), save as candidate
      // but prefer a subsequent commercial merchant (e.g. MEGA MART PVT LTD)
      final isBank = _matchesAny(lower, ['bank', 'pos terminal', 'banking']);
      if (isBank) {
        bankCandidate ??= _capitalizeWords(cleaned);
        continue;
      }

      return _capitalizeWords(cleaned);
    }

    return bankCandidate;
  }

  /// Suggests a category keyword based on merchant name and receipt content.
  String? extractCategoryHint(String text, String? merchant) {
    final merchantLower = (merchant ?? '').toLowerCase();
    final combined = '$merchantLower $text'.toLowerCase();

    // 1. Check merchant name first (highest confidence)
    if (_matchesAny(merchantLower, [
      'restaurant',
      'cafe',
      'chaaye',
      'khana',
      'coffee',
      'bistro',
      'bar',
      'diner',
      'kitchen',
      'starbucks',
      'mcdonald',
      'burger',
      'pizza',
      'subway',
      'kfc',
      'taco',
      'bakery',
      'pub',
      'grill',
      'food',
      'roadhouse',
      'fire and ice',
    ])) {
      return 'food';
    }
    if (_matchesAny(merchantLower, [
      'grocery',
      'groceries',
      'market',
      'supermarket',
      'mart',
      'costco',
      'walmart',
      'aldi',
      'trader joe',
      'kroger',
      'bhatbhateni',
      'bhat-bhateni',
      'big mart',
      'mega mart',
      'foods',
      'bakery',
      'produce',
    ])) {
      return 'groceries';
    }
    if (_matchesAny(merchantLower, ['electric', 'water', 'sewerage', 'meter rent', 'charges', 'telecom', 'wifi', 'internet', 'mobile', 'broadband', 'utility', 'power'])) {
      return 'bills';
    }
    if (_matchesAny(merchantLower, ['fuel', 'gas', 'petrol', 'diesel', 'shell', 'bp', 'chevron', 'exxon', 'uber', 'lyft', 'taxi', 'parking', 'transit', 'station', 'metro'])) {
      return 'transport';
    }
    if (_matchesAny(merchantLower, ['pharmacy', 'chemist', 'drug', 'clinic', 'hospital', 'medical', 'dental', 'health', 'care', 'medicine'])) {
      return 'health';
    }
    if (_matchesAny(merchantLower, ['clothing', 'apparel', 'shoes', 'fashion', 'mall', 'retail', 'amazon', 'target', 'h&m', 'zara', 'nike'])) {
      return 'shopping';
    }
    if (_matchesAny(merchantLower, ['cinema', 'theater', 'theatre', 'movie', 'games', 'arcade', 'ticket', 'concert'])) {
      return 'entertainment';
    }

    // 2. Check full body text if merchant name didn't yield a match
    if (_matchesAny(combined, [
      'restaurant',
      'cafe',
      'chaaye',
      'khana',
      'coffee',
      'bistro',
      'bar',
      'diner',
      'kitchen',
      'pizza',
      'burger',
      'grill',
      'food',
      'bakery',
    ])) {
      return 'food';
    }
    if (_matchesAny(combined, [
      'grocery',
      'groceries',
      'market',
      'supermarket',
      'mart',
      'costco',
      'walmart',
      'aldi',
      'trader joe',
      'kroger',
      'bhatbhateni',
      'bhat-bhateni',
      'big mart',
      'mega mart',
      'foods',
      'produce',
    ])) {
      return 'groceries';
    }
    if (_matchesAny(combined, ['electric', 'water', 'sewerage', 'meter rent', 'charges', 'telecom', 'wifi', 'internet', 'mobile', 'broadband', 'utility', 'power'])) {
      return 'bills';
    }
    if (_matchesAny(combined, ['fuel', 'gas', 'petrol', 'diesel', 'shell', 'bp', 'chevron', 'exxon', 'uber', 'lyft', 'taxi', 'parking', 'transit', 'station', 'metro'])) {
      return 'transport';
    }
    if (_matchesAny(combined, ['pharmacy', 'chemist', 'drug', 'clinic', 'hospital', 'medical', 'dental', 'health', 'care', 'medicine'])) {
      return 'health';
    }
    if (_matchesAny(combined, ['clothing', 'apparel', 'shoes', 'fashion', 'mall', 'retail', 'amazon', 'target', 'h&m', 'zara', 'nike'])) {
      return 'shopping';
    }
    if (_matchesAny(combined, ['cinema', 'theater', 'theatre', 'movie', 'games', 'arcade', 'ticket', 'concert'])) {
      return 'entertainment';
    }

    return null;
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  String _capitalizeWords(String input) {
    return input
        .split(' ')
        .map((w) {
          if (w.isEmpty) return '';
          if (w.contains('-')) {
            return w.split('-').map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}').join('-');
          }
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
