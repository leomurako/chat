import 'package:flutter/material.dart';

import 'data/mock_library_data.dart';
import 'models/library_models.dart';

void main() {
  runApp(const LibrarySystemApp());
}

class LibrarySystemApp extends StatefulWidget {
  const LibrarySystemApp({super.key});

  @override
  State<LibrarySystemApp> createState() => _LibrarySystemAppState();
}

class _LibrarySystemAppState extends State<LibrarySystemApp> {
  final LibraryStore store = LibraryStore();
  LibraryUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '図書館オンラインサービス',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (currentUser == null) {
            return LoginScreen(
              store: store,
              onLogin: (user) {
                setState(() {
                  currentUser = user;
                });
              },
            );
          }

          if (currentUser!.role == UserRole.admin) {
            return AdminDashboard(
              store: store,
              admin: currentUser!,
              onLogout: () {
                setState(() {
                  currentUser = null;
                });
              },
            );
          }

          return UserDashboard(
            store: store,
            user: currentUser!,
            onLogout: () {
              setState(() {
                currentUser = null;
              });
            },
          );
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    required this.onLogin,
  });

  final LibraryStore store;
  final ValueChanged<LibraryUser> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole selectedRole = UserRole.user;
  final classController = TextEditingController(text: '48HR');
  final studentNumberController = TextEditingController(text: '12');
  final userNameController = TextEditingController(text: '山田太郎');
  final adminNameController = TextEditingController(text: '図書委員 長谷川');
  final passwordController = TextEditingController(text: '1234');
  String? errorText;

  @override
  void dispose() {
    classController.dispose();
    studentNumberController.dispose();
    userNameController.dispose();
    adminNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _fillSample() {
    if (selectedRole == UserRole.user) {
      classController.text = '48HR';
      studentNumberController.text = '12';
      userNameController.text = '山田太郎';
      passwordController.text = '1234';
    } else {
      adminNameController.text = '図書委員 長谷川';
      passwordController.text = 'admin123';
    }
  }

  void _submit() {
    final user = widget.store.login(
      LoginInput(
        role: selectedRole,
        className: classController.text,
        studentNumber: studentNumberController.text,
        name: userNameController.text,
        adminName: adminNameController.text,
        password: passwordController.text,
      ),
    );

    if (user == null) {
      setState(() {
        errorText = '入力情報が一致しません。サンプル値で試すこともできます。';
      });
      return;
    }

    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = selectedRole == UserRole.admin;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.local_library_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '図書館オンラインサービス',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '学校PCから使いやすいWeb版を想定した初期実装です。今の段階ではモックデータで画面遷移と業務フローを確認できます。',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: const [
                              _InfoChip(label: '利用者画面'),
                              _InfoChip(label: '管理者画面'),
                              _InfoChip(label: 'クラス表示重視'),
                              _InfoChip(label: 'Web配布前提'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SampleAccountCard(isAdmin: isAdmin),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<UserRole>(
                            segments: const [
                              ButtonSegment(
                                value: UserRole.user,
                                icon: Icon(Icons.person_outline),
                                label: Text('利用者'),
                              ),
                              ButtonSegment(
                                value: UserRole.admin,
                                icon: Icon(Icons.admin_panel_settings_outlined),
                                label: Text('管理者'),
                              ),
                            ],
                            selected: {selectedRole},
                            onSelectionChanged: (selection) {
                              setState(() {
                                selectedRole = selection.first;
                                errorText = null;
                                _fillSample();
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isAdmin ? '管理者ログイン' : '利用者ログイン',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 20),
                          if (!isAdmin) ...[
                            _FormLabel(label: 'クラス'),
                            TextField(
                              controller: classController,
                              decoration: const InputDecoration(
                                hintText: '例: 48HR',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FormLabel(label: '番号'),
                            TextField(
                              controller: studentNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '例: 12',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FormLabel(label: '名前'),
                            TextField(
                              controller: userNameController,
                              decoration: const InputDecoration(
                                hintText: '例: 山田太郎',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ] else ...[
                            _FormLabel(label: '使用者名'),
                            TextField(
                              controller: adminNameController,
                              decoration: const InputDecoration(
                                hintText: '例: 図書委員 長谷川',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _FormLabel(label: 'パスワード'),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.login),
                            label: const Text('ログイン'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                errorText = null;
                                _fillSample();
                              });
                            },
                            icon: const Icon(Icons.auto_fix_high_outlined),
                            label: const Text('サンプル値を入れる'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDashboard extends StatelessWidget {
  const UserDashboard({
    super.key,
    required this.store,
    required this.user,
    required this.onLogout,
  });

  final LibraryStore store;
  final LibraryUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final loans = store.currentLoansForUser(user.id);
    final overdue = loans.where((item) {
      final dueDate = item.reservation.dueDate;
      return dueDate != null && dueDate.isBefore(DateTime.now());
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('利用者画面'),
              Text(
                user.displayLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('ログアウト'),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '予約'),
              Tab(text: '登録申請'),
              Tab(text: '借りている本・履歴'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (overdue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _NoticeCard(
                  color: const Color(0xFFFFF1F1),
                  icon: Icons.warning_amber_rounded,
                  title: '返却期限を過ぎている本があります',
                  message:
                      '${overdue.first.book.title} ほか ${overdue.length} 件。管理者に返却確認を依頼してください。',
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  BookReservationTab(store: store, user: user),
                  BookRequestTab(store: store, user: user),
                  LoansAndHistoryTab(store: store, user: user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    super.key,
    required this.store,
    required this.admin,
    required this.onLogout,
  });

  final LibraryStore store;
  final LibraryUser admin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('管理者画面'),
              Text(
                admin.displayLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('ログアウト'),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '予約本確認'),
              Tab(text: '本登録・解除'),
              Tab(text: '集計'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ReservationManagementTab(store: store),
            BookManagementTab(store: store),
            AnalyticsTab(store: store),
          ],
        ),
      ),
    );
  }
}

class BookReservationTab extends StatefulWidget {
  const BookReservationTab({
    super.key,
    required this.store,
    required this.user,
  });

  final LibraryStore store;
  final LibraryUser user;

  @override
  State<BookReservationTab> createState() => _BookReservationTabState();
}

class _BookReservationTabState extends State<BookReservationTab> {
  final searchController = TextEditingController();
  String selectedGenre = 'すべて';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final genres = {
      'すべて',
      ...widget.store.books.map((book) => book.genre),
    }.toList();

    final books = widget.store.books.where((book) {
      final matchesGenre =
          selectedGenre == 'すべて' || book.genre == selectedGenre;
      final haystack = [
        book.title,
        book.author,
        book.publisher,
        book.genre,
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesGenre && matchesQuery;
    }).toList();

    final activeCount = widget.store.activeReservationsCountForUser(widget.user.id);
    final todayCount = widget.store.todaysReservationCount(widget.user.id);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _NoticeCard(
                  color: const Color(0xFFEFF6FF),
                  icon: Icons.rule_folder_outlined,
                  title: '予約ルール',
                  message:
                      '同時に最大2冊、1日2回まで予約できます。現在 ${activeCount}冊 / 今日 ${todayCount}回です。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'キーワード・作者・出版社で検索',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedGenre,
                  decoration: const InputDecoration(
                    labelText: 'ジャンル',
                    border: OutlineInputBorder(),
                  ),
                  items: genres
                      .map((genre) => DropdownMenuItem(
                            value: genre,
                            child: Text(genre),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGenre = value ?? 'すべて';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: books.isEmpty
                ? const Center(child: Text('該当する本がありません'))
                : ListView.separated(
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final remaining = widget.store.remainingCopies(book.id);
                      final canReserve =
                          remaining > 0 &&
                          widget.store.activeReservationsCountForUser(widget.user.id) < 2 &&
                          widget.store.todaysReservationCount(widget.user.id) < 2;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${book.genre} / ${book.author} / ${book.publisher}',
                                      style: const TextStyle(color: Colors.black54),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _TinyChip(label: '在庫 ${remaining}/${book.totalCopies}'),
                                        if (remaining <= 0)
                                          const _TinyChip(
                                            label: '予約不可',
                                            color: Color(0xFFFFE8E8),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                onPressed: canReserve
                                    ? () {
                                        final result = widget.store.reserveBook(
                                          userId: widget.user.id,
                                          bookId: book.id,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              result
                                                  ? '「${book.title}」を予約しました'
                                                  : '予約条件を満たしていないため予約できません',
                                            ),
                                          ),
                                        );
                                        setState(() {});
                                      }
                                    : null,
                                child: const Text('予約'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BookRequestTab extends StatefulWidget {
  const BookRequestTab({
    super.key,
    required this.store,
    required this.user,
  });

  final LibraryStore store;
  final LibraryUser user;

  @override
  State<BookRequestTab> createState() => _BookRequestTabState();
}

class _BookRequestTabState extends State<BookRequestTab> {
  final titleController = TextEditingController();
  final genreController = TextEditingController();
  final authorController = TextEditingController();
  final publisherController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    genreController.dispose();
    authorController.dispose();
    publisherController.dispose();
    super.dispose();
  }

  void _submit() {
    if (titleController.text.trim().isEmpty ||
        genreController.text.trim().isEmpty ||
        authorController.text.trim().isEmpty ||
        publisherController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての項目を入力してください')),
      );
      return;
    }

    widget.store.submitRequest(
      userId: widget.user.id,
      title: titleController.text.trim(),
      genre: genreController.text.trim(),
      author: authorController.text.trim(),
      publisher: publisherController.text.trim(),
    );
    titleController.clear();
    genreController.clear();
    authorController.clear();
    publisherController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登録申請を送信しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeCard(
            color: const Color(0xFFF4F1FF),
            icon: Icons.library_add_outlined,
            title: '本の登録申請',
            message: '図書館に未登録の本を申請できます。承認されると管理者側で蔵書へ反映します。',
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'タイトル',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: genreController,
                          decoration: const InputDecoration(
                            labelText: 'ジャンル',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: '作者',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: publisherController,
                          decoration: const InputDecoration(
                            labelText: '出版社',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('登録申請'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoansAndHistoryTab extends StatelessWidget {
  const LoansAndHistoryTab({
    super.key,
    required this.store,
    required this.user,
  });

  final LibraryStore store;
  final LibraryUser user;

  @override
  Widget build(BuildContext context) {
    final currentLoans = store.currentLoansForUser(user.id);
    final history = store.historyForUser(user.id);

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '借りている本'),
                Tab(text: '履歴'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                children: [
                  _ReservationListView(
                    items: currentLoans,
                    emptyText: '現在借りている本はありません',
                    showDueDate: true,
                  ),
                  _ReservationListView(
                    items: history,
                    emptyText: '履歴はまだありません',
                    showDueDate: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationManagementTab extends StatelessWidget {
  const ReservationManagementTab({
    super.key,
    required this.store,
  });

  final LibraryStore store;

  @override
  Widget build(BuildContext context) {
    final reserved = store.reservationsForStatus(ReservationStatus.reserved);
    final delivered = store.reservationsForStatus(ReservationStatus.delivered);

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _NoticeCard(
                    color: const Color(0xFFE8F4FF),
                    icon: Icons.sync_alt_outlined,
                    title: '予約本と配達済みを管理',
                    message: '配達済みや返却済みの更新で、利用者側の状態も反映される想定です。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const TabBar(
              tabs: [
                Tab(text: '予約本'),
                Tab(text: '配達済み'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                children: [
                  _AdminReservationList(
                    items: reserved,
                    actionLabel: '配達済みにする',
                    onPressed: (id) => store.markDelivered(id),
                  ),
                  _AdminReservationList(
                    items: delivered,
                    actionLabel: '返却済みにする',
                    onPressed: (id) => store.markReturned(id),
                    showDueDate: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookManagementTab extends StatefulWidget {
  const BookManagementTab({
    super.key,
    required this.store,
  });

  final LibraryStore store;

  @override
  State<BookManagementTab> createState() => _BookManagementTabState();
}

class _BookManagementTabState extends State<BookManagementTab> {
  final titleController = TextEditingController();
  final genreController = TextEditingController();
  final authorController = TextEditingController();
  final publisherController = TextEditingController();
  final copiesController = TextEditingController(text: '1');

  @override
  void dispose() {
    titleController.dispose();
    genreController.dispose();
    authorController.dispose();
    publisherController.dispose();
    copiesController.dispose();
    super.dispose();
  }

  void _registerBook() {
    final copies = int.tryParse(copiesController.text.trim());
    if (titleController.text.trim().isEmpty ||
        genreController.text.trim().isEmpty ||
        authorController.text.trim().isEmpty ||
        publisherController.text.trim().isEmpty ||
        copies == null ||
        copies <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本の情報を正しく入力してください')),
      );
      return;
    }

    widget.store.addBook(
      title: titleController.text.trim(),
      genre: genreController.text.trim(),
      author: authorController.text.trim(),
      publisher: publisherController.text.trim(),
      totalCopies: copies,
    );

    titleController.clear();
    genreController.clear();
    authorController.clear();
    publisherController.clear();
    copiesController.text = '1';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本を登録しました')),
    );
  }

  Future<void> _approveRequest(BuildContext context, BookRequestView request) async {
    final copiesController = TextEditingController(text: '1');
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('申請を承認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.request.title),
            const SizedBox(height: 12),
            TextField(
              controller: copiesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '登録冊数',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('承認'),
          ),
        ],
      ),
    );

    if (approved == true) {
      final copies = int.tryParse(copiesController.text.trim()) ?? 1;
      widget.store.approveRequest(request.request.id, copies < 1 ? 1 : copies);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申請を承認して蔵書へ追加しました')),
        );
      }
    }
    copiesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = widget.store.pendingRequests();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _NoticeCard(
            color: const Color(0xFFEFFCF0),
            icon: Icons.edit_note_outlined,
            title: '本の登録・削除',
            message: '管理者が直接登録し、不要になった本は一覧から解除できます。',
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本登録', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'タイトル',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: genreController,
                          decoration: const InputDecoration(
                            labelText: 'ジャンル',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: '作者',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: publisherController,
                          decoration: const InputDecoration(
                            labelText: '出版社',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: copiesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '冊数',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _registerBook,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('登録'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('蔵書一覧', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ...widget.store.books.map(
                    (book) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        tileColor: const Color(0xFFF8FAFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(book.title),
                        subtitle: Text(
                          '${book.genre} / ${book.author} / ${book.publisher} / ${book.totalCopies}冊',
                        ),
                        trailing: TextButton.icon(
                          onPressed: () => widget.store.removeBook(book.id),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('解除'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('アンケート結果', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    const Text('承認待ちの申請はありません')
                  else
                    ...requests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          tileColor: const Color(0xFFF8FAFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(request.request.title),
                          subtitle: Text(
                            '${request.user.className} ${request.user.studentNumber}番 ${request.user.name}\n'
                            '${request.request.genre} / ${request.request.author} / ${request.request.publisher}',
                          ),
                          isThreeLine: true,
                          trailing: FilledButton(
                            onPressed: () => _approveRequest(context, request),
                            child: const Text('承認'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({
    super.key,
    required this.store,
  });

  final LibraryStore store;

  @override
  Widget build(BuildContext context) {
    final classStats = store.reservationsByClass().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ranking = store.userRanking();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: '総予約数',
                value: '${store.reservations.length}件',
                icon: Icons.book_online_outlined,
              ),
              _MetricCard(
                title: '貸出中',
                value:
                    '${store.reservationsForStatus(ReservationStatus.delivered).length}件',
                icon: Icons.local_shipping_outlined,
              ),
              _MetricCard(
                title: '申請待ち',
                value: '${store.pendingRequests().length}件',
                icon: Icons.mark_email_unread_outlined,
              ),
              _MetricCard(
                title: '蔵書数',
                value: '${store.books.length}冊',
                icon: Icons.menu_book_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('クラスごとの予約数',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ...classStats.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(width: 90, child: Text(entry.key)),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: classStats.isEmpty
                                        ? 0
                                        : entry.value / classStats.first.value,
                                    minHeight: 12,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${entry.value}件'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ユーザーランキング',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ...ranking.take(5).toList().asMap().entries.map(
                          (entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(row.key.displayLabel),
                                trailing: Text('${row.value}回'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('管理画面利用ログ',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ...store.adminLogs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: const Color(0xFFF8FAFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(log.adminName),
                        subtitle: Text(log.action),
                        trailing: Text(formatDateTime(log.createdAt)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReservationList extends StatelessWidget {
  const _AdminReservationList({
    required this.items,
    required this.actionLabel,
    required this.onPressed,
    this.showDueDate = false,
  });

  final List<ReservationView> items;
  final String actionLabel;
  final ValueChanged<String> onPressed;
  final bool showDueDate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('該当データはありません'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.book.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${item.user.className} / ${item.user.studentNumber}番 / ${item.user.name}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        showDueDate
                            ? '期限: ${dueDateLabel(item.reservation.dueDate)}'
                            : '予約日時: ${formatDateTime(item.reservation.reservedAt)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => onPressed(item.reservation.id),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReservationListView extends StatelessWidget {
  const _ReservationListView({
    required this.items,
    required this.emptyText,
    required this.showDueDate,
  });

  final List<ReservationView> items;
  final String emptyText;
  final bool showDueDate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            title: Text(item.book.title),
            subtitle: Text('${item.book.author} / ${item.book.publisher}'),
            trailing: showDueDate
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('期限'),
                      Text(
                        dueDateLabel(item.reservation.dueDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Text(formatDateTime(item.reservation.returnedAt)),
          ),
        );
      },
    );
  }
}

class _SampleAccountCard extends StatelessWidget {
  const _SampleAccountCard({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('サンプルアカウント',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (!isAdmin) ...const [
            Text('クラス: 48HR'),
            Text('番号: 12'),
            Text('名前: 山田太郎'),
            Text('パスワード: 1234'),
          ] else ...const [
            Text('使用者名: 図書委員 長谷川'),
            Text('パスワード: admin123'),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({
    required this.label,
    this.color = const Color(0xFFEFF4FF),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 16),
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final yyyy = dateTime.year.toString().padLeft(4, '0');
  final mm = dateTime.month.toString().padLeft(2, '0');
  final dd = dateTime.day.toString().padLeft(2, '0');
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final min = dateTime.minute.toString().padLeft(2, '0');
  return '$yyyy/$mm/$dd $hh:$min';
}

String dueDateLabel(DateTime? dueDate) {
  if (dueDate == null) return '未設定';

  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final days = normalizedDue.difference(normalizedToday).inDays;

  if (days > 0) return 'あと${days}日';
  if (days == 0) return '本日まで';
  return '${days.abs()}日経過';
}
