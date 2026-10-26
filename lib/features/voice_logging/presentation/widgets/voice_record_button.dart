import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/services/audio_recorder_service.dart';
import 'package:my_meal/core/services/gemini_voice_service.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/settings/providers/settings_providers.dart';
import 'package:my_meal/features/voice_logging/presentation/widgets/voice_review_bottom_sheet.dart';

class VoiceRecordButton extends ConsumerStatefulWidget {
  const VoiceRecordButton({super.key});

  @override
  ConsumerState<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends ConsumerState<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final GeminiVoiceService _geminiService = GeminiVoiceService();

  bool _isRecording = false;
  bool _isProcessing = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _recorderService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final apiKey = ref.read(geminiApiKeyProvider).value ?? '';
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, configure sua Chave do Gemini na aba de Configurações.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (_isProcessing) return;

    if (_isRecording) {
      // Finalizar gravação e enviar para IA
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      try {
        final audioPath = await _recorderService.stopRecording();
        if (audioPath != null) {
          final result = await _geminiService.processAudioMeal(
            audioPath: audioPath,
            apiKey: apiKey,
          );

          if (mounted) {
            final targetDate = ref.read(selectedDateProvider);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => VoiceReviewBottomSheet(
                initialResult: result,
                targetDate: targetDate,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao processar áudio: $e'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } else {
      // Iniciar gravação
      try {
        await _recorderService.startRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao iniciar gravação: $e'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'A IA está analisando sua refeição...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_isRecording) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = 1.0 + (_animController.value * 0.08);
          return Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleRecording,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dangerColor.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop_circle, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Ouvindo... Toque para finalizar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return FloatingActionButton.extended(
      onPressed: _toggleRecording,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.mic, size: 26),
      label: const Text(
        'Falar Refeição',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
