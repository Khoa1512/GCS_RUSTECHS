import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/data/constants/telemetry_constants.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'dart:async';

class TelemetrySelector {
  static void show({
    required BuildContext context,
    required int index,
    required List<TelemetryData> displayedTelemetry,
    required Function(int, TelemetryData) onTelemetrySelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TelemetrySelectorDialog(
          index: index,
          displayedTelemetry: displayedTelemetry,
          onTelemetrySelected: onTelemetrySelected,
        );
      },
    );
  }
}

class TelemetrySelectorDialog extends StatefulWidget {
  final int index;
  final List<TelemetryData> displayedTelemetry;
  final Function(int, TelemetryData) onTelemetrySelected;

  const TelemetrySelectorDialog({
    super.key,
    required this.index,
    required this.displayedTelemetry,
    required this.onTelemetrySelected,
  });

  @override
  State<TelemetrySelectorDialog> createState() =>
      _TelemetrySelectorDialogState();
}

class _TelemetrySelectorDialogState extends State<TelemetrySelectorDialog> {
  String searchQuery = '';
  List<TelemetryData> filteredTelemetry = [];
  final TelemetryService _telemetryService = TelemetryService();
  StreamSubscription? _telemetrySubscription;

  @override
  void initState() {
    super.initState();
    _updateFilteredTelemetry();

    // Listen to telemetry updates to refresh values in real-time
    _telemetrySubscription = _telemetryService.telemetryStream.listen((
      telemetryData,
    ) {
      if (mounted) {
        setState(() {
          _updateFilteredTelemetry();
        });
      }
    });
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  void _updateFilteredTelemetry() {
    // Get all available telemetry options with real-time data
    var allTelemetry = TelemetryConstants.allTelemetryData.map((item) {
      // Update values with real data if connected
      return TelemetryConstants.getUpdatedTelemetryItem(item);
    }).toList();

    if (searchQuery.isEmpty) {
      filteredTelemetry = allTelemetry;
    } else {
      filteredTelemetry = allTelemetry
          .where(
            (telemetry) => telemetry.label.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
  }

  void _filterTelemetry(String query) {
    setState(() {
      searchQuery = query;
      _updateFilteredTelemetry();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade800, Colors.grey.shade900],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTelemetryGrid(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.8),
            AppColors.primaryColor.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select Telemetry Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        onChanged: _filterTelemetry,
        decoration: InputDecoration(
          hintText: 'Search telemetry...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
          filled: true,
          fillColor: Colors.grey.shade700,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildTelemetryGrid() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filteredTelemetry.length,
          itemBuilder: (context, i) {
            final telemetry = filteredTelemetry[i];
            final isCurrentlyDisplayed = widget.displayedTelemetry.any(
              (t) => t.label == telemetry.label,
            );

            return _buildTelemetryCard(telemetry, isCurrentlyDisplayed);
          },
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(
    TelemetryData telemetry,
    bool isCurrentlyDisplayed,
  ) {
    return GestureDetector(
      onTap: () {
        widget.onTelemetrySelected(widget.index, telemetry);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCurrentlyDisplayed
              ? telemetry.color.withValues(alpha: 0.2)
              : Colors.grey.shade700.withValues(alpha: 0.5),
          border: Border.all(
            color: isCurrentlyDisplayed
                ? telemetry.color
                : telemetry.color.withValues(alpha: 0.3),
            width: isCurrentlyDisplayed ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              telemetry.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  telemetry.value,
                  style: TextStyle(
                    color: telemetry.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (telemetry.unit.isNotEmpty) ...[
                  SizedBox(width: 4),
                  Text(
                    telemetry.unit,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Click on any telemetry data to replace the selected item',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Found ${filteredTelemetry.length} telemetry parameters',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
