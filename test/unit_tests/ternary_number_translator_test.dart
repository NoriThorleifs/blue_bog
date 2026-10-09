import 'package:blue_bog/functions/three_thirds/ternary_number_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holy numbers', () {
    print("| Decimal | Ternary expression |");
    print("| ----------- | ----------- |");
    for (int i = 177140; i < 177149; i++) {
      String ternaryString = intToTernaryString(i);
      print("| $i | $ternaryString |");
    }
  });
}
