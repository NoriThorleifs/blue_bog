import 'dart:math';

int highestPowerOf3(int n) => n < 3 ? 0 : (log(n) / log(3)).floor();

String intToTernaryString(int n) {
  if (n == 0) {
    return "Zero";
  }
  if (!n.isFinite) {
    return "Does not compute!";
  }
  String out;
  if (n.isNegative) {
    out = "Negative ";
  } else {
    out = "";
  }
  n = n.abs();
  if (n <= 2) {
    return "$out${["Single", "Couple"][n - 1]}";
  }

  int firstPower = highestPowerOf3(n);
  int firstStep = pow(3, firstPower).toInt();
  int remainder = n - firstStep;
  if (remainder == 0) {
    return "$out${firstPower == 1 ? "Three" : "Holy $firstPower"}";
  }
  if (remainder == 1 || remainder == 2) {
    return "$out${["Unholy", "Sickly"][remainder - 1]} $firstPower";
  }
  if (firstPower == 1) {
    out += "Three";
  } else {
    out += "Power $firstPower";
  }
  int secondPower = highestPowerOf3(remainder);
  int secondStep = pow(3, secondPower).toInt();
  if (secondPower > 0 && remainder >= secondStep) {
    out += " and ${secondPower == 1 ? "Three" : "Power $secondPower"}";
    remainder -= secondStep;
  }
  int threes = remainder ~/ 3;
  if (threes > 0) out += " and ${threes == 1 ? "Three" : "$threes Threes"}";
  if (remainder % 3 == 1) out += " and a Single";
  if (remainder % 3 == 2) out += " and a Couple";
  return out;
}
