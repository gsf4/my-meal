# AGENTS.md — Guia de Desenvolvimento para Agentes de IA

Este documento contém o contexto de arquitetura, padrões de projeto, convenções de código e instruções operacionais para agentes autônomos de IA que colaboram no desenvolvimento do **My Meal**.

---

## 1. Visão Geral do Projeto

* **Nome do Projeto**: My Meal
* **Objetivo**: Aplicativo mobile em Flutter para rastreamento de calorias e macronutrientes (proteínas, carboidratos e gorduras), com interface inspirada no MyFitnessPal.
* **Premissa Central**: **100% Offline-first** com banco de dados local SQLite (sem necessidade de backend central para dados do usuário).
* **Grande Diferencial**: **Registro Inteligente de Refeições por Voz (Voice Logging)** com processamento multimodal direto no Google Gemini 1.5 Flash.

---

## 2. Stack Tecnológica

| Camada | Tecnologia | Detalhes |
| :--- | :--- | :--- |
| **Linguagem & Framework** | Dart 3.9+ / Flutter 3.35+ | Gerenciado via FVM (`C:\Users\gabri\fvm\versions\3.35.0\bin\flutter.bat`) |
| **Gerenciamento de Estado** | `flutter_riverpod` | StateNotifier, Notifier e Providers imutáveis |
| **Banco de Dados Local** | `sqflite` + `sqflite_common_ffi` | Suporte nativo para Android, iOS e Windows Desktop |
| **Inteligência Artificial** | `google_generative_ai` | Gemini Flash Multimodal (`gemini-2.5-flash` com detecção dinâmica e fallback) |
| **Gravação de Áudio** | `record` | Formato `.m4a` / AAC em 44.1kHz / 128kbps |
| **Persistência de Ajustes** | `shared_preferences` | Metas diárias e Chave de API do usuário |
| **Internacionalização** | `intl` | Datas e números formatados em português brasileiro (`pt_BR`) |

---

## 3. Estrutura de Diretórios

```text
myMeal/
├── lib/
│   ├── main.dart                                # Ponto de entrada, casca de navegação (IndexedStack) e temas
│   ├── core/
│   │   ├── constants/app_constants.dart         # Metas padrão, chaves de SharedPreferences e modelos
│   │   ├── theme/app_theme.dart                 # Paleta de macros (P, C, G), temas Light e Dark
│   │   ├── database/database_helper.dart        # Inicialização do SQLite, tabelas e seed de 20 alimentos TACO
│   │   └── services/
│   │       ├── audio_recorder_service.dart      # Gravação do microfone com o pacote record
│   │       ├── gemini_voice_service.dart        # Envio multimodal do áudio para o Gemini e parse do JSON
│   │       └── backup_service.dart              # Backup/Restauração JSON e exportação/importação CSV
│   └── features/
│       ├── foods/                               # Catálogo e CRUD de alimentos
│       │   ├── models/food_item.dart            # Entidade FoodItem com cálculo de proporção (100g vs 1g)
│       │   ├── repositories/food_repository.dart# Consultas SQLite e matching fonético/textual
│       │   ├── providers/food_providers.dart    # Riverpod Notifiers para alimentos
│       │   └── presentation/screens/            # FoodListScreen e FoodFormDialog
│       ├── meals/                               # Registro de refeições e cálculo diário
│       │   ├── models/meal_type.dart            # Enum: breakfast, lunch, dinner, snack + deduções de horário
│       │   ├── models/meal_log.dart             # Entidade MealLog com JOIN ao FoodItem
│       │   ├── repositories/meal_repository.dart# Consultas agregadas por data
│       │   ├── providers/meal_providers.dart    # Estado da data selecionada e cálculo de totais
│       │   └── presentation/                    # ManualAddMealDialog e componentes
│       ├── dashboard/                           # Tela principal (Diário)
│       │   └── presentation/
│       │       ├── screens/dashboard_screen.dart# Visualização do dia, navegação de datas e cards
│       │       └── widgets/                     # CalorieSummaryCard, MacroProgressCard, MealSectionCard
│       ├── voice_logging/                       # Fluxo de voz com IA
│       │   ├── models/voice_meal_result.dart    # Modelos do retorno da IA e itens detectados
│       │   └── presentation/widgets/            # VoiceRecordButton e VoiceReviewBottomSheet
│       └── settings/                            # Metas diárias e API Key
│           ├── models/daily_goal.dart           # Entidade DailyGoal
│           ├── repositories/settings_repository.dart # Carregamento híbrido de chave (.env + prefs)
│           ├── providers/settings_providers.dart# Providers de metas e progresso
│           └── presentation/screens/settings_screen.dart
├── test/
│   ├── macro_calculation_test.dart              # Testes unitários de proporção, MealType e metas
│   └── widget_test.dart                         # Teste de montagem do app
├── pubspec.yaml
└── .env.example                                 # Modelo para configuração da GEMINI_API_KEY
```

