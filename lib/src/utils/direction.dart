import 'package:flutter/widgets.dart';

/// True when the enclosing text direction is right-to-left.
bool isRtlOf(BuildContext context) => Directionality.of(context) == TextDirection.rtl;
