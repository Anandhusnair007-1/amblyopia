import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  void setToken(String token) {
    _token = token;
  }

  Future<bool> isOnline() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<http.Response> post(String url, Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(String url) async {
    return await http.get(
      Uri.parse(url),
      headers: _headers(),
    );
  }
}
