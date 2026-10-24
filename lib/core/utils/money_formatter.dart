import 'package:intl/intl.dart';

final _naira = NumberFormat('#,##0', 'en_NG');

/// ₦185,000 rather than ₦185000.
String formatNaira(num amount) => '₦${_naira.format(amount)}';
