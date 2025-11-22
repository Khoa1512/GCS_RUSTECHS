import 'package:flutter/material.dart';
import 'dart:io';

import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:webview_windows/webview_windows.dart' as windows;

class PlatformWebView extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;

  const PlatformWebView({
    super.key,
    required this.url,
    this.width,
    this.height,
  });

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _hasError = false;

  // For webview_flutter (macOS)
  webview.WebViewController? _webViewController;

  // For webview_windows (Windows)
  final windows.WebviewController _windowsController = windows.WebviewController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    if (Platform.isMacOS) {
      // Use webview_flutter for macOS
      _webViewController = webview.WebViewController()
        ..setJavaScriptMode(webview.JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          webview.NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (webview.WebResourceError error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else if (Platform.isWindows) {
      // Initialize webview_windows
      _initializeWindowsWebView();
    }
  }

  Future<void> _initializeWindowsWebView() async {
    try {
      await _windowsController.initialize();
      await _windowsController.loadUrl(widget.url);

      _windowsController.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == windows.LoadingState.loading;
          });
        }
      });

      _windowsController.url.listen((url) {
      });

      if (mounted) {
        setState(() {
          _hasError = false;
        });
      }
    } catch (e) {
      // print('Error initializing Windows WebView: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildWebView(),
            if (_isLoading) _buildLoadingWidget(),
            if (_hasError) _buildErrorWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    if (Platform.isMacOS) {
      // Use webview_flutter for macOS
      return webview.WebViewWidget(controller: _webViewController!);
    } else if (Platform.isWindows) {
      // Use webview_windows for Windows
      return windows.Webview(_windowsController);
    } else {
      // Fallback for other platforms
      return _buildFallbackView();
    }
  }

  Widget _buildFallbackView() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'WebView not supported on this platform',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Platform: ${Platform.operatingSystem}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Open in external browser using url_launcher
              },
              child: const Text('Open in Browser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Loading camera stream...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to load camera stream',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: ${widget.url}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _reloadWebView();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _reloadWebView() {
    if (Platform.isMacOS && _webViewController != null) {
      _webViewController!.reload();
    } else if (Platform.isWindows) {
      _windowsController.reload();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _windowsController.dispose();
    }
    super.dispose();
  }
}
