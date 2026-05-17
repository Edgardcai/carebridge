import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'integration_ports.dart';

/// On-device OCR using ML Kit **Latin script only** (no bundled Chinese model).
/// Huawei / no-Play-Services devices must not use `TextRecognitionScript.chinese`
/// without the matching native dependency (causes crash).
class MlKitOcrPort implements OcrPort, DisposableIntegration {
  MlKitOcrPort({
    TextRecognizer? latinRecognizer,
    Uuid? uuid,
  })  : _latinRecognizer = latinRecognizer ??
            TextRecognizer(script: TextRecognitionScript.latin),
        _uuid = uuid ?? const Uuid();

  final TextRecognizer _latinRecognizer;
  final Uuid _uuid;

  @override
  Future<List<OcrCandidate>> extractTaskCandidates({
    required String patientId,
    required String localImagePath,
  }) async {
    final input = InputImage.fromFilePath(localImagePath);
    final latin = await _latinRecognizer.processImage(input);
    final rawLines = latin.blocks
        .expand((block) => block.lines)
        .map((line) => _normalize(line.text))
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final lines = _candidateLines(rawLines);

    final now = DateTime.now();
    return lines.map(
      (line) {
        final type = _classify(line);
        return OcrCandidate(
          id: _uuid.v4(),
          patientId: patientId,
          type: type,
          extractedText: line,
          confidence: _confidenceFor(type, line),
          scheduledAt: _extractDateTime(line, now),
        );
      },
    ).toList(growable: false);
  }

