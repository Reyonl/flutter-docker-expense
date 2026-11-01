import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';

abstract class ExpenseApiClient {
  Future<FinancialSummary> fetchSummary();
  Future<List<ExpenseTransaction>> fetchTransactions({
    String? type,
    String? search,
  });
  Future<ExpenseTransaction> createTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  });
  Future<void> deleteTransaction(int id);
}

class HttpExpenseApiClient implements ExpenseApiClient {
  final String baseUrl;
  final http.Client _client;

  HttpExpenseApiClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:4000/api',
            ),
        _client = client ?? http.Client();

  @override
  Future<FinancialSummary> fetchSummary() async {
    final uri = Uri.parse('$baseUrl/summary');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat ringkasan (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FinancialSummary.fromJson(data);
  }

  @override
  Future<List<ExpenseTransaction>> fetchTransactions({
    String? type,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (type != null && type.isNotEmpty && type != 'all') {
      queryParams['type'] = type;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('$baseUrl/transactions').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat daftar transaksi (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ExpenseTransaction.fromJson)
        .toList();
  }

  @override
  Future<ExpenseTransaction> createTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final uri = Uri.parse('$baseUrl/transactions');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'amount': amount,
        'type': type,
        'category': category,
        'note': note,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      final errMsg = (data['error'] as String?) ?? 'Gagal menyimpan transaksi';
      throw Exception(errMsg);
    }
    return ExpenseTransaction.fromJson(data['item'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final uri = Uri.parse('$baseUrl/transactions/$id');
    final response = await _client.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus transaksi (${response.statusCode})');
    }
  }
}
