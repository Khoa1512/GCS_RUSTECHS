import 'package:video_player/video_player.dart';
import 'package:skylink/data/models/video_record.dart';
import 'package:flutter/services.dart';

class VideoMetadataService {
  static final VideoMetadataService _instance = VideoMetadataService._internal();
  factory VideoMetadataService() => _instance;
  VideoMetadataService._internal();

  // Cache to store already extracted metadata
  final Map<String, VideoRecord> _metadataCache = {};

  /// Get actual duration of video file
  Future<Duration> getVideoDuration(String assetPath) async {
    try {
      // Create video player controller from asset
      final controller = VideoPlayerController.asset(assetPath);
      await controller.initialize();

      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      // Return default duration if error
      return Duration(minutes: 3, seconds: 37);
    }
  }

  /// Get actual file size of video file
  Future<int> getVideoFileSize(String assetPath) async {
    try {

      // Load asset as bytes to get size
      final ByteData data = await rootBundle.load(assetPath);
      final int sizeInBytes = data.lengthInBytes;

      return sizeInBytes;
    } catch (e) {
      // Return default size if error (12MB)
      return 12 * 1024 * 1024;
    }
  }

  /// Update video record with real metadata (duration and file size)
  Future<VideoRecord> updateVideoWithRealMetadata(VideoRecord video) async {
    // Check cache first
    if (_metadataCache.containsKey(video.id)) {
      return _metadataCache[video.id]!;
    }

    try {
      // print('🔍 Extracting real metadata for: ${video.title}');

      // Get real duration and file size
      final Duration realDuration = await getVideoDuration(video.filePath);
      final int realFileSize = await getVideoFileSize(video.filePath);

      // Create updated video record
      final updatedVideo = VideoRecord(
        id: video.id,
        title: video.title,
        filePath: video.filePath,
        recordedAt: video.recordedAt,
        duration: realDuration,
        thumbnailPath: video.thumbnailPath,
        fileSize: realFileSize,
      );

      // Cache the result
      _metadataCache[video.id] = updatedVideo;


      return updatedVideo;
    } catch (e) {
      // Return original video if error
      return video;
    }
  }

  /// Clear metadata cache
  void clearCache() {
    _metadataCache.clear();
  }

  /// Get cache status
  bool isVideoCached(String videoId) {
    return _metadataCache.containsKey(videoId);
  }
}
