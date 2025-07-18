import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/flight/mini_map_item.dart';

class RealTimeInforSection extends StatefulWidget {
  const RealTimeInforSection({super.key});

  @override
  State<RealTimeInforSection> createState() => _RealTimeInforSectionState();
}

class _RealTimeInforSectionState extends State<RealTimeInforSection> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Row(children: [MiniMapItem()]));
  }
}
