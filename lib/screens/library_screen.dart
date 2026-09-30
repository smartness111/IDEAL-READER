import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/library_service.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _library = LibraryService();
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final books = await _library.loadBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  static const _supportedExtensions = [
    'txt',
    'epub',
    'docx',
    'pdf',
    'jpg',
    'jpeg',
    'png',
  ];

  Future<void> _addBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    final format = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'txt';
    final title = fileName.replaceAll(
      RegExp(r'\.(txt|epub|docx|pdf|jpe?g|png)$', caseSensitive: false),
      '',
    );

    try {
      await _library.addBook(sourcePath: path, title: title, format: format);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add that file: $e')),
      );
    }
  }

  Future<void> _removeBook(Book book) async {
    await _library.removeBook(book.id);
    await _refresh();
  }

  IconData _iconFor(String format) {
    switch (format) {
      case 'epub':
        return Icons.menu_book;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.article;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Books')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No books yet.\nTap + to add a .txt, .epub, .docx, '
                      '.pdf, or image (.jpg/.png) file.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return ListTile(
                      leading: Icon(_iconFor(book.format)),
                      title: Text(book.title),
                      subtitle: Text(book.format.toUpperCase()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeBook(book),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(book: book),
                          ),
                        );
                        _refresh();
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBook,
        tooltip: 'Add a book',
        child: const Icon(Icons.add),
      ),
    );
  }
}
