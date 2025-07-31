import 'package:flutter/material.dart';

class TelemetryData {
  final String label;
  final String value;
  final Color color;
  final String unit;

  TelemetryData({
    required this.label,
    required this.value,
    required this.color,
    required this.unit,
  });

  TelemetryData copyWith({
    String? label,
    String? value,
    Color? color,
    String? unit,
  }) {
    return TelemetryData(
      label: label ?? this.label,
      value: value ?? this.value,
      color: color ?? this.color,
      unit: unit ?? this.unit,
    );
  }
}
