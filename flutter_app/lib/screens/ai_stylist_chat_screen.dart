import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_stylist_service.dart';
import '../state/outfit_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/placeholder_image.dart';
import 'wardrobe_item_detail_screen.dart';

class ChatMessage {
  ChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.options = const [],
    this.generalAdvice,
  });

  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<StylistOutfitOption> options;
  final String? generalAdvice;

  Map<String, dynamic> toJson() => {
    'is_user': isUser,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'general_advice': generalAdvice,
    'options': options.map((o) => o.toJson()).toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];
    final parsedOptions = rawOptions
        .whereType<Map>()
        .map((e) => StylistOutfitOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ChatMessage(
      isUser: json['is_user'] == true,
      text: (json['text'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      options: parsedOptions,
      generalAdvice: json['general_advice']?.toString(),
    );
  }
}

class AiStylistChatScreen extends StatefulWidget {
  const AiStylistChatScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<AiStylistChatScreen> createState() => _AiStylistChatScreenState();
}

class _AiStylistChatScreenState extends State<AiStylistChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _savedOptionKeys = <String>{};
  List<StylistChatSessionData> _sessions = const [];
  late String _currentSessionId;
  bool _isThinking = false;

  static const List<String> _quickPromptSuggestions = [
    'Outfit kuliah hari ini',
    'Wisuda teman',
    'Semi-formal meeting',
    'Nongkrong kasual',
  ];

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _currentSessionId = _newSessionId();

    // Friendly opening message from AI Stylist explaining free-form input
    _messages.add(_buildGreetingMessage());
    _restoreLatestSessionAndHandleInitialQuery();
  }

  String _newSessionId() => 'session-${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage _buildGreetingMessage() => ChatMessage(
    isUser: false,
    text: 'Halo! Aku AI Stylist pribadimu. Kamu bisa bebas menanyakan rekomendasi outfit untuk acara apa saja, preferensi warna, atau gaya tertentu (misalnya: wisuda teman, ngampus santai, meeting formal, hingga paduan warna netral). Ceritakan apa yang kamu butuhkan!',
    timestamp: DateTime.now(),
  );

  bool get _isEmptyNewSession =>
      !_messages.any((m) => m.isUser) && !_isThinking;

  Future<void> _restoreLatestSessionAndHandleInitialQuery() async {
    final sessions = await aiStylistService.loadChatSessions();
    if (!mounted) return;

    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      setState(() {
        _sessions = sessions;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleSend(initial);
      });
      return;
    }

    if (sessions.isNotEmpty) {
      final latest = sessions.first;
      final restored = latest.messages.map(ChatMessage.fromJson).toList();
      if (restored.isNotEmpty) {
        setState(() {
          _sessions = sessions;
          _currentSessionId = latest.id;
          _messages
            ..clear()
            ..addAll(restored);
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _persistHistory() async {
    await aiStylistService.upsertChatSession(
      sessionId: _currentSessionId,
      messages: _messages.map((m) => m.toJson()).toList(),
    );
    final updated = await aiStylistService.loadChatSessions();
    if (mounted) {
      setState(() {
        _sessions = updated;
      });
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = _newSessionId();
      _messages
        ..clear()
        ..add(_buildGreetingMessage());
      _savedOptionKeys.clear();
      _isThinking = false;
    });
  }

  void _openSession(StylistChatSessionData session) {
    final restored = session.messages.map(ChatMessage.fromJson).toList();
    setState(() {
      _currentSessionId = session.id;
      _messages
        ..clear()
        ..addAll(restored.isEmpty ? [_buildGreetingMessage()] : restored);
      _savedOptionKeys.clear();
      _isThinking = false;
    });
    _scrollToBottom();
  }

  String _formatIndonesianDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = today.difference(target).inDays;

    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final timePart = '$hh:$mm';

    if (diffDays == 0) return 'Hari ini • $timePart';
    if (diffDays == 1) return 'Kemarin • $timePart';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final monthName = months[dateTime.month - 1];
    return '${dateTime.day} $monthName ${dateTime.year} • $timePart';
  }

  Future<void> _showHistoryBottomSheet() async {
    final loaded = await aiStylistService.loadChatSessions();
    if (!mounted) return;
    setState(() {
      _sessions = loaded;
    });

    final palette = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: palette.action,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Riwayat Obrolan',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${_sessions.length} sesi',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.surfaceMuted),
                    if (_sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 36,
                              color: palette.inkMuted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada riwayat obrolan tersimpan.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: palette.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final session = _sessions[idx];
                            final isActive = session.id == _currentSessionId;
                            return Material(
                              color: isActive
                                  ? palette.action.withValues(alpha: 0.12)
                                  : palette.canvas,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  _openSession(session);
                                },
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    6,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isActive
                                          ? palette.action.withValues(
                                              alpha: 0.4,
                                            )
                                          : palette.surfaceMuted,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              session.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: palette.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatIndonesianDateTime(
                                                session.updatedAt,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: palette.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: palette.inkMuted,
                                        ),
                                        tooltip: 'Hapus Sesi',
                                        onPressed: () async {
                                          await aiStylistService
                                              .deleteChatSession(session.id);
                                          final refreshed =
                                              await aiStylistService
                                                  .loadChatSessions();
                                          if (!mounted) return;
                                          setState(() {
                                            _sessions = refreshed;
                                          });
                                          setSheetState(() {});
                                          if (session.id == _currentSessionId) {
                                            _startNewChat();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isThinking) return;

    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(isUser: true, text: cleanQuery, timestamp: DateTime.now()),
      );
      _isThinking = true;
    });
    _scrollToBottom();
    _persistHistory();

    // Build recent chat history (last 6 messages before the current prompt)
    final priorMessages = _messages.length > 1
        ? _messages.sublist(1, _messages.length - 1)
        : const <ChatMessage>[];
    final recentTurns =
        (priorMessages.length > 6
                ? priorMessages.sublist(priorMessages.length - 6)
                : priorMessages)
            .map((m) => StylistChatTurn(isUser: m.isUser, text: m.text))
            .toList();

    // Process through AiStylistService
    try {
      final response = await aiStylistService.recommend(
        query: cleanQuery,
        history: recentTurns,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: response.message,
            timestamp: DateTime.now(),
            options: response.options,
            generalAdvice: response.generalAdvice,
          ),
        );
        _isThinking = false;
      });
      _scrollToBottom();
      await _persistHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Maaf, terjadi kendala saat memproses permintaanmu. Coba sampaikan gayamu dengan kata kunci acara atau warna ya.',
            timestamp: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
      _scrollToBottom();
      await _persistHistory();
    }
  }

  Future<void> _saveOptionToFavorites(
    BuildContext context,
    StylistOutfitOption option,
  ) async {
    final optionKey = _optionKey(option);
    if (_savedOptionKeys.contains(optionKey)) return;

    try {
      final safeName = option.title.trim().length > 80
          ? option.title.trim().substring(0, 80)
          : option.title.trim();
      final validUuidIds = option.items
          .map((i) => i.id)
          .where((id) => _uuidPattern.hasMatch(id))
          .toList();

      final outfit = SavedOutfit(
        id: newOutfitId(),
        name: safeName.isEmpty ? 'Rekomendasi AI Stylist' : safeName,
        itemIds: validUuidIds,
        threshold: (option.matchScore / 100.0).clamp(0.0, 1.0),
        favorite: true,
      );
      await saveOutfit(outfit);

      if (mounted) {
        setState(() {
          _savedOptionKeys.add(optionKey);
        });
      }
      if (context.mounted) {
        showSuccessSnackBar(context, 'Kombinasi tersimpan di Favorit');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan favorit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _optionKey(StylistOutfitOption option) =>
      '${option.source.name}:${option.title}:${option.items.map((i) => i.id).join(',')}';

  IconData _iconForCategory(String category) => switch (category) {
    'Tops' => Icons.checkroom_outlined,
    'Bottoms' => Icons.accessibility_new_outlined,
    'Outerwear' => Icons.dry_cleaning_outlined,
    'Shoes' || 'Footwear' => Icons.hiking_outlined,
    'Accessories' => Icons.watch_outlined,
    _ => Icons.checkroom_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.sheet,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.action.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: palette.action, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Stylist GAYAKU',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Asisten Gaya Pribadi • Online',
                        style: TextStyle(fontSize: 11, color: palette.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: palette.ink),
            tooltip: 'Riwayat Obrolan',
            onPressed: _showHistoryBottomSheet,
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: palette.ink),
            tooltip: 'Obrolan Baru',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List (Spacious & Clean)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length + (_isThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessageItem(palette, _messages[index]);
                  }
                  if (_isThinking && index == _messages.length) {
                    return _buildThinkingBubble(palette);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Quick Prompt Chips when starting a fresh empty session
            if (_isEmptyNewSession)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickPromptSuggestions.map((prompt) {
                    return ActionChip(
                      avatar: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: palette.action,
                      ),
                      label: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.ink,
                        ),
                      ),
                      backgroundColor: palette.sheet,
                      side: BorderSide(
                        color: palette.action.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onPressed: () => _handleSend(prompt),
                    );
                  }).toList(),
                ),
              ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: palette.sheet,
                border: Border(
                  top: BorderSide(color: palette.surfaceMuted, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.surfaceMuted),
                      ),
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSend,
                        style: TextStyle(fontSize: 14, color: palette.ink),
                        decoration: InputDecoration(
                          hintText: 'Tanya rekomendasi gaya pakaian...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: palette.inkMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: palette.action,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _isThinking
                          ? null
                          : () => _handleSend(_textController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: palette.onAction,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: palette.action.withValues(alpha: 0.12),
            child: Icon(Icons.auto_awesome, size: 16, color: palette.action),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.sheet,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.surfaceMuted),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(palette.action),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stylist sedang mencocokkan lemarimu...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(AppPalette palette, ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.action,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.action.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: palette.onAction,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // AI Message Bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: palette.action.withValues(alpha: 0.12),
            child: Icon(Icons.auto_awesome, size: 16, color: palette.action),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat explanation bubble
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.sheet,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: palette.surfaceMuted),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: palette.ink,
                    ),
                  ),
                ),

                // General Advice Card (Fallback when wardrobe items are missing)
                if (message.generalAdvice != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: palette.accentInk,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panduan Gaya Rekomendasi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: palette.accentInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.generalAdvice!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Outfit Options Cards
                if (message.options.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.options.map(
                    (opt) => _buildOutfitOptionCard(palette, opt),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitOptionCard(
    AppPalette palette,
    StylistOutfitOption option,
  ) {
    final isSaved = _savedOptionKeys.contains(_optionKey(option));
    final isWardrobeSource =
        option.source == StylistRecommendationSource.wardrobe;
    final sourceBg = isWardrobeSource
        ? palette.action.withValues(alpha: 0.1)
        : palette.accent.withValues(alpha: 0.14);
    final sourceFg = isWardrobeSource ? palette.action : palette.accentInk;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.action.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source label & Match Score Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sourceBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option.sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: sourceFg,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB7E4C7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF1E5631),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${option.matchScore}% Match',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E5631),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Option Title
          Text(
            option.title,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 10),

          // Garment Thumbnails Row
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: option.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = option.items[idx];
                return GestureDetector(
                  onTap: isWardrobeSource
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WardrobeItemDetailScreen(item: item),
                          ),
                        )
                      : null,
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                      color: palette.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.surfaceMuted),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: double.infinity,
                              child: PlaceholderImage(
                                imagePath: item.imagePath,
                                icon: _iconForCategory(item.category),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Styling justification
          Text(
            option.stylingReason,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: palette.inkMuted,
            ),
          ),

          if (option.tips.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...option.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: palette.action)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Quick Action Button: Simpan ke Favorit
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: palette.action,
              ),
              label: Text(
                isSaved ? 'Tersimpan di Favorit' : 'Simpan ke Favorit',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.action,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.action, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSaved
                  ? null
                  : () => _saveOptionToFavorites(context, option),
            ),
          ),
        ],
      ),
    );
  }
}
