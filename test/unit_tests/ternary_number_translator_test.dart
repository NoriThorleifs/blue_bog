import 'package:blue_bog/three-thirds/ternary_number_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holy numbers', () {
    print("| Decimal | Ternary expression |");
    print("| ----------- | ----------- |");
    for (int i = -5; i < 100; i++) {
      String ternaryString = intToTernaryString(i);
      print("| $i | $ternaryString |");
    }
  });
}
