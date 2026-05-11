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
  })  : _latinRecognizer =
            latinRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
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
    final lines = latin.blocks
        .expand((block) => block.lines)
        .map((line) => _normalize(line.text))
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final now = DateTime.now();
    return lines
        .map(
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
        )
        .toList(growable: false);
  }

  String _normalize(String raw) {
    return raw
        .replaceAll(RegExp(r'[|¦]'), 'I')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  OcrCandidateType _classify(String text) {
    final lower = text.toLowerCase();

    final hasTime = RegExp(r'\b\d{1,2}(:\d{2})?\s?(am|pm)?\b').hasMatch(lower);
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
            _hasAny(lower, const ['hospital', 'clinic', 'dr ', ' dr.', 'doctor']))) {
      return OcrCandidateType.appointment;
    }
    if (_hasAny(lower, const [
          'walk',
          'exercise',
          'physio',
          'stretch',
          'range of motion',
          'rehab',
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
    final hasTimeSignal = RegExp(r'\b\d{1,2}(:\d{2})?\s?(am|pm)?\b', caseSensitive: false)
        .hasMatch(text);
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
    final timeMatch = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)?\b', caseSensitive: false)
        .firstMatch(lower);
    if (timeMatch == null) {
      return null;
    }
    var hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
    final minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
    final suffix = timeMatch.group(3)?.toLowerCase();
    if (suffix == 'pm' && hour < 12) hour += 12;
    if (suffix == 'am' && hour == 12) hour = 0;

    final dayOffset = lower.contains('tomorrow')
        ? 1
        : lower.contains('next week')
            ? 7
            : 0;
    final base = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  @override
  Future<void> disposeIntegration() async {
    await _latinRecognizer.close();
  }
}
