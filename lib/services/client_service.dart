import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import '../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientService {
  final String baseUrl = ApiConstants.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<ClientModel>> getActiveClients() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/clients/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => ClientModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('خطأ في جلب العملاء: $e');
      return [];
    }
  }
}