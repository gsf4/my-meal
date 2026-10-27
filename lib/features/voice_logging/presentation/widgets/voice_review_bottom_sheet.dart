import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:my_meal/core/services/audio_recorder_service.dart';
import 'package:my_meal/core/services/gemini_voice_service.dart';
import 'package:my_meal/core/theme/app_theme.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/presentation/screens/food_form_dialog.dart';
import 'package:my_meal/features/foods/providers/food_providers.dart';
import 'package:my_meal/features/meals/models/meal_log.dart';
import 'package:my_meal/features/meals/models/meal_type.dart';
import 'package:my_meal/features/meals/providers/meal_providers.dart';
import 'package:my_meal/features/settings/providers/settings_providers.dart';
import 'package:my_meal/features/voice_logging/models/voice_meal_result.dart';

class VoiceReviewBottomSheet extends ConsumerStatefulWidget {
  final VoiceMealResult initialResult;
  final DateTime targetDate;
  final bool isPlanningMode;
  final double? targetRemainingCalories;
  final double? targetRemainingProtein;

  const VoiceReviewBottomSheet({
    super.key,
    required this.initialResult,
    required this.targetDate,
    this.isPlanningMode = false,
    this.targetRemainingCalories,
    this.targetRemainingProtein,
  });

  @override
  ConsumerState<VoiceReviewBottomSheet> createState() => _VoiceReviewBottomSheetState();
}