---

## 4. Regras de Negócio e Convenções Cruciais

### 4.1. Cálculos de Proporcionalidade dos Alimentos
* Todo `FoodItem` possui uma unidade base (`unitType`):
  - `FoodUnitType.per100g`: O cálculo de calorias e macros para uma quantidade `x` em gramas deve ser sempre `valor * (x / 100.0)`.
  - `FoodUnitType.per1g`: O cálculo de calorias e macros para `x` em gramas deve ser `valor * x`.
* Nunca assuma gramas como valor fixo sem aplicar o fator correspondente à unidade.

### 4.2. Tratamento de Alimentos Identificados por Voz
* Se o alimento falado der match com o banco de dados local (`FoodRepository.findBestMatch`), associa o `FoodItem` local existente.
* Se o alimento **não constar no banco**:
  - Exibir badge de alerta no BottomSheet de revisão (*"Item não existe no banco"*).
  - O usuário pode tocar no aviso para definir nome, calorias, macros e unidade (100g ou 1g).
  - Caso o usuário confirme a refeição sem preencher os macros, o alimento **deve ser criado automaticamente no banco local**, porém marcado com `isPendingNutrition = true`, exibindo um indicador visual no Dashboard e na lista de alimentos para que possa ser completado depois sem travar o fluxo.

### 4.3. Fluxo de Áudio & IA
* **Multimodal Direto**: O áudio gravado em `.m4a` é enviado como `DataPart('audio/m4a', bytes)` diretamente ao Gemini Flash (com modelo ativo resolvido dinamicamente via `GeminiVoiceService`).
* Não use serviços externos de Speech-to-Text se puder utilizar a entrada de áudio multimodal do Gemini, pois isso preserva nuances coloquiais e culinárias em português.
* **Revisão Obrigatória**: O áudio nunca deve registrar a refeição silenciosamente; ele sempre abre o `VoiceReviewBottomSheet` para permitir que o usuário confira ou use o botão **"+ Falar mais"** para anexar novos itens à mesma refeição.

### 4.4. Segurança & Chaves de API
* **NUNCA** commite chaves de API, senhas ou tokens no repositório.
* O arquivo `.env` está explicitamente no `.gitignore`.
* A recuperação da chave do Gemini segue a ordem:
  1. `SharedPreferences` (chave cadastrada pelo usuário na tela de Ajustes);
  2. Arquivo `.env` local (`dotenv.env['GEMINI_API_KEY']`);
  3. Parâmetro `--dart-define=GEMINI_API_KEY=xxx`.

### 4.5. Backup, Exportação e Importação de Dados
* **Formato JSON (Lossless)**: Utilizado para backup integral de segurança (`foods`, `meal_logs` e `daily_goals`). Não altera IDs e utiliza `ConflictAlgorithm.replace` ao restaurar para evitar duplicações.
* **Formato CSV (Excel/Sheets)**:
  - Todas as exportações para planilhas devem conter o cabeçalho com delimitador `;` e o marcador BOM UTF-8 (`\uFEFF`) para evitar problemas de caracteres e acentos no Microsoft Excel em português brasileiro.
  - A importação CSV aceita separadores `;` ou `,` e faz a leitura resiliente de números decimais com vírgula ou ponto.

---

## 5. Diretrizes para Modificações de Código por Agentes

1. **Integridade de Documentação**: Mantenha os comentários explicativos e a integridade da arquitetura em camadas (`core` vs `features`).
2. **Compatibilidade Multiplataforma**: Mantenha o suporte a Windows Desktop via `sqflite_common_ffi` e `Platform.isWindows` para permitir testes rápidos sem emulador.
3. **Validação Obrigatória**:
   - Sempre execute `flutter analyze` após alterar arquivos para garantir **0 erros** e nenhum warning novo.
   - Sempre execute `flutter test` para validar a suíte de testes unitários.
4. **Novas Features**:
   - Ao adicionar novos campos ou tabelas no SQLite, use migrations no `DatabaseHelper` ou incremente a versão do banco com fallback adequado.
