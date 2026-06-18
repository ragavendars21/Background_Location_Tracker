import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _full  = DateFormat('dd MMM yyyy, HH:mm:ss');
  static final _short = DateFormat('HH:mm  dd MMM');

  static String toIso8601(DateTime dateTime) =>
      dateTime.toUtc().toIso8601String();

  static DateTime fromIso8601(String isoString) =>
      DateTime.parse(isoString).toLocal();

  static String timestampToDisplay(String isoString) =>
      _full.format(fromIso8601(isoString));

  // Compact form for list tiles: "14:32  14 Jun"
  static String timestampToShort(String isoString) =>
      _short.format(fromIso8601(isoString));
}
