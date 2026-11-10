import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/services/outfit_service.dart';
import 'package:flutter_app/state/outfit_store.dart';
import 'package:flutter_app/state/planner_store.dart';

import 'fixtures.dart';

/// A backend that is down, to prove the sync path never escapes.
class _DeadOutfitService implements OutfitService {
  @override
  Future<List<SavedOutfit>> outfits() async =>
      throw const SocketException('Failed host lookup');

  @override
  Future<SavedOutfit> save(SavedOutfit outfit) async => outfit;

  @override
  Future<void> remove(String id) async {}
}

class _DeadPlannerService implements PlannerService {
  @override
  Future<List<PlannerEntry>> entries() async =>
      throw const SocketException('Failed host lookup');

  @override
  Future<PlannerEntry> save(PlannerEntry entry) async => entry;

  @override
  Future<void> remove(DateTime day) async {}
}

void main() {
  setUp(() {
    useOutfitService(DemoOutfitService());
    usePlannerService(DemoPlannerService());
    savedOutfits.value = [];
    plannerEntries.value = {};
  });

  tearDown(() {
    useOutfitService(DemoOutfitService());
    usePlannerService(DemoPlannerService());
    savedOutfits.value = [];
    plannerEntries.value = {};
  });

  test('a combination is saved, edited in place and deleted', () async {
    final outfit = SavedOutfit(
      id: newOutfitId(),
      name: 'Kantor',
      itemIds: [wardrobeFixture.first.id],
      threshold: 0.7,
    );
    await saveOutfit(outfit);
    expect(savedOutfits.value.single.name, 'Kantor');

    await saveOutfit(
      SavedOutfit(
        id: outfit.id,
        name: 'Kantor Senin',
        itemIds: outfit.itemIds,
        threshold: 0.7,
      ),
    );
    expect(savedOutfits.value, hasLength(1), reason: 'same id edits in place');
    expect(savedOutfits.value.single.name, 'Kantor Senin');

    await toggleOutfitFavorite(outfit.id);
    expect(savedOutfits.value.single.favorite, isTrue);

    await deleteOutfit(outfit.id);
    expect(savedOutfits.value, isEmpty);
  });

  test('planning the same day twice replaces the entry', () async {
    final day = DateTime(2026, 11, 9);
    await savePlannerEntry(
      PlannerEntry(day: day, outfitId: 'a', occasion: 'Kantor'),
    );
    await savePlannerEntry(
      PlannerEntry(day: day, outfitId: 'b', occasion: 'Dinner'),
    );

    expect(plannerEntries.value, hasLength(1));
    expect(plannerEntries.value[dayKey(day)]!.outfitId, 'b');
    expect(plannerEntries.value[dayKey(day)]!.occasion, 'Dinner');

    await deletePlannerEntry(day);
    expect(plannerEntries.value, isEmpty);
  });

  test('a dead backend leaves the screens on their current data', () async {
    savedOutfits.value = [
      SavedOutfit(id: 'kept', name: 'Tetap', itemIds: const [], threshold: 0.6),
    ];
    plannerEntries.value = {
      DateTime(2026, 11, 9): PlannerEntry(
        day: DateTime(2026, 11, 9),
        outfitId: 'kept',
      ),
    };
    useOutfitService(_DeadOutfitService());
    usePlannerService(_DeadPlannerService());

    await loadOutfitsFromBackend();
    await loadPlannerFromBackend();

    expect(savedOutfits.value.single.name, 'Tetap');
    expect(plannerEntries.value, hasLength(1));
  });

  test('a combination renders only the garments it can resolve', () {
    final look = lookFromOutfit(
      SavedOutfit(
        id: 'x',
        name: 'Setelan',
        itemIds: [wardrobeFixture.first.id, 'gone'],
        threshold: 0.9,
      ),
      wardrobeFixture,
    );

    expect(look.items, hasLength(1));
    expect(look.colorHarmony, 90);
    expect(look.imagePath, wardrobeFixture.first.imagePath);
  });
}
