import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static const String _endpoint = 'https://openrouter.ai/api/v1/chat/completions';

  Future<String> analyzeVehicleImage({
    required String imageUrl,
    required String prompt,
    String model = 'openai/gpt-4o',
  }) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      throw Exception('مفتاح OpenRouter API غير موجود.');
    }

    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      "model": model,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {"url": imageUrl}
            }
          ]
        }
      ]
    });

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? '';
      } else {
        throw Exception('خطأ في التحليل: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('فشل الاتصال: $e');
    }
  }
}
