import 'dart:math';

String intToTernaryString(int input) {
  if (input == 0) {
    return "Zero";
  }
  String output = "";
  if (!input.isFinite) {
    return "Does not compute!";
  }
  if (input.isNegative) {
    input = input.abs();
    output += "Negative ";
  }
  if (input == 1) {
    return "${output}Single";
  }
  if (input == 2) {
    return "${output}Couple";
  }
  int nearestPow = 0;
  for (int i = 1; i < 19683; i++) {
    int remainder = input - pow(3, i).toInt();
    if (remainder == 0) {
      output += "Holy $i";
      return output;
    } else if (remainder.abs() < 3) {
      output += "Unholy $i";
      return output;
    } else if (remainder < 0) {
      nearestPow = i - 1;
      output += "Power $nearestPow ";
      break;
    }
  }
  int additional = input - pow(3, nearestPow).toInt();
  int threes = additional ~/ 3;
  if (threes != 0) {
    if (threes == 1) {
      output += "and Three";
    } else {
      output += "and $threes Threes";
    }
  }
  switch (additional % 3) {
    case 1:
      output += " and a Single";
      break;
    case 2:
      output += " and a Couple";
      break;
    default:
  }
  return output;
}
