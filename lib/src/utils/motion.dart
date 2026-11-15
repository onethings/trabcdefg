import 'package:flutter/widgets.dart';

/// True when the OS asks apps to reduce motion; UI animations should collapse.
bool reduceMotionOf(BuildContext context) => MediaQuery.disableAnimationsOf(context);
