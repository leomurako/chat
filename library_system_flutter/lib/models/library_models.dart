enum UserRole { user, admin }

enum ReservationStatus { reserved, delivered, returned }

enum RequestStatus { pending, approved, rejected }

class LibraryUser {
  const LibraryUser({
    required this.id,
    required this.role,
    required this.name,
    required this.password,
    this.className,
    this.studentNumber,
    this.adminName,
  });

  final String id;
  final UserRole role;
  final String name;
  final String password;
  final String? className;
  final int? studentNumber;
  final String? adminName;

  String get displayLabel {
    if (role == UserRole.admin) {
      return adminName ?? name;
    }

    final classPart = className ?? "";
    final numberPart = studentNumber == null ? "" : "${studentNumber!}番";
    return "$classPart $numberPart $name".trim();
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.genre,
    required this.author,
    required this.publisher,
    required this.totalCopies,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String genre;
  final String author;
  final String publisher;
  final int totalCopies;
  final bool isActive;

  Book copyWith({
    String? id,
    String? title,
    String? genre,
    String? author,
    String? publisher,
    int? totalCopies,
    bool? isActive,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      totalCopies: totalCopies ?? this.totalCopies,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.reservedAt,
    required this.status,
    this.deliveredAt,
    this.dueDate,
    this.returnedAt,
  });

  final String id;
  final String userId;
  final String bookId;
  final DateTime reservedAt;
  final ReservationStatus status;
  final DateTime? deliveredAt;
  final DateTime? dueDate;
  final DateTime? returnedAt;

  Reservation copyWith({
    String? id,
    String? userId,
    String? bookId,
    DateTime? reservedAt,
    ReservationStatus? status,
    DateTime? deliveredAt,
    DateTime? dueDate,
    DateTime? returnedAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      reservedAt: reservedAt ?? this.reservedAt,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      dueDate: dueDate ?? this.dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }
}

class BookRequest {
  const BookRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.genre,
    required this.author,
    required this.publisher,
    required this.requestedAt,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String userId;
  final String title;
  final String genre;
  final String author;
  final String publisher;
  final DateTime requestedAt;
  final RequestStatus status;

  BookRequest copyWith({
    String? id,
    String? userId,
    String? title,
    String? genre,
    String? author,
    String? publisher,
    DateTime? requestedAt,
    RequestStatus? status,
  }) {
    return BookRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
    );
  }
}

class AdminLog {
  const AdminLog({
    required this.id,
    required this.adminUserId,
    required this.adminName,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final String adminUserId;
  final String adminName;
  final String action;
  final DateTime createdAt;
}
