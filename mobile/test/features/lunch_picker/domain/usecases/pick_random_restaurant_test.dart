import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failures.dart';
import 'package:mobile/features/lunch_picker/domain/usecases/pick_random_restaurant.dart';

import '../../../../fixtures/restaurant_fixtures.dart';

void main() {
  test('returns EmptySelectionFailure when there are no candidates', () async {
    final useCase = PickRandomRestaurant();

    final result = await useCase(const PickRandomParams([]));

    expect(result.isLeft(), true);
    result.fold(
      (failure) => expect(failure, isA<EmptySelectionFailure>()),
      (_) => fail('expected a Left'),
    );
  });

  test('the sole candidate is always picked', () async {
    final useCase = PickRandomRestaurant();
    final only = buildRestaurant(id: 42);

    final result = await useCase(PickRandomParams([only]));

    result.fold((_) => fail('expected a Right'), (pick) => expect(pick.id, 42));
  });

  test('with a seeded Random, the pick is deterministic', () async {
    final candidates = List.generate(5, (i) => buildRestaurant(id: i));
    final useCase = PickRandomRestaurant(random: Random(7));

    final result = await useCase(PickRandomParams(candidates));

    // Random(7).nextInt(5) is stable across Dart VM/JS for a fixed seed.
    final expectedIndex = Random(7).nextInt(5);
    result.fold(
      (_) => fail('expected a Right'),
      (pick) => expect(pick.id, candidates[expectedIndex].id),
    );
  });
}
