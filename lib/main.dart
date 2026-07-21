import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VehicleAIApp());
}

class VehicleAIApp extends StatelessWidget {
  const VehicleAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خبير معاينة السيارات الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E3A8A),
        brightness: Brightness.light,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyData = prefs.getString('scan_history');
    if (historyData != null) {
      final List<dynamic> decoded = jsonDecode(historyData);
      setState(() {
        _history.clear();
        _history.addAll(decoded.map((e) => Map<String, String>.from(e)));
      });
    }
  }

  Future<void> _saveToHistory(String result, String modelUsed) async {
    final prefs = await SharedPreferences.getInstance();
    final newEntry = {
      'date': DateTime.now().toString().substring(0, 16),
      'model': modelUsed,
      'report': result,
    };
    setState(() {
      _history.insert(0, newEntry);
    });
    await prefs.setString('scan_history', jsonEncode(_history));
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
    setState(() {
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onScanCompleted: _saveToHistory),
      HistoryScreen(history: _history, onClear: _clearHistory),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'فحص جديد',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'سجل الفحوصات',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(String result, String model) onScanCompleted;
  const HomeScreen({Key? key, required this.onScanCompleted}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _result = '';
  bool _isLoading = false;

  String _selectedModel = 'openai/gpt-4o';
  final Map<String, String> _models = {
    'openai/gpt-4o': 'GPT-4o (الأعلى دقة وتحليلاً)',
    'anthropic/claude-3.5-sonnet': 'Claude 3.5 Sonnet (دقيق للتفاصيل)',
    'google/gemini-flash-1.5': 'Gemini Flash 1.5 (سريع جداً)',
    'meta-llama/llama-3.2-90b-vision-instruct': 'Llama 3.2 Vision (مفتوح المصدر)',
  };

  final String _apiKey = const String.fromEnvironment('OPENROUTER_API_KEY');

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _result = '';
        });
      }
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء اختيار الصورة: $e');
    }
  }

  Future<void> _analyzeVehicle() async {
    if (_selectedImage == null) return;

    if (_apiKey.isEmpty) {
      _showSnackBar('مفتاح API غير متوفر. تأكد من ضبط OPENROUTER_API_KEY في GitHub Secrets.');
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

      const systemPrompt = '''
أنت خبير معاينة تقنية وهياكل سيارات (Senior Vehicle Loss Adjuster & Inspector). 
قم بتحليل صورة المركبة المرفقة بأسلوب تقني دقيق ومبسط باللغة العربية، واتبع التنسيق التالي:

1. 🚗 **تحديد المركبة:**
   - نوع السيارة وطرازها (إن أمكن).
   - اللون الخارجي ونوع الطلاء.

2. 🔍 **معاينة الهيكل الخارجي (Bodywork):**
   - حالة الصدمات أو الانبعاجات (Dents).
   - الخدوش أو الاحتكاكات (Scratches).
   - حالة الأضواء والزجاج والمرايا.

3. ⚠️ **تقييم الأضرار:**
   - درجة الضرر: (طفيف / متوسط / جسيم).
   - تحديد موقع الضرر بدقة (مثال: المصد الأمامي الأيمن...).

4. 🛠️ **التوصيات والإصلاح:**
   - القطع التي تحتاج سمكرة/تقويم.
   - القطع التي تحتاج طلاء.
   - القطع التي تتطلب الاستبدال.

5. 📊 **التقييم العام:**
   - إعطاء درجة للحالة العامة للمركبة من 10/10.
''';

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://github.com/ihabsekkar-png/vehicle-ai-app',
          'X-Title': 'Vehicle AI Inspector Pro',
        },
        body: jsonEncode({
          "model": _selectedModel,
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": systemPrompt},
                {
                  "type": "image_url",
                  "image_url": {"url": dataUrl}
                }
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        final content = data['choices'][0]['message']['content'] ?? 'لم يتم الحصول على إجابة.';
        
        setState(() {
          _result = content;
        });

        widget.onScanCompleted(content, _models[_selectedModel] ?? _selectedModel);
      } else {
        _showSnackBar('خطأ من سيرفر الذكاء الاصطناعي (${response.statusCode})');
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص السيارات بالذكاء الاصطناعي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // اختيار نموذج الذكاء الاصطناعي
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          items: _models.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedModel = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // صندوق معاينة الصورة
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 54, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text(
                            'اضغط هنا لالتقاط أو اختيار صورة المركبة',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار التحكّم
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('الكاميرا'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('المعرض'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // زر بدء الفحص الشامل
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_selectedImage == null || _isLoading) ? null : _analyzeVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: Text(
                  _isLoading ? 'جاري تحليل هيكل المركبة...' : 'بدء التقرير الفني الشامل',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // عرض نتيجة التقرير
            if (_result.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_turned_in, color: Colors.green),
                              SizedBox(width: 8),
                              Text('تقرير المعاينة الفنية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _result));
                              _showSnackBar('تم نسخ التقرير إلى الحافظة');
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      SelectableText(
                        _result,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('التقاط بواسطة الكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<Map<String, String>> history;
  final VoidCallback onClear;

  const HistoryScreen({Key? key, required this.history, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الفحوصات السابقة'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('مسح السجل'),
                    content: const Text('هل أنت تأكد من مسح جميع التقارير المحفوظة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                      TextButton(
                        onPressed: () {
                          onClear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('مسح', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            )
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('لا توجد تقارير فحوصات محفوظة بعد.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const Icon(Icons.article, color: Colors.blue),
                    title: Text(item['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('النموذج: ${item['model'] ?? ''}', style: const TextStyle(fontSize: 12)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SelectableText(item['report'] ?? ''),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
