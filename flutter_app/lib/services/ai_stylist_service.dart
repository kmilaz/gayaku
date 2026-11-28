import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../state/wardrobe_store.dart';

/// Compile-time Gemini configuration via `--dart-define`:
/// `flutter run --dart-define=GEMINI_API_KEY=... --dart-define=GEMINI_MODEL=gemini-2.5-flash`
const String _envGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _envGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-2.5-flash',
);

/// Origin of a recommended outfit option.
enum StylistRecommendationSource { wardrobe, catalog, inspiration }

/// Lightweight chat turn passed to the stylist for conversational context.
class StylistChatTurn {
  const StylistChatTurn({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

/// Persisted multi-session chat record stored per user in SharedPreferences.
class StylistChatSessionData {
  const StylistChatSessionData({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  static String deriveTitleFromMessages(List<Map<String, dynamic>> messages) {
    for (final msg in messages) {
      if (msg['is_user'] == true) {
        final raw = (msg['text'] ?? '').toString().trim();
        if (raw.isNotEmpty) {
          if (raw.length <= 40) return raw;
          return '${raw.substring(0, 37)}...';
        }
      }
    }
    return 'Obrolan Baru';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updated_at': updatedAt.toIso8601String(),
    'messages': messages,
  };

  factory StylistChatSessionData.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'] as List? ?? const [];
    final parsedMsgs = rawMsgs
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return StylistChatSessionData(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Obrolan Baru').toString(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      messages: parsedMsgs,
    );
  }
}

/// Structured user intent extracted from conversational text.
class StylistIntent {
  const StylistIntent({
    required this.rawQuery,
    this.occasion,
    this.rawOccasion,
    this.targetFormality = 3,
    this.preferredColors = const [],
    this.preferredCategories = const [],
    this.preferredTone,
    this.preferNewest = false,
    this.genderContext,
  });

  final String rawQuery;
  final String? occasion;
  final String? rawOccasion;
  final int targetFormality;
  final List<String> preferredColors;
  final List<String> preferredCategories;
  final String? preferredTone; // 'cerah', 'gelap', 'netral'
  final bool preferNewest;
  final String? genderContext; // 'pria', 'wanita', or null
}

/// An outfit recommendation assembled by the AI Stylist.
class StylistOutfitOption {
  const StylistOutfitOption({
    required this.title,
    required this.items,
    required this.matchScore,
    required this.stylingReason,
    this.styleTag = 'Kasual',
    this.tips = const [],
    this.source = StylistRecommendationSource.wardrobe,
    this.usedGemini = false,
  });

  final String title;
  final List<WardrobeItem> items;
  final int matchScore; // 0..100
  final String stylingReason;
  final String styleTag;
  final List<String> tips;
  final StylistRecommendationSource source;
  final bool usedGemini;

  String get sourceLabel => switch (source) {
    StylistRecommendationSource.wardrobe => 'Dari Lemarimu',
    StylistRecommendationSource.catalog => 'Rekomendasi Katalog GAYAKU',
    StylistRecommendationSource.inspiration => 'Inspirasi Gaya GAYAKU',
  };

  Map<String, dynamic> toJson() => {
    'title': title,
    'match_score': matchScore,
    'styling_reason': stylingReason,
    'style_tag': styleTag,
    'tips': tips,
    'source': source.name,
    'used_gemini': usedGemini,
    'items': items
        .map(
          (i) => {
            'id': i.id,
            'name': i.name,
            'category': i.category,
            'subcategory': i.subcategory,
            'image_path': i.imagePath,
            'label': i.label,
            'brand': i.brand,
            'color_name': i.colorName,
            'color_argb': i.color.toARGB32(),
            'formality': i.formality,
            'occasions': i.occasions,
            'confidence': i.confidence,
          },
        )
        .toList(),
  };

  factory StylistOutfitOption.fromJson(Map<String, dynamic> json) {
    final sourceName = (json['source'] ?? 'wardrobe').toString();
    final source = StylistRecommendationSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => StylistRecommendationSource.wardrobe,
    );
    final rawItems = json['items'] as List? ?? const [];
    final parsedItems = <WardrobeItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      parsedItems.add(
        WardrobeItem(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? 'Item').toString(),
          category: (m['category'] ?? 'Tops').toString(),
          subcategory: m['subcategory']?.toString(),
          imagePath: (m['image_path'] ?? '').toString(),
          label: (m['label'] ?? '').toString(),
          brand: (m['brand'] ?? '').toString(),
          colorName: (m['color_name'] ?? '').toString(),
          color: Color((m['color_argb'] as num?)?.toInt() ?? 0xFFD3A277),
          formality: (m['formality'] as num?)?.toInt() ?? 3,
          occasions: (m['occasions'] as List? ?? const [])
              .map((e) => e.toString())
              .toList(),
          confidence: (m['confidence'] as num?)?.toDouble(),
        ),
      );
    }

    return StylistOutfitOption(
      title: (json['title'] ?? 'Rekomendasi Gaya').toString(),
      items: parsedItems,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 80,
      stylingReason: (json['styling_reason'] ?? '').toString(),
      styleTag: (json['style_tag'] ?? 'Kasual').toString(),
      tips: (json['tips'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      source: source,
      usedGemini: json['used_gemini'] == true,
    );
  }
}

/// Complete response from the AI Stylist.
class StylistResponse {
  const StylistResponse({
    required this.message,
    required this.intent,
    this.options = const [],
    this.generalAdvice,
    this.followUpPrompts = const [],
    this.usedGemini = false,
  });

  final String message;
  final StylistIntent intent;
  final List<StylistOutfitOption> options;
  final String? generalAdvice;
  final List<String> followUpPrompts;
  final bool usedGemini;
}

typedef GeminiGenerateCallback = Future<String?> Function({
  required String apiKey,
  required String model,
  required String prompt,
});

typedef CatalogFetchCallback = Future<List<WardrobeItem>> Function(
  StylistIntent intent,
);

/// Hybrid AI Stylist service powered by Gemini API + Supabase context
/// (`wardrobe_items` and optional catalog tables) with automatic local fallback.
class AiStylistService {
  const AiStylistService({
    String? apiKey,
    String? model,
    this.geminiCaller,
    this.catalogFetcher,
  }) : _apiKeyOverride = apiKey,
       _modelOverride = model;

  final String? _apiKeyOverride;
  final String? _modelOverride;
  final GeminiGenerateCallback? geminiCaller;
  final CatalogFetchCallback? catalogFetcher;

  String get apiKey => _apiKeyOverride ?? _envGeminiApiKey;
  String get model =>
      (_modelOverride != null && _modelOverride.trim().isNotEmpty)
      ? _modelOverride.trim()
      : _envGeminiModel;

  /// Parse the user's natural language query into intent attributes.
  StylistIntent parseIntent(String query) {
    final lower = query.toLowerCase();

    String? occasion;
    String? rawOccasion;
    int targetFormality = 3;

    // 1. Detect Occasion & Formality
    if (_containsAny(lower, [
      'kondangan malam',
      'wisuda',
      'graduation',
      'kondangan',
      'lamaran',
      'engagement',
      'resepsi',
      'pesta',
      'party',
      'wedding',
      'nikahan',
      'dinner',
      'gala',
      'prom',
      'smart-casual',
      'smart casual',
    ])) {
      occasion = 'Smart-Casual';
      if (lower.contains('kondangan malam')) {
        rawOccasion = 'kondangan malam';
      } else if (lower.contains('smart-casual') ||
          lower.contains('smart casual')) {
        rawOccasion = 'tampilan smart-casual';
      } else {
        rawOccasion =
            _matchedKeyword(lower, [
              'wisuda',
              'kondangan',
              'lamaran',
              'resepsi',
              'pesta',
              'wedding',
            ]) ??
            'wisuda';
      }
      targetFormality =
          (lower.contains('smart') && !lower.contains('kondangan')) ? 3 : 4;
    } else if (_containsAny(lower, [
      'sidang & interview',
      'interview',
      'wawancara',
      'sidang',
      'kantor',
      'office',
      'meeting',
      'rapat',
      'kerja',
      'work',
      'formal',
      'presentasi',
      'presentation',
      'seminar',
      'konferensi',
    ])) {
      occasion = 'Formal';
      if (lower.contains('sidang') && lower.contains('interview')) {
        rawOccasion = 'sidang & interview';
      } else {
        rawOccasion =
            _matchedKeyword(lower, [
              'interview',
              'sidang',
              'kantor',
              'meeting',
              'presentasi',
              'kerja',
            ]) ??
            'kantor';
      }
      targetFormality = 5;
    } else if (_containsAny(lower, [
      'olahraga / gym',
      'olahraga',
      'sport',
      'lari',
      'running',
      'gym',
      'workout',
      'jogging',
      'fitness',
      'sepeda',
      'cycling',
      'badminton',
      'futsal',
    ])) {
      occasion = 'Sport';
      rawOccasion = lower.contains('gym')
          ? 'olahraga / gym'
          : (_matchedKeyword(lower, [
                  'olahraga',
                  'lari',
                  'gym',
                  'workout',
                  'jogging',
                ]) ??
                'olahraga');
      targetFormality = 1;
    } else if (_containsAny(lower, [
      'kafe',
      'cafe',
      'nongkrong di kafe',
      'nongkrong kafe',
      'ngampus',
      'kuliah',
      'campus',
      'college',
      'nongkrong',
      'hangout',
      'jalan',
      'santai',
      'chill',
      'casual',
      'kasual',
      'harian',
      'daily',
      'kencan',
      'date',
      'mall',
      'ngopi',
    ])) {
      occasion = 'Kasual';
      if (lower.contains('kafe') || lower.contains('cafe')) {
        rawOccasion = 'nongkrong di kafe';
      } else {
        rawOccasion =
            _matchedKeyword(lower, [
              'ngampus',
              'kuliah',
              'nongkrong',
              'santai',
              'kencan',
              'jalan',
            ]) ??
            'kasual';
      }
      targetFormality = 2;
    } else {
      occasion = 'Kasual';
      rawOccasion = 'santai';
      targetFormality = 3;
    }

    final preferNewest =
        lower.contains('terbaru') || lower.contains('terbaruku');

    // 2. Detect Gender Context
    String? genderContext;
    if (_containsAny(lower, [
      'cewek',
      'wanita',
      'perempuan',
      'hijab',
      'dress',
      'kebaya',
      'rok',
      'blouse',
      'women',
      'female',
    ])) {
      genderContext = 'wanita';
    } else if (_containsAny(lower, ['cowok', 'pria', 'laki', 'men', 'male'])) {
      genderContext = 'pria';
    }

    // 3. Detect Preferred Colors
    final preferredColors = <String>[];
    if (lower.contains('hitam') || lower.contains('black')) {
      preferredColors.add('Hitam');
    }
    if (lower.contains('putih') || lower.contains('white')) {
      preferredColors.add('Putih');
    }
    if (lower.contains('navy') ||
        lower.contains('biru') ||
        lower.contains('blue')) {
      preferredColors.add('Biru');
    }
    if (lower.contains('merah') ||
        lower.contains('red') ||
        lower.contains('maroon')) {
      preferredColors.add('Merah');
    }
    if (lower.contains('pink') || lower.contains('merah muda')) {
      preferredColors.add('Pink');
    }
    if (lower.contains('hijau') ||
        lower.contains('green') ||
        lower.contains('sage') ||
        lower.contains('olive')) {
      preferredColors.add('Hijau');
    }
    if (lower.contains('kuning') ||
        lower.contains('yellow') ||
        lower.contains('mustard')) {
      preferredColors.add('Kuning');
    }
    if (lower.contains('abu') ||
        lower.contains('grey') ||
        lower.contains('gray')) {
      preferredColors.add('Abu-abu');
    }
    if (lower.contains('cokelat') ||
        lower.contains('brown') ||
        lower.contains('krem') ||
        lower.contains('beige') ||
        lower.contains('tan')) {
      preferredColors.add('Cokelat');
    }

    String? tone;
    if (lower.contains('netral') || lower.contains('neutral')) {
      tone = 'netral';
    } else if (lower.contains('cerah') || lower.contains('bright')) {
      tone = 'cerah';
    } else if (lower.contains('gelap') || lower.contains('dark')) {
      tone = 'gelap';
    }

    // 4. Detect Preferred Categories
    final preferredCategories = <String>[];
    if (_containsAny(lower, [
      'kemeja',
      'kaos',
      't-shirt',
      'shirt',
      'blouse',
      'polo',
      'baju',
      'atasan',
    ])) {
      preferredCategories.add('Tops');
    }
    if (_containsAny(lower, [
      'celana',
      'jeans',
      'chinos',
      'rok',
      'kulot',
      'trousers',
      'pants',
      'skirt',
      'bawahan',
    ])) {
      preferredCategories.add('Bottoms');
    }
    if (_containsAny(lower, [
      'jaket',
      'blazer',
      'cardigan',
      'hoodie',
      'outer',
      'jas',
      'jacket',
      'coat',
    ])) {
      preferredCategories.add('Outerwear');
    }
    if (_containsAny(lower, [
      'sepatu',
      'sneakers',
      'loafers',
      'heels',
      'boots',
      'sandals',
      'pantofel',
      'shoes',
      'sepatu santai',
    ])) {
      preferredCategories.add('Footwear');
    }
    if (_containsAny(lower, [
      'topi',
      'dasi',
      'tas',
      'bag',
      'belt',
      'ikat pinggang',
      'jam',
      'watch',
    ])) {
      preferredCategories.add('Accessories');
    }

    return StylistIntent(
      rawQuery: query,
      occasion: occasion,
      rawOccasion: rawOccasion,
      targetFormality: targetFormality,
      preferredColors: preferredColors,
      preferredCategories: preferredCategories,
      preferredTone: tone,
      preferNewest: preferNewest,
      genderContext: genderContext,
    );
  }

  /// Process query using Gemini API (when configured & online) with Supabase
  /// wardrobe + catalog context, or seamlessly fall back to local rules.
  Future<StylistResponse> recommend({
    required String query,
    List<WardrobeItem>? wardrobe,
    List<WardrobeItem>? catalogItems,
    List<StylistChatTurn> history = const [],
  }) async {
    final intent = parseIntent(query);

    // 1. Collect active user wardrobe items (exclude anything marked laundry).
    final rawWardrobe = wardrobe ?? await _loadActiveWardrobeItems();
    final activeWardrobe = rawWardrobe.where(_isAvailableForWear).toList();

    // 2. Collect relevant sample items from Supabase catalog/partner table if any.
    final resolvedCatalog =
        catalogItems ?? await _loadSupabaseCatalogItems(intent);

    // 3. Try Gemini API when GEMINI_API_KEY is present.
    if (apiKey.trim().isNotEmpty) {
      final geminiResponse = await _tryGeminiRecommend(
        query: query,
        intent: intent,
        wardrobe: activeWardrobe,
        catalog: resolvedCatalog,
        history: history,
      );
      if (geminiResponse != null) {
        return geminiResponse;
      }
    }

    // 4. Automatic local rule-based fallback using the exact same sources.
    return _recommendLocally(
      intent: intent,
      wardrobe: activeWardrobe,
      catalog: resolvedCatalog,
    );
  }

  Future<List<WardrobeItem>> _loadActiveWardrobeItems() async {
    final cached = wardrobeItems.value;
    final client = _trySupabaseClient();
    if (client == null || client.auth.currentUser == null) {
      return cached;
    }
    try {
      final rows = await client
          .from('wardrobe_items')
          .select(
            'id, name, label, category, subcategory, brand, color_name, dominant_color, formality, occasions, image_url, image_path',
          )
          .order('created_at', ascending: false)
          .limit(40);
      final mapped = <WardrobeItem>[];
      for (final row in rows) {
        final status = (row['status'] ?? row['laundry_status'] ?? '')
            .toString()
            .toLowerCase();
        if (status.contains('cucian') || status.contains('laundry')) continue;
        final cachedMatch = cached
            .where((w) => w.id == row['id'].toString())
            .firstOrNull;
        mapped.add(
          _wardrobeItemFromRow(row, fallbackImage: cachedMatch?.imagePath),
        );
      }
      return mapped.isNotEmpty ? mapped : cached;
    } catch (_) {
      return cached;
    }
  }

  Future<List<WardrobeItem>> _loadSupabaseCatalogItems(
    StylistIntent intent,
  ) async {
    if (catalogFetcher != null) {
      try {
        return await catalogFetcher!(intent);
      } catch (_) {
        return const [];
      }
    }
    final client = _trySupabaseClient();
    if (client == null) return const [];

    // Probe potential team catalog/partner dataset tables safely.
    for (final table in const ['catalog_items', 'partner_items']) {
      try {
        final rows = await client.from(table).select().limit(24);
        if (rows.isNotEmpty) {
          return rows
              .map<WardrobeItem>((row) => _wardrobeItemFromRow(row))
              .toList();
        }
      } catch (_) {
        // Table may not exist yet in the current Supabase schema; continue gracefully.
      }
    }
    return const [];
  }

  String? get activeUserId => _trySupabaseClient()?.auth.currentUser?.id;

  static const int maxPersistedMessages = 20;
  static const int maxPersistedSessions = 15;

  String historyStorageKey([String? userId]) {
    final resolved = (userId != null && userId.isNotEmpty)
        ? userId
        : (activeUserId ?? 'guest');
    return 'ai_stylist_history_$resolved';
  }

  String sessionsStorageKey([String? userId]) {
    final resolved = (userId != null && userId.isNotEmpty)
        ? userId
        : (activeUserId ?? 'guest');
    return 'ai_stylist_sessions_$resolved';
  }

  Future<List<StylistChatSessionData>> loadChatSessions({
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(sessionsStorageKey(userId));
      if (raw == null || raw.trim().isEmpty) {
        // Migrate legacy single-session history if present.
        final legacy = await loadSerializedHistory(userId: userId);
        if (legacy.isEmpty) return const [];
        final hasUserMsg = legacy.any((m) => m['is_user'] == true);
        if (!hasUserMsg) return const [];
        final migrated = StylistChatSessionData(
          id: 'session-legacy',
          title: StylistChatSessionData.deriveTitleFromMessages(legacy),
          updatedAt: DateTime.now(),
          messages: legacy,
        );
        await saveChatSessions([migrated], userId: userId);
        return [migrated];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final sessions = decoded
          .whereType<Map>()
          .map(
            (e) =>
                StylistChatSessionData.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((s) => s.id.isNotEmpty)
          .toList();
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions.take(maxPersistedSessions).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveChatSessions(
    List<StylistChatSessionData> sessions, {
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = [...sessions]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final capped = sorted.take(maxPersistedSessions).toList();
      await prefs.setString(
        sessionsStorageKey(userId),
        jsonEncode(capped.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // Ignore storage errors on unsupported/unmocked environments.
    }
  }

  Future<void> upsertChatSession({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
    DateTime? updatedAt,
    String? userId,
  }) async {
    final trimmedMessages = messages.length > maxPersistedMessages
        ? messages.sublist(messages.length - maxPersistedMessages)
        : messages;
    final hasUserMessage = trimmedMessages.any((m) => m['is_user'] == true);
    if (!hasUserMessage) return;

    final existing = await loadChatSessions(userId: userId);
    final updated = StylistChatSessionData(
      id: sessionId,
      title: StylistChatSessionData.deriveTitleFromMessages(trimmedMessages),
      updatedAt: updatedAt ?? DateTime.now(),
      messages: trimmedMessages,
    );
    final next = existing.where((s) => s.id != sessionId).toList()
      ..insert(0, updated);
    await saveChatSessions(next, userId: userId);
  }

  Future<void> deleteChatSession(String sessionId, {String? userId}) async {
    final existing = await loadChatSessions(userId: userId);
    final next = existing.where((s) => s.id != sessionId).toList();
    await saveChatSessions(next, userId: userId);
  }

  Future<void> clearChatSessions({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionsStorageKey(userId));
      await prefs.remove(historyStorageKey(userId));
    } catch (_) {
      // Ignore storage errors on unsupported/unmocked environments.
    }
  }

  Future<List<Map<String, dynamic>>> loadSerializedHistory({
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(historyStorageKey(userId));
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSerializedHistory(
    List<Map<String, dynamic>> messages, {
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = messages.length > maxPersistedMessages
          ? messages.sublist(messages.length - maxPersistedMessages)
          : messages;
      await prefs.setString(historyStorageKey(userId), jsonEncode(trimmed));
    } catch (_) {
      // Ignore storage errors on unsupported/unmocked environments.
    }
  }

  Future<void> clearSerializedHistory({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(historyStorageKey(userId));
    } catch (_) {
      // Ignore storage errors on unsupported/unmocked environments.
    }
  }

  sb.SupabaseClient? _trySupabaseClient() {
    try {
      return sb.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  WardrobeItem _wardrobeItemFromRow(
    Map<String, dynamic> row, {
    String? fallbackImage,
  }) {
    final imageUrl = (row['image_url'] ?? '').toString();
    final imagePath = (row['image_path'] ?? '').toString();
    final resolvedImage = imageUrl.isNotEmpty
        ? imageUrl
        : (imagePath.isNotEmpty ? imagePath : (fallbackImage ?? ''));

    final rawOccasions = row['occasions'];
    final occasions = rawOccasions is List
        ? rawOccasions.map((e) => e.toString()).toList()
        : const <String>[];

    final hex = (row['dominant_color'] ?? '#D3A277').toString();
    final parsedColor = _parseHexColor(hex);

    return WardrobeItem(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? 'Item').toString(),
      category: (row['category'] ?? 'Tops').toString(),
      subcategory: row['subcategory']?.toString(),
      imagePath: resolvedImage,
      label: (row['label'] ?? '').toString(),
      brand: (row['brand'] ?? '').toString(),
      colorName: (row['color_name'] ?? '').toString(),
      color: parsedColor,
      formality: (row['formality'] as num?)?.toInt() ?? 3,
      occasions: occasions,
    );
  }

  Color _parseHexColor(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFFD3A277);
  }

  bool _isAvailableForWear(WardrobeItem item) {
    final lowerName = item.name.toLowerCase();
    final lowerBrand = item.brand.toLowerCase();
    return !lowerName.contains('masuk cucian') &&
        !lowerBrand.contains('masuk cucian');
  }

  Future<StylistResponse?> _tryGeminiRecommend({
    required String query,
    required StylistIntent intent,
    required List<WardrobeItem> wardrobe,
    required List<WardrobeItem> catalog,
    required List<StylistChatTurn> history,
  }) async {
    try {
      final prompt = _buildGeminiPrompt(
        query: query,
        intent: intent,
        wardrobe: wardrobe,
        catalog: catalog,
        history: history,
      );

      final rawText = geminiCaller != null
          ? await geminiCaller!(apiKey: apiKey, model: model, prompt: prompt)
          : await _callGeminiHttp(apiKey: apiKey, model: model, prompt: prompt);

      if (rawText == null || rawText.trim().isEmpty) return null;
      return _parseGeminiJsonResponse(
        rawText: rawText,
        intent: intent,
        wardrobe: wardrobe,
        catalog: catalog,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _callGeminiHttp({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.65,
          },
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      return parts.first['text']?.toString();
    } finally {
      client.close(force: true);
    }
  }

  String _buildGeminiPrompt({
    required String query,
    required StylistIntent intent,
    required List<WardrobeItem> wardrobe,
    required List<WardrobeItem> catalog,
    required List<StylistChatTurn> history,
  }) {
    final recentHistory = history.length > 6
        ? history.sublist(history.length - 6)
        : history;

    final wardrobeJson = wardrobe
        .take(30)
        .map(
          (i) => {
            'id': i.id,
            'name': i.name,
            'category': i.category,
            'color': i.colorName,
            'formality': i.formality,
            'occasions': i.occasions,
          },
        )
        .toList();

    final catalogJson = catalog
        .take(24)
        .map(
          (i) => {
            'id': i.id,
            'name': i.name,
            'category': i.category,
            'color': i.colorName,
            'formality': i.formality,
            'occasions': i.occasions,
          },
        )
        .toList();

    final historyJson = recentHistory
        .map((t) => {'role': t.isUser ? 'user' : 'assistant', 'text': t.text})
        .toList();

    return '''
Kamu adalah AI Stylist GAYAKU berbahasa Indonesia yang ramah, ringkas, dan paham teori warna serta keserasian acara.

Permintaan user terbaru: "$query"
Konteks terdeteksi: acara=${intent.occasion}, target_formalitas=${intent.targetFormality}, gender=${intent.genderContext ?? 'netral'}, warna_diminati=${intent.preferredColors}.

Riwayat chat terakhir (maks 6):
${jsonEncode(historyJson)}

Lemari pribadi user (wardrobe_items aktif):
${jsonEncode(wardrobeJson)}

Katalog dataset tim GAYAKU (catalog_items):
${jsonEncode(catalogJson)}

Aturan Prioritas:
1. Prioritas 1 (`wardrobe_combinations`): Jika lemari user punya pasangan Tops dan Bottoms yang cocok dengan permintaan, rakit 1-3 kombinasi terbaik menggunakan `item_ids` dari lemari user.
2. Prioritas 2A (`catalog_recommendations`): Jika lemari user belum lengkap/tidak punya pasangan yang cocok, DAN `catalog_items` tidak kosong, rekomendasikan 1-3 pasangan dari `catalog_items` menggunakan `item_ids` dari katalog.
3. Prioritas 2B (`inspiration_looks`): Jika lemari user belum lengkap DAN `catalog_items` kosong, buat 2-3 kartu `inspiration_looks` terstruktur sesuai konteks gender & acara user.

Kembalikan HANYA JSON valid dengan struktur:
{
  "message": "penjelasan singkat ramah dalam Bahasa Indonesia",
  "general_advice": "tips styling umum singkat (opsional)",
  "wardrobe_combinations": [
    {
      "title": "nama kombinasi (maks 70 karakter)",
      "item_ids": ["id1", "id2"],
      "match_score": 88,
      "styling_reason": "alasan harmoni warna dan formalitas",
      "style_tag": "Smart-Casual",
      "tips": ["tip 1"]
    }
  ],
  "catalog_recommendations": [
    {
      "title": "nama rekomendasi katalog",
      "item_ids": ["cat_id1", "cat_id2"],
      "match_score": 85,
      "styling_reason": "alasan kecocokan",
      "style_tag": "Smart-Casual",
      "tips": ["tip 1"]
    }
  ],
  "inspiration_looks": [
    {
      "title": "nama inspirasi gaya",
      "match_score": 90,
      "styling_reason": "alasan kecocokan dengan acara dan gender",
      "style_tag": "Smart-Casual",
      "tips": ["tip 1"],
      "items": [
        {"name": "Kemeja Putih Rapi", "category": "Tops", "color_name": "Putih", "formality": 4},
        {"name": "Celana Chino Navy", "category": "Bottoms", "color_name": "Navy", "formality": 4}
      ]
    }
  ]
}
''';
  }

  StylistResponse? _parseGeminiJsonResponse({
    required String rawText,
    required StylistIntent intent,
    required List<WardrobeItem> wardrobe,
    required List<WardrobeItem> catalog,
  }) {
    final cleaned = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) return null;

    final wardrobeById = {for (final item in wardrobe) item.id: item};
    final catalogById = {for (final item in catalog) item.id: item};

    final options = <StylistOutfitOption>[];

    // Priority 1: Wardrobe combinations
    final wardrobeCombos = decoded['wardrobe_combinations'];
    if (wardrobeCombos is List) {
      for (final entry in wardrobeCombos) {
        if (entry is! Map<String, dynamic>) continue;
        final ids = (entry['item_ids'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final resolvedItems = ids
            .map((id) => wardrobeById[id])
            .whereType<WardrobeItem>()
            .toList();
        if (resolvedItems.isEmpty) continue;
        options.add(
          _optionFromJson(
            entry: entry,
            items: resolvedItems,
            source: StylistRecommendationSource.wardrobe,
            defaultTag: intent.occasion ?? 'Kasual',
            usedGemini: true,
          ),
        );
      }
    }

    // Priority 2A: Catalog recommendations
    if (options.isEmpty) {
      final catalogRecs = decoded['catalog_recommendations'];
      if (catalogRecs is List) {
        for (final entry in catalogRecs) {
          if (entry is! Map<String, dynamic>) continue;
          final ids = (entry['item_ids'] as List? ?? const [])
              .map((e) => e.toString())
              .toList();
          final resolvedItems = ids
              .map((id) => catalogById[id] ?? wardrobeById[id])
              .whereType<WardrobeItem>()
              .toList();
          if (resolvedItems.isEmpty) continue;
          options.add(
            _optionFromJson(
              entry: entry,
              items: resolvedItems,
              source: StylistRecommendationSource.catalog,
              defaultTag: intent.occasion ?? 'Kasual',
              usedGemini: true,
            ),
          );
        }
      }
    }

    // Priority 2B: Structured inspiration looks
    if (options.isEmpty) {
      final inspirations = decoded['inspiration_looks'];
      if (inspirations is List) {
        var idx = 0;
        for (final entry in inspirations) {
          if (entry is! Map<String, dynamic>) continue;
          idx++;
          final rawItems = entry['items'] as List? ?? const [];
          final parsedItems = <WardrobeItem>[];
          var itemIdx = 0;
          for (final rawItem in rawItems) {
            if (rawItem is! Map<String, dynamic>) continue;
            itemIdx++;
            final colorName = (rawItem['color_name'] ?? 'Netral').toString();
            parsedItems.add(
              WardrobeItem(
                id: 'insp-$idx-$itemIdx',
                name: (rawItem['name'] ?? 'Item Inspirasi').toString(),
                category: (rawItem['category'] ?? 'Tops').toString(),
                imagePath: '',
                colorName: colorName,
                color: _colorFromIndonesianName(colorName),
                formality:
                    (rawItem['formality'] as num?)?.toInt() ??
                    intent.targetFormality,
                occasions: [intent.occasion ?? 'Kasual'],
              ),
            );
          }
          if (parsedItems.isEmpty) continue;
          options.add(
            _optionFromJson(
              entry: entry,
              items: parsedItems,
              source: StylistRecommendationSource.inspiration,
              defaultTag: intent.occasion ?? 'Kasual',
              usedGemini: true,
            ),
          );
        }
      }
    }

    if (options.isEmpty) return null;

    final message = (decoded['message'] ?? '').toString().trim();
    final generalAdvice = decoded['general_advice']?.toString().trim();

    return StylistResponse(
      message: message.isNotEmpty
          ? message
          : _buildStylistIntro(intent, options.length),
      intent: intent,
      options: options.take(3).toList(),
      generalAdvice: (generalAdvice != null && generalAdvice.isNotEmpty)
          ? generalAdvice
          : null,
      usedGemini: true,
    );
  }

  StylistOutfitOption _optionFromJson({
    required Map<String, dynamic> entry,
    required List<WardrobeItem> items,
    required StylistRecommendationSource source,
    required String defaultTag,
    required bool usedGemini,
  }) {
    final score = ((entry['match_score'] as num?)?.toInt() ?? 85).clamp(50, 99);
    final tips = (entry['tips'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return StylistOutfitOption(
      title: (entry['title'] ?? 'Rekomendasi Gaya').toString(),
      items: items,
      matchScore: score,
      stylingReason:
          (entry['styling_reason'] ?? 'Paduan warna dan formalitas seimbang.')
              .toString(),
      styleTag: (entry['style_tag'] ?? defaultTag).toString(),
      tips: tips,
      source: source,
      usedGemini: usedGemini,
    );
  }

  StylistResponse _recommendLocally({
    required StylistIntent intent,
    required List<WardrobeItem> wardrobe,
    required List<WardrobeItem> catalog,
  }) {
    // Priority 1: Assemble combinations from user's own wardrobe.
    final wardrobeOptions = _assembleCombinations(
      intent: intent,
      items: wardrobe,
      source: StylistRecommendationSource.wardrobe,
    );
    if (wardrobeOptions.isNotEmpty) {
      return StylistResponse(
        message: _buildStylistIntro(intent, wardrobeOptions.length),
        intent: intent,
        options: wardrobeOptions,
        followUpPrompts: _generateFollowUps(intent),
      );
    }

    // Priority 2A: Assemble combinations from Supabase team catalog if available.
    if (catalog.isNotEmpty) {
      final catalogOptions = _assembleCombinations(
        intent: intent,
        items: catalog,
        source: StylistRecommendationSource.catalog,
      );
      if (catalogOptions.isNotEmpty) {
        final occasionLabel = intent.rawOccasion ?? 'acara kamu';
        return StylistResponse(
          message:
              'Lemarimu belum memiliki pasangan lengkap untuk $occasionLabel. Berikut ${catalogOptions.length} rekomendasi padu padan dari Katalog GAYAKU:',
          intent: intent,
          options: catalogOptions,
          followUpPrompts: _generateFollowUps(intent),
        );
      }
    }

    // Priority 2B: Generate 2-3 structured inspiration_looks + general advice.
    return _buildInspirationFallbackResponse(intent, wardrobe);
  }

  List<StylistOutfitOption> _assembleCombinations({
    required StylistIntent intent,
    required List<WardrobeItem> items,
    required StylistRecommendationSource source,
  }) {
    final tops = items.where((i) => i.category == 'Tops').toList();
    final bottoms = items.where((i) => i.category == 'Bottoms').toList();
    final outerwear = items.where((i) => i.category == 'Outerwear').toList();
    final footwear = items
        .where((i) => i.category == 'Shoes' || i.category == 'Footwear')
        .toList();
    final accessories = items
        .where((i) => i.category == 'Accessories')
        .toList();

    if (tops.isEmpty || bottoms.isEmpty) {
      return const [];
    }

    final combinations = <StylistOutfitOption>[];

    for (final top in tops) {
      for (final bottom in bottoms) {
        final pairScore = pairSubscores(
          top,
          bottom,
          occasion: intent.occasion ?? 'Kasual',
        );

        double score =
            (pairScore.color * 0.40) +
            (pairScore.formality * 0.35) +
            (pairScore.occasion * 0.25);

        final topFormalityGap = (top.formality - intent.targetFormality).abs();
        final bottomFormalityGap = (bottom.formality - intent.targetFormality)
            .abs();
        final avgFormalityGap = (topFormalityGap + bottomFormalityGap) / 2.0;
        if (avgFormalityGap <= 1.0) {
          score += 0.08;
        }

        if (intent.preferredColors.isNotEmpty) {
          final topColorMatch = intent.preferredColors.any(
            (c) => top.colorName.toLowerCase().contains(c.toLowerCase()),
          );
          final bottomColorMatch = intent.preferredColors.any(
            (c) => bottom.colorName.toLowerCase().contains(c.toLowerCase()),
          );
          if (topColorMatch || bottomColorMatch) {
            score += 0.10;
          }
        }

        if (intent.preferredTone == 'netral' &&
            (isNeutral(top.color) || isNeutral(bottom.color))) {
          score += 0.05;
        }

        if (intent.preferNewest &&
            (tops.indexOf(top) <= 1 || bottoms.indexOf(bottom) <= 1)) {
          score += 0.12;
        }

        final normalizedScore = (score.clamp(0.0, 1.0) * 100).round();
        if (normalizedScore < 50) continue;

        final outfitItems = <WardrobeItem>[top, bottom];

        if (footwear.isNotEmpty) {
          final bestShoe = footwear.reduce((a, b) {
            final aGap = (a.formality - intent.targetFormality).abs();
            final bGap = (b.formality - intent.targetFormality).abs();
            return aGap <= bGap ? a : b;
          });
          outfitItems.add(bestShoe);
        }

        if ((intent.targetFormality >= 3) && outerwear.isNotEmpty) {
          final matchingOuter = outerwear.firstWhere(
            (o) => (o.formality - intent.targetFormality).abs() <= 1,
            orElse: () => outerwear.first,
          );
          if (!outfitItems.contains(matchingOuter)) {
            outfitItems.add(matchingOuter);
          }
        } else if (accessories.isNotEmpty && outfitItems.length < 4) {
          outfitItems.add(accessories.first);
        }

        final colorHarmony = harmonyOf(top.color, bottom.color);
        final reason = _generateStylingReason(
          top: top,
          bottom: bottom,
          harmony: colorHarmony,
          occasion: intent.occasion ?? 'Kasual',
          targetFormality: intent.targetFormality,
        );

        final tips = _generateTips(
          top: top,
          bottom: bottom,
          occasion: intent.occasion ?? 'Kasual',
        );

        combinations.add(
          StylistOutfitOption(
            title: _generateOptionTitle(
              combinations.length + 1,
              intent.occasion ?? 'Kasual',
              top,
              bottom,
            ),
            items: outfitItems,
            matchScore: normalizedScore,
            stylingReason: reason,
            styleTag: intent.occasion ?? 'Kasual',
            tips: tips,
            source: source,
          ),
        );
      }
    }

    combinations.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    final selectedOptions = <StylistOutfitOption>[];
    final seenTopIds = <String>{};
    for (final opt in combinations) {
      final topId = opt.items.first.id;
      if (!seenTopIds.contains(topId) || selectedOptions.length < 2) {
        selectedOptions.add(opt);
        seenTopIds.add(topId);
      }
      if (selectedOptions.length >= 3) break;
    }

    return selectedOptions;
  }

  StylistResponse _buildInspirationFallbackResponse(
    StylistIntent intent,
    List<WardrobeItem> items,
  ) {
    final occasionLabel = intent.rawOccasion ?? 'acara kamu';
    final isWomen = intent.genderContext == 'wanita';
    final String advice;

    if (intent.occasion == 'Smart-Casual' || intent.targetFormality == 4) {
      advice = isWomen
          ? 'Untuk acara semi-formal seperti $occasionLabel, pilih atasan blouse atau tunik berpotongan rapi (warna pastel, putih, atau navy) dipadukan dengan celana kulot/bahan atau rok midi dan flat shoes atau low heels.'
          : 'Untuk acara semi-formal seperti $occasionLabel, paduan ideal adalah kemeja katun polos berkerah rapi (warna putih, biru muda, atau navy) dipadukan dengan celana chino atau celana bahan berpotongan slim-fit. Tambahkan sepatu loafers atau dress shoes untuk sentuhan elegan.';
    } else if (intent.occasion == 'Formal' || intent.targetFormality == 5) {
      advice = isWomen
          ? 'Untuk acara formal seperti $occasionLabel, gunakan kemeja atau blouse rapi dengan blazer terstruktur, celana bahan atau rok lurus warna gelap, serta sepatu pantofel atau heels tertutup.'
          : 'Untuk acara formal seperti $occasionLabel, gunakan kemeja berkerah kaku dipadukan dengan celana bahan hitam/charcoal, jas atau blazer, serta sepatu pantofel atau oxfords gelap yang bersih.';
    } else if (intent.occasion == 'Sport') {
      advice =
          'Untuk $occasionLabel, pilih pakaian berbahan breathable jersey atau dri-fit dengan celana training/jogger dan sepatu running yang memiliki bantalan empuk.';
    } else {
      advice =
          'Untuk gaya kasual santai seperti $occasionLabel, kaos polos berkualitas atau polo shirt dipadukan dengan celana jeans atau chinos serta sneakers bersih akan memberikan kesan effortless stylish.';
    }

    final inspirations = _buildStructuredInspirationLooks(intent);
    final hasSomeItems = items.isNotEmpty;
    final message = hasSomeItems
        ? 'Lemarimu saat ini belum memiliki pasangan lengkap untuk $occasionLabel. Berikut ${inspirations.length} inspirasi gaya rekomendasi dari GAYAKU:'
        : 'Lemarimu masih kosong! Sambil menunggu kamu menambahkan koleksi pakaian, berikut ${inspirations.length} inspirasi gaya rekomendasi untuk $occasionLabel:';

    return StylistResponse(
      message: message,
      intent: intent,
      options: inspirations,
      generalAdvice: advice,
      followUpPrompts: _generateFollowUps(intent),
    );
  }

  List<StylistOutfitOption> _buildStructuredInspirationLooks(
    StylistIntent intent,
  ) {
    final occasion = intent.occasion ?? 'Kasual';
    final isWomen = intent.genderContext == 'wanita';

    if (occasion == 'Smart-Casual') {
      if (isWomen) {
        return [
          StylistOutfitOption(
            title: 'Inspirasi 1: Anggun Pastel Semi-Formal',
            items: [
              _inspItem(
                'insp-w-sc-1a',
                'Blouse Satin Sage',
                'Tops',
                'Hijau',
                4,
              ),
              _inspItem(
                'insp-w-sc-1b',
                'Celana Kulot Krem',
                'Bottoms',
                'Cokelat',
                4,
              ),
              _inspItem(
                'insp-w-sc-1c',
                'Kitten Heels Nude',
                'Shoes',
                'Cokelat',
                4,
              ),
            ],
            matchScore: 92,
            stylingReason: 'Palet earth-tone lembut memberi kesan anggun, rapi, dan cocok untuk acara wisuda atau kondangan.',
            styleTag: 'Smart-Casual',
            tips: const [
              'Tambahkan tas clutch senada agar tampilan makin serasi.',
            ],
            source: StylistRecommendationSource.inspiration,
          ),
          StylistOutfitOption(
            title: 'Inspirasi 2: Klasik Modern Navy & Putih',
            items: [
              _inspItem(
                'insp-w-sc-2a',
                'Tunik Brokat Putih',
                'Tops',
                'Putih',
                4,
              ),
              _inspItem(
                'insp-w-sc-2b',
                'Rok Lilit / Plisket Navy',
                'Bottoms',
                'Biru',
                4,
              ),
              _inspItem(
                'insp-w-sc-2c',
                'Flat Shoes Putih Bersih',
                'Shoes',
                'Putih',
                4,
              ),
            ],
            matchScore: 89,
            stylingReason: 'Kontras bersih putih dan navy memberi tampilan klasik yang tidak berlebihan.',
            styleTag: 'Smart-Casual',
            tips: const ['Pilih aksesori anting atau jam tangan minimalis.'],
            source: StylistRecommendationSource.inspiration,
          ),
        ];
      }
      return [
        StylistOutfitOption(
          title: 'Inspirasi 1: Smart-Casual Navy & Krem',
          items: [
            _inspItem(
              'insp-m-sc-1a',
              'Kemeja Oxford Putih',
              'Tops',
              'Putih',
              4,
            ),
            _inspItem(
              'insp-m-sc-1b',
              'Celana Chino Krem',
              'Bottoms',
              'Cokelat',
              4,
            ),
            _inspItem(
              'insp-m-sc-1c',
              'Blazer Navy Ringan',
              'Outerwear',
              'Biru',
              4,
            ),
            _inspItem('insp-m-sc-1d', 'Loafers Cokelat', 'Shoes', 'Cokelat', 4),
          ],
          matchScore: 92,
          stylingReason: 'Kombinasi warna netral hangat dengan aksen navy sangat aman dan berkelas untuk wisuda maupun kondangan.',
          styleTag: 'Smart-Casual',
          tips: const [
            'Gulung lengan blazer sedikit jika acara berlangsung siang hari.',
          ],
          source: StylistRecommendationSource.inspiration,
        ),
        StylistOutfitOption(
          title: 'Inspirasi 2: Minimalis Monokrom Rapi',
          items: [
            _inspItem(
              'insp-m-sc-2a',
              'Kemeja Kerah Mandarin Abu',
              'Tops',
              'Abu-abu',
              4,
            ),
            _inspItem(
              'insp-m-sc-2b',
              'Celana Bahan Hitam Slim',
              'Bottoms',
              'Hitam',
              4,
            ),
            _inspItem('insp-m-sc-2c', 'Derby Shoes Hitam', 'Shoes', 'Hitam', 4),
          ],
          matchScore: 88,
          stylingReason: 'Potongan clean monokrom memberi siluet rapi tanpa terasa terlalu kaku.',
          styleTag: 'Smart-Casual',
          tips: const [
            'Gunakan jam tangan strap kulit hitam untuk sentuhan akhir.',
          ],
          source: StylistRecommendationSource.inspiration,
        ),
      ];
    }

    if (occasion == 'Formal') {
      return [
        StylistOutfitOption(
          title: 'Inspirasi 1: Eksekutif Klasik',
          items: [
            _inspItem(
              'insp-f-1a',
              isWomen ? 'Blouse Kerah Putih' : 'Kemeja Formal Putih',
              'Tops',
              'Putih',
              5,
            ),
            _inspItem('insp-f-1b', 'Celana Bahan Hitam', 'Bottoms', 'Hitam', 5),
            _inspItem(
              'insp-f-1c',
              'Blazer / Jas Hitam',
              'Outerwear',
              'Hitam',
              5,
            ),
            _inspItem(
              'insp-f-1d',
              isWomen ? 'Pump Heels Hitam' : 'Pantofel Hitam',
              'Shoes',
              'Hitam',
              5,
            ),
          ],
          matchScore: 94,
          stylingReason: 'Standar profesional tertinggi dengan tingkat formalitas seimbang untuk sidang atau interview.',
          styleTag: 'Formal',
          tips: const ['Pastikan kemeja disetrika rapi sebelum dipakai.'],
          source: StylistRecommendationSource.inspiration,
        ),
        StylistOutfitOption(
          title: 'Inspirasi 2: Charcoal Profesional',
          items: [
            _inspItem(
              'insp-f-2a',
              isWomen ? 'Kemeja Biru Muda' : 'Kemeja Oxford Biru Muda',
              'Tops',
              'Biru',
              5,
            ),
            _inspItem(
              'insp-f-2b',
              'Celana Bahan Abu Tua',
              'Bottoms',
              'Abu-abu',
              5,
            ),
            _inspItem('insp-f-2c', 'Sepatu Formal Hitam', 'Shoes', 'Hitam', 5),
          ],
          matchScore: 89,
          stylingReason: 'Nuansa biru muda dan abu-abu tua memberi kesan tenang, kompeten, dan terpercaya.',
          styleTag: 'Formal',
          tips: const [
            'Padukan dengan ikat pinggang gelap yang senada dengan sepatu.',
          ],
          source: StylistRecommendationSource.inspiration,
        ),
      ];
    }

    if (occasion == 'Sport') {
      return [
        StylistOutfitOption(
          title: 'Inspirasi 1: Athleisure Breathable',
          items: [
            _inspItem('insp-s-1a', 'Kaos Dri-Fit Hitam', 'Tops', 'Hitam', 1),
            _inspItem(
              'insp-s-1b',
              'Celana Jogger Abu-abu',
              'Bottoms',
              'Abu-abu',
              1,
            ),
            _inspItem('insp-s-1c', 'Running Shoes Putih', 'Shoes', 'Putih', 1),
          ],
          matchScore: 91,
          stylingReason: 'Material ringan menyerap keringat dengan warna netral yang nyaman untuk gym maupun lari pagi.',
          styleTag: 'Sport',
          tips: const [
            'Gunakan kaus kaki sport katun untuk kenyamanan ekstra.',
          ],
          source: StylistRecommendationSource.inspiration,
        ),
        StylistOutfitOption(
          title: 'Inspirasi 2: Sporty Cerah Aktif',
          items: [
            _inspItem('insp-s-2a', 'Jersey Olahraga Navy', 'Tops', 'Biru', 1),
            _inspItem(
              'insp-s-2b',
              'Celana Training Hitam',
              'Bottoms',
              'Hitam',
              1,
            ),
            _inspItem('insp-s-2c', 'Sneakers Lari', 'Shoes', 'Hitam', 1),
          ],
          matchScore: 87,
          stylingReason: 'Kombinasi praktis dan tahan lama untuk aktivitas fisik intensitas sedang hingga tinggi.',
          styleTag: 'Sport',
          tips: const [
            'Tambahkan topi olahraga jika beraktivitas di luar ruangan.',
          ],
          source: StylistRecommendationSource.inspiration,
        ),
      ];
    }

    return [
      StylistOutfitOption(
        title: 'Inspirasi 1: Kasual Effortless Netral',
        items: [
          _inspItem('insp-c-1a', 'Kaos Katun Putih Polos', 'Tops', 'Putih', 2),
          _inspItem(
            'insp-c-1b',
            'Celana Jeans Biru Medium',
            'Bottoms',
            'Biru',
            2,
          ),
          _inspItem('insp-c-1c', 'Sneakers Putih Bersih', 'Shoes', 'Putih', 2),
        ],
        matchScore: 91,
        stylingReason: 'Paduan klasik putih dan denim yang selalu rapi untuk ngampus maupun nongkrong di kafe.',
        styleTag: 'Kasual',
        tips: const [
          'Tambahkan jaket denim atau kemeja flanel sebagai outer bila perlu.',
        ],
        source: StylistRecommendationSource.inspiration,
      ),
      StylistOutfitOption(
        title: 'Inspirasi 2: Earth-Tone Santai',
        items: [
          _inspItem(
            'insp-c-2a',
            isWomen ? 'Cardigan Rajut Krem' : 'Polo Shirt Hitam',
            'Tops',
            isWomen ? 'Cokelat' : 'Hitam',
            2,
          ),
          _inspItem('insp-c-2b', 'Celana Chino Olive', 'Bottoms', 'Hijau', 2),
          _inspItem('insp-c-2c', 'Sneakers Kasual', 'Shoes', 'Putih', 2),
        ],
        matchScore: 87,
        stylingReason: 'Sentuhan warna bumi yang hangat membuat tampilan kasual terlihat lebih terkurasi.',
        styleTag: 'Kasual',
        tips: const ['Pilih tas tote bag kanvas untuk melengkapi gaya harian.'],
        source: StylistRecommendationSource.inspiration,
      ),
    ];
  }

  WardrobeItem _inspItem(
    String id,
    String name,
    String category,
    String colorName,
    int formality,
  ) {
    return WardrobeItem(
      id: id,
      name: name,
      category: category,
      imagePath: '',
      colorName: colorName,
      color: _colorFromIndonesianName(colorName),
      formality: formality,
    );
  }

  Color _colorFromIndonesianName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('hitam') || lower.contains('black')) {
      return const Color(0xFF1F2937);
    }
    if (lower.contains('putih') || lower.contains('white')) {
      return const Color(0xFFF9FAFB);
    }
    if (lower.contains('navy') || lower.contains('biru')) {
      return const Color(0xFF1E3A8A);
    }
    if (lower.contains('hijau') ||
        lower.contains('sage') ||
        lower.contains('olive')) {
      return const Color(0xFF4D7C5D);
    }
    if (lower.contains('merah') || lower.contains('maroon')) {
      return const Color(0xFF991B1B);
    }
    if (lower.contains('abu')) {
      return const Color(0xFF6B7280);
    }
    if (lower.contains('cokelat') ||
        lower.contains('krem') ||
        lower.contains('nude')) {
      return const Color(0xFFD3A277);
    }
    return const Color(0xFFD3A277);
  }

  String _buildStylistIntro(StylistIntent intent, int optionCount) {
    if (intent.preferNewest) {
      return 'Kombinasi padu padan terbaik menggunakan koleksi pakaian terbarumu dari lemari:';
    }
    if (intent.rawQuery.toLowerCase().contains('sepatu santai')) {
      return 'Paduan outfit kasual yang pas dipadukan dengan sepatu santai koleksimu:';
    }

    final occasionName = intent.rawOccasion ?? 'acara kamu';
    final occasionTag = intent.occasion ?? 'Kasual';

    if (intent.targetFormality >= 4) {
      return 'Untuk $occasionName, gaya $occasionTag paling pas agar kamu tampil rapi, percaya diri, dan berkelas. Aku menemukan $optionCount kombinasi terbaik langsung dari lemarimu:';
    } else if (intent.occasion == 'Sport') {
      return 'Untuk aktivitas $occasionName, kenyamanan gerak dan bahan breathable adalah prioritas utama. Ini paduan outfit sporty yang cocok dari lemarimu:';
    } else {
      return 'Pilihan santai tapi tetap modis untuk $occasionName! Berikut $optionCount rekomendasi padu padan seimbang dari lemarimu:';
    }
  }

  String _generateOptionTitle(
    int index,
    String occasion,
    WardrobeItem top,
    WardrobeItem bottom,
  ) {
    if (occasion == 'Smart-Casual') {
      return 'Opsi $index: Setelan Semi-Formal Elegan';
    } else if (occasion == 'Formal') {
      return 'Opsi $index: Setelan Formal Profesional';
    } else if (occasion == 'Sport') {
      return 'Opsi $index: Setelan Sporty Aktif';
    }
    return 'Opsi $index: Paduan Kasual Rapi';
  }

  String _generateStylingReason({
    required WardrobeItem top,
    required WardrobeItem bottom,
    required ColorHarmony harmony,
    required String occasion,
    required int targetFormality,
  }) {
    final harmonyDesc = switch (harmony) {
      ColorHarmony.netral =>
        'Harmoni warna netral yang bersih dan mudah dipadukan.',
      ColorHarmony.analog => 'Kombinasi warna analog yang senada dan memberikan kesan harmonis lembut.',
      ColorHarmony.komplementer =>
        'Paduan warna komplementer yang kontras berimbang dan menarik visual.',
      ColorHarmony.triadic => 'Kombinasi dinamis yang seimbang dan segar.',
      ColorHarmony.kontras =>
        'Sentuhan warna berani yang memberi daya tarik tersendiri.',
    };

    final formalityGap = (top.formality - bottom.formality).abs();
    final formalityDesc = formalityGap <= 1
        ? 'Tingkat formalitas ${top.name} dan ${bottom.name} sangat seimbang.'
        : 'Paduan kasual-smart yang fleksibel dipakai beraktivitas.';

    return '$harmonyDesc $formalityDesc';
  }

  List<String> _generateTips({
    required WardrobeItem top,
    required WardrobeItem bottom,
    required String occasion,
  }) {
    final list = <String>[];
    if (top.category == 'Tops' && top.name.toLowerCase().contains('kemeja')) {
      list.add('Masukkan kemeja ke dalam celana untuk tampilan lebih rapi.');
    }
    if (occasion == 'Smart-Casual' || occasion == 'Formal') {
      list.add('Gunakan ikat pinggang berwarna senada dengan sepatu.');
    } else {
      list.add('Gulung sedikit ujung lengan atau celana untuk gaya santai.');
    }
    return list;
  }

  List<String> _generateFollowUps(StylistIntent intent) {
    final occasion = intent.occasion ?? 'Kasual';
    if (occasion == 'Smart-Casual' || occasion == 'Formal') {
      return [
        'Ingin opsi warna lebih netral',
        'Rekomendasi sepatu yang cocok',
        'Gaya yang sedikit lebih santai',
      ];
    } else if (occasion == 'Sport') {
      return [
        'Rekomendasi sepatu olahraga',
        'Ganti warna lebih gelap',
        'Opsi outfit untuk gym',
      ];
    } else {
      return [
        'Cari paduan yang lebih formal',
        'Pilihan warna pastel / cerah',
        'Tambahkan jaket atau luaran',
      ];
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  String? _matchedKeyword(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return kw;
    }
    return null;
  }
}

/// Global singleton instance of AI Stylist Service.
const aiStylistService = AiStylistService();
