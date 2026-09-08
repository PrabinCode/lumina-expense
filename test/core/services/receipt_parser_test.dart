import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/services/receipt_parser_service.dart';

void main() {
  late ReceiptParserService parser;

  setUp(() {
    parser = ReceiptParserService();
  });

  group('ReceiptParserService - Amount Extraction', () {
    test('extracts Total when explicit TOTAL keyword is present', () {
      const receipt = '''
        WALMART SUPERCENTER
        Store #1234
        Date: 09/07/2026
        
        MILK 1GAL        3.49
        BREAD WHEAT      2.29
        EGGS DOZEN       4.19
        
        SUBTOTAL         9.97
        TAX              0.80
        TOTAL           10.77
        CASH TENDERED   20.00
        CHANGE DUE       9.23
        THANK YOU FOR SHOPPING!
      ''';

      final result = parser.parse(receipt);
      expect(result.amount, equals(10.77));
      expect(result.merchantName, contains('Walmart'));
      expect(result.suggestedCategoryKeyword, equals('groceries'));
    });

    test('extracts Grand Total with currency symbol and thousands separator', () {
      const receipt = '''
        BEST BUY ELECTRONICS
        100 Tech Blvd
        
        Laptop Computer   1,199.99
        Wireless Mouse       49.99
        
        Subtotal          1,249.98
        Sales Tax            99.99
        GRAND TOTAL      \$1,349.97
      ''';

      final result = parser.parse(receipt);
      expect(result.amount, equals(1349.97));
      expect(result.merchantName, contains('Best Buy'));
    });

    test('handles two-line total label and value', () {
      const receipt = '''
        STARBUCKS COFFEE
        123 Main Street
        
        Caffe Latte
        Croissant
        
        TOTAL AMOUNT:
        \$8.75
      ''';

      final result = parser.parse(receipt);
      expect(result.amount, equals(8.75));
      expect(result.merchantName, contains('Starbucks'));
      expect(result.suggestedCategoryKeyword, equals('food'));
    });

    test('handles comma decimal separator', () {
      const receipt = '''
        CAFE DE PARIS
        24 Rue de Rivoli
        
        Espresso       2,80
        Croissant      1,90
        TOTAL          4,70
      ''';

      final result = parser.parse(receipt);
      expect(result.amount, equals(4.70));
    });
  });

  group('ReceiptParserService - Date Extraction', () {
    test('extracts ISO date format (YYYY-MM-DD)', () {
      const receipt = '''
        SHELL SERVICE STATION
        Date: 2026-09-07
        Time: 14:32
        Pump 4 Regular  45.00
        TOTAL           45.00
      ''';

      final result = parser.parse(receipt);
      expect(result.date, equals(DateTime(2026, 9, 7)));
      expect(result.suggestedCategoryKeyword, equals('transport'));
    });

    test('extracts slash date format (DD/MM/YYYY or MM/DD/YYYY)', () {
      const receipt = '''
        PHARMACY CARE
        Date: 15/04/2026
        Vitamin C       12.50
        TOTAL           12.50
      ''';

      final result = parser.parse(receipt);
      expect(result.date, equals(DateTime(2026, 4, 15)));
      expect(result.suggestedCategoryKeyword, equals('health'));
    });

    test('extracts textual date format (DD Mon YYYY)', () {
      const receipt = '''
        TARGET STORES
        07 Sep 2026 18:22
        Items: 3
        TOTAL: 32.40
      ''';

      final result = parser.parse(receipt);
      expect(result.date, equals(DateTime(2026, 9, 7)));
      expect(result.merchantName, contains('Target'));
    });
  });

  group('ReceiptParserService - Merchant & Category Detection', () {
    test('filters out invoice noise lines and gets clean merchant name', () {
      const receipt = '''
        TAX INVOICE
        CUSTOMER COPY
        REG NO: 987654321
        COSTCO WHOLESALE
        Tel: 555-0199
        Total: 84.20
      ''';

      final result = parser.parse(receipt);
      expect(result.merchantName, equals('Costco Wholesale'));
      expect(result.suggestedCategoryKeyword, equals('groceries'));
    });

    test('handles empty or blank text gracefully', () {
      final result = parser.parse('');
      expect(result.amount, isNull);
      expect(result.date, isNull);
      expect(result.merchantName, isNull);
    });
  });

  group('ReceiptParserService - Real-world Nepali Bills', () {
    test('parses Global IME Bank POS slip (amount NPR 821.00, date 05/09/2026)', () {
      const posReceipt = '''
        Global IME Bank
        ग्लोबल आइएमई बैंक लि.
        MEGA MART PVT LTD
        02, GOLFUTAR, KATHMANDU, BAGMATI
        PROVINCE

        DATE: 05/09/2026   TIME: 19:57:10
        MID: 100300030003314   TID: 10002812
        RRN: 624819193140   TRACE NO: 010840
        BATCH NUMBER:   348
        INVOICE NUMBER:   009081

        SALE

        AMOUNT                 NPR 821.00

        APPROVED
        CARDHOLDER PIN VERIFIED
        CHANDRA SHRESTHA/PRABIN
        Card No: 459521XXXXXX1804
        Card Type:
        AID: A0000000031010
        APPROVAL CODE: 010840
        CHIP 00 A0000000031010 8080048000
        6800 420300 40 B9FFBD60E5E4B374
        (THANK YOU FOR USING OUR SERVICE)
        ** CUSTOMER COPY **
      ''';

      final result = parser.parse(posReceipt);
      expect(result.amount, equals(821.00));
      expect(result.date, equals(DateTime(2026, 9, 5)));
    });

    test('parses Global IME Bank POS slip when columnar OCR separates label and value', () {
      // When OCR separates left and right columns into distinct blocks:
      const columnarPosReceipt = '''
        Global IME Bank
        MEGA MART PVT LTD
        DATE: 05/09/2026
        MID: 100300030003314
        RRN: 624819193140
        BATCH NUMBER:
        INVOICE NUMBER:
        SALE
        AMOUNT
        APPROVED
        TIME: 19:57:10
        TID: 10002812
        TRACE NO: 010840
        348
        009081
        NPR 821.00
      ''';

      final result = parser.parse(columnarPosReceipt);
      expect(result.amount, equals(821.00));
      expect(result.date, equals(DateTime(2026, 9, 5)));
    });

    test('parses Big Mart invoice (Grand Total 821.00, GrossAmt 821.00, date 05/Sep/2026)', () {
      const bigMartReceipt = '''
        BIG MART
        ** MEGA MART PVT. LTD. **
        Hattigauda, Kathmandu
        www.bigmart.com.np
        VAT NO. : 303408110
        ** Abbreviated Tax Invoice **

        Bill Date : 05/Sep/2026
        Bill No: 58/CM/00026408/Sep/26
        Customer: Mr. Prabin Chandra Shrestha
        CRM No.: BM_IT_3708
        PANNO.:

        Particulars   Qty   Rate   Amount
        1). GYAN CHHAKI AATA 2KG.   1.00 195.00   195.00
        HSCODE:
        2). HALDIRAM'S MOONG DAAL 180.   2.00 150.00   300.00
        HSCODE:
        3). HALDIRAM'S KHATTA MEETHA ,   1.00 126.00   126.00
        HSCODE:21.06
        4). BIKANO ALL TIME MIXTURE 1,   1.00 100.00   100.00
        HSCODE:
        5). BIKANO ALL IN ONE 130G,   1.00 100.00   100.00
        HSCODE:

        GrossAmt :                     821.00
        Saving in this bill:             0.00
        Grand Total :                  821.00
        Rs. Eight Hundred Twenty-One Only
        Global IME Bank                821.00
        Customer Paid:  821.00Refund:    0.00
      ''';

      final result = parser.parse(bigMartReceipt);
      expect(result.amount, equals(821.00));
      expect(result.date, equals(DateTime(2026, 9, 5)));
      expect(result.merchantName, contains('Big Mart'));
    });

    test('parses Big Mart invoice when columnar OCR separates totals', () {
      const columnarBigMart = '''
        BIG MART
        ** MEGA MART PVT. LTD. **
        Hattigauda, Kathmandu
        VAT NO. : 303408110
        Bill Date : 05/Sep/2026
        Bill No: 58/CM/00026408/Sep/26
        Customer: Mr. Prabin Chandra Shrestha
        CRM No.: BM_IT_3708
        GrossAmt :
        Saving in this bill:
        Grand Total :
        Rs. Eight Hundred Twenty-One Only
        Global IME Bank
        Customer Paid:
        821.00
        0.00
        821.00
        821.00
      ''';

      final result = parser.parse(columnarBigMart);
      expect(result.amount, equals(821.00));
      expect(result.date, equals(DateTime(2026, 9, 5)));
      expect(result.merchantName, contains('Big Mart'));
    });

    test('parses Bhat-Bhateni Super Market (ignores Total Qty: 4, extracts Net Amount 850.00, date 16/09/2075)', () {
      const bhatBhateniReceipt = '''
        BHAT-BHATENI SUPER MARKET
        KATHMANDU, NEPAL
        VAT No: 300142084
        ABBREVIATED TAX INVOICE

        Bill # : SI594960-MMX-075/76
        Transaction Date : 16/09/2075
        Invoice Date     : 16/09/2075
        Payment Mode : Cash

        Sn Particulars    Qty    Rate    Amount
        1  ARNA LIGHT       3   225.00   675.00
        2  ARNA PREMIU      1   175.00   175.00

        Net Amount        :     850.00

        Tender            :    1000.00
        Change            :     150.00

        Total Qty         :          4

        WELCOME TO GREAT SHOPPING EXPERIENCE
        BRANCH- MAHARAJGUNJ
      ''';

      final result = parser.parse(bhatBhateniReceipt);
      expect(result.amount, equals(850.00));
      expect(result.date, equals(DateTime(2075, 9, 16)));
      expect(result.merchantName, contains('Bhat-Bhateni'));
      expect(result.suggestedCategoryKeyword, equals('groceries'));
    });

    test('parses Chaaye Khana bill (Payable 1,452, date 14-February-2025, ignores subtotal Total: 2 1,320)', () {
      const chaayeKhanaReceipt = '''
        chaaye khana
        Sector-2, DHA, Islamabad.
        Phone No.    051-2311931
        G.S.T./NTN No. /4585147-3
        Provisional Bill
        Inv # : 000038/14/02/2025 Cashier : Evening
        Date : 14-February-2025  Time : 08:56:36 PM
        Table No. : ( 20 )      Server : JIBRAN

        # Description       Price  QTY  Total
        1 APPLE PIE          625    1    625
        2 CARROT CAKE SLICE  695    1    695

        Total :                     2  1,320

        Total Amount                   1,320
        5.00 % Sale Tax                   66
        5 % Service Charge                66
        Payable                        1,452
        Received                           0

        Balance Amount                (1,452)
      ''';

      final result = parser.parse(chaayeKhanaReceipt);
      expect(result.amount, equals(1452.00));
      expect(result.date, equals(DateTime(2025, 2, 14)));
      expect(result.merchantName, contains('Chaaye Khana'));
      expect(result.suggestedCategoryKeyword, equals('food'));
    });

    test('parses Fire And Ice Pvt Ltd tax invoice (picks final Total 1,044.12 over subtotal 840.00, date 2019/03/10)', () {
      const fireAndIceReceipt = '''
        TAX INVOICE
        Fire And Ice Pvt Ltd
        Thamel Ph: 014-250210
        TPIN 300046054

        Invoice No.: 32541
        Buyer's Name:Cash Sales
        Mode of Payment:CASH
        Table/Loc: 12/2
        Date: 2019/03/10

        SNo  Particular         Qty    Rate    Amount
        1    Coke Bott            1   115.00   115.00
        2    Hawaiiana            1   725.00   725.00

        Words: One Thousand, Forty-four Rupees And One Two Paisa Only.

        Total:         840.00
        Dis:              .00
        SC[10%]:        84.00
        Taxable Amt:   924.00
        VAT [13%]:     120.12

        Total:       1,044.12
      ''';

      final result = parser.parse(fireAndIceReceipt);
      expect(result.amount, equals(1044.12));
      expect(result.date, equals(DateTime(2019, 3, 10)));
      expect(result.merchantName, contains('Fire And Ice'));
      expect(result.suggestedCategoryKeyword, equals('food'));
    });

    test('parses Utility water/electricity bill (NET PAYABLE: 24468 without decimal places)', () {
      const utilityReceipt = '''
        CURRENT/FAULT    : 5570
        PREVIOUS         : 4603
        UNITS            : 967
        UNITS BILLED     : 967
        ADDITIONAL UNITS : 0
        WATER CHARGES    : 24175
        SEWERAGE CHARGES : 0
        METER RENT       : 293
        SUNDRY           : 0
        ADDITIONAL CHARGES : 0
        ARREARS/CREDIT   : 0 / 0
        TOTAL            : 24468
        NET PAYABLE      : 24468

        AMOUNT IN WORDS
        Rupees Two Four Four Six Eight Only
      ''';

      final result = parser.parse(utilityReceipt);
      expect(result.amount, equals(24468.00));
      expect(result.suggestedCategoryKeyword, equals('bills'));
    });

    test('parses Roadhouse Cafe bill (ignores Total Items: 2, extracts GRAND TOTAL 1665.62, date Sept 13 2020)', () {
      const roadhouseReceipt = '''
        Roadhouse Cafe Pvt. Ltd.
        Bhatbhateni
        Kathmandu, Nepal
        PAN NO. : 500029899
        TAX INVOICE
        ORIGINAL COPY

        Bill No # 1419
        Sunday, September 13, 2020 5:37 PM
        Employee : Mr. bhatta
        No of Guests :

        Item           Qty Rate     Amount
        Mexicana Pizza V  1 670.00  670.00
        The Greek Pizza   1 670.00  670.00

        Total Items     : 2

        SubTotal       : 1340.00
        Service Charge 10% : 134.00
        VAT 13%        : 191.62

        GRAND TOTAL    : 1665.62

        Telephone : +977 01 4426587
        Thank you for your visit.
      ''';

      final result = parser.parse(roadhouseReceipt);
      expect(result.amount, equals(1665.62));
      expect(result.date, equals(DateTime(2020, 9, 13)));
      expect(result.merchantName, contains('Roadhouse Cafe'));
      expect(result.suggestedCategoryKeyword, equals('food'));
    });
  });
}
