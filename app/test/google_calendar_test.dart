import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onward/data/google_calendar.dart';
import 'package:onward/domain/models.dart';

void main() {
  test('creates an event linked to the GoalSpring action', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return request.method == 'GET'
          ? http.Response('{"items":[]}', 200)
          : http.Response('{}', 200);
    });
    final sync = GoogleCalendarSync(
      authorizationHeaders: () async => {'authorization': 'Bearer test'},
      client: client,
    );
    final due = DateTime.utc(2026, 8, 16, 9);

    await sync.upsert(
      GoalAction(
        id: 'action-1',
        goalId: 'goal-1',
        title: 'Take the next step',
        description: 'A focused GoalSpring action',
        dueDate: due,
        estimatedDuration: 25,
      ),
    );

    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(
      requests.first.url.queryParameters['privateExtendedProperty'],
      'onwardActionId=action-1',
    );
    final event = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(event['summary'], 'Take the next step');
    expect(event['start'], {'dateTime': due.toIso8601String()});
    expect(event['extendedProperties'], {
      'private': {'onwardActionId': 'action-1'},
    });
  });
}
