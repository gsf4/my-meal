import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_meal/core/services/gemini_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiVoiceService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('listAvailableModels filtra apenas modelos com generateContent e remove prefixo models/', () async {
      final mockClient = MockClient((request) async {
        final sampleResponse = {
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'supportedGenerationMethods': ['generateContent', 'countTokens'],
            },
            {
              'name': 'models/text-embedding-004',
              'supportedGenerationMethods': ['embedContent'],
            },
            {
              'name': 'models/gemini-2.0-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
          ]
        };
        return http.Response(jsonEncode(sampleResponse), 200);
      });

      final service = GeminiVoiceService(httpClient: mockClient);
      final models = await service.listAvailableModels('fake-api-key');

      expect(models.length, 2);
      expect(models.contains('gemini-2.5-flash'), isTrue);
      expect(models.contains('gemini-2.0-flash'), isTrue);
      expect(models.contains('text-embedding-004'), isFalse);
    });

    test('resolveBestModel prioriza modelos Flash 3.8 e salva em cache', () async {
      final mockClient = MockClient((request) async {
        final sampleResponse = {
          'models': [
            {
              'name': 'models/gemini-3.5-flash-lite',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-3.8-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-pro',
              'supportedGenerationMethods': ['generateContent'],
            },
          ]
        };
        return http.Response(jsonEncode(sampleResponse), 200);
      });

      final service = GeminiVoiceService(httpClient: mockClient);
      final bestModel = await service.resolveBestModel('fake-api-key');

      expect(bestModel, 'gemini-3.8-flash');

      // Verifica se salvou nas SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gemini_model'), 'gemini-3.8-flash');
    });

    test('resolveBestModel ignora modelos legados no cache (como gemini-1.5-flash e 2.5-flash)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_model', 'gemini-2.5-flash');

      final mockClient = MockClient((request) async {
        final sampleResponse = {
          'models': [
            {
              'name': 'models/gemini-3.8-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
          ]
        };
        return http.Response(jsonEncode(sampleResponse), 200);
      });

      final service = GeminiVoiceService(httpClient: mockClient);
      final bestModel = await service.resolveBestModel('fake-api-key');

      expect(bestModel, 'gemini-3.8-flash');
    });
  });
}
