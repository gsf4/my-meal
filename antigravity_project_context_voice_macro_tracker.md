# Projeto: Voice Macro Tracker (Clone Inteligente do MyFitnessPal)

## 1. Visão Geral
O objetivo deste projeto é desenvolver um aplicativo mobile em Flutter focado no rastreamento de calorias e macronutrientes (proteínas, carboidratos e gorduras). O app terá uma interface semelhante ao MyFitnessPal, mas será totalmente offline (usando Local Storage) e contará com um grande diferencial: **registro de refeições por comando de voz processado por IA (Google API/LLM)**.

## 2. Stack Tecnológica
*   **Framework:** Flutter (Dart).
*   **Armazenamento Local:** Banco de dados local (sugestão: Isar, Hive ou SQLite) para persistência de dados sem necessidade de backend.
*   **Integração de IA:** API do Google (Gemini 1.5 Pro/Flash ou Google Speech-to-Text + LLM) para transcrição e extração de dados estruturados a partir do áudio do usuário.
*   **Gerenciamento de Estado:** À escolha da IA (sugestão: Riverpod, Provider ou Bloc).

## 3. Requisitos Funcionais Principais

### 3.1. Dashboard Principal (Visão Diária)
*   Exibição do progresso diário de calorias e macronutrientes.
*   Gráficos ou barras de progresso mostrando: Consumido vs. Restante.
*   Lista das refeições do dia (Café da manhã, Almoço, Janta, Lanches).

### 3.2. Banco de Dados de Alimentos
*   **Importação Inicial:** O app deve prever uma forma de importar um JSON ou CSV inicial com os alimentos mais comuns (ex: arroz, feijão, frango, ovo, aveia).
*   **Adição Manual:** Tela para o usuário cadastrar novos alimentos.
*   **Estrutura da Tabela Nutricional:** Os dados devem ser baseados em porções de 1g ou 100g para facilitar o cálculo multiplicativo na hora de registrar a refeição.

### 3.3. O Grande Diferencial: Registro por Áudio (Voice Logging)
*   Um botão de microfone proeminente na tela inicial.
*   O usuário grava um áudio (ex: "Comi 200 gramas de arroz branco, 150 gramas de peito de frango grelhado e uma colher de azeite").
*   O áudio é enviado para a API do Google, que processa a linguagem natural e retorna um JSON estruturado com os alimentos e as quantidades identificadas.
*   O app cruza esses dados com o banco de dados local e registra a refeição automaticamente, ou pede confirmação caso o alimento não exista.

## 4. Modelagem de Dados Sugerida (Entidades)

*   **Food (Alimento):**
    *   `id` (String/Int)
    *   `name` (String)
    *   `caloriesPer100g` (Double)
    *   `proteinPer100g` (Double)
    *   `carbsPer100g` (Double)
    *   `fatPer100g` (Double)

*   **MealLog (Registro de Refeição):**
    *   `id` (String/Int)
    *   `date` (DateTime)
    *   `foodId` (Relacionamento)
    *   `consumedGrams` (Double)
    *   `mealType` (Enum: Breakfast, Lunch, Dinner, Snack)

*   **DailyGoal (Meta Diária):**
    *   `calories` (Double) - Ex: 2575
    *   `protein` (Double) - Ex: 171
    *   `carbs` (Double) - Ex: 281
    *   `fat` (Double) - Ex: 85

## 5. Plano de Ação para o Antigravity (Fases de Desenvolvimento)

*   **Fase 1: Setup e Infraestrutura Local:** Criar o projeto Flutter, configurar o banco de dados local escolhido e criar os modelos de dados.
*   **Fase 2: Gestão de Alimentos (CRUD):** Criar as telas e lógicas para listar, adicionar e buscar alimentos no banco local, incluindo um script de seed (dados iniciais).
*   **Fase 3: Dashboard e Registro Manual:** Desenvolver a tela principal com os cálculos de macros diários (consumido vs restante) e permitir o registro manual de refeições.
*   **Fase 4: Integração de Áudio e LLM:** Implementar a gravação de áudio, conexão com a API do Google, prompt de extração de dados e o parse da resposta para cadastrar a refeição magicamente.