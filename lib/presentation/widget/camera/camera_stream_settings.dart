import 'package:flutter/material.dart';

class CameraStreamSettings extends StatefulWidget {
  final String currentUrl;
  final Function(String) onUrlChanged;
  final VoidCallback onClose;

  const CameraStreamSettings({
    super.key,
    required this.currentUrl,
    required this.onUrlChanged,
    required this.onClose,
  });

  @override
  State<CameraStreamSettings> createState() => _CameraStreamSettingsState();
}

class _CameraStreamSettingsState extends State<CameraStreamSettings> {
  late TextEditingController _urlController;
  final List<String> _commonUrls = [
    "https://mr2v2r37jzqd.connect.remote.it/",
    "https://www.youtube.com/watch?v=Wrj-2zuhE-Q&list=RDWrj-2zuhE-Q&start_radio=1",
    "http://localhost:8080/video",
    "rtmp://example.com/live/stream",
    "https://example.com/camera/feed",
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Container(
      width: isSmallScreen ? screenSize.width * 0.95 : screenSize.width * 0.6,
      constraints: BoxConstraints(
        maxWidth: isSmallScreen ? 400 : 600,
        maxHeight: screenSize.height * 0.8,
      ),
      margin: EdgeInsets.all(isSmallScreen ? 8 : 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Camera Stream Settings',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),

            // Current URL info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Current Stream URL:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentUrl,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),

            // URL Input
            Text(
              'New Camera Stream URL:',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter camera stream URL...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),

            // Sample URLs section
            Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Quick Select URLs:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Container(
              height: isSmallScreen ? 100 : 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _commonUrls.length,
                itemBuilder: (context, index) {
                  final url = _commonUrls[index];
                  final isSelected = url == widget.currentUrl;
                  return Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 4 : 8,
                      vertical: 1,
                    ),
                    child: ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.blue : Colors.grey,
                        size: isSmallScreen ? 16 : 20,
                      ),
                      title: Text(
                        url,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected ? Colors.blue : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _urlController.text = url;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 8 : 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                ElevatedButton(
                  onPressed: () {
                    final newUrl = _urlController.text.trim();
                    if (newUrl.isNotEmpty) {
                      widget.onUrlChanged(newUrl);
                      widget.onClose();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 24,
                      vertical: isSmallScreen ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
