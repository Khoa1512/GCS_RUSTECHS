import 'package:flutter/material.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_state.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_handlers.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_edit_handlers.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_mission_ops.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_mission_stats.dart';
import 'package:skylink/presentation/view/main/map/controllers/map_page_ui_helpers.dart';
import 'package:skylink/presentation/widget/common/app_bar.dart';
import 'package:skylink/presentation/widget/map/components/floating_mission_actions.dart';
import 'package:skylink/presentation/widget/map/components/polygon_drawing_controls.dart';
import 'package:skylink/presentation/widget/map/components/bounding_box_drawing_controls.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';
import 'package:skylink/presentation/widget/map/components/waypoint_edit_panel.dart';
import 'package:skylink/presentation/widget/map/components/batch_edit_panel.dart';
import 'package:skylink/presentation/widget/map/components/mission_sidebar.dart';
import 'package:skylink/presentation/widget/flight/drone_map_widget.dart';
import 'package:skylink/presentation/widget/map/components/mission_tutorial_overlay.dart';
import 'package:skylink/presentation/widget/camera/resizable_camera_overlay.dart';
import 'package:skylink/presentation/widget/flight/pdf.dart';
import 'package:skylink/presentation/widget/gimbal/gimbal_control_compact.dart';
import 'package:skylink/services/telemetry_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with
        MapPageHandlers,
        MapPageEditHandlers,
        MapPageMissionOps,
        MapPageUIHelpers {
  // Centralized state
  @override
  final MapPageState state = MapPageState();

  // Expose setState as updateState for mixins
  @override
  void Function(void Function()) get updateState => setState;

  @override
  void initState() {
    super.initState();
    state.initialize();
    setupMavlinkListener();
    setupGpsListener();
    setupConnectionListener();
    state.ensureLayerLinksForWaypoints();

    // Force initial map refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  void calculateMissionStats() {
    final stats = MissionStatsCalculator.calculate(state.routePoints);
    setState(() {
      state.totalDistance = stats.totalDistance;
      state.estimatedTime = stats.estimatedTime;
      state.batteryUsage = stats.batteryUsage;
    });
  }

  void _handleSettingsChanged(String setting) {
    switch (setting) {
      case 'camera':
        setState(() {
          state.showCameraView = !state.showCameraView;
        });
        break;
      case 'mission':
        setState(() {
          state.showMissionSidebar = !state.showMissionSidebar;
        });
        break;
      case 'mission_planning':
        setState(() {
          state.isMissionPlanningMode = !state.isMissionPlanningMode;
          state.showMissionSidebar = state.isMissionPlanningMode;
        });
        break;
      case 'pdf':
        setState(() {
          state.showPdfCompass = !state.showPdfCompass;
        });
        break;
      case 'gimbal_control':
        setState(() {
          state.showGimbalControl = !state.showGimbalControl;
          // Tự động bật camera nếu chưa bật
          if (state.showGimbalControl && !state.showCameraView) {
            state.showCameraView = true;
          }
        });
        break;
    }
  }

  void _toggleCameraSwap() {
    setState(() {
      state.isCameraSwapped = !state.isCameraSwapped;
    });
  }

  Widget _buildCurrentMap() {
    if (state.isMissionPlanningMode) {
      return MainMapSimple(
        key: state.mapKey,
        mapController: state.mapController,
        mapType: state.selectedMapType!,
        routePoints: state.routePoints,
        onTap: onMapTap,
        onWaypointDrag: onWaypointDrag,
        onWaypointTap: onWaypointTap,
        onWaypointDragStart: onWaypointDragStart,
        onWaypointDragEnd: onWaypointDragEnd,
        onPointerHover: onPointerHover,
        isConfigValid: true,
        homePoint: state.homePoint,
        waypointLayerLinks: state.waypointLayerLinks,
        selectedWaypoint: state.selectedWaypoint,
        selectedWaypointIds: state.selectedWaypointIds,
        isDrawingBoundingBox: state.isDrawingBoundingBox,
        boundingBoxStart: state.boundingBoxStart,
        boundingBoxEnd: state.boundingBoxEnd,
        isDrawingPolygon: state.isDrawingPolygon,
        polygonPoints: state.polygonPoints,
      );
    } else {
      return const DroneMapWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QGCAppBar(onSettingsChanged: _handleSettingsChanged),
      body: Row(
        children: [
          // Map Section
          Expanded(
            flex: state.showMissionSidebar ? 7 : 10,
            child: Stack(
              children: [
                // Main map
                _buildCurrentMap(),

                // Mission Planning UI
                if (state.isMissionPlanningMode) ...[
                  // Floating actions
                  _buildFloatingActions(),

                  // Template selection indicator
                  if (state.isSelectingOrbitCenter)
                    _buildTemplateSelectionIndicator(),

                  // Edit panels
                  if (state.isEditMode && state.selectedWaypoint != null)
                    _buildWaypointEditPanel(),

                  if (state.isBatchEditMode) _buildBatchEditPanel(),

                  // Tutorial overlay
                  if (state.showTutorial)
                    MissionTutorialOverlay(
                      onClose: () => setState(() => state.showTutorial = false),
                      targetKey: state.helpButtonKey,
                    ),
                ],

                // Camera and PFD overlays (non-planning mode)
                if (!state.isMissionPlanningMode) ...[
                  ResizableCameraOverlay(
                    isVisible: state.showCameraView,
                    onClose: () => setState(() => state.showCameraView = false),
                    isSwapped: state.isCameraSwapped,
                    onSwap: _toggleCameraSwap,
                    mapWidget: _buildCurrentMap(),
                    onSizeChanged: (width) {
                      setState(() {
                        state.cameraOverlayWidth = width;
                      });
                    },
                  ),
                  if (state.showPdfCompass) _buildPdfCompass(),

                  // Gimbal Control - Động theo camera width
                  if (state.showGimbalControl &&
                      state.showCameraView &&
                      !state.isCameraSwapped)
                    Positioned(
                      bottom: 0,
                      left:
                          4 +
                          state.cameraOverlayWidth +
                          20, // 16px (camera left) + camera width + 20px spacing
                      child: GimbalControlCompact(
                        onClose: () {
                          setState(() {
                            state.showGimbalControl = false;
                          });
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Mission Sidebar
          if (state.showMissionSidebar) _buildMissionSidebar(),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show drawing controls OR mission actions (not both)
          if (state.isDrawingPolygon)
            // Polygon drawing controls replace mission actions
            PolygonDrawingControls(
              pointCount: state.polygonPoints.length,
              onUndo: state.polygonPoints.isNotEmpty
                  ? undoLastPolygonPoint
                  : null,
              onFinish: finishPolygonDrawing,
              onCancel: cancelPolygonDrawing,
              canFinish: state.polygonPoints.length >= 3,
            )
          else if (state.isDrawingBoundingBox)
            // Bounding box drawing control replaces mission actions
            BoundingBoxDrawingControls(onCancel: cancelBoundingBoxDrawing)
          else
            // Normal mission actions (when not drawing)
            FloatingMissionActions(
              onAddWaypoint: handleAddWaypoint,
              onOrbitTemplate: handleOrbitTemplate,
              onSurveyTemplate: handleBoundingBoxSurvey,
              onPolygonSurvey: handlePolygonSurvey,
              onUndo: handleUndo,
              onRedo: handleRedo,
              onClearMission: handleClearMission,
              canUndo: state.undoRedoManager.canUndo,
              canRedo: state.undoRedoManager.canRedo,
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelectionIndicator() {
    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - 50,
      left: state.showMissionSidebar
          ? MediaQuery.of(context).size.width * 0.35 - 120
          : MediaQuery.of(context).size.width / 2 - 120,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Nhấn chọn tâm bay vòng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointEditPanel() {
    return Positioned(
      top: 16,
      right: state.showMissionSidebar ? null : 16,
      left: state.showMissionSidebar ? 16 : null,
      width: 320,
      child: WaypointEditPanel(
        waypoint: state.selectedWaypoint!,
        onSave: handleSaveWaypoint,
        onCancel: handleCancelEdit,
        onDelete: handleDeleteWaypoint,
        onConvertType: handleConvertWaypoint,
        isSimpleMode: state.isSimpleMode,
        onModeToggle: handleModeToggle,
        onPrevWaypoint: handlePrevWaypoint,
        onNextWaypoint: handleNextWaypoint,
        totalWaypoints: state.routePoints.length,
        currentIndex: state.getCurrentWaypointIndex(),
      ),
    );
  }

  Widget _buildBatchEditPanel() {
    return Positioned(
      top: 16,
      right: state.showMissionSidebar ? null : 16,
      left: state.showMissionSidebar ? 16 : null,
      child: BatchEditPanel(
        selectedWaypoints: state.routePoints
            .where((wp) => state.selectedWaypointIds.contains(wp.id))
            .toList(),
        onCancel: handleBatchEditCancel,
        onSave: handleBatchEditApply,
        onDelete: handleBatchDelete,
        isSimpleMode: state.isSimpleMode,
        onModeToggle: (isSimple) =>
            setState(() => state.isSimpleMode = isSimple),
      ),
    );
  }

  Widget _buildPdfCompass() {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: StreamBuilder<Map<String, double>>(
          stream: TelemetryService().telemetryStream,
          builder: (context, snapshot) {
            final telemetry = snapshot.data ?? {};
            final isConnected = TelemetryService().isConnected;
            final hasGps = TelemetryService().hasValidGpsFix;

            return SolidFlightDisplay(
              roll: telemetry['roll'] ?? 0.0,
              pitch: telemetry['pitch'] ?? 0.0,
              heading: telemetry['compass_heading'] ?? 0.0,
              altitude: telemetry['altitude_rel'] ?? 0.0,
              airspeed: telemetry['groundspeed'] ?? 0.0,
              batteryPercent: telemetry['battery'] ?? 0.0,
              voltageBattery: telemetry['voltageBattery'] ?? 0.0,
              flightMode: TelemetryService().currentMode,
              isArmed: TelemetryService().isArmed,
              isConnected: isConnected,
              hasGpsLock: hasGps,
              linkQuality: isConnected ? 100 : 0,
              satellites: (telemetry['satellites'] ?? 0.0).toInt(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMissionSidebar() {
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          border: Border(
            left: BorderSide(
              color: Colors.teal.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Stack(
          children: [
            MissionSidebar(
              routePoints: state.routePoints,
              totalDistance: state.totalDistance,
              estimatedTime: state.estimatedTime,
              batteryUsage: state.batteryUsage,
              riskLevel: 'Low',
              onReadMission: handleReadMission,
              onSendMission: state.routePoints.isNotEmpty
                  ? () => handleSendConfigs(state.routePoints)
                  : null,
              onImportMission: handleImport,
              onReorderWaypoints: handleReorderWaypoints,
              onEditWaypoint: handleEditWaypoint,
              onDeleteWaypoint: handleDeleteWaypointFromSidebar,
              isConnected: TelemetryService().mavlinkAPI.isConnected,
            ),
            _buildSidebarCollapseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCollapseButton() {
    return Positioned(
      right: 0,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(16),
          ),
          onTap: () => setState(() => state.showMissionSidebar = false),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withValues(alpha: 0.1),
                  Colors.teal.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.teal.shade400,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
