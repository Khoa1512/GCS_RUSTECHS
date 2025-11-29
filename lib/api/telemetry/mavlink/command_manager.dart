import 'dart:async';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

/// Manages reliable command sending with ACK/Retry logic
class CommandManager {
  final void Function(MavlinkMessage) _sendCallback;
  final Map<int, Completer<bool>> _pendingCommands = {};

  // Track active retry timers to cancel them if needed
  final Map<int, Timer> _retryTimers = {};

  CommandManager(this._sendCallback);

  /// Send a command and wait for ACK.
  /// Returns true if ACK received with MAV_RESULT_ACCEPTED.
  Future<bool> sendCommand(
    CommandLong cmd, {
    int retries = 3,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final completer = Completer<bool>();
    final cmdId = cmd.command;

    // If a command of this type is already pending, cancel it (or queue it? for now replace)
    if (_pendingCommands.containsKey(cmdId)) {
      _pendingCommands[cmdId]?.complete(false); // Fail previous
      _retryTimers[cmdId]?.cancel();
    }

    _pendingCommands[cmdId] = completer;

    int attempts = 0;

    void attemptSend() {
      attempts++;
      _sendCallback(cmd);
      print('CommandManager: Sending CMD $cmdId (Attempt $attempts/$retries)');

      if (attempts <= retries) {
        _retryTimers[cmdId] = Timer(timeout, () {
          if (!completer.isCompleted) {
            print(
              'CommandManager: Timeout waiting for ACK for CMD $cmdId. Retrying...',
            );
            attemptSend();
          }
        });
      } else {
        if (!completer.isCompleted) {
          print(
            'CommandManager: Failed to get ACK for CMD $cmdId after $retries retries.',
          );
          _pendingCommands.remove(cmdId);
          completer.complete(false);
        }
      }
    }

    // Start first attempt
    attemptSend();

    return completer.future;
  }

  /// Handle incoming ACK
  void handleAck(CommandAck ack) {
    final cmdId = ack.command;
    if (_pendingCommands.containsKey(cmdId)) {
      final completer = _pendingCommands.remove(cmdId);
      _retryTimers[cmdId]?.cancel();
      _retryTimers.remove(cmdId);

      final success = ack.result == 0; // MAV_RESULT_ACCEPTED = 0
      if (success) {
        print('CommandManager: ACK Received for CMD $cmdId (Success)');
      } else {
        print(
          'CommandManager: ACK Received for CMD $cmdId (Failed with result ${ack.result})',
        );
      }

      if (completer != null && !completer.isCompleted) {
        completer.complete(success);
      }
    }
  }

  void dispose() {
    for (var timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _pendingCommands.clear();
  }
}
