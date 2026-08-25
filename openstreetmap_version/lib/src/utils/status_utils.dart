// lib/src/utils/status_utils.dart

import 'package:flutter/material.dart';

Color getStatusColor(String? status) {
  switch (status) {
    case 'online':
      return Colors.green;
    case 'offline':
      return Colors.red;
    case 'unknown':
      return Colors.grey;
    default:
      return Colors.black;
  }
}

String getStatusText(int index) {
  switch (index) {
    case 1:
      return 'online';
    case 2:
      return 'offline';
    case 3:
      return 'unknown';
    default:
      return 'all';
  }
}