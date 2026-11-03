import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// The language model behind the companion, behind a small interface so it
/// can be swapped with one setting (Gemini free tier today; a paid tier,
/// Claude or an on-device model later) without touching the rules, which
/// live in `logic/companion.dart`.

class ModelTurn {
  const ModelTurn(this.fromAppa, this.text);
  final bool fromAppa;
  final String text;
}

enum SuggestionType { none, call, story, plan }

enum SensitiveTopic { none, health, money, familyConflict }

class ModelReply {
  const ModelReply({
    required this.reply,
    this.suggestion = SuggestionType.none,
    this.suggestionContact,
    this.suggestionText,
    this.topic = SensitiveTopic.none,
    this.feelings = const {},
    this.remember = const [],
  });

  final String reply;
  final SuggestionType suggestion;
  final String? suggestionContact;
  final String? suggestionText;
  final SensitiveTopic topic;
  final Set<Feeling> feelings;
  final List<String> remember;
}

abstract class CompanionModel {
  bool get configured;

  /// One reply to the conversation so far.
  Future<ModelReply> reply({
    required String system,
    required List<ModelTurn> turns,
  });

  /// Tamil transcript of a voice recording (story archive), or null.
  Future<String?> transcribe(String audioPath);
}

/// Google Gemini via its REST API with the free-tier key from Google AI
/// Studio. Note: on the free tier Google may use requests to improve its
/// products. The family chose this knowingly; move to a paid tier (same key
/// type, billing on) to stop that.
class GeminiCompanionModel implements CompanionModel {
  GeminiCompanionModel({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  bool get configured => apiKey.trim().isNotEmpty;

  Uri get _url => Uri.parse('$_base/$model:generateContent');

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'x-goog-api-key': apiKey,
  };

  static const _schema = {
    'type': 'OBJECT',
    'properties': {
      'reply': {'type': 'STRING'},
      'suggestion_type': {
        'type': 'STRING',
        'enum': ['none', 'call', 'story', 'plan'],
      },
      'suggestion_contact': {'type': 'STRING'},
      'suggestion_text': {'type': 'STRING'},
      'topic': {
        'type': 'STRING',
        'enum': ['none', 'health', 'money', 'family_conflict'],
      },
      'feelings': {
        'type': 'ARRAY',
        'items': {
          'type': 'STRING',
          'enum': ['unwanted', 'angry', 'lonely', 'sad'],
        },
      },
      'remember': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['reply', 'suggestion_type', 'topic'],
  };

  @override
  Future<ModelReply> reply({
    required String system,
    required List<ModelTurn> turns,
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        for (final t in turns)
          {
            'role': t.fromAppa ? 'user' : 'model',
            'parts': [
              {'text': t.text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': 0.6,
        'maxOutputTokens': 600,
        'responseMimeType': 'application/json',
        'responseSchema': _schema,
      },
    };
    final res = await _http.post(
      _url,
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw HttpException(
        'Gemini ${res.statusCode}: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}',
      );
    }
    return parseGeminiReply(res.body);
  }

  @override
  Future<String?> transcribe(String audioPath) async {
    final bytes = await File(audioPath).readAsBytes();
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'இந்தக் குரல் பதிவை அப்படியே தமிழில் எழுதிக் கொடுங்கள். '
                  'பேசியவர் சொன்னதை மட்டும் எழுதுங்கள்; சுருக்கவோ திருத்தவோ வேண்டாம்.',
            },
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.0},
    };
    final res = await _http.post(
      _url,
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      debugPrint('Gemini transcribe ${res.statusCode}');
      return null;
    }
    return _firstText(jsonDecode(res.body))?.trim();
  }
}

String? _firstText(dynamic json) {
  final c = (json as Map)['candidates'] as List?;
  if (c == null || c.isEmpty) return null;
  final parts = ((c.first as Map)['content'] as Map?)?['parts'] as List?;
  if (parts == null || parts.isEmpty) return null;
  return (parts.first as Map)['text'] as String?;
}

/// Parses a generateContent response whose text is our JSON schema.
/// Tolerant: anything missing or wrong-shaped becomes a safe default.
ModelReply parseGeminiReply(String responseBody) {
  final text = _firstText(jsonDecode(responseBody));
  if (text == null) return const ModelReply(reply: '');
  Map<String, dynamic> j;
  try {
    j = Map<String, dynamic>.from(jsonDecode(text) as Map);
  } catch (_) {
    return ModelReply(reply: text);
  }
  String? str(String k) {
    final v = j[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  return ModelReply(
    reply: str('reply') ?? '',
    suggestion: switch (j['suggestion_type']) {
      'call' => SuggestionType.call,
      'story' => SuggestionType.story,
      'plan' => SuggestionType.plan,
      _ => SuggestionType.none,
    },
    suggestionContact: str('suggestion_contact'),
    suggestionText: str('suggestion_text'),
    topic: switch (j['topic']) {
      'health' => SensitiveTopic.health,
      'money' => SensitiveTopic.money,
      'family_conflict' => SensitiveTopic.familyConflict,
      _ => SensitiveTopic.none,
    },
    feelings: {
      for (final f in (j['feelings'] as List? ?? []))
        if (Feeling.values.asNameMap()[f] != null)
          Feeling.values.asNameMap()[f]!,
    },
    remember: [
      for (final r in (j['remember'] as List? ?? []))
        if (r is String && r.trim().isNotEmpty) r.trim(),
    ],
  );
}

/// Scripted stand-in for tests.
class FakeCompanionModel implements CompanionModel {
  FakeCompanionModel(this.replies);
  final List<ModelReply> replies;
  final List<String> systems = [];
  int calls = 0;

  @override
  bool get configured => true;

  @override
  Future<ModelReply> reply({
    required String system,
    required List<ModelTurn> turns,
  }) async {
    systems.add(system);
    return replies[calls++ % replies.length];
  }

  @override
  Future<String?> transcribe(String audioPath) async =>
      'எழுத்து வடிவம்: $audioPath';
}

/// Used when no key is set: the companion tile stays hidden.
class NoCompanionModel implements CompanionModel {
  @override
  bool get configured => false;
  @override
  Future<ModelReply> reply({
    required String system,
    required List<ModelTurn> turns,
  }) => throw UnsupportedError('companion not configured');
  @override
  Future<String?> transcribe(String audioPath) async => null;
}
