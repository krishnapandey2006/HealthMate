import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/data/india_states.dart';

void main() {
  test('contains all 28 states and 8 union territories', () {
    expect(indiaStates, hasLength(36));
    expect(
      indiaStates.where((state) => state.type == 'State'),
      hasLength(28),
    );
    expect(
      indiaStates.where((state) => state.type == 'Union territory'),
      hasLength(8),
    );
    final names = indiaStates.map((state) => state.name).toList();
    expect(names.toSet(), hasLength(36));
  });

  test('finds states by full name, code, alias and old spelling', () {
    expect(findIndiaState('Maharashtra')?.name, 'Maharashtra');
    expect(findIndiaState('MH')?.name, 'Maharashtra');
    expect(findIndiaState('Orissa')?.name, 'Odisha');
    expect(findIndiaState('Tamilnadu')?.name, 'Tamil Nadu');
    expect(findIndiaState('Pondicherry')?.name, 'Puducherry');
    expect(findIndiaState('New Delhi')?.name, 'Delhi');
    expect(findIndiaState('J&K')?.name, 'Jammu and Kashmir');
    expect(findIndiaState('Atlantis'), isNull);
  });

  test('search matches city hints and union territory type', () {
    final maharashtra = findIndiaState('Maharashtra')!;
    expect(stateMatchesQuery(maharashtra, 'Mumbai'), isTrue);
    expect(stateMatchesQuery(maharashtra, 'pune'), isTrue);
    expect(stateMatchesQuery(maharashtra, 'Kerala'), isFalse);

    final unionTerritories = indiaStates
        .where((state) => stateMatchesQuery(state, 'union territory'))
        .toList();
    expect(unionTerritories, hasLength(8));
  });

  test('every state has at least one city hint and a stable type', () {
    for (final state in indiaStates) {
      expect(state.name.trim(), isNotEmpty);
      expect(state.cities, isNotEmpty, reason: state.name);
      expect(['State', 'Union territory'], contains(state.type));
    }
  });
}
