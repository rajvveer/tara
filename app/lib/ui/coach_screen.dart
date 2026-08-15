import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../app_scope.dart';
import '../data/api.dart';
import '../data/realtime.dart';
import 'theme.dart';
import 'widgets.dart';

class CoachMessage {
  CoachMessage({required this.assistant, required this.text});

  final bool assistant;
  String text;

  static CoachMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final role = value['role']?.toString();
    final text = value['content']?.toString().trim() ?? '';
    if ((role != 'assistant' && role != 'user') || text.isEmpty) return null;
    return CoachMessage(assistant: role == 'assistant', text: text);
  }

  Map<String, String> toJson() => {
    'role': assistant ? 'assistant' : 'user',
    'content': text,
  };
}

class CoachSession {
  final List<CoachMessage> messages = [];
}

class CoachConversation {
  CoachConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  String title;
  DateTime updatedAt;
  final List<CoachMessage> messages;

  bool get started => messages.any((message) => !message.assistant);

  static String titleFrom(String message) {
    final title = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    return title.length <= 42
        ? title
        : '${title.substring(0, 42).trimRight()}…';
  }

  static CoachConversation? fromJson(Object? value) {
    if (value is! Map || value['messages'] is! List) return null;
    final id = value['id']?.toString().trim() ?? '';
    final messages = (value['messages'] as List)
        .map(CoachMessage.fromJson)
        .whereType<CoachMessage>()
        .toList();
    final firstUser = messages.where((message) => !message.assistant);
    if (id.isEmpty || firstUser.isEmpty) return null;
    final updatedAt = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
    return CoachConversation(
      id: id,
      title: value['title']?.toString().trim().isNotEmpty == true
          ? value['title'].toString().trim()
          : titleFrom(firstUser.first.text),
      updatedAt: updatedAt ?? DateTime.now(),
      messages: messages,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages
        .where((message) => message.text.trim().isNotEmpty)
        .map((message) => message.toJson())
        .toList(),
  };
}

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.realtime, this.session});

  final RealtimeClient? realtime;
  final CoachSession? session;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  late final CoachSession _session;
  late final RealtimeClient _realtime;
  late final CacheStore _cache;
  late final Future<void> _historyLoaded;
  StreamSubscription<Map<String, dynamic>>? _events;
  final List<CoachConversation> _conversations = [];
  Future<void> _historyWrite = Future.value();
  CoachConversation? _activeConversation;
  String? _historyKey;
  String? _legacyHistoryKey;
  bool _initialized = false;
  bool _waiting = false;
  String? _error;

  List<CoachMessage> get _messages =>
      _activeConversation?.messages ?? _session.messages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _session = widget.session ?? CoachSession();
    _realtime = widget.realtime ?? RealtimeClient(context.appRead.api);
    _cache = context.appRead.cache;
    final userId = context.appRead.user?.id;
    _historyKey = !context.appRead.demo && userId != null
        ? 'coach_conversations_$userId'
        : null;
    _legacyHistoryKey = _historyKey == null ? null : 'coach_history_$userId';
    _events = _realtime.events.listen(_onEvent);
    _messages.removeWhere((message) => message.text.isEmpty);
    if (_historyKey == null) {
      _addWelcomeMessage();
    } else {
      _replaceWithNewConversation();
    }
    _historyLoaded = _historyKey == null ? Future.value() : _restoreHistory();
  }

  void _replaceWithNewConversation() {
    _conversations.removeWhere((conversation) => !conversation.started);
    final conversation = CoachConversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAt: DateTime.now(),
      messages: [],
    );
    _conversations.insert(0, conversation);
    _activeConversation = conversation;
    _addWelcomeMessage();
  }

  void _newChat() {
    if (_waiting) return;
    setState(() {
      _error = null;
      _replaceWithNewConversation();
    });
    _scrollToEnd();
  }

  void _addWelcomeMessage() {
    if (_messages.isNotEmpty) return;
    final name = context.appRead.user?.name.trim().split(RegExp(r'\s+')).first;
    _messages.add(
      CoachMessage(
        assistant: true,
        text: name == null || name.isEmpty
            ? 'I’m Tara. What would make today feel a little easier?'
            : 'Hi $name — I’m Tara. What would make today feel a little easier?',
      ),
    );
  }

  Future<void> _restoreHistory() async {
    try {
      final stored = await _cache.read(_historyKey!);
      final restored = stored is List
          ? stored
                .map(CoachConversation.fromJson)
                .whereType<CoachConversation>()
                .toList()
          : <CoachConversation>[];
      var migrated = false;
      if (restored.isEmpty && _legacyHistoryKey != null) {
        final legacy = await _cache.read(_legacyHistoryKey!);
        if (legacy is List) {
          final messages = legacy
              .map(CoachMessage.fromJson)
              .whereType<CoachMessage>()
              .toList();
          final firstUser = messages.where((message) => !message.assistant);
          if (firstUser.isNotEmpty) {
            restored.add(
              CoachConversation(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: CoachConversation.titleFrom(firstUser.first.text),
                updatedAt: DateTime.now(),
                messages: messages,
              ),
            );
            migrated = true;
          }
        }
      }
      if (!mounted || restored.isEmpty) return;
      restored.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _conversations
          ..clear()
          ..addAll(restored);
        _activeConversation = _conversations.first;
      });
      if (migrated) {
        _persistHistory();
        await _historyWrite;
        await _cache.remove(_legacyHistoryKey!);
      }
      _scrollToEnd();
    } catch (_) {}
  }

  void _persistHistory() {
    final key = _historyKey;
    if (key == null) return;
    final conversations = _conversations
        .where((conversation) => conversation.started)
        .toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final snapshot = conversations
        .map((conversation) => conversation.toJson())
        .toList();
    _historyWrite = _historyWrite
        .then((_) => _cache.write(key, snapshot))
        .catchError((Object _) {});
  }

  void _touchActiveConversation([String? firstMessage]) {
    final conversation = _activeConversation;
    if (conversation == null) return;
    if (firstMessage != null && conversation.title == 'New chat') {
      conversation.title = CoachConversation.titleFrom(firstMessage);
    }
    conversation.updatedAt = DateTime.now();
    _conversations
      ..remove(conversation)
      ..insert(0, conversation);
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString();
    final rawData = event['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    if (type == 'chat.start') {
      setState(() {
        _waiting = true;
        _error = null;
      });
    } else if (type == 'chat.delta') {
      final text = data['text']?.toString() ?? '';
      if (text.isEmpty) return;
      setState(() {
        _waiting = true;
        if (_messages.isEmpty || !_messages.last.assistant) {
          _messages.add(CoachMessage(assistant: true, text: text));
        } else {
          _messages.last.text += text;
        }
      });
      _scrollToEnd();
    } else if (type == 'chat.done') {
      setState(() {
        _waiting = false;
        _touchActiveConversation();
      });
      _persistHistory();
      _scrollToEnd();
    } else if (type == 'chat.data_changed') {
      unawaited(context.appRead.refresh(silent: true));
    } else if (type == 'error' || type == 'transport.error') {
      setState(() {
        _waiting = false;
        _messages.removeWhere((message) => message.text.isEmpty);
        _error =
            data['message']?.toString() ??
            'Tara could not answer right now. Please try again.';
      });
      _persistHistory();
      _scrollToEnd();
    }
  }

  Future<void> _send([String? suggestion]) async {
    if (_waiting || context.appRead.demo) return;
    await _historyLoaded;
    if (!mounted || _waiting || context.appRead.demo) return;
    final message = (suggestion ?? _composer.text).trim();
    if (message.isEmpty) return;
    final history = _messages
        .where((item) => item.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map(
          (item) => {
            'role': item.assistant ? 'assistant' : 'user',
            'content': item.text,
          },
        )
        .toList();
    _composer.clear();
    setState(() {
      _error = null;
      _waiting = true;
      _messages
        ..add(CoachMessage(assistant: false, text: message))
        ..add(CoachMessage(assistant: true, text: ''));
      _touchActiveConversation(message);
    });
    _persistHistory();
    _scrollToEnd();
    try {
      await _realtime.connect();
      _realtime.send('chat.message', {'message': message, 'history': history});
    } on ApiException catch (error) {
      _showSendError(error.message);
    } catch (_) {
      _showSendError('Tara could not connect. Please try again.');
    }
  }

  void _showSendError(String message) {
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _messages.removeWhere((item) => item.text.isEmpty);
      _error = message;
    });
    _persistHistory();
  }

  void _openConversation(CoachConversation conversation) {
    setState(() {
      _activeConversation = conversation;
      _error = null;
    });
    _scrollToEnd();
  }

  Future<bool> _deleteConversation(CoachConversation conversation) async {
    if (_waiting) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          '“${conversation.title}” will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    await _historyWrite;
    if (!mounted) return false;
    setState(() {
      _conversations.remove(conversation);
      if (identical(_activeConversation, conversation)) {
        final remaining = _conversations.where((item) => item.started).toList();
        if (remaining.isEmpty) {
          _replaceWithNewConversation();
        } else {
          remaining.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          _activeConversation = remaining.first;
        }
      }
      _error = null;
    });
    _persistHistory();
    await _historyWrite;
    return true;
  }

  Future<void> _showChatHistory() async {
    if (_waiting) return;
    await _historyLoaded;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final conversations =
              _conversations
                  .where((conversation) => conversation.started)
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final localizations = MaterialLocalizations.of(sheetContext);
          return FractionallySizedBox(
            heightFactor: .86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chats',
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close chat history',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('coach-new-chat'),
                    onPressed: () {
                      _newChat();
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.edit_square),
                    label: const Text('New chat'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Text(
                    'Recent',
                    style: Theme.of(sheetContext).textTheme.labelLarge
                        ?.copyWith(color: onwardMuted(sheetContext)),
                  ),
                ),
                if (conversations.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Your previous chats will appear here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext).textTheme.bodyLarge
                              ?.copyWith(color: onwardMuted(sheetContext)),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final selected = identical(
                          conversation,
                          _activeConversation,
                        );
                        return ListTile(
                          key: ValueKey('coach-thread-${conversation.id}'),
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : onwardMuted(context),
                          ),
                          title: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${localizations.formatShortDate(conversation.updatedAt.toLocal())} · ${conversation.messages.length} messages',
                          ),
                          onTap: () {
                            _openConversation(conversation);
                            Navigator.pop(sheetContext);
                          },
                          trailing: AppPopupMenuButton<String>(
                            key: ValueKey(
                              'coach-thread-menu-${conversation.id}',
                            ),
                            tooltip: 'Options for ${conversation.title}',
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (_) async {
                              final deleted = await _deleteConversation(
                                conversation,
                              );
                              if (deleted && sheetContext.mounted) {
                                setSheetState(() {});
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _messages.removeWhere((message) => message.text.isEmpty);
    _events?.cancel();
    if (widget.realtime == null) unawaited(_realtime.dispose());
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    final scheme = Theme.of(context).colorScheme;
    final standalone = Navigator.of(context).canPop();
    final suggestions = [
      'Show my upcoming tasks',
      'Create a new goal',
      'Help me plan this week',
      'Review my progress',
    ];
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    if (standalone) ...[
                      IconButton(
                        key: const ValueKey('coach-back'),
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 2),
                    ],
                    const _TaraAvatar(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tara AI',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your personal goal coach',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: onwardMuted(context)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('coach-history'),
                      tooltip: 'Chat history',
                      onPressed: _waiting ? null : _showChatHistory,
                      icon: const Icon(Icons.history_rounded),
                    ),
                    IconButton(
                      key: const ValueKey('coach-new-chat-header'),
                      tooltip: 'New chat',
                      onPressed: _waiting ? null : _newChat,
                      icon: const Icon(Icons.edit_square),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _messages.length == 1
                    ? _TaraWelcome(
                        name: state.user?.name ?? 'Friend',
                        suggestions: suggestions,
                        waiting: _waiting,
                        onSuggestion: _send,
                      )
                    : ListView.builder(
                        key: const ValueKey('coach-message-list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _CoachBubble(
                            key: ValueKey('coach-message-$index'),
                            message: message,
                            waiting:
                                _waiting &&
                                index == _messages.length - 1 &&
                                message.assistant &&
                                message.text.isEmpty,
                          );
                        },
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
                ),
              if (state.demo)
                Container(
                  key: const ValueKey('coach-demo-notice'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sign in to chat with Tara about your goals.',
                        ),
                      ),
                    ],
                  ),
                )
              else
                _CoachComposer(
                  controller: _composer,
                  waiting: _waiting,
                  clearNavigation: !standalone,
                  onSend: _send,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaraWelcome extends StatelessWidget {
  const _TaraWelcome({
    required this.name,
    required this.suggestions,
    required this.waiting,
    required this.onSuggestion,
  });

  final String name;
  final List<String> suggestions;
  final bool waiting;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rawFirstName = name.trim().split(' ').first;
    final firstName = rawFirstName.isEmpty
        ? 'Friend'
        : '${rawFirstName[0].toUpperCase()}${rawFirstName.substring(1)}';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'morning'
        : hour < 18
        ? 'afternoon'
        : 'evening';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        AppSurface(
          key: const ValueKey('coach-welcome-card'),
          color: scheme.surface,
          radius: 24,
          depth: .45,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const _TaraAvatar(size: 92),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good $greeting, $firstName!',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'I’m here to help you build better habits and move your goals forward every day.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onwardMuted(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('How can I help?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...suggestions.map(
          (suggestion) => AppSurface(
            radius: 18,
            depth: .45,
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: waiting ? null : () => onSuggestion(suggestion),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        suggestion,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: onwardMuted(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaraAvatar extends StatelessWidget {
  const _TaraAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .06),
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .16 : .9,
          ),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .16),
            blurRadius: size * .22,
            offset: Offset(0, size * .06),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/illustrations/tara-nav-v1.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({super.key, required this.message, required this.waiting});

  final CoachMessage message;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final foreground = message.assistant ? scheme.onSurface : Colors.white;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      color: foreground,
      height: 1.4,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.assistant
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (message.assistant) ...[
            const _TaraAvatar(size: 32),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Semantics(
              liveRegion: message.assistant,
              label: message.assistant ? 'Tara’s message' : 'Your message',
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: message.assistant
                      ? (dark ? OnwardColors.darkElevated : scheme.surface)
                      : scheme.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(message.assistant ? 6 : 20),
                    bottomRight: Radius.circular(message.assistant ? 20 : 6),
                  ),
                  border: Border.all(
                    color: message.assistant
                        ? scheme.outline.withValues(alpha: dark ? .28 : .7)
                        : scheme.primary,
                  ),
                  boxShadow: dark
                      ? null
                      : [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: .07),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: waiting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : message.assistant
                    ? MarkdownBody(
                        data: message.text,
                        selectable: true,
                        softLineBreak: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: bodyStyle,
                              strong: bodyStyle?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              em: bodyStyle?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              a: bodyStyle?.copyWith(
                                color: scheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.primary,
                              ),
                              h1: theme.textTheme.titleLarge?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                              h2: theme.textTheme.titleMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                              h3: bodyStyle?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              h1Padding: const EdgeInsets.only(bottom: 8),
                              h2Padding: const EdgeInsets.only(bottom: 6),
                              h3Padding: const EdgeInsets.only(bottom: 4),
                              blockSpacing: 9,
                              listIndent: 20,
                              listBullet: bodyStyle?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              code: bodyStyle?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              codeblockDecoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outline),
                              ),
                              blockquote: bodyStyle?.copyWith(
                                color: onwardMuted(context),
                                fontStyle: FontStyle.italic,
                              ),
                              blockquotePadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border(
                                  left: BorderSide(
                                    color: scheme.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              tableHead: bodyStyle?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              tableBody: bodyStyle,
                              tableBorder: TableBorder.all(
                                color: scheme.outline,
                              ),
                              tableCellsPadding: const EdgeInsets.all(8),
                            ),
                      )
                    : Text(message.text, style: bodyStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachComposer extends StatelessWidget {
  const _CoachComposer({
    required this.controller,
    required this.waiting,
    required this.clearNavigation,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool waiting;
  final bool clearNavigation;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 820;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        compact && clearNavigation
            ? MediaQuery.paddingOf(context).bottom + 32
            : 12,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: dark ? OnwardColors.darkElevated : scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outline.withValues(alpha: dark ? .5 : .85),
          ),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF3C5680).withValues(alpha: .1),
                    blurRadius: 20,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('coach-composer'),
                controller: controller,
                enabled: !waiting,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: waiting ? null : (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message Tara…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: waiting ? 'Tara is replying' : 'Send message',
              child: IconButton.filled(
                key: const ValueKey('coach-send'),
                onPressed: waiting ? null : onSend,
                style: IconButton.styleFrom(fixedSize: const Size.square(44)),
                icon: waiting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
