import 'package:store_manager/utils/arabic_reshaper.dart';

void main() {
  final samples = [
    "17 شنطة بيبي شفاف",
    "60 شنطة جامبو اسود",
    "شنطة قطن 40",
    "just test",
  ];

  for (final s in samples) {
    final formatted = ArabicReshaper.reshapeAndReverse(s);
    print("Input:     $s");
    print("Formatted: $formatted");
    print("---");
  }
}
