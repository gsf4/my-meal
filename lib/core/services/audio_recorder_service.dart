import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  Future<String?> startRecording() async {
    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      throw Exception('Permissão de gravação de áudio negada');
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/mymeal_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentRecordingPath = filePath;

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    return filePath;
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path ?? _currentRecordingPath;
  }

  Future<void> cancelRecording() async {
    await _audioRecorder.cancel();
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      _currentRecordingPath = null;
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
