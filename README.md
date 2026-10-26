# My Meal 🥗🎙️

> Aplicativo offline-first em Flutter para rastreamento de calorias e macronutrientes, inspirado no MyFitnessPal, com o diferencial de registro inteligente de refeições por voz utilizando IA multimodal (Google Gemini 1.5 Flash).

---

## ✨ Funcionalidades Principais

- 🎙️ **Registro de Refeições por Voz (Voice Logging)**: Fale o que comeu em linguagem natural (ex: *"50g de arroz, 120g de frango e 1 colher de azeite"*). A IA converte medidas caseiras para gramas e infere a refeição.
- 📋 **BottomSheet de Revisão Inteligente**:
  - Permite revisar e ajustar alimentos e gramas detectados.
  - Botão **"+ Falar mais"** para anexar novos itens ao mesmo registro por voz.
  - Alerta para itens não cadastrados no banco de dados, permitindo cadastrar macros na hora ou salvar com indicador de pendência de dados nutricionais.
- 📊 **Dashboard & Diário**:
  - Acompanhamento diário de Calorias (Meta, Consumido e Restante).
  - Barras de progresso com cores distintas para Proteínas, Carboidratos e Gorduras.
  - Seções organizadas para Café da Manhã, Almoço, Jantar e Lanches, com opção de inserção manual.
- 💾 **100% Offline-first com SQLite**:
  - Todos os dados ficam salvos no seu aparelho sem necessidade de servidor backend.
  - Catálogo inicial pré-carregado com 20 alimentos típicos da culinária brasileira (tabela TACO/IBGE).
- ⚙️ **Metas Personalizadas & Chave Gemini**:
  - Ajuste de metas nutricionais diárias a qualquer momento.
  - Suporte híbrido para carregar a chave de API do Gemini via `.env` ou tela de Ajustes do aplicativo.
- 📦 **Backup, Exportação e Importação de Dados**:
  - **Backup Completo em JSON**: exporte e restaure todos os alimentos, histórico de refeições e metas com 1 clique para não perder seus dados.
  - **Planilhas CSV para Excel / Google Sheets**: exporte seu histórico de refeições e catálogo de alimentos formatados com delimitador `;` e BOM UTF-8 para visualização perfeita no Excel.
  - **Importação em Lote**: importe planilhas CSV de alimentos diretamente para o banco local.

---

## 🛠️ Stack Tecnológica

- **Framework**: [Flutter](https://flutter.dev/) (Dart 3.9+)
- **Gerenciamento de Estado**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Banco de Dados Local**: SQLite (`sqflite` e `sqflite_common_ffi`)
- **Inteligência Artificial**: [Google Generative AI SDK](https://pub.dev/packages/google_generative_ai) (Gemini 1.5 Flash Multimodal)
- **Gravação de Áudio**: [Record](https://pub.dev/packages/record)

---

## 🚀 Como Executar

### Pré-requisitos
- Flutter 3.35+ instalado
- (Opcional) Chave de API do Google Gemini (gratuita em [Google AI Studio](https://aistudio.google.com/))

### Passos

1. Clone o repositório:
```bash
git clone https://github.com/gsf4/my-meal.git
cd my-meal
```

2. Obtenha as dependências:
```bash
flutter pub get
```

3. (Opcional) Configure sua API Key no `.env`:
```bash
cp .env.example .env
# Adicione sua chave no arquivo .env
```
*(Você também pode inserir a chave diretamente pela aba de Ajustes no aplicativo!)*

4. Execute o app:
```bash
flutter run
```

---

## 🧪 Testes

Para rodar a suíte de testes unitários:
```bash
flutter test
```
