import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _color() {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'inprogress':
        return Colors.blue;
      case 'blocked':
        return Colors.red;
      case 'active':
        return Colors.green;
      case 'onhold':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      case 'planning':
        return Colors.purple;
      default: // pending
        return Colors.orange;
    }
  }

  String _label() => status == 'inprogress' ? 'In Progress' : status.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
