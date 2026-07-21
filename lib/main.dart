import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const VehicleAIApp());
}

class VehicleAIApp extends StatelessWidget {
  const VehicleAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle AI Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _result = '';
  bool _isLoading = false;

  // جلب مفتاح API الممرر من GitHub Actions
  final String _apiKey = const String.fromEnvironment('OPENROUTER_API_KEY');

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _result = '';
        });
      }
    } catch (e) {
      _showSnackBar('خطأ في التقاط الصورة: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    if (_apiKey.isEmpty) {
      _showSnackBar('مفتاح OPENROUTER_API_KEY غير معرف في GitHub Secrets');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      const promptText = '''
أنت خبير معاينة تقنية وهياكل سيارات (Vehicle Inspector). 
قم بتحليل صورة المركبة المرفقة بأسلوب تقني دقيق ومبسط باللغة العربية:
1. نوع السيارة وطرازها ولونها.
2. حالة الهيكل الخارجي (صدمات، خدوش، انبعاجات).
3. تقييم الأضرار (طفيف / متوسط / جسيم) ومكانها.
4. التوصيات والإصلاحات المطلوبة.
5. التقييم العام للمركبة من 10/10.
''';

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "openai/gpt-4o",
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": promptText},
                {
                  "type": "image_url",
                  "image_url": {"url": dataUrl}
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        setState(() {
          _result = data['choices'][0]['message']['content'];
        });
      } else {
        _showSnackBar('خطأ من الخادم: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('فشل الاتصال: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص السيارات بالذكاء الاصطناعي'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('التقط أو اختر صورة للمركبة'),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('الكاميرا'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('المعرض'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedImage == null || _isLoading) ? null : _analyzeImage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('بدء التحليل الفني', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            if (_result.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _result,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
