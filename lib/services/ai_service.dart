import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  static const String _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _defaultModel = 'openai/gpt-4o';
  static const String _prefModelKey = 'selected_ai_model';

  /// جلب النموذج المختار من الإعدادات
  Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefModelKey) ?? _defaultModel;
    } catch (_) {
      return _defaultModel;
    }
  }

  /// حفظ النموذج في الإعدادات
  Future<bool> setSelectedModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_prefModelKey, modelId);
  }

  /// إرسال الصورة المرفوعة مع الطلب إلى OpenRouter
  Future<String> analyzeVehicleImage({
    required String imageUrl,
    required String prompt,
  }) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';

    if (apiKey.trim().isEmpty) {
      throw Exception('مفتاح API غير موجود. تأكد من إعداد OPENROUTER_API_KEY.');
    }

    final selectedModel = await getSelectedModel();

    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${apiKey.trim()}',
      'HTTP-Referer': 'https://github.com/ihabsekkar-png/vehicle-ai-app',
      'X-Title': 'Vehicle AI Scan Professional App',
    };

    final requestBody = jsonEncode({
      "model": selectedModel,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": prompt
            },
            {
              "type": "image_url",
              "image_url": {
                "url": imageUrl
              }
            }
          ]
        }
      ]
    });

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: requestBody,
      );

      final decodedResponseBody = utf8.decode(response.bodyBytes);
      final jsonResponse = jsonDecode(decodedResponseBody) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final choices = jsonResponse['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return content.trim();
          }
        }
        throw Exception('الاستجابة من الذكاء الاصطناعي فارغة.');
      } else {
        final error = jsonResponse['error'] as Map<String, dynamic>?;
        final errorMessage = error?['message'] ?? 'رمز الخطأ: ${response.statusCode}';
        throw Exception('خطأ OpenRouter: $errorMessage');
      }
    } catch (e) {
      throw Exception('فشل الاتصال بالذكاء الاصطناعي: $e');
    }
  }
}
