import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- GLOBAL DATE FORMATTER ---
String formatTimestamp(dynamic value) {
  if (value == null) return '-';
  
  // Case 1: Value is a Firestore Timestamp
  if (value is Timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toDate());
  }
  
  // Case 2: Value is a Dart DateTime
  if (value is DateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }
  
  // Case 3: Value is a String
  if (value is String) {
    // Attempt to parse ISO 8601 strings (e.g. "2024-01-07 18:22:09.436")
    DateTime? parsedDate = DateTime.tryParse(value);
    if (parsedDate != null) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);
    }
    // If parsing fails, it might already be formatted or invalid, so return as is.
  }
  
  return value.toString();
}