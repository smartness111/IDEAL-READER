class Book {
  final String id;
  final String title;
  final String filePath;
  final String format; // 'txt' or 'epub'
  int lastChunkIndex;

  Book({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    this.lastChunkIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'format': format,
        'lastChunkIndex': lastChunkIndex,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['filePath'] as String,
        format: json['format'] as String,
        lastChunkIndex: (json['lastChunkIndex'] as num?)?.toInt() ?? 0,
      );
}
