import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// typedef لتوافق مع الكود القديم الذي يستخدم FaFaIcon
/// في font_awesome_flutter 11+ أصبح الاسم الصحيح هو FaIcon
typedef FaFaIcon = FaIcon;

/// دالة مساعدة لتحويل أي نوع أيقونة إلى IconData
/// في font_awesome_flutter 11+، أصبحت الأيقونات من نوع FaIconData
/// وليس IconData، وهذه الدالة تحولها للتوافق مع مكونات Icon القديمة.
IconData toIconData(dynamic icon) {
  if (icon is FaIconData) return icon.data;
  return icon as IconData;
}

/// دالة لعرض أيقونة بشكل صحيح حسب نوعها:
/// - أيقونات Font Awesome → FaIcon
/// - أيقونات Material → Icon
Widget compatIcon(dynamic icon, {Color? color, double? size}) {
  if (icon is FaIconData) {
    return FaIcon(icon, color: color, size: size);
  }
  return Icon(icon as IconData, color: color, size: size);
}