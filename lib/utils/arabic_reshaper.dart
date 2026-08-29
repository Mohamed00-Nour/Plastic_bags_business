/// Arabic text reshaper for PDF generation.
///
/// The `pdf` Dart package does not perform Arabic text shaping (connecting
/// letters into initial/medial/final forms). This utility converts standard
/// Arabic Unicode characters into their Unicode Presentation Forms-B
/// equivalents, which are pre-shaped and render correctly without any
/// OpenType GSUB processing.
library;

class ArabicReshaper {
  ArabicReshaper._();

  /// Reshape Arabic text for PDF rendering.
  /// Non-Arabic characters are left untouched.
  static String reshape(String input) {
    if (input.isEmpty) return input;

    final runes = input.runes.toList();
    final result = <int>[];
    final len = runes.length;

    for (int i = 0; i < len; i++) {
      final c = runes[i];

      // Handle Lam-Alef ligatures
      if (_isLam(c) && i + 1 < len) {
        final next = runes[i + 1];
        final ligature = _getLamAlefLigature(c, next, i > 0 && _isArabicLetter(runes[i - 1]) && _canConnect(runes[i - 1], isAfter: true));
        if (ligature != null) {
          result.add(ligature);
          i++; // skip next char (alef)
          continue;
        }
      }

      if (!_isArabicLetter(c)) {
        result.add(c);
        continue;
      }

      final entry = _arabicForms[c];
      if (entry == null) {
        result.add(c);
        continue;
      }

      final prevIsArabic = i > 0 && _isArabicLetter(runes[i - 1]) && _canConnect(runes[i - 1], isAfter: true);

      // Skip diacritics when looking for next connecting letter
      int nextIdx = i + 1;
      while (nextIdx < len && _isDiacritic(runes[nextIdx])) {
        nextIdx++;
      }
      final nextIsArabic = nextIdx < len && _isArabicLetter(runes[nextIdx]) && _canConnect(c, isAfter: true);

      int form;
      if (prevIsArabic && nextIsArabic) {
        form = entry.medial; // medial
      } else if (prevIsArabic) {
        form = entry.final_; // final
      } else if (nextIsArabic) {
        form = entry.initial; // initial
      } else {
        form = entry.isolated; // isolated
      }

      result.add(form);
    }

    return String.fromCharCodes(result);
  }

  /// Reshapes Arabic text and reverses character order for PDF LTR rendering engine.
  static String reshapeAndReverse(String input) {
    if (input.isEmpty) return input;

    // If string contains no Arabic letters, leave untouched!
    if (!input.runes.any(_isArabicLetter)) {
      return input;
    }

    final reshaped = reshape(input);

    final words = reshaped.split(' ');
    final reversedWords = words.map((w) {
      if (w.runes.any(_isArabicPresentationForm)) {
        return String.fromCharCodes(w.runes.toList().reversed);
      }
      return w;
    }).toList().reversed;

    return reversedWords.join(' ');
  }

  static bool _isArabicPresentationForm(int c) {
    return (c >= 0xFE70 && c <= 0xFEFF) || (c >= 0x0600 && c <= 0x06FF);
  }

  static bool _isDiacritic(int c) {
    return c >= 0x064B && c <= 0x065F || c == 0x0670;
  }

  static bool _isLam(int c) => c == 0x0644;

  static bool _isArabicLetter(int c) {
    return _arabicForms.containsKey(c) || _isDiacritic(c);
  }

  /// Whether this letter can connect to the next letter (has initial/medial forms)
  static bool _canConnect(int c, {required bool isAfter}) {
    final entry = _arabicForms[c];
    if (entry == null) return false;
    if (isAfter) return entry.canConnectAfter;
    return true;
  }

  static int? _getLamAlefLigature(int lam, int alef, bool prevConnects) {
    // Lam-Alef ligatures in Presentation Forms-B
    switch (alef) {
      case 0x0622: // Alef with Madda
        return prevConnects ? 0xFEF6 : 0xFEF5;
      case 0x0623: // Alef with Hamza Above
        return prevConnects ? 0xFEF8 : 0xFEF7;
      case 0x0625: // Alef with Hamza Below
        return prevConnects ? 0xFEFA : 0xFEF9;
      case 0x0627: // Plain Alef
        return prevConnects ? 0xFEFC : 0xFEFB;
      default:
        return null;
    }
  }
}

/// Stores the 4 presentation forms of an Arabic letter.
class _ArabicLetterForms {
  final int isolated;
  final int final_;
  final int initial;
  final int medial;
  final bool canConnectAfter; // whether this letter connects to the following letter

  const _ArabicLetterForms({
    required this.isolated,
    required this.final_,
    required this.initial,
    required this.medial,
    required this.canConnectAfter,
  });
}

/// Unicode Arabic Presentation Forms-B mapping.
/// Letters that don't connect forward (like Alef, Dal, Ra, etc.)
/// have initial = isolated and medial = final.
final Map<int, _ArabicLetterForms> _arabicForms = {
  // Hamza
  0x0621: const _ArabicLetterForms(isolated: 0xFE80, final_: 0xFE80, initial: 0xFE80, medial: 0xFE80, canConnectAfter: false),

  // Alef with Madda
  0x0622: const _ArabicLetterForms(isolated: 0xFE81, final_: 0xFE82, initial: 0xFE81, medial: 0xFE82, canConnectAfter: false),

  // Alef with Hamza Above
  0x0623: const _ArabicLetterForms(isolated: 0xFE83, final_: 0xFE84, initial: 0xFE83, medial: 0xFE84, canConnectAfter: false),

  // Waw with Hamza
  0x0624: const _ArabicLetterForms(isolated: 0xFE85, final_: 0xFE86, initial: 0xFE85, medial: 0xFE86, canConnectAfter: false),

  // Alef with Hamza Below
  0x0625: const _ArabicLetterForms(isolated: 0xFE87, final_: 0xFE88, initial: 0xFE87, medial: 0xFE88, canConnectAfter: false),

  // Yeh with Hamza
  0x0626: const _ArabicLetterForms(isolated: 0xFE89, final_: 0xFE8A, initial: 0xFE8B, medial: 0xFE8C, canConnectAfter: true),

  // Alef
  0x0627: const _ArabicLetterForms(isolated: 0xFE8D, final_: 0xFE8E, initial: 0xFE8D, medial: 0xFE8E, canConnectAfter: false),

  // Baa
  0x0628: const _ArabicLetterForms(isolated: 0xFE8F, final_: 0xFE90, initial: 0xFE91, medial: 0xFE92, canConnectAfter: true),

  // Taa Marbouta
  0x0629: const _ArabicLetterForms(isolated: 0xFE93, final_: 0xFE94, initial: 0xFE93, medial: 0xFE94, canConnectAfter: false),

  // Taa
  0x062A: const _ArabicLetterForms(isolated: 0xFE95, final_: 0xFE96, initial: 0xFE97, medial: 0xFE98, canConnectAfter: true),

  // Thaa
  0x062B: const _ArabicLetterForms(isolated: 0xFE99, final_: 0xFE9A, initial: 0xFE9B, medial: 0xFE9C, canConnectAfter: true),

  // Jeem
  0x062C: const _ArabicLetterForms(isolated: 0xFE9D, final_: 0xFE9E, initial: 0xFE9F, medial: 0xFEA0, canConnectAfter: true),

  // Haa
  0x062D: const _ArabicLetterForms(isolated: 0xFEA1, final_: 0xFEA2, initial: 0xFEA3, medial: 0xFEA4, canConnectAfter: true),

  // Khaa
  0x062E: const _ArabicLetterForms(isolated: 0xFEA5, final_: 0xFEA6, initial: 0xFEA7, medial: 0xFEA8, canConnectAfter: true),

  // Dal
  0x062F: const _ArabicLetterForms(isolated: 0xFEA9, final_: 0xFEAA, initial: 0xFEA9, medial: 0xFEAA, canConnectAfter: false),

  // Thal
  0x0630: const _ArabicLetterForms(isolated: 0xFEAB, final_: 0xFEAC, initial: 0xFEAB, medial: 0xFEAC, canConnectAfter: false),

  // Ra
  0x0631: const _ArabicLetterForms(isolated: 0xFEAD, final_: 0xFEAE, initial: 0xFEAD, medial: 0xFEAE, canConnectAfter: false),

  // Zay
  0x0632: const _ArabicLetterForms(isolated: 0xFEAF, final_: 0xFEB0, initial: 0xFEAF, medial: 0xFEB0, canConnectAfter: false),

  // Seen
  0x0633: const _ArabicLetterForms(isolated: 0xFEB1, final_: 0xFEB2, initial: 0xFEB3, medial: 0xFEB4, canConnectAfter: true),

  // Sheen
  0x0634: const _ArabicLetterForms(isolated: 0xFEB5, final_: 0xFEB6, initial: 0xFEB7, medial: 0xFEB8, canConnectAfter: true),

  // Sad
  0x0635: const _ArabicLetterForms(isolated: 0xFEB9, final_: 0xFEBA, initial: 0xFEBB, medial: 0xFEBC, canConnectAfter: true),

  // Dad
  0x0636: const _ArabicLetterForms(isolated: 0xFEBD, final_: 0xFEBE, initial: 0xFEBF, medial: 0xFEC0, canConnectAfter: true),

  // Tah
  0x0637: const _ArabicLetterForms(isolated: 0xFEC1, final_: 0xFEC2, initial: 0xFEC3, medial: 0xFEC4, canConnectAfter: true),

  // Dhah
  0x0638: const _ArabicLetterForms(isolated: 0xFEC5, final_: 0xFEC6, initial: 0xFEC7, medial: 0xFEC8, canConnectAfter: true),

  // Ain
  0x0639: const _ArabicLetterForms(isolated: 0xFEC9, final_: 0xFECA, initial: 0xFECB, medial: 0xFECC, canConnectAfter: true),

  // Ghain
  0x063A: const _ArabicLetterForms(isolated: 0xFECD, final_: 0xFECE, initial: 0xFECF, medial: 0xFED0, canConnectAfter: true),

  // Faa
  0x0641: const _ArabicLetterForms(isolated: 0xFED1, final_: 0xFED2, initial: 0xFED3, medial: 0xFED4, canConnectAfter: true),

  // Qaf
  0x0642: const _ArabicLetterForms(isolated: 0xFED5, final_: 0xFED6, initial: 0xFED7, medial: 0xFED8, canConnectAfter: true),

  // Kaf
  0x0643: const _ArabicLetterForms(isolated: 0xFED9, final_: 0xFEDA, initial: 0xFEDB, medial: 0xFEDC, canConnectAfter: true),

  // Lam
  0x0644: const _ArabicLetterForms(isolated: 0xFEDD, final_: 0xFEDE, initial: 0xFEDF, medial: 0xFEE0, canConnectAfter: true),

  // Meem
  0x0645: const _ArabicLetterForms(isolated: 0xFEE1, final_: 0xFEE2, initial: 0xFEE3, medial: 0xFEE4, canConnectAfter: true),

  // Noon
  0x0646: const _ArabicLetterForms(isolated: 0xFEE5, final_: 0xFEE6, initial: 0xFEE7, medial: 0xFEE8, canConnectAfter: true),

  // Heh
  0x0647: const _ArabicLetterForms(isolated: 0xFEE9, final_: 0xFEEA, initial: 0xFEEB, medial: 0xFEEC, canConnectAfter: true),

  // Waw
  0x0648: const _ArabicLetterForms(isolated: 0xFEED, final_: 0xFEEE, initial: 0xFEED, medial: 0xFEEE, canConnectAfter: false),

  // Alef Maksura
  0x0649: const _ArabicLetterForms(isolated: 0xFEEF, final_: 0xFEF0, initial: 0xFEEF, medial: 0xFEF0, canConnectAfter: false),

  // Yaa
  0x064A: const _ArabicLetterForms(isolated: 0xFEF1, final_: 0xFEF2, initial: 0xFEF3, medial: 0xFEF4, canConnectAfter: true),

  // Tatweel (Kashida) - just passes through as a connector
  0x0640: const _ArabicLetterForms(isolated: 0x0640, final_: 0x0640, initial: 0x0640, medial: 0x0640, canConnectAfter: true),
};
