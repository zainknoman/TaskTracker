import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import 'tokens.dart';

/// Parses a `#rrggbb` project/member color; falls back to the brand primary.
Color parseHex(String? hex, [Color fallback = Brand.primary]) {
  if (hex == null) return fallback;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Mirrors `STATUS_META` in js/utils.js (label, dot, color).
class StatusMeta {
  final String label;
  final Color dot;
  final Color color;
  const StatusMeta(this.label, this.dot, this.color);
}

const statusMeta = {
  'pending': StatusMeta('Pending', Color(0xFFFBBF24), Color(0xFFD97706)),
  'inprogress': StatusMeta('In Progress', Color(0xFF60A5FA), Color(0xFF2563EB)),
  'completed': StatusMeta('Completed', Color(0xFF34D399), Color(0xFF059669)),
  'blocked': StatusMeta('Blocked', Color(0xFFF87171), Color(0xFFDC2626)),
};

const taskStatusOptions = [
  ('pending', 'Pending'),
  ('inprogress', 'In Progress'),
  ('completed', 'Completed'),
  ('blocked', 'Blocked'),
];

const priorityOptions = [
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
  ('critical', 'Critical'),
];

String priorityLabel(String p) =>
    p.isEmpty ? p : p[0].toUpperCase() + p.substring(1);

String fmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());

bool isOverdue(Task t) =>
    t.dueDate != null &&
    t.status != 'completed' &&
    t.dueDate!.isBefore(DateTime.now());

/// Whole days from today (negative = overdue), like `daysUntil` on the web.
int daysUntil(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(d.year, d.month, d.day);
  return due.difference(today).inDays;
}

String initials(String? name) {
  final n = (name ?? '?').trim();
  if (n.isEmpty) return '?';
  return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
}
