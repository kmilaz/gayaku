import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/screens/ai_stylist_chat_screen.dart';
import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/services/ai_stylist_service.dart';
import 'package:flutter_app/state/wardrobe_store.dart';

void main() {
  group('AiStylistService Intent Parsing', () {
    const service = AiStylistService();

    test('parses semi-formal wisuda query with navy color', () {
      final intent = service.parseIntent(
        'Rekomendasi pakaian ke wisuda teman warna navy',
      );
      expect(intent.occasion, 'Smart-Casual');
      expect(intent.targetFormality, 4);
      expect(intent.preferredColors, contains('Biru'));
    });

    test('parses formal interview query', () {
      final intent = service.parseIntent(
        'Baju untuk interview kerja di kantor',
      );
      expect(intent.occasion, 'Formal');
      expect(intent.targetFormality, 5);
      expect(intent.preferredCategories, contains('Tops'));
    });

    test('parses casual campus query with black t-shirt', () {
      final intent = service.parseIntent(
        'Outfit santai ngampus pakai kaos hitam',
      );
      expect(intent.occasion, 'Kasual');
      expect(intent.targetFormality, 2);
      expect(intent.preferredColors, contains('Hitam'));
      expect(intent.preferredCategories, contains('Tops'));
    });

    test('parses sporty running query', () {
      final intent = service.parseIntent('Mau lari pagi olahraga santai');
      expect(intent.occasion, 'Sport');
      expect(intent.targetFormality, 1);
    });

    test('parses expanded topics: kondangan malam, sidang, kafe, netral, hitam putih, terbaru', () {
      final kondangan = service.parseIntent('Kondangan malam');
      expect(kondangan.occasion, 'Smart-Casual');
      expect(kondangan.targetFormality, 4);

      final sidang = service.parseIntent('Sidang & interview');
      expect(sidang.occasion, 'Formal');
      expect(sidang.targetFormality, 5);

      final kafe = service.parseIntent('Nongkrong di kafe');
      expect(kafe.occasion, 'Kasual');
      expect(kafe.targetFormality, 2);

      final hitamPutih = service.parseIntent('Padu padan hitam & putih');
      expect(hitamPutih.preferredColors, containsAll(['Hitam', 'Putih']));

      final netral = service.parseIntent('Outfit warna netral');
      expect(netral.preferredTone, 'netral');

      final terbaru = service.parseIntent('Rekomendasi dari baju terbaruku');
      expect(terbaru.preferNewest, isTrue);

      final sepatu = service.parseIntent('Padukan sepatu santai');
      expect(sepatu.preferredCategories, contains('Footwear'));
    });
  });

  group('AiStylistService Recommendations & Hybrid Fallback', () {
    const service = AiStylistService();

    test('returns structured inspiration looks and advice when wardrobe & catalog are empty', () async {
      final response = await service.recommend(
        query: 'Rekomendasi pakaian ke wisuda teman untuk cewek',
        wardrobe: [],
        catalogItems: [],
      );

      expect(response.options.length, greaterThanOrEqualTo(2));
      expect(
        response.options.first.source,
        StylistRecommendationSource.inspiration,
      );
      expect(response.options.first.sourceLabel, 'Inspirasi Gaya GAYAKU');
      expect(response.generalAdvice, isNotNull);
      expect(response.generalAdvice, contains('semi-formal'));
    });

    test('uses catalog recommendations when wardrobe is incomplete and catalog has items', () async {
      final catalogItems = [
        const WardrobeItem(
          id: 'cat-top-1',
          name: 'Kemeja Linen Putih',
          category: 'Tops',
          imagePath: '',
          colorName: 'Putih',
          color: Color(0xFFFFFFFF),
          formality: 4,
          occasions: ['Smart-Casual'],
        ),
        const WardrobeItem(
          id: 'cat-bot-1',
          name: 'Celana Chino Navy',
          category: 'Bottoms',
          imagePath: '',
          colorName: 'Navy',
          color: Color(0xFF000080),
          formality: 4,
          occasions: ['Smart-Casual'],
        ),
      ];

      final response = await service.recommend(
        query: 'Acara wisuda teman',
        wardrobe: [],
        catalogItems: catalogItems,
      );

      expect(response.options, isNotEmpty);
      expect(
        response.options.first.source,
        StylistRecommendationSource.catalog,
      );
      expect(response.options.first.sourceLabel, 'Rekomendasi Katalog GAYAKU');
    });

    test(
      'assembles matching outfit from wardrobe and skips Masuk Cucian',
      () async {
        final demoWardrobe = [
          const WardrobeItem(
            id: 'top-laundry',
            name: 'Kemeja Kotor (Masuk Cucian)',
            category: 'Tops',
            imagePath: '',
            colorName: 'Putih',
            color: Color(0xFFFFFFFF),
            formality: 4,
            occasions: ['Smart-Casual'],
          ),
          const WardrobeItem(
            id: 'top-1',
            name: 'Kemeja Oxford Putih',
            category: 'Tops',
            imagePath: '',
            colorName: 'Putih',
            color: Color(0xFFFFFFFF),
            formality: 4,
            occasions: ['Smart-Casual', 'Formal'],
          ),
          const WardrobeItem(
            id: 'bottom-1',
            name: 'Celana Chino Navy',
            category: 'Bottoms',
            imagePath: '',
            colorName: 'Navy',
            color: Color(0xFF000080),
            formality: 4,
            occasions: ['Smart-Casual'],
          ),
          const WardrobeItem(
            id: 'shoe-1',
            name: 'Sepatu Loafers Cokelat',
            category: 'Shoes',
            imagePath: '',
            colorName: 'Cokelat',
            color: Color(0xFF8B4513),
            formality: 4,
            occasions: ['Smart-Casual'],
          ),
        ];

        final response = await service.recommend(
          query: 'Acara wisuda teman',
          wardrobe: demoWardrobe,
        );

        expect(response.options, isNotEmpty);
        expect(
          response.options.first.source,
          StylistRecommendationSource.wardrobe,
        );
        expect(response.options.first.sourceLabel, 'Dari Lemarimu');
        expect(response.options.first.items.length, greaterThanOrEqualTo(2));
        expect(
          response.options.first.items.any((i) => i.id == 'top-laundry'),
          isFalse,
        );
        expect(response.options.first.matchScore, greaterThan(60));
        expect(response.options.first.stylingReason, isNotEmpty);
      },
    );

    test('parses Gemini JSON response when GEMINI_API_KEY is configured and falls back on error', () async {
      final wardrobe = [
        const WardrobeItem(
          id: 'w-top-1',
          name: 'Kemeja Putih',
          category: 'Tops',
          imagePath: '',
          colorName: 'Putih',
          color: Color(0xFFFFFFFF),
          formality: 4,
        ),
        const WardrobeItem(
          id: 'w-bot-1',
          name: 'Celana Hitam',
          category: 'Bottoms',
          imagePath: '',
          colorName: 'Hitam',
          color: Color(0xFF000000),
          formality: 4,
        ),
      ];

      final geminiService = AiStylistService(
        apiKey: 'test-key',
        model: 'gemini-2.5-flash',
        geminiCaller:
            ({required apiKey, required model, required prompt}) async {
              expect(apiKey, 'test-key');
              expect(model, 'gemini-2.5-flash');
              expect(prompt, contains('w-top-1'));
              return '''
{
  "message": "Ini paduan terbaik dari Gemini untuk acara wisudamu!",
  "wardrobe_combinations": [
    {
      "title": "Setelan Monokrom Rapi",
      "item_ids": ["w-top-1", "w-bot-1"],
      "match_score": 93,
      "styling_reason": "Putih dan hitam memberi kesan rapi.",
      "style_tag": "Smart-Casual",
      "tips": ["Gunakan jam tangan kulit."]
    }
  ]
}
''';
            },
      );

      final geminiResponse = await geminiService.recommend(
        query: 'Wisuda teman',
        wardrobe: wardrobe,
        history: const [
          StylistChatTurn(isUser: true, text: 'Halo'),
          StylistChatTurn(isUser: false, text: 'Halo!'),
        ],
      );
      expect(geminiResponse.usedGemini, isTrue);
      expect(geminiResponse.options.first.title, 'Setelan Monokrom Rapi');
      expect(geminiResponse.options.first.sourceLabel, 'Dari Lemarimu');

      final failingGeminiService = AiStylistService(
        apiKey: 'test-key',
        geminiCaller:
            ({required apiKey, required model, required prompt}) async {
              throw Exception('Offline');
            },
      );
      final fallbackResponse = await failingGeminiService.recommend(
        query: 'Wisuda teman',
        wardrobe: wardrobe,
      );
      expect(fallbackResponse.usedGemini, isFalse);
      expect(fallbackResponse.options, isNotEmpty);
    });
  });

  group('HomeScreen AI Stylist Entry & Chat Screen UI', () {
    setUp(() {
      wardrobeItems.value = [
        const WardrobeItem(
          id: 'item-top',
          name: 'Kemeja Katun',
          category: 'Tops',
          imagePath: '',
          colorName: 'Putih',
          color: Colors.white,
          formality: 4,
        ),
        const WardrobeItem(
          id: 'item-bot',
          name: 'Celana Chino',
          category: 'Bottoms',
          imagePath: '',
          colorName: 'Hitam',
          color: Colors.black,
          formality: 4,
        ),
      ];
    });

    testWidgets(
      'HomeScreen renders clean AI Stylist card and opens chat on tap',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(640, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen(showNav: false)),
        );
        await tester.pump();

        expect(find.text('AI Stylist GAYAKU'), findsOneWidget);
        expect(find.text('TANYA GAYA'), findsOneWidget);
        expect(
          find.text("Tanya AI: 'Outfit wisuda, ngampus, atau kondangan'..."),
          findsOneWidget,
        );

        await tester.tap(
          find.text("Tanya AI: 'Outfit wisuda, ngampus, atau kondangan'..."),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AiStylistChatScreen), findsOneWidget);
      },
    );

    testWidgets(
      'AiStylistChatScreen displays friendly opening guide and supports free text',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(640, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const MaterialApp(home: AiStylistChatScreen()));
        await tester.pump();

        expect(find.text('AI Stylist GAYAKU'), findsOneWidget);
        expect(
          find.textContaining('Halo! Aku AI Stylist pribadimu'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'bebas menanyakan rekomendasi outfit untuk acara apa saja',
          ),
          findsOneWidget,
        );

        await tester.enterText(
          find.byType(TextField),
          'Mau outfit kasual ngampus',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Mau outfit kasual ngampus'), findsOneWidget);
      },
    );

    testWidgets(
      'AiStylistChatScreen supports quick prompt chips, multi-session history, and new chat',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(640, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 1. Open chat: quick prompt chips appear on empty new session.
        await tester.pumpWidget(const MaterialApp(home: AiStylistChatScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Outfit kuliah hari ini'), findsOneWidget);
        expect(find.text('Wisuda teman'), findsOneWidget);
        expect(find.text('Semi-formal meeting'), findsOneWidget);
        expect(find.text('Nongkrong kasual'), findsOneWidget);

        // Send first session query via free text.
        await tester.enterText(
          find.byType(TextField),
          'Outfit ke wisuda teman',
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Outfit ke wisuda teman'), findsOneWidget);
        expect(find.text('Dari Lemarimu'), findsWidgets);

        // 2. Simulate leaving and re-opening: latest session is restored.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: AiStylistChatScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Outfit ke wisuda teman'), findsOneWidget);
        expect(find.text('Dari Lemarimu'), findsWidgets);

        // 3. Tap "Obrolan Baru" (Icons.add_comment_outlined) and tap quick chip.
        await tester.tap(find.byIcon(Icons.add_comment_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Outfit ke wisuda teman'), findsNothing);
        expect(find.text('Outfit kuliah hari ini'), findsOneWidget);

        await tester.tap(find.text('Outfit kuliah hari ini'));
        await tester.pumpAndSettle();

        expect(find.text('Outfit kuliah hari ini'), findsOneWidget);

        // 4. Open "Riwayat Obrolan" (Icons.history_rounded) and switch back to Session 1.
        await tester.tap(find.byIcon(Icons.history_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Riwayat Obrolan'), findsOneWidget);
        expect(find.text('Outfit ke wisuda teman'), findsOneWidget);

        await tester.tap(find.text('Outfit ke wisuda teman'));
        await tester.pumpAndSettle();

        expect(find.text('Outfit ke wisuda teman'), findsOneWidget);
        expect(find.text('Dari Lemarimu'), findsWidgets);

        // 5. Delete Session 1 from history bottom sheet.
        await tester.tap(find.byIcon(Icons.history_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
        await tester.pumpAndSettle();

        expect(find.text('Outfit ke wisuda teman'), findsNothing);
      },
    );
  });

  group('AiStylistService Chat History Persistence', () {
    const service = AiStylistService();

    test(
      'caps multi-sessions at 15, title at 40 chars, and isolates by userId',
      () async {
        SharedPreferences.setMockInitialValues({});

        for (var i = 0; i < 18; i++) {
          await service.upsertChatSession(
            sessionId: 'sess-$i',
            updatedAt: DateTime(2026, 11, 28, 10, i),
            userId: 'user-a',
            messages: [
              {
                'is_user': true,
                'text': i == 17
                    ? 'Rekomendasi pakaian yang sangat panjang sekali untuk acara wisuda kampus'
                    : 'Sesi obrolan nomor $i',
                'timestamp': DateTime(2026, 11, 28, 10, i).toIso8601String(),
                'options': <Map<String, dynamic>>[],
              },
            ],
          );
        }

        await service.upsertChatSession(
          sessionId: 'sess-b1',
          userId: 'user-b',
          messages: [
            {
              'is_user': true,
              'text': 'Sesi User B',
              'timestamp': DateTime(2026, 11, 28, 12, 0).toIso8601String(),
              'options': <Map<String, dynamic>>[],
            },
          ],
        );

        final loadedA = await service.loadChatSessions(userId: 'user-a');
        final loadedB = await service.loadChatSessions(userId: 'user-b');

        expect(loadedA.length, 15);
        expect(loadedA.first.id, 'sess-17');
        expect(loadedA.first.title.length, lessThanOrEqualTo(40));
        expect(loadedA.first.title, endsWith('...'));
        expect(loadedA.last.id, 'sess-3');

        expect(loadedB.length, 1);
        expect(loadedB.first.title, 'Sesi User B');

        await service.deleteChatSession('sess-17', userId: 'user-a');
        expect((await service.loadChatSessions(userId: 'user-a')).length, 14);
        expect((await service.loadChatSessions(userId: 'user-b')).length, 1);
      },
    );
  });
}