  String _normalize(String raw) {
    return raw
        .replaceAll(RegExp(r'[|¦]'), 'I')
        .replaceAllMapped(
          RegExp(r'\b([ap])\.\s*m\.?', caseSensitive: false),
          (match) => '${match.group(1)!.toLowerCase()}m',
        )
        .replaceAllMapped(
          RegExp(r'\b(\d{1,2})\s+([ap])\s*m\b', caseSensitive: false),
          (match) => '${match.group(1)}${match.group(2)!.toLowerCase()}m',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _candidateLines(List<String> rawLines) {
    final seen = <String>{};
    final kept = <String>[];
    for (final line in rawLines) {
      final key = line.toLowerCase();
      if (seen.contains(key) || !_looksLikeActionLine(line)) {
        continue;
      }
      seen.add(key);
      kept.add(line);
    }
    return kept;
  }

  bool _looksLikeActionLine(String text) {
    final lower = text.toLowerCase();
    final words =
        RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!).toList();
    final digitCount = RegExp(r'\d').allMatches(lower).length;
    final letterCount = RegExp(r'[a-z]').allMatches(lower).length;

    if (words.length < 2 || letterCount < 5) return false;
    if (_isTopicHeading(lower)) return false;
    if (_isDeviceOrNoteMetadata(lower, digitCount, letterCount)) return false;

    return _hasAny(lower, const [
      'take',
      'tablet',
      'capsule',
      'pill',
      'dose',
      'daily',
      'after meal',
      'before meal',
      'follow-up',
      'follow up',
      'clinic',
      'doctor',
      'appointment',
      'visit',
      'walk',
      'exercise',
      'physio',
      'stretch',
      'range of motion',
      'rehab',
      'check',
      'wound',
      'incision',
      'dressing',
      'site',
      'morning',
      'afternoon',
      'evening',
      'night',
      'bedtime',
    ]);
  }

  bool _isTopicHeading(String lower) {
    final compact = lower.replaceAll(RegExp(r'[^a-z]'), '');
    return const {
      'medicine',
      'medicines',
      'medication',
      'notes',
      'note',
      'untitled',
    }.contains(compact);
  }

  bool _isDeviceOrNoteMetadata(String lower, int digitCount, int letterCount) {
    final noActionSignal = !_hasAny(lower, const [
      'take',
      'tablet',
      'capsule',
      'pill',
      'dose',
      'follow',
      'clinic',
      'doctor',
      'appointment',
      'walk',
      'exercise',
      'check',
      'wound',
      'incision',
      'daily',
      'evening',
      'morning',
    ]);
    if (!noActionSignal) return false;
    if (RegExp(r'^\d{1,2}:\d{2}(?:\s+\d+)*$').hasMatch(lower)) return true;
    if (RegExp(r'^\d{4}[/-]\d{1,2}[/-]\d{1,2}\b').hasMatch(lower)) return true;
    return digitCount > letterCount;
  }

  OcrCandidateType _classify(String text) {
    final lower = text.toLowerCase();

    final hasTime = _extractTime(lower) != null;
    final hasDate = RegExp(r'\b\d{1,2}[/-]\d{1,2}\b').hasMatch(lower);

    if (_hasAny(lower, const [
          'follow-up',
          'follow up',
          'clinic',
          'doctor',
          'dept',
          'appointment',
          'visit',
        ]) ||
        ((hasTime || hasDate) &&
            _hasAny(lower,
                const ['hospital', 'clinic', 'dr ', ' dr.', 'doctor']))) {
      return OcrCandidateType.appointment;
    }
    if (_hasAny(lower, const [
      'walk',
      'exercise',
      'physio',
      'stretch',
      'range of motion',
      'rehab',
      'check wound',
      'wound',
      'incision',
      'dressing',
    ])) {
      return OcrCandidateType.instruction;
    }
    if (_hasAny(lower, const [
      'mg',
      'tablet',
      'capsule',
      'pill',
      'after meal',
      'before meal',
      'bid',
      'tid',
    ])) {
      return OcrCandidateType.medication;
    }
    if (_hasAny(lower, const ['take', 'medicine', 'dose', 'daily'])) {
      return OcrCandidateType.medication;
    }
    return OcrCandidateType.other;
  }

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any((keyword) => text.contains(keyword));

  double _confidenceFor(OcrCandidateType type, String text) {
    final hasTimeSignal = _extractTime(text.toLowerCase()) != null;
    switch (type) {
      case OcrCandidateType.medication:
        return hasTimeSignal ? 0.9 : 0.82;
      case OcrCandidateType.appointment:
        return hasTimeSignal ? 0.92 : 0.84;
      case OcrCandidateType.instruction:
        return 0.78;
      case OcrCandidateType.other:
        return 0.6;
    }
  }

  DateTime? _extractDateTime(String text, DateTime now) {
    final lower = text.toLowerCase();
    final parsedTime = _extractTime(lower);
    if (parsedTime == null) {
      return null;
    }

    final dayOffset = lower.contains('tomorrow')
        ? 1
        : lower.contains('next week')
            ? 7
            : 0;
    var base =
        DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
    final dateMatch =
        RegExp(r'\b(?:(\d{4})[/-])?(\d{1,2})[/-](\d{1,2})\b').firstMatch(lower);
    if (dateMatch != null) {
      final year = int.tryParse(dateMatch.group(1) ?? '') ?? now.year;
      final month = int.tryParse(dateMatch.group(2) ?? '') ?? now.month;
      final day = int.tryParse(dateMatch.group(3) ?? '') ?? now.day;
      base = DateTime(year, month, day);
    }
    return DateTime(
        base.year, base.month, base.day, parsedTime.hour, parsedTime.minute);
  }

  ({int hour, int minute})? _extractTime(String lower) {
    final suffixMatch =
        RegExp(r'\b(?:at\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b')
            .firstMatch(lower);
    if (suffixMatch != null) {
      var hour = int.tryParse(suffixMatch.group(1) ?? '') ?? 9;
      final minute = int.tryParse(suffixMatch.group(2) ?? '') ?? 0;
      final suffix = suffixMatch.group(3);
      if (suffix == 'pm' && hour < 12) hour += 12;
      if (suffix == 'am' && hour == 12) hour = 0;
      return (
        hour: hour.clamp(0, 23).toInt(),
        minute: minute.clamp(0, 59).toInt(),
      );
    }

    final colonMatch =
        RegExp(r'\b(?:at\s*)?([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(lower);
    if (colonMatch != null) {
      return (
        hour: int.parse(colonMatch.group(1)!),
        minute: int.parse(colonMatch.group(2)!),
      );
    }

    if (lower.contains('morning')) return (hour: 8, minute: 0);
    if (lower.contains('afternoon')) return (hour: 14, minute: 0);
    if (lower.contains('evening')) return (hour: 18, minute: 0);
    if (lower.contains('night') || lower.contains('bedtime')) {
      return (hour: 21, minute: 0);
    }
    return null;
  }

  @override
  Future<void> disposeIntegration() async {
    await _latinRecognizer.close();
  }
}
