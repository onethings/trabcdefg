import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/publish_budget.dart';

void main() {
  group('publish budget', () {
    test('a publish spends the budget until the interval has passed', () {
      final budget = PublishBudget(100);
      expect(budget.due(1000), isTrue);
      expect(budget.due(1050), isFalse);
      expect(budget.due(1099), isFalse);
      expect(budget.due(1100), isTrue);
    });

    test('a clock that stepped backwards does not hold a publish off', () {
      final budget = PublishBudget(1000);
      expect(budget.due(10000), isTrue);
      expect(budget.due(9000), isTrue);
      expect(budget.due(9500), isFalse);
    });

    test('reset lets the next publish through', () {
      final budget = PublishBudget(600);
      expect(budget.due(1000), isTrue);
      expect(budget.due(1010), isFalse);
      budget.reset();
      expect(budget.due(1010), isTrue);
    });

    test('the first publish after construction always goes through', () {
      expect(PublishBudget(1).due(5), isTrue);
      expect(PublishBudget(100).due(1), isTrue);
    });

    test('an interval of zero publishes every time', () {
      final budget = PublishBudget(0);
      expect(budget.due(10), isTrue);
      expect(budget.due(10), isTrue);
    });
  });
}
