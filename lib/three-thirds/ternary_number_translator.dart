import 'dart:math';

int findHighestPowerOfThree(int input) {
  if (input < 3) {
    return 0;
  }
  for (int i = 1; i < 19683; i++) {
    int remainder = input - pow(3, i).toInt();
    if (remainder < 0) {
      return i - 1;
    }
  }
  return 0;
}

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
  int nearestPow = findHighestPowerOfThree(input);
  int remainder = input - pow(3, nearestPow).toInt();
  if (remainder == 0) {
    if (nearestPow == 1) {
      return "Three";
    }
    output += "Holy $nearestPow";
    return output;
  } else if (remainder == 1) {
    output += "Unholy $nearestPow";
    return output;
  } else if (remainder == 2) {
    output += "Sickly $nearestPow";
    return output;
  } else {
    if (nearestPow == 1) {
      output += "Three";
    } else {
      output += "Power $nearestPow";
    }
    int remainderPow = findHighestPowerOfThree(remainder);
    if (remainderPow > 0) {
      remainder -= pow(3, remainderPow).toInt();
      if (remainderPow == 1) {
        output += " and Three";
      } else {
        output += " and Power $remainderPow";
      }
    }
  }

  int threes = remainder ~/ 3;
  if (threes != 0) {
    if (threes == 1) {
      output += " and Three";
    } else {
      output += " and $threes Threes";
    }
  }
  switch (remainder % 3) {
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
