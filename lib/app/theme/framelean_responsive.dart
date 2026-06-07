import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const frameLeanScreenDesignSize = Size(685, 640);

double frameLeanFontSizeResolver(num fontSize, ScreenUtil instance) {
  final scaledSize = fontSize * instance.scaleText;
  final baseSize = fontSize.toDouble();
  if (scaledSize > baseSize) {
    return baseSize;
  }
  return scaledSize;
}

extension FrameLeanResponsiveSize on num {
  double get flSp {
    try {
      return sp;
    } catch (_) {
      return toDouble();
    }
  }

  double get flR {
    try {
      return r;
    } catch (_) {
      return toDouble();
    }
  }
}
