import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AIService _aiService = AIService();
  String _selectedModel = 'openai/gpt-4o';
  bool _isLoading = true;

  final List<Map<String, String>> _availableModels = const [
    {'id': 'openai/gpt-4o', 'name': 'GPT-4o (OpenAI) - دقة وسرعة عالية'},
    {'id': 'anthropic/claude-3.5-sonnet', 'name': 'Claude 3.5 Sonnet - ممتاز للتفاصيل'},
    {'id': 'meta-llama/llama-3.2-90b-vision-instruct', 'name': 'Llama 3.2 Vision - مفتوح المصدر'},
    {'id': 'google/gemini-flash-1.5', 'name': 'Gemini Flash 1.5 (عبر OpenRouter)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentModel();
  }

  Future<void> _loadCurrentModel() async {
    final current = await _aiService.getSelectedModel();
    setState(() {
      _selectedModel = current;
      _isLoading = false;
    });
  }

  Future<void> _onModelChanged(String? newModel) async {
    if (newModel == null) return;
    setState(() => _selectedModel = newModel);
    await _aiService.setSelectedModel(newModel);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث نموذج الذكاء الاصطناعي بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النموذج')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر نموذج التحليل:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          items: _availableModels.map((model) {
                            return DropdownMenuItem<String>(
                              value: model['id'],
                              child: Text(model['name']!),
                            );
                          }).toList(),
                          onChanged: _onModelChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
