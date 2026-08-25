// lib/src/utils/cupertino_pickers.dart
// iOS 風格（Cupertino 滾輪）的日期 / 時間選擇器 helper。
// 以底部彈出（CupertinoModalPopup）呈現滾輪，取代 Material 的 showDatePicker / showTimePicker。
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// iOS 風格日期滾輪選擇器，回傳選取的日期（取消回傳 null）。
Future<DateTime?> showCupertinoDatePickerSheet(BuildContext context, {required DateTime initialDate, required DateTime firstDate, required DateTime lastDate}) {
  DateTime selected = initialDate;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => Container(
      height: 260,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 20), child: const Text('Done'), onPressed: () => Navigator.of(context).pop(selected)),
            ),
            Expanded(
              child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: selected, minimumDate: firstDate, maximumDate: lastDate, onDateTimeChanged: (value) => selected = value),
            ),
          ],
        ),
      ),
    ),
  );
}

/// iOS 風格時間滾輪選擇器，回傳選取的時間（取消回傳 null）。
Future<TimeOfDay?> showCupertinoTimePickerSheet(BuildContext context, {required TimeOfDay initialTime}) {
  TimeOfDay selected = initialTime;
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (context) => Container(
      height: 260,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 20), child: const Text('Done'), onPressed: () => Navigator.of(context).pop(selected)),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2000, 1, 1, selected.hour, selected.minute),
                onDateTimeChanged: (value) => selected = TimeOfDay(hour: value.hour, minute: value.minute),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