class _VoiceReviewBottomSheetState extends ConsumerState<VoiceReviewBottomSheet> {
  late MealType _mealType;
  late List<VoiceDetectedFoodItem> _items;
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  bool _isAppendingAudio = false;
  bool _isProcessingAudio = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialResult.suggestedMealType;
    _items = List.from(widget.initialResult.items);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _recordMoreAudio() async {
    final apiKey = ref.read(geminiApiKeyProvider).value ?? '';
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure sua Chave do Gemini nas Configurações.')),
      );
      return;
    }

    if (_isAppendingAudio) {
      // Parar gravação e processar
      setState(() {
        _isAppendingAudio = false;
        _isProcessingAudio = true;
      });

      try {
        final path = await _audioRecorder.stopRecording();
        if (path != null) {
          final voiceService = GeminiVoiceService();
          final newResult = await voiceService.processAudioMeal(
            audioPath: path,
            apiKey: apiKey,
          );

          setState(() {
            _items.addAll(newResult.items);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao processar áudio: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessingAudio = false);
        }
      }
    } else {
      // Iniciar gravação de áudio adicional
      try {
        await _audioRecorder.startRecording();
        setState(() => _isAppendingAudio = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível gravar áudio: $e')),
          );
        }
      }
    }
  }

  void _openFoodFormForItem(int index) async {
    final item = _items[index];
    final result = await showDialog<FoodItem>(
      context: context,
      builder: (ctx) => FoodFormDialog(
        initialName: item.spokenName,
        initialCalories: item.estimatedCaloriesPer100g,
        initialProtein: item.estimatedProteinPer100g,
        initialCarbs: item.estimatedCarbsPer100g,
        initialFat: item.estimatedFatPer100g,
      ),
    );

    if (result != null) {
      await ref.read(foodListProvider.notifier).addFood(result);
      setState(() {
        _items[index].matchedFood = result;
      });
    }
  }

  void _editItemGrams(int index) {
    final item = _items[index];
    final isPortion = item.portionName != null && item.portionQuantity != null && item.portionQuantity! > 0;
    final portionUnitWeight = isPortion ? (item.grams / item.portionQuantity!) : 1.0;

    final initialCount = isPortion ? item.portionQuantity! : item.grams;
    final controller = TextEditingController(
      text: initialCount % 1 == 0 ? initialCount.toInt().toString() : initialCount.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade de ${item.matchedFood?.name ?? item.spokenName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: isPortion 
                ? 'Quantidade de "${item.portionName}"'
                : (item.matchedFood != null 
                    ? 'Quantidade (${item.matchedFood!.unitType.label})'
                    : 'Quantidade'),
            suffixText: isPortion ? 'porção(ões)' : (item.matchedFood?.unitType.unitSuffix ?? 'g'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(',', '.')) ?? initialCount;
              if (parsed > 0) {
                setState(() {
                  if (isPortion) {
                    _items[index].portionQuantity = parsed;
                    _items[index].grams = parsed * portionUnitWeight;
                  } else {
                    _items[index].grams = parsed;
                  }
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _confirmAndSave() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum alimento na lista para registrar.')),
      );
      return;
    }

    final List<MealLog> logsToInsert = [];
    final now = DateTime.now();
    const uuid = Uuid();

    for (final item in _items) {
      FoodItem food;
      if (item.matchedFood != null) {
        food = item.matchedFood!;
      } else {
        // Criar automaticamente no banco local com indicador de pendência de dados nutricionais
        food = FoodItem(
          id: uuid.v4(),
          name: item.spokenName,
          unitType: FoodUnitType.per100g,
          calories: item.estimatedCaloriesPer100g ?? 0.0,
          protein: item.estimatedProteinPer100g ?? 0.0,
          carbs: item.estimatedCarbsPer100g ?? 0.0,
          fat: item.estimatedFatPer100g ?? 0.0,
          isPendingNutrition: item.estimatedCaloriesPer100g == null || item.estimatedCaloriesPer100g == 0,
        );
        await ref.read(foodListProvider.notifier).addFood(food);
      }

      logsToInsert.add(
        MealLog(
          id: uuid.v4(),
          date: widget.targetDate,
          mealType: _mealType,
          foodId: food.id,
          consumedAmount: item.grams,
          portionId: item.portionId,
          portionName: item.portionName,
          portionQuantity: item.portionQuantity,
          createdAt: now,
          food: food,
        ),
      );
    }

    await ref.read(mealLogsProvider.notifier).addMultipleMealLogs(logsToInsert);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${logsToInsert.length} alimento(s) registrado(s) em ${_mealType.detailedLabel}!'),
          backgroundColor: AppTheme.caloriesColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;

    for (final item in _items) {
      totalCalories += item.displayCalories;
      totalProtein += item.displayProtein;
      totalCarbs += item.displayCarbs;
      totalFat += item.displayFat;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arraste
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  widget.isPlanningMode ? Icons.auto_awesome : Icons.mic_none_outlined,
                  color: widget.isPlanningMode ? const Color(0xFF8B5CF6) : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isPlanningMode ? 'Planejamento de Refeição' : 'Revisão do Registro por Voz',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Banner de Metas do Planejamento
          if (widget.isPlanningMode &&
              (widget.targetRemainingProtein != null || widget.targetRemainingCalories != null)) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFF8B5CF6), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Metas Restantes a Bater',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B5CF6)),
                      ),
                      const Spacer(),
                      if (totalProtein >= ((widget.targetRemainingProtein ?? 0) - 1.0))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 12),
                              SizedBox(width: 4),
                              Text('Proteína batida! 🎉', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Proteína: +${widget.targetRemainingProtein?.toStringAsFixed(0) ?? '0'}g ➔ ${totalProtein.toStringAsFixed(1)}g',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.proteinColor),
                      ),
                      Text(
                        'Calorias: +${widget.targetRemainingCalories?.toStringAsFixed(0) ?? '0'} kcal ➔ ${totalCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.caloriesColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Seletor do Tipo de Refeição
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Refeição:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<MealType>(
                    initialValue: _mealType,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    items: MealType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(type.detailedLabel),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _mealType = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Resumo de macros previstos
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroSummary('Calorias', '${totalCalories.toStringAsFixed(0)} kcal', AppTheme.caloriesColor),
                _buildMacroSummary('Proteínas', '${totalProtein.toStringAsFixed(1)}g', AppTheme.proteinColor),
                _buildMacroSummary('Carbos', '${totalCarbs.toStringAsFixed(1)}g', AppTheme.carbsColor),
                _buildMacroSummary('Gorduras', '${totalFat.toStringAsFixed(1)}g', AppTheme.fatColor),
              ],
            ),
          ),

          // Lista de Alimentos Detectados
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            child: _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Nenhum alimento na lista.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isExistingInDb = item.matchedFood != null && !item.matchedFood!.isPendingNutrition;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.matchedFood?.name ?? item.spokenName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _editItemGrams(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            item.displayAmount,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit, size: 14, color: Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Aviso de alimento não cadastrado
                              if (!isExistingInDb)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 14, color: AppTheme.warningColor),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Item não existe no banco.',
                                          style: TextStyle(color: AppTheme.warningColor, fontSize: 11),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _openFoodFormForItem(index),
                                        child: const Text('Definir macros', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              // Resumo de macros do item
                              Row(
                                children: [
                                  Text(
                                    '${item.displayCalories.toStringAsFixed(0)} kcal',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('P: ${item.displayProtein.toStringAsFixed(1)}g', style: const TextStyle(color: AppTheme.proteinColor, fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Text('C: ${item.displayCarbs.toStringAsFixed(1)}g', style: const TextStyle(color: AppTheme.carbsColor, fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Text('G: ${item.displayFat.toStringAsFixed(1)}g', style: const TextStyle(color: AppTheme.fatColor, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Botões de Ação: Gravar mais por voz e Confirmar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                // Botão de adicionar mais itens por voz
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAppendingAudio ? AppTheme.dangerColor : Colors.grey.shade200,
                    foregroundColor: _isAppendingAudio ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessingAudio ? null : _recordMoreAudio,
                  icon: _isProcessingAudio
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isAppendingAudio ? Icons.stop : Icons.mic),
                  label: Text(
                    _isProcessingAudio 
                        ? 'Processando...' 
                        : (_isAppendingAudio ? 'Parar e Anexar' : '+ Falar mais'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão de Confirmação
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _confirmAndSave,
                    child: Text(
                      widget.isPlanningMode ? 'Confirmar Refeição Planejada' : 'Confirmar e Registrar',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
