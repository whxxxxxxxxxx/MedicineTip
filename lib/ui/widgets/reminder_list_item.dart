import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import 'package:intl/intl.dart';

class ReminderListItem extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final Function(bool) onToggleActive;
  final DateFormat _timeFormat = DateFormat('HH:mm');

  ReminderListItem({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: reminder.scheduledTimes.map((time) {
        return ListTile(
          title: Text(reminder.medicineName),
          subtitle: Text(
            '${_timeFormat.format(time)} 提醒',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          leading: Icon(
            Icons.medication,
            color: reminder.isActive ? Theme.of(context).primaryColor : Colors.grey,
          ),
          trailing: Switch(
            value: reminder.isActive,
            onChanged: onToggleActive,
          ),
          onTap: onTap,
        );
      }).toList(),
    );
  }
}