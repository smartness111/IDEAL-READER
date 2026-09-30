import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

/// Keeps track of which books the user has added, where the app's own
/// copy of each file lives, and how far the user got in each one.
class LibraryService {
  static const _prefsKey = 'library_books_v1';

  Future<List<Book>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  /// Copies the picked file into the app's own storage so it keeps working
  /// even if the user moves or deletes the original file.
  Future<Book> addBook({
    required String sourcePath,
    required String title,
    required String format,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(docsDir.path, 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final destPath = p.join(booksDir.path, '$id.$format');
    await File(sourcePath).copy(destPath);

    final book = Book(id: id, title: title, filePath: destPath, format: format);
    final books = await loadBooks();
    books.add(book);
    await _saveBooks(books);
    return book;
  }

  Future<void> updateProgress(String id, int chunkIndex) async {
    final books = await loadBooks();
    final idx = books.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    books[idx].lastChunkIndex = chunkIndex;
    await _saveBooks(books);
  }

  Future<void> removeBook(String id) async {
    final books = await loadBooks();
    final idx = books.indexWhere((b) => b.id == id);
    if (idx == -1) return;

    final book = books[idx];
    final file = File(book.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    books.removeAt(idx);
    await _saveBooks(books);
  }
}
