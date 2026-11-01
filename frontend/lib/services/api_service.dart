import 'dart:convert';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
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
  Future<ExpenseTransaction> updateTransaction({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  });
  Future<void> deleteTransaction(int id);
  Future<void> flushRedisCache();
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
  Future<ExpenseTransaction> updateTransaction({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final uri = Uri.parse('$baseUrl/transactions/$id');
    final response = await _client.put(
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
    if (response.statusCode != 200) {
      final errMsg = (data['error'] as String?) ?? 'Gagal memperbarui transaksi';
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

  @override
  Future<void> flushRedisCache() async {
    final uri = Uri.parse('$baseUrl/cache/flush');
    final response = await _client.post(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal mengosongkan Redis cache (${response.statusCode})');
    }
  }
}

/// Client langsung ke Google Cloud Firestore (`dompetku-4a2e1`)
/// menggunakan konfigurasi dari `DefaultFirebaseOptions.currentPlatform`.
/// Memungkinkan aplikasi berjalan di Android/Web produksi tanpa butuh VPS Docker.
class FirebaseExpenseApiClient implements ExpenseApiClient {
  final FirebaseOptions options;
  final http.Client _client;

  FirebaseExpenseApiClient({
    FirebaseOptions? options,
    http.Client? client,
  })  : options = options ?? DefaultFirebaseOptions.currentPlatform,
        _client = client ?? http.Client();

  String get _collectionUrl =>
      'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/transactions';

  Map<String, dynamic> _toFirestoreFields({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    required String note,
    required String createdAt,
  }) {
    return {
      'fields': {
        'id': {'integerValue': id.toString()},
        'title': {'stringValue': title},
        'amount': {'doubleValue': amount},
        'type': {'stringValue': type},
        'category': {'stringValue': category},
        'note': {'stringValue': note},
        'createdAt': {'stringValue': createdAt},
      },
    };
  }

  ExpenseTransaction _fromFirestoreDoc(Map<String, dynamic> doc) {
    final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
    final docName = (doc['name'] as String?) ?? '';

    int id = 0;
    final idField = fields['id'] as Map<String, dynamic>?;
    if (idField != null && idField['integerValue'] != null) {
      id = int.tryParse(idField['integerValue'].toString()) ?? 0;
    } else if (docName.isNotEmpty) {
      final tail = docName.split('/').last.replaceAll('tx_', '');
      id = int.tryParse(tail) ?? 0;
    }

    double amount = 0;
    final amountField = fields['amount'] as Map<String, dynamic>?;
    if (amountField != null) {
      if (amountField['doubleValue'] != null) {
        amount = (amountField['doubleValue'] as num).toDouble();
      } else if (amountField['integerValue'] != null) {
        amount = double.tryParse(amountField['integerValue'].toString()) ?? 0;
      }
    }

    String readString(String key, [String fallback = '']) {
      final f = fields[key] as Map<String, dynamic>?;
      return (f?['stringValue'] as String?) ?? fallback;
    }

    return ExpenseTransaction(
      id: id,
      title: readString('title', 'Tanpa Judul'),
      amount: amount,
      type: readString('type', 'expense'),
      category: readString('category', 'Lainnya'),
      note: readString('note', ''),
      createdAt: readString(
        'createdAt',
        (doc['createTime'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  @override
  Future<List<ExpenseTransaction>> fetchTransactions({
    String? type,
    String? search,
  }) async {
    final uri = Uri.parse('$_collectionUrl?pageSize=200&key=${options.apiKey}');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Gagal memuat dari Firebase Firestore (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List<dynamic>?) ?? const [];
    var items = docs
        .whereType<Map<String, dynamic>>()
        .map(_fromFirestoreDoc)
        .toList();

    items.sort((a, b) => b.id.compareTo(a.id));

    if (type != null && type.isNotEmpty && type != 'all') {
      items = items.where((tx) => tx.type == type).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      items = items.where((tx) {
        return tx.title.toLowerCase().contains(q) ||
            tx.category.toLowerCase().contains(q) ||
            tx.note.toLowerCase().contains(q);
      }).toList();
    }

    return items;
  }

  @override
  Future<FinancialSummary> fetchSummary() async {
    final allItems = await fetchTransactions();
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, CategoryBreakdown> catMap = {};

    for (final tx in allItems) {
      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
      final key = '${tx.type}:${tx.category}';
      final prev = catMap[key];
      if (prev == null) {
        catMap[key] = CategoryBreakdown(
          category: tx.category,
          type: tx.type,
          total: tx.amount,
          count: 1,
        );
      } else {
        catMap[key] = CategoryBreakdown(
          category: prev.category,
          type: prev.type,
          total: prev.total + tx.amount,
          count: prev.count + 1,
        );
      }
    }

    final byCategory = catMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return FinancialSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      transactionCount: allItems.length,
      byCategory: byCategory,
      containerId: 'firebase:${options.projectId}',
      cacheStatus: 'CLOUD',
      redisConnected: true,
    );
  }

  @override
  Future<ExpenseTransaction> createTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 1000000000;
    final createdAt = DateTime.now().toUtc().toIso8601String();
    return upsertTransaction(
      ExpenseTransaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        category: category,
        note: note,
        createdAt: createdAt,
      ),
    );
  }

  Future<ExpenseTransaction> upsertTransaction(ExpenseTransaction tx) async {
    final uri = Uri.parse('$_collectionUrl/tx_${tx.id}?key=${options.apiKey}');
    final response = await _client.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(
        _toFirestoreFields(
          id: tx.id,
          title: tx.title,
          amount: tx.amount,
          type: tx.type,
          category: tx.category,
          note: tx.note,
          createdAt: tx.createdAt,
        ),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Gagal menyimpan ke Firebase Firestore (${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromFirestoreDoc(data);
  }

  @override
  Future<ExpenseTransaction> updateTransaction({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    String note = '',
  }) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();
    return upsertTransaction(
      ExpenseTransaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        category: category,
        note: note,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final uri = Uri.parse('$_collectionUrl/tx_$id?key=${options.apiKey}');
    final response = await _client.delete(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Gagal menghapus dari Firebase Firestore (${response.statusCode})',
      );
    }
  }

  @override
  Future<void> flushRedisCache() async {
    // Pada mode Firebase Cloud, data langsung diambil real-time dari Firestore.
    return;
  }

  /// Menyalin daftar transaksi dari Docker PostgreSQL ke Firebase Cloud Firestore.
  Future<int> syncFromDocker(List<ExpenseTransaction> items) async {
    int count = 0;
    for (final tx in items) {
      await upsertTransaction(tx);
      count++;
    }
    return count;
  }
}
