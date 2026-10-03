class CurrencyFormatter {
  static String _currency = 'INR';

  static String get currency => _currency;

  static void setCurrency(String currency) {
    _currency = currency;
  }

  static String symbol([String? currency]) {
    switch (currency ?? _currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
      default:
        return '₹';
    }
  }

  static String format(double amount) {
    return '${symbol()}${amount.toStringAsFixed(2)}';
  }
}
