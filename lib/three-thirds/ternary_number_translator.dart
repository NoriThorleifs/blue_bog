import 'dart:math';

String intToTernaryString(int input){
  if (input == 0){
    return "Zero";
  }
  String output = "";
  if(!input.isFinite){
    return "Does not compute!";
  }
  if(input.isNegative){
    input = input.abs();
    output += "Negative ";
  }
  int nearestPow = 0;
  for (int i = 1; i < 19683; i++){
    int remainder = input - pow(3, i).toInt();
    if (remainder == 0){
      output += "Holy $i";
      return output;
    } else if (remainder.abs() < 3){
      output += "Unholy $i";
      return output;
    } else if(remainder < 0){
      nearestPow = i-1;
      break;
    }
  }
  int additional = input - pow(3, nearestPow).toInt();
  return output;
}