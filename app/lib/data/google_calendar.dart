import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

typedef GoogleAuthorizationHeaders = Future<Map<String, String>?> Function();

class GoogleCalendarSync {
  GoogleCalendarSync({
    required GoogleAuthorizationHeaders authorizationHeaders,
    http.Client? client,
  }) : _authorizationHeaders = authorizationHeaders,
       _client = client ?? http.Client();

  final GoogleAuthorizationHeaders _authorizationHeaders;
  final http.Client _client;

  static const _eventsPath = '/calendar/v3/calendars/primary/events';

  Future<void> upsert(GoalAction action) async {
    try {
      final headers = await _headers();
      if (headers == null) return;
      final eventId = await _eventId(action.id, headers);
      final uri = eventId == null
          ? Uri.https('www.googleapis.com', _eventsPath)
          : Uri.https('www.googleapis.com', '$_eventsPath/$eventId');
      final body = jsonEncode({
        'summary': action.title,
        if (action.description.isNotEmpty) 'description': action.description,
        'start': {'dateTime': action.dueDate.toUtc().toIso8601String()},
        'end': {
          'dateTime': action.dueDate
              .add(
                Duration(
                  minutes: action.estimatedDuration.clamp(5, 1440).toInt(),
                ),
              )
              .toUtc()
              .toIso8601String(),
        },
        'extendedProperties': {
          'private': {'onwardActionId': action.id},
        },
      });
      if (eventId == null) {
        await _client.post(uri, headers: headers, body: body);
      } else {
        await _client.patch(uri, headers: headers, body: body);
      }
    } catch (_) {
      // Calendar sync must never block the primary GoalSpring action flow.
    }
  }

  Future<void> delete(String actionId) async {
    try {
      final headers = await _headers();
      if (headers == null) return;
      final eventId = await _eventId(actionId, headers);
      if (eventId != null) {
        await _client.delete(
          Uri.https('www.googleapis.com', '$_eventsPath/$eventId'),
          headers: headers,
        );
      }
    } catch (_) {
      // Calendar sync must never block the primary GoalSpring action flow.
    }
  }

  Future<Map<String, String>?> _headers() async {
    final headers = await _authorizationHeaders();
    return headers == null
        ? null
        : {...headers, 'content-type': 'application/json'};
  }

  Future<String?> _eventId(String actionId, Map<String, String> headers) async {
    final response = await _client.get(
      Uri.https('www.googleapis.com', _eventsPath, {
        'privateExtendedProperty': 'onwardActionId=$actionId',
        'maxResults': '1',
        'singleEvents': 'true',
      }),
      headers: headers,
    );
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body);
    final items = payload is Map ? payload['items'] : null;
    final first = items is List && items.isNotEmpty ? items.first : null;
    return first is Map ? first['id']?.toString() : null;
  }
}
