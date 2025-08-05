class VideoRecord {
  final String id;
  final String title;
  final String filePath;
  final DateTime recordedAt;
  final Duration duration;
  final String thumbnailPath;
  final int fileSize; // in bytes

  VideoRecord({
    required this.id,
    required this.title,
    required this.filePath,
    required this.recordedAt,
    required this.duration,
    required this.thumbnailPath,
    required this.fileSize,
  });

  // Format file size to human readable
  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // Format duration to mm:ss
  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Format recorded date
  String get formattedDate {
    return '${recordedAt.day.toString().padLeft(2, '0')}/${recordedAt.month.toString().padLeft(2, '0')}/${recordedAt.year} ${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }
}
