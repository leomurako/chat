import '../models/library_models.dart';
import 'library_store_base.dart';

class MockLibraryStore extends LibraryStoreBase {
  MockLibraryStore() {
    _users = [
      const LibraryUser(
        id: "student-001",
        role: UserRole.user,
        className: "48HR",
        studentNumber: 12,
        name: "山田太郎",
        password: "1234",
      ),
      const LibraryUser(
        id: "student-002",
        role: UserRole.user,
        className: "48HR",
        studentNumber: 18,
        name: "佐藤花子",
        password: "1234",
      ),
      const LibraryUser(
        id: "student-003",
        role: UserRole.user,
        className: "49HR",
        studentNumber: 3,
        name: "鈴木一郎",
        password: "1234",
      ),
      const LibraryUser(
        id: "admin-001",
        role: UserRole.admin,
        name: "admin01",
        adminName: "図書委員 長谷川",
        password: "admin123",
      ),
      const LibraryUser(
        id: "admin-002",
        role: UserRole.admin,
        name: "admin02",
        adminName: "担当教員 田中",
        password: "admin123",
      ),
    ];

    _books = [
      const Book(
        id: "book-001",
        title: "負けるという選択肢はない",
        genre: "伝記",
        author: "山本申伸",
        publisher: "ドジャース出版",
        totalCopies: 2,
      ),
      const Book(
        id: "book-002",
        title: "憧れるのをやめましょう",
        genre: "スポーツ",
        author: "大谷似翔平",
        publisher: "青空書房",
        totalCopies: 1,
      ),
      const Book(
        id: "book-003",
        title: "杉谷、左で打てや。",
        genre: "小説",
        author: "山田哲入",
        publisher: "スワローズ社",
        totalCopies: 3,
      ),
      const Book(
        id: "book-004",
        title: "俺を出すことが最善の選択肢だ",
        genre: "伝記",
        author: "前田大自然",
        publisher: "学校図書出版",
        totalCopies: 2,
      ),
    ];

    _reservations = [
      Reservation(
        id: "res-001",
        userId: "student-002",
        bookId: "book-001",
        reservedAt: DateTime.now().subtract(const Duration(hours: 3)),
        status: ReservationStatus.reserved,
      ),
      Reservation(
        id: "res-002",
        userId: "student-003",
        bookId: "book-002",
        reservedAt: DateTime.now().subtract(const Duration(days: 5)),
        status: ReservationStatus.delivered,
        deliveredAt: DateTime.now().subtract(const Duration(days: 4)),
        dueDate: DateTime.now().add(const Duration(days: 10)),
      ),
      Reservation(
        id: "res-003",
        userId: "student-001",
        bookId: "book-003",
        reservedAt: DateTime.now().subtract(const Duration(days: 25)),
        status: ReservationStatus.returned,
        deliveredAt: DateTime.now().subtract(const Duration(days: 23)),
        dueDate: DateTime.now().subtract(const Duration(days: 9)),
        returnedAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
    ];

    _requests = [
      BookRequest(
        id: "req-001",
        userId: "student-001",
        title: "宇宙と図書館",
        genre: "科学",
        author: "高橋未来",
        publisher: "未来出版",
        requestedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      BookRequest(
        id: "req-002",
        userId: "student-003",
        title: "静かな読書術",
        genre: "実用",
        author: "森本静",
        publisher: "青葉社",
        requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _adminLogs = [
      AdminLog(
        id: "log-001",
        adminUserId: "admin-001",
        adminName: "図書委員 長谷川",
        action: "ログイン",
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  late List<LibraryUser> _users;
  late List<Book> _books;
  late List<Reservation> _reservations;
  late List<BookRequest> _requests;
  late List<AdminLog> _adminLogs;

  @override
  List<LibraryUser> get users => List.unmodifiable(_users);

  LibraryUser userById(String id) => _users.firstWhere((user) => user.id == id);

  Book bookById(String id) => _books.firstWhere((book) => book.id == id);

  @override
  List<Book> get books => List.unmodifiable(_books.where((book) => book.isActive));

  @override
  List<Book> get allBooks => List.unmodifiable(_books);

  @override
  List<Reservation> get reservations => List.unmodifiable(_reservations);

  @override
  List<BookRequest> get requests => List.unmodifiable(_requests);

  @override
  List<AdminLog> get adminLogs {
    final logs = [..._adminLogs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(logs);
  }

  @override
  Future<LibraryUser?> login(LoginInput input) async {
    return _loginSync(input);
  }

  LibraryUser? _loginSync(LoginInput input) {
    if (input.role == UserRole.admin) {
      final adminName = (input.adminName ?? "").trim();
      if (adminName.isEmpty) return null;

      LibraryUser? user;
      for (final candidate in _users) {
        if (candidate.role == UserRole.admin &&
            candidate.adminName == adminName &&
            candidate.password == input.password) {
          user = candidate;
          break;
        }
      }
      if (user == null) return null;

      _adminLogs = [
        AdminLog(
          id: "log-${DateTime.now().millisecondsSinceEpoch}",
          adminUserId: user.id,
          adminName: user.adminName ?? user.name,
          action: "ログイン",
          createdAt: DateTime.now(),
        ),
        ..._adminLogs,
      ];
      notifyListeners();
      return user;
    }

    final className = (input.className ?? "").trim();
    final name = (input.name ?? "").trim();
    final studentNumber = int.tryParse((input.studentNumber ?? "").trim());
    if (className.isEmpty || name.isEmpty || studentNumber == null) return null;

    for (final user in _users) {
      if (user.role == UserRole.user &&
          user.className == className &&
          user.studentNumber == studentNumber &&
          user.name == name &&
          user.password == input.password) {
        return user;
      }
    }
    return null;
  }

  @override
  int activeReservationsCountForUser(String userId) {
    return _reservations
        .where((reservation) =>
            reservation.userId == userId &&
            reservation.status != ReservationStatus.returned)
        .length;
  }

  int remainingCopies(String bookId) {
    final book = bookById(bookId);
    final activeCount = _reservations
        .where((reservation) =>
            reservation.bookId == bookId &&
            reservation.status != ReservationStatus.returned)
        .length;
    return book.totalCopies - activeCount;
  }

  int todaysReservationCount(String userId) {
    final now = DateTime.now();
    return _reservations
        .where((reservation) =>
            reservation.userId == userId &&
            reservation.reservedAt.year == now.year &&
            reservation.reservedAt.month == now.month &&
            reservation.reservedAt.day == now.day)
        .length;
  }

  List<ReservationView> reservationsForStatus(ReservationStatus status) {
    return _reservations
        .where((reservation) => reservation.status == status)
        .map((reservation) => ReservationView(
              reservation: reservation,
              user: userById(reservation.userId),
              book: bookById(reservation.bookId),
            ))
        .toList()
      ..sort((a, b) => b.reservation.reservedAt.compareTo(a.reservation.reservedAt));
  }

  List<ReservationView> currentLoansForUser(String userId) {
    return _reservations
        .where((reservation) =>
            reservation.userId == userId &&
            reservation.status != ReservationStatus.returned)
        .map((reservation) => ReservationView(
              reservation: reservation,
              user: userById(reservation.userId),
              book: bookById(reservation.bookId),
            ))
        .toList()
      ..sort((a, b) => b.reservation.reservedAt.compareTo(a.reservation.reservedAt));
  }

  List<ReservationView> historyForUser(String userId) {
    return _reservations
        .where((reservation) =>
            reservation.userId == userId &&
            reservation.status == ReservationStatus.returned)
        .map((reservation) => ReservationView(
              reservation: reservation,
              user: userById(reservation.userId),
              book: bookById(reservation.bookId),
            ))
        .toList()
      ..sort((a, b) => b.reservation.returnedAt!.compareTo(a.reservation.returnedAt!));
  }

  List<BookRequestView> pendingRequests() {
    return _requests
        .where((request) => request.status == RequestStatus.pending)
        .map((request) => BookRequestView(
              request: request,
              user: userById(request.userId),
            ))
        .toList()
      ..sort((a, b) => b.request.requestedAt.compareTo(a.request.requestedAt));
  }

  @override
  Future<bool> reserveBook({required String userId, required String bookId}) async {
    if (activeReservationsCountForUser(userId) >= 2) return false;
    if (todaysReservationCount(userId) >= 2) return false;
    if (remainingCopies(bookId) <= 0) return false;

    final alreadyReserved = _reservations.any((reservation) =>
        reservation.userId == userId &&
        reservation.bookId == bookId &&
        reservation.status != ReservationStatus.returned);
    if (alreadyReserved) return false;

    _reservations = [
      Reservation(
        id: "res-${DateTime.now().millisecondsSinceEpoch}",
        userId: userId,
        bookId: bookId,
        reservedAt: DateTime.now(),
        status: ReservationStatus.reserved,
      ),
      ..._reservations,
    ];
    notifyListeners();
    return true;
  }

  @override
  Future<void> markDelivered(String reservationId) async {
    _reservations = _reservations
        .map((reservation) => reservation.id == reservationId
            ? reservation.copyWith(
                status: ReservationStatus.delivered,
                deliveredAt: DateTime.now(),
                dueDate: DateTime.now().add(const Duration(days: 14)),
              )
            : reservation)
        .toList();
    notifyListeners();
  }

  @override
  Future<void> markReturned(String reservationId) async {
    _reservations = _reservations
        .map((reservation) => reservation.id == reservationId
            ? reservation.copyWith(
                status: ReservationStatus.returned,
                returnedAt: DateTime.now(),
              )
            : reservation)
        .toList();
    notifyListeners();
  }

  @override
  Future<void> addBook({
    required String title,
    required String genre,
    required String author,
    required String publisher,
    required int totalCopies,
  }) async {
    _books = [
      Book(
        id: "book-${DateTime.now().millisecondsSinceEpoch}",
        title: title,
        genre: genre,
        author: author,
        publisher: publisher,
        totalCopies: totalCopies,
      ),
      ..._books,
    ];
    notifyListeners();
  }

  @override
  Future<void> removeBook(String bookId) async {
    _books = _books
        .map((book) => book.id == bookId ? book.copyWith(isActive: false) : book)
        .toList();
    notifyListeners();
  }

  @override
  Future<void> submitRequest({
    required String userId,
    required String title,
    required String genre,
    required String author,
    required String publisher,
  }) async {
    _requests = [
      BookRequest(
        id: "req-${DateTime.now().millisecondsSinceEpoch}",
        userId: userId,
        title: title,
        genre: genre,
        author: author,
        publisher: publisher,
        requestedAt: DateTime.now(),
      ),
      ..._requests,
    ];
    notifyListeners();
  }

  @override
  Future<void> approveRequest(String requestId, int totalCopies) async {
    final request = _requests.firstWhere((request) => request.id == requestId);
    _books = [
      Book(
        id: "book-${DateTime.now().millisecondsSinceEpoch}",
        title: request.title,
        genre: request.genre,
        author: request.author,
        publisher: request.publisher,
        totalCopies: totalCopies,
      ),
      ..._books,
    ];
    _requests = _requests
        .map((item) => item.id == requestId
            ? item.copyWith(status: RequestStatus.approved)
            : item)
        .toList();
    notifyListeners();
  }

  @override
  Map<String, int> reservationsByClass() {
    final result = <String, int>{};
    for (final reservation in _reservations) {
      final user = userById(reservation.userId);
      if (user.role != UserRole.user || user.className == null) continue;
      result[user.className!] = (result[user.className!] ?? 0) + 1;
    }
    return result;
  }

  @override
  List<MapEntry<LibraryUser, int>> userRanking() {
    final counts = <String, int>{};
    for (final reservation in _reservations) {
      counts[reservation.userId] = (counts[reservation.userId] ?? 0) + 1;
    }

    final ranking = counts.entries
        .map((entry) => MapEntry(userById(entry.key), entry.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranking;
  }
}
