import 'package:blue_bog/three-thirds/ternary_number_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holy numbers', () {
    for (int i = -5; i < 30; i++) {
      String ternaryString = intToTernaryString(i);
      print("$i = $ternaryString");
    }
  });
}
