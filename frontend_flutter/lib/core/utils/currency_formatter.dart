import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _nairaFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  static final NumberFormat _nairaWithDecimals = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  static String formatNaira(num amount, {bool showDecimals = false}) {
    return showDecimals ? _nairaWithDecimals.format(amount) : _nairaFormat.format(amount);
  }

  static String format(num amount, {bool showDecimals = false}) {
    return formatNaira(amount, showDecimals: showDecimals);
  }
}
