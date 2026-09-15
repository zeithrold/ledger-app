import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_app/app/theme/ledger_tokens.dart';
import 'package:ledger_app/core/identity/models.dart';
import 'package:ledger_app/core/identity/providers.dart';
import 'package:ledger_app/features/auth/failure_view.dart';
import 'package:ledger_app/l10n/l10n.dart';
import 'package:ledger_app/shared/ui/ledger_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Read-only books with content preserved during refresh.
class BooksPage extends ConsumerStatefulWidget {
  /// Creates the BooksPage screen.
  const BooksPage({super.key});
  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  List<Book>? _books;
  ApiFailure? _failure;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    final identity = ref.read(identityProvider);
    final session = identity.auth.sessionKey;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final books = await identity.api!.books();
      if (mounted && identity.auth.sessionKey == session) {
        setState(() => _books = books);
      }
    } on ApiFailure catch (failure) {
      if (mounted && identity.auth.sessionKey == session) {
        identity.handleFailure(failure);
        if (mounted) setState(() => _failure = failure);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personal = ref.read(identityProvider).context!;
    final l10n = context.l10n;
    return LedgerPage(
      title: l10n.booksTitle,
      leading: IconButton(
        tooltip: l10n.backToHome,
        onPressed: () => context.pop(),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      actions: [
        IconButton(
          key: const ValueKey('refresh-books'),
          tooltip: l10n.refreshAction,
          onPressed: _loading ? null : _load,
          icon: const Icon(LucideIcons.refreshCw),
        ),
      ],
      children: [
        Text(
          '${l10n.personalSpaceLabel}: ${personal.tenantName}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: LedgerTokens.lg),
        if (_loading && _books != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.refreshingLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: LedgerTokens.sm),
        ],
        if (_failure case final failure?) ...[
          FailureView(failure),
          const SizedBox(height: LedgerTokens.md),
          LedgerAction(
            label: l10n.retryAction,
            secondary: true,
            onPressed: _loading ? null : _load,
          ),
          const SizedBox(height: LedgerTokens.lg),
        ],
        if (_books == null && _loading) const LedgerLoading(),
        if (_books case final books?)
          if (books.isEmpty)
            LedgerStateView(
              title: l10n.homeEmptyBody,
              body: l10n.booksEmptyExplanation,
              icon: LucideIcons.bookOpen,
            )
          else
            LedgerGroup(
              children: [
                for (final book in books)
                  LedgerRow(
                    key: ValueKey('book-${book.id}'),
                    title: book.name,
                    subtitle: '${l10n.currencyLabel} · ${book.baseCurrency}',
                    leading: Icon(
                      LucideIcons.bookOpen,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    trailing: book.id == personal.defaultBook.id
                        ? LedgerBadge(l10n.defaultBadge)
                        : null,
                    onTap: () =>
                        context.push('/books/${Uri.encodeComponent(book.id)}'),
                  ),
              ],
            ),
      ],
    );
  }
}

/// Authorized book details with a real route back stack and refresh feedback.
class BookDetailPage extends ConsumerStatefulWidget {
  /// Creates the BookDetailPage screen.
  const BookDetailPage({required this.id, super.key});

  /// Book identifier supplied by the route.
  final String id;
  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  Book? _book;
  ApiFailure? _failure;
  bool _loading = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BookDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _book = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final identity = ref.read(identityProvider);
    final session = identity.auth.sessionKey;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final book = await identity.api!.book(widget.id);
      if (mounted &&
          generation == _generation &&
          identity.auth.sessionKey == session) {
        setState(() => _book = book);
      }
    } on ApiFailure catch (failure) {
      if (mounted &&
          generation == _generation &&
          identity.auth.sessionKey == session) {
        identity.handleFailure(failure);
        if (mounted) setState(() => _failure = failure);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LedgerPage(
      title: _book?.name ?? l10n.bookDetailsTitle,
      leading: IconButton(
        key: const ValueKey('book-back'),
        tooltip: l10n.backToHome,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      actions: [
        IconButton(
          key: const ValueKey('refresh-book'),
          tooltip: l10n.refreshAction,
          onPressed: _loading ? null : _load,
          icon: const Icon(LucideIcons.refreshCw),
        ),
      ],
      children: [
        if (_book case final book?) ...[
          if (book.id ==
              ref.read(identityProvider).context!.defaultBook.id) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LedgerBadge(l10n.defaultBadge),
            ),
            const SizedBox(height: LedgerTokens.xl),
          ],
          LedgerSection(
            title: l10n.bookDetailsTitle,
            children: [
              LedgerRow(title: l10n.currencyLabel, subtitle: book.baseCurrency),
            ],
          ),
        ],
        if (_loading)
          if (_book == null)
            const LedgerLoading()
          else
            Semantics(liveRegion: true, child: Text(l10n.refreshingLabel)),
        if (_failure case final failure?) ...[
          FailureView(failure),
          const SizedBox(height: LedgerTokens.lg),
          LedgerAction(
            label: l10n.retryAction,
            secondary: true,
            onPressed: _loading ? null : _load,
          ),
        ],
      ],
    );
  }
}
