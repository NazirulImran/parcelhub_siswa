import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- GLOBAL DATE FORMATTER ---
String formatTimestamp(dynamic value) {
  if (value == null) return '-';
  
  // Case 1: Value is a Firestore Timestamp
  if (value is Timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toDate());
  }
  
  // Case 2: Value is already a String (legacy data?)
  return value.toString();
}