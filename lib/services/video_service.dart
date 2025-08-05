import 'package:skylink/data/models/video_record.dart';
import 'package:skylink/services/video_metadata_service.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  final VideoMetadataService _metadataService = VideoMetadataService();

  // Mock data - Replace with real database later
  final List<VideoRecord> _videos = [
    VideoRecord(
      id: '1',
      title: 'Mission Flight - Morning Patrol',
      filePath: 'assets/videos/baoloc1.mp4', // Real video file with large size
      recordedAt: DateTime.now().subtract(Duration(hours: 2)),
      duration: Duration(
        minutes: 3,
        seconds: 37,
      ), // Thời lượng thực tế của video
      thumbnailPath:
          'assets/thumbnails/baoloc1.png', // Pre-created thumbnail in assets
      fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    ),
    VideoRecord(
      id: '2',
      title: 'Surveillance - North Sector',
      filePath: 'assets/videos/baoloc2.mp4',
      recordedAt: DateTime.now().subtract(Duration(hours: 5)),
      duration: Duration(
        minutes: 3,
        seconds: 37,
      ), // Thời lượng thực tế của video
      thumbnailPath: 'assets/thumbnails/baoloc2.png',
      fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    ),
    VideoRecord(
      id: '3',
      title: 'Test Flight - Calibration',
      filePath: 'assets/videos/baoloc3.mp4',
      recordedAt: DateTime.now().subtract(Duration(days: 1, hours: 3)),
      duration: Duration(
        minutes: 3,
        seconds: 37,
      ), // Thời lượng thực tế của video
      thumbnailPath: 'assets/thumbnails/baoloc1.png',
      fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    ),
    VideoRecord(
      id: '4',
      title: 'Emergency Response Training',
      filePath: 'assets/videos/baoloc2.mp4',
      recordedAt: DateTime.now().subtract(Duration(days: 2)),
      duration: Duration(
        minutes: 3,
        seconds: 37,
      ), // Thời lượng thực tế của video
      thumbnailPath: 'assets/thumbnails/baoloc2.png',
      fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    ),
    VideoRecord(
      id: '5',
      title: 'Routine Inspection - Building A',
      filePath: 'assets/videos/baoloc1.mp4',
      recordedAt: DateTime.now().subtract(Duration(days: 3, hours: 1)),
      duration: Duration(
        minutes: 3,
        seconds: 37,
      ), // Thời lượng thực tế của video
      thumbnailPath: 'assets/thumbnails/baoloc1.png',
      fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    ),
    // VideoRecord(
    //   id: '6',
    //   title: 'Night Vision Test',
    //   filePath: 'assets/videos/baoloc1.mp4',
    //   recordedAt: DateTime.now().subtract(Duration(days: 4, hours: 8)),
    //   duration: Duration(minutes: 3, seconds: 37), // Thời lượng thực tế của video
    //   thumbnailPath: 'assets/thumbnails/night_vision.png',
    //   fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    // ),
    // VideoRecord(
    //   id: '7',
    //   title: 'Perimeter Security Check',
    //   filePath: 'assets/videos/baoloc2.mp4',
    //   recordedAt: DateTime.now().subtract(Duration(days: 5, hours: 2)),
    //   duration: Duration(minutes: 3, seconds: 37), // Thời lượng thực tế của video
    //   thumbnailPath: 'assets/thumbnails/perimeter_security.png',
    //   fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    // ),
    // VideoRecord(
    //   id: '8',
    //   title: 'Weather Monitoring Flight',
    //   filePath: 'assets/videos/baoloc3.mp4',
    //   recordedAt: DateTime.now().subtract(Duration(days: 6, hours: 4)),
    //   duration: Duration(minutes: 3, seconds: 37), // Thời lượng thực tế của video
    //   thumbnailPath: 'assets/thumbnails/weather_monitoring.png',
    //   fileSize: 12 * 1024 * 1024, // Ước tính kích thước thực tế ~12MB
    // ),
  ];

  // Get all videos sorted by date (newest first)
  List<VideoRecord> getAllVideos() {
    return List.from(_videos)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  // Get all videos with real metadata (duration and file size extracted from actual files)
  Future<List<VideoRecord>> getAllVideosWithRealMetadata() async {
    try {
      // print('📊 Getting all videos with real metadata...');

      List<VideoRecord> videosWithRealMetadata = [];

      for (VideoRecord video in _videos) {
        final videoWithRealMetadata = await _metadataService
            .updateVideoWithRealMetadata(video);
        videosWithRealMetadata.add(videoWithRealMetadata);
      }

      // Sort by date (newest first)
      videosWithRealMetadata.sort(
        (a, b) => b.recordedAt.compareTo(a.recordedAt),
      );

      // print('✅ All videos updated with real metadata');
      return videosWithRealMetadata;
    } catch (e) {
      // print('❌ Error getting videos with real metadata: $e');
      // Return videos with original metadata if error
      return getAllVideos();
    }
  }

  // Get video by ID
  VideoRecord? getVideoById(String id) {
    try {
      return _videos.firstWhere((video) => video.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get video by ID with real metadata (duration and file size extracted from actual file)
  Future<VideoRecord> getVideoByIdWithRealMetadata(String id) async {
    try {
      final video = getVideoById(id);
      if (video == null) {
        throw Exception('Video with ID $id not found');
      }

      // print('🔍 Getting video with real metadata: ${video.title}');
      return await _metadataService.updateVideoWithRealMetadata(video);
    } catch (e) {
      // print('❌ Error getting video with real metadata: $e');
      rethrow;
    }
  }

  // Add new video record (for future use)
  void addVideo(VideoRecord video) {
    _videos.add(video);
  }

  // Delete video
  bool deleteVideo(String id) {
    final index = _videos.indexWhere((video) => video.id == id);
    if (index != -1) {
      _videos.removeAt(index);
      return true;
    }
    return false;
  }

  // Search videos by title
  List<VideoRecord> searchVideos(String query) {
    if (query.isEmpty) return getAllVideos();

    return _videos
        .where(
          (video) => video.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }
}
