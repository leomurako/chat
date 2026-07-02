import 'package:flutter/foundation.dart';

import '../models/library_models.dart';

class LoginInput {
  const LoginInput({
    required this.role,
    this.className,
    this.studentNumber,
    this.name,
    this.adminName,
    required this.password,
  });

  final UserRole role;
  final String? className;
  final String? studentNumber;
  final String? name;
  final String? adminName;
  final String password;
}

class ReservationView {
  const ReservationView({
    required this.reservation,
    required this.user,
    required this.book,
  });

  final Reservation reservation;
  final LibraryUser user;
  final Book book;
}

class BookRequestView {
  const BookRequestView({
    required this.request,
    required this.user,
  });

  final BookRequest request;
  final LibraryUser user;
}

abstract class LibraryStoreBase extends ChangeNotifier {
  List<Book> get books;
  List<Book> get allBooks;
  List<Reservation> get reservations;
  List<BookRequest> get requests;
  List<AdminLog> get adminLogs;

  Future<LibraryUser?> login(LoginInput input);

  int activeReservationsCountForUser(String userId);
  int remainingCopies(String bookId);
  int todaysReservationCount(String userId);

  List<ReservationView> reservationsForStatus(ReservationStatus status);
  List<ReservationView> currentLoansForUser(String userId);
  List<ReservationView> historyForUser(String userId);
  List<BookRequestView> pendingRequests();

  Future<bool> reserveBook({required String userId, required String bookId});
  Future<void> markDelivered(String reservationId);
  Future<void> markReturned(String reservationId);

  Future<void> addBook({
    required String title,
    required String genre,
    required String author,
    required String publisher,
    required int totalCopies,
  });

  Future<void> removeBook(String bookId);

  Future<void> submitRequest({
    required String userId,
    required String title,
    required String genre,
    required String author,
    required String publisher,
  });

  Future<void> approveRequest(String requestId, int totalCopies);

  Map<String, int> reservationsByClass();
  List<MapEntry<LibraryUser, int>> userRanking();
}

