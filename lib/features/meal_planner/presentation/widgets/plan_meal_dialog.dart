import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_meal/core/services/audio_recorder_service.dart';
import 'package:my_meal/core/services/gemini_voice_service.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/settings/providers/settings_providers.dart';
import 'package:my_meal/features/voice_logging/presentation/widgets/voice_review_bottom_sheet.dart';

class PlanMealDialog extends ConsumerStatefulWidget {
  final MealType mealType;
  final DateTime targetDate;

  const PlanMealDialog({
    super.key,
    required this.mealType,
    required this.targetDate,
  });

  static Future<void> show(BuildContext context, {
    required MealType mealType,
    required DateTime targetDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanMealDialog(
        mealType: mealType,
        targetDate: targetDate,
      ),
    );
  }

  @override
  ConsumerState<PlanMealDialog> createState() => _PlanMealDialogState();
}

class _PlanMealDialogState extends ConsumerState<PlanMealDialog>
    with SingleTickerProviderStateMixin {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final GeminiVoiceService _geminiService = GeminiVoiceService();

  bool _isRecording = false;
  bool _isProcessing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorderService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording({
    required double remainingCalories,
    required double remainingProtein,
  }) async {
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
      // Finaliza a gravação e envia para planejamento da IA
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      try {
        final audioPath = await _recorderService.stopRecording();
        if (audioPath != null) {
          final result = await _geminiService.planAudioMeal(
            audioPath: audioPath,
            apiKey: apiKey,
            remainingCalories: remainingCalories,
            remainingProtein: remainingProtein,
            targetMealType: widget.mealType,
          );

          if (mounted) {
            Navigator.of(context).pop(); // Fecha o diálogo de gravação

            // Abre o BottomSheet de revisão em modo planejamento
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => VoiceReviewBottomSheet(
                initialResult: result,
                targetDate: widget.targetDate,
                isPlanningMode: true,
                targetRemainingCalories: remainingCalories,
                targetRemainingProtein: remainingProtein,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao planejar refeição: $e'),
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
      // Inicia a gravação de áudio
      try {
        await _recorderService.startRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao iniciar gravação de voz: $e'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(nutritionProgressProvider);
    final remainingCalories = progress.remainingCalories > 0 ? progress.remainingCalories : 0.0;
    final remainingProtein = progress.remainingProtein > 0 ? progress.remainingProtein : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Barra de arraste
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Cabeçalho com Ícone da Refeição
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planejar ${widget.mealType.detailedLabel}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Sugestão de porções para bater suas metas',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card de Saldo Nutricional do Dia
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Metas restantes do dia:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.proteinColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Prioridade: Proteína ⚡',
                        style: TextStyle(
                          color: AppTheme.proteinColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBalanceItem(
                      label: 'Proteína Restante',
                      value: '${remainingProtein.toStringAsFixed(1)}g',
                      color: AppTheme.proteinColor,
                    ),
                    Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.25)),
                    _buildBalanceItem(
                      label: 'Calorias Restantes',
                      value: '${remainingCalories.toStringAsFixed(0)} kcal',
                      color: AppTheme.caloriesColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Instrução para o usuário
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 20, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Fale o que pretende comer (ex: "goma de tapioca e ovos médios"). O app calculará as porções para você!',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Botão de Gravação com Animação
          if (_isProcessing) ...[
            Column(
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Calculando porções para bater sua proteína...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Consultando IA e ajustando com seu banco local',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ] else ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isRecording ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: FloatingActionButton(
                      heroTag: 'fab_plan_meal_dialog',
                      onPressed: () => _toggleRecording(
                        remainingCalories: remainingCalories,
                        remainingProtein: remainingProtein,
                      ),
                      backgroundColor: _isRecording ? AppTheme.dangerColor : const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: _isRecording ? 8 : 4,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 34,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              _isRecording ? 'Gravando... Toque no botão para finalizar' : 'Toque no microfone para falar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _isRecording ? AppTheme.dangerColor : Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  }

  Widget _buildBalanceItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
