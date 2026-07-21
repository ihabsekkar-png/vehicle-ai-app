import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/ai_service.dart';

class VehicleController {
  final AIService _aiService = AIService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> ensureAuthenticated() async {
    User? user = _auth.currentUser;
    if (user == null) {
      final userCredential = await _auth.signInAnonymously();
      user = userCredential.user;
    }
    return user;
  }

  Future<String> executeFullScan({
    required File imageFile,
    required String prompt,
  }) async {
    final user = await ensureAuthenticated();
    final userId = user?.uid ?? 'anonymous_user';

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageRef = _storage.ref().child('vehicles/$userId/$timestamp.jpg');
    
    final uploadTask = await storageRef.putFile(imageFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final analysisResult = await _aiService.analyzeVehicleImage(
      imageUrl: downloadUrl,
      prompt: prompt,
    );

    await _firestore.collection('vehicle_analyses').add({
      'userId': userId,
      'imageUrl': downloadUrl,
      'prompt': prompt,
      'analysisResult': analysisResult,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return analysisResult;
  }
}
