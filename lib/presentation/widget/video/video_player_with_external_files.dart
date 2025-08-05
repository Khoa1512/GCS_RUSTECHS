import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skylink/data/models/video_record.dart';
import 'package:skylink/core/constant/app_color.dart';

class CustomCupertinoControls extends StatefulWidget {
  final Color backgroundColor;
  final Color iconColor;
  final Function(BuildContext) onSpeedTap;

  const CustomCupertinoControls({
    super.key,
    required this.backgroundColor,
    required this.iconColor,
    required this.onSpeedTap,
  });

  @override
  State<CustomCupertinoControls> createState() =>
      _CustomCupertinoControlsState();
}

class _CustomCupertinoControlsState extends State<CustomCupertinoControls> {
  bool _hideStuff = true;
  late Timer _hideTimer;
  final Duration _controlsTimeOut = const Duration(seconds: 5);

  ChewieController get chewieController => ChewieController.of(context);
  VideoPlayerController get controller =>
      chewieController.videoPlayerController;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer = Timer(_controlsTimeOut, () {
      if (mounted) {
        setState(() {
          _hideStuff = true;
        });
      }
    });
  }

  void _showControls() {
    if (_hideStuff) {
      setState(() {
        _hideStuff = false;
      });
    }
    _hideTimer.cancel();
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Toggle play/pause when tapping anywhere on video
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        _showControls();
      },
      child: Stack(
        children: [
          // Main video area
          Positioned.fill(child: Container(color: Colors.transparent)),
          // Controls overlay
          AnimatedOpacity(
            opacity: _hideStuff ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Spacer(),
                  // Bottom controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Progress bar (made thicker)
                        SizedBox(
                          height: 10, // Thicker progress bar
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: AppColors.primaryColor,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              bufferedColor: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Single row with all controls and info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left side: Time only
                            Row(
                              children: [
                                // Time display
                                ValueListenableBuilder(
                                  valueListenable: controller,
                                  builder: (context, value, child) {
                                    final position = value.position;
                                    final duration = value.duration;
                                    return Text(
                                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                      style: TextStyle(
                                        color: widget.iconColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            // Center: Play controls with skip buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Skip backward 5s
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.backward_fill,
                                          color: widget.iconColor,
                                          size: 18,
                                        ),
                                        Text(
                                          '5s',
                                          style: TextStyle(
                                            color: widget.iconColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onPressed: () {
                                    final currentPosition =
                                        controller.value.position;
                                    final newPosition =
                                        currentPosition -
                                        const Duration(seconds: 5);
                                    controller.seekTo(newPosition);
                                    _showControls();
                                  },
                                ),
                                const SizedBox(width: 12),
                                // Play/Pause button
                                ValueListenableBuilder(
                                  valueListenable: controller,
                                  builder: (context, value, child) {
                                    return CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          value.isPlaying
                                              ? CupertinoIcons.pause_fill
                                              : CupertinoIcons.play_fill,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (value.isPlaying) {
                                          controller.pause();
                                        } else {
                                          controller.play();
                                        }
                                        _showControls();
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                // Skip forward 5s
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.forward_fill,
                                          color: widget.iconColor,
                                          size: 18,
                                        ),
                                        Text(
                                          '5s',
                                          style: TextStyle(
                                            color: widget.iconColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onPressed: () {
                                    final currentPosition =
                                        controller.value.position;
                                    final newPosition =
                                        currentPosition +
                                        const Duration(seconds: 5);
                                    controller.seekTo(newPosition);
                                    _showControls();
                                  },
                                ),
                              ],
                            ),
                            // Right side: Volume, Speed, and Fullscreen
                            Row(
                              children: [
                                // Volume toggle button
                                ValueListenableBuilder(
                                  valueListenable: controller,
                                  builder: (context, value, child) {
                                    final isMuted = value.volume == 0.0;
                                    return CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Icon(
                                          isMuted
                                              ? CupertinoIcons.volume_off
                                              : CupertinoIcons.volume_up,
                                          color: widget.iconColor,
                                          size: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (isMuted) {
                                          controller.setVolume(1.0);
                                        } else {
                                          controller.setVolume(0.0);
                                        }
                                        _showControls();
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Speed button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: ValueListenableBuilder(
                                      valueListenable: controller,
                                      builder: (context, value, child) {
                                        final speed = value.playbackSpeed;
                                        return Text(
                                          '${speed}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  onPressed: () => widget.onSpeedTap(context),
                                ),
                                const SizedBox(width: 8),
                                // Fullscreen button
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.fullscreen,
                                      color: widget.iconColor,
                                      size: 20,
                                    ),
                                  ),
                                  onPressed: () {
                                    chewieController.toggleFullScreen();
                                    _showControls();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

class VideoPlayerWithExternalFiles extends StatefulWidget {
  final VideoRecord video;

  const VideoPlayerWithExternalFiles({super.key, required this.video});

  static Future<void> show(BuildContext context, VideoRecord video) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return VideoPlayerWithExternalFiles(video: video);
      },
    );
  }

  @override
  State<VideoPlayerWithExternalFiles> createState() =>
      _VideoPlayerWithExternalFilesState();
}

class _VideoPlayerWithExternalFilesState
    extends State<VideoPlayerWithExternalFiles> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _loadingStatus = 'Preparing video...';
  double _loadingProgress = 0.0;
  bool _isBuffering = false;

  // File path info
  String _localFilePath = '';
  bool _isFileReady = false;

  @override
  void initState() {
    super.initState();
    _prepareVideoFile();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  /// Prepares the video file by copying from assets to Documents directory if needed
  Future<void> _prepareVideoFile() async {
    try {
      setState(() {
        _loadingStatus = 'Checking file...';
        _loadingProgress = 0.1;
      });

      // Get file name from path
      final fileName = widget.video.filePath.split('/').last;

      // Get app's document directory
      final docDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${docDir.path}/videos');

      // Create videos directory if it doesn't exist
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      // Path where we will store the file
      final localFilePath = '${videosDir.path}/$fileName';
      _localFilePath = localFilePath;

      // Check if file already exists in documents directory
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        print(
          'Video file already exists in documents directory: $localFilePath',
        );
        setState(() {
          _isFileReady = true;
          _loadingStatus = 'File found. Initializing player...';
          _loadingProgress = 0.3;
        });
      } else {
        // Copy file from assets to documents directory
        setState(() {
          _loadingStatus = 'Copying video file to documents directory...';
          _loadingProgress = 0.2;
        });

        // Get asset file path
        final assetPath = widget.video.filePath.replaceFirst('assets/', '');

        try {
          // Load asset as ByteData
          final byteData = await rootBundle.load('assets/$assetPath');

          // Write to local file
          await localFile.writeAsBytes(byteData.buffer.asUint8List());

          print('Video file copied successfully to: $localFilePath');
          setState(() {
            _isFileReady = true;
            _loadingStatus = 'File copied. Initializing player...';
            _loadingProgress = 0.3;
          });
        } catch (e) {
          print('Error copying asset file: $e');
          throw Exception('Failed to copy video file: $e');
        }
      }

      // Initialize video player once file is ready
      await _initializeVideoPlayer();
    } catch (e) {
      print('Error preparing video file: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _loadingStatus = 'Error preparing video: $e';
        _loadingProgress = 0.0;
      });
    }
  }

  /// Initializes the video player with the local file
  Future<void> _initializeVideoPlayer() async {
    if (!_isFileReady) {
      throw Exception('Video file is not ready yet');
    }

    try {
      setState(() {
        _loadingStatus = 'Initializing video controller...';
        _loadingProgress = 0.4;
      });

      // Create video player controller from the local file
      final file = File(_localFilePath);
      _videoPlayerController = VideoPlayerController.file(file);

      // Listen for buffering
      _videoPlayerController!.addListener(() {
        final value = _videoPlayerController!.value;
        if (value.isBuffering != _isBuffering && mounted) {
          setState(() {
            _isBuffering = value.isBuffering;
            if (_isBuffering) {
              _loadingStatus = 'Buffering video...';
            }
          });
        }
      });

      setState(() {
        _loadingStatus = 'Loading video data...';
        _loadingProgress = 0.6;
      });

      // Initialize the controller
      await _videoPlayerController!.initialize();

      setState(() {
        _loadingStatus = 'Setting up player controls...';
        _loadingProgress = 0.8;
      });

      // Create Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: true,
        showControls: true,
        // Use custom CupertinoControls for better desktop experience
        customControls: Platform.isAndroid
            ? null
            : CustomCupertinoControls(
                backgroundColor: const Color.fromRGBO(41, 41, 41, 0.7),
                iconColor: Colors.white,
                onSpeedTap: (context) => _showSpeedPopup(context, null),
              ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryColor,
          handleColor: AppColors.primaryColor,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade500,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryColor,
          handleColor: AppColors.primaryColor,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade500,
        ),
        // Custom options menu theme
        optionsTranslation: OptionsTranslation(
          playbackSpeedButtonText: 'Speed',
          subtitlesButtonText: 'Subtitles',
          cancelButtonText: 'Cancel',
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Video playback error',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red.shade300, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isInitialized = true;
        _loadingStatus = 'Video ready!';
        _loadingProgress = 1.0;
      });

      print('Video player initialized successfully');

      // Start playback after a short delay to ensure buffer
      Future.delayed(Duration(milliseconds: 500), () {
        if (_chewieController != null && mounted) {
          _chewieController!.play();
        }
      });
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _loadingStatus = 'Error initializing player: $e';
        _loadingProgress = 0.0;
      });
    }
  }

  /// Shows a compact speed selection popup at bottom right
  Future<void> _showSpeedPopup(
    BuildContext context,
    dynamic speedOption,
  ) async {
    final overlay = Overlay.of(context);

    OverlayEntry? overlayEntry;
    OverlayEntry? outsideOverlay;

    // Define speed options
    final speedOptions = [
      {'label': '0.25x', 'value': 0.25},
      {'label': '0.5x', 'value': 0.5},
      {'label': '0.75x', 'value': 0.75},
      {'label': '1.0x', 'value': 1.0},
      {'label': '1.25x', 'value': 1.25},
      {'label': '1.5x', 'value': 1.5},
      {'label': '1.75x', 'value': 1.75},
      {'label': '2.0x', 'value': 2.0},
    ];

    final currentSpeed = _videoPlayerController?.value.playbackSpeed ?? 1.0;

    void removeOverlays() {
      try {
        overlayEntry?.remove();
        outsideOverlay?.remove();
      } catch (e) {
        print('Error removing overlays: $e');
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100, // Position above the single row controls
        right: 80, // Position above the speed button (now on the right)
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(41, 41, 41, 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.speed,
                        color: AppColors.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Speed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Speed options
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: speedOptions.map((option) {
                      final isSelected =
                          (option['value'] as double) == currentSpeed;
                      return GestureDetector(
                        onTap: () {
                          // Change playback speed
                          _videoPlayerController?.setPlaybackSpeed(
                            option['value'] as double,
                          );
                          // Remove overlays
                          removeOverlays();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryColor.withOpacity(0.2)
                                : Colors.transparent,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryColor.withOpacity(
                                      0.5,
                                    ),
                                    width: 1,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryColor,
                                  size: 14,
                                ),
                              if (isSelected) const SizedBox(width: 6),
                              Text(
                                option['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Add gesture detector to detect outside taps
    outsideOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: removeOverlays,
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
      ),
    );

    try {
      overlay.insert(outsideOverlay);
      overlay.insert(overlayEntry);

      // Auto-dismiss after 5 seconds
      Timer(const Duration(seconds: 5), removeOverlays);
    } catch (e) {
      print('Error inserting overlays: $e');
      removeOverlays();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildVideoPlayer()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam, color: AppColors.primaryColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      widget.video.formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '• ${widget.video.formattedDuration}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '• ${widget.video.formattedFileSize}',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasError) {
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Failed to load video',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade300, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                  _prepareVideoFile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Show thumbnail in the background while loading
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  widget.video.thumbnailPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: Colors.grey.shade800);
                  },
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'File size: ${widget.video.formattedFileSize}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 400,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _loadingProgress,
                          backgroundColor: Colors.grey.shade700,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_loadingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isBuffering)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Buffering...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder,
                              color: AppColors.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Playing from Documents Directory',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Optimized for large video files',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.black,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: GestureDetector(
          onTap: () {
            // Let Chewie handle tap events for default controls
          },
          child: Stack(
            children: [
              // Main video player with default Chewie controls
              if (_chewieController != null)
                Positioned.fill(child: Chewie(controller: _chewieController!))
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
