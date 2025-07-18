import 'package:flutter/material.dart';

class MiniMapItem extends StatefulWidget {
  const MiniMapItem({super.key});

  @override
  State<MiniMapItem> createState() => _MiniMapItemState();
}

class _MiniMapItemState extends State<MiniMapItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade700,
            ),
            child: Center(
              child: Text(
                'Map View',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
