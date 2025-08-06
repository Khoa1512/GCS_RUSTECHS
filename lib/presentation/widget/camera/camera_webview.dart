// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// class CameraWebView extends StatefulWidget {
//   final String streamUrl;
//   final double? width;
//   final double? height;

//   const CameraWebView({
//     super.key,
//     required this.streamUrl,
//     this.width,
//     this.height,
//   });

//   @override
//   State<CameraWebView> createState() => _CameraWebViewState();
// }

// class _CameraWebViewState extends State<CameraWebView> {
//   InAppWebViewController? _controller;
//   bool _isLoading = true;
//   bool _hasError = false;

//   @override
//   void initState() {
//     super.initState();
//     print('Initializing camera stream: ${widget.streamUrl}');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: widget.width ?? double.infinity,
//       height: widget.height ?? double.infinity,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         color: Colors.black,
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(12),
//         child: Stack(
//           children: [
//             // InAppWebView for camera stream
//             InAppWebView(
//               initialUrlRequest: URLRequest(
//                 url: WebUri(widget.streamUrl),
//               ),
//               initialSettings: InAppWebViewSettings(
//                 javaScriptEnabled: true,
//                 mediaPlaybackRequiresUserGesture: false,
//                 allowsInlineMediaPlayback: true,
//                 supportZoom: false,
//                 clearCache: true,
//                 mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
//                 isInspectable: kDebugMode,
//               ),
//               onWebViewCreated: (controller) {
//                 _controller = controller;
//                 print('InAppWebView created successfully');
//               },
//               onLoadStart: (controller, url) {
//                 print('Loading started: $url');
//                 setState(() {
//                   _isLoading = true;
//                   _hasError = false;
//                 });
//               },
//               onLoadStop: (controller, url) {
//                 print('Loading finished: $url');
//                 setState(() {
//                   _isLoading = false;
//                 });
//               },
//               onReceivedError: (controller, request, error) {
//                 print('WebView error: ${error.description}');
//                 setState(() {
//                   _hasError = true;
//                   _isLoading = false;
//                 });
//               },
//               onProgressChanged: (controller, progress) {
//                 if (progress == 100) {
//                   setState(() {
//                     _isLoading = false;
//                   });
//                 }
//               },
//             ),
//             if (_isLoading) _buildLoadingWidget(),
//             if (_hasError) _buildErrorWidget(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLoadingWidget() {
//     return Container(
//       color: Colors.black54,
//       child: const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Loading camera stream...',
//               style: TextStyle(color: Colors.white),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorWidget() {
//     return Container(
//       color: Colors.grey[900],
//       child: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 48),
//             const SizedBox(height: 16),
//             const Text(
//               'Unable to load camera stream',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'URL: ${widget.streamUrl}',
//               style: TextStyle(color: Colors.grey[400], fontSize: 12),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _hasError = false;
//                   _isLoading = true;
//                 });
//                 _controller?.reload();
//               },
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }
// }
