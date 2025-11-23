import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:waiting_room_app/main.dart';

// Simple fakes to match how other widget/unit tests in this repo provide
// a supabase-like client during tests.
class _FakeQuery {
  final List<Map<String, dynamic>> calls = [];

  Future<void> insert(Map<String, dynamic> data) async {
    calls.add(data);
  }

  Future<void> delete() async {}
  Future<void> match(Map<String, dynamic> _) async {}
}

class _FakeClient {
  final _FakeQuery query;
  _FakeClient(this.query);
  dynamic from(String _) => query;
}

void main() {
  test(
    'addClient in testing mode does not call geolocation and stores null coords',
    () async {
      final fakeQuery = _FakeQuery();
      final fakeClient = _FakeClient(fakeQuery);

      final provider = QueueProvider.forTesting(fakeClient);

      await provider.addClient('GeoTest');

      final client = provider.clients.last;
      expect(client.lat, isNull);
      expect(client.lng, isNull);
    },
  );

  testWidgets('Displays location not captured for test-mode client', (tester) async {
    final fakeQuery = _FakeQuery();
    final fakeClient = _FakeClient(fakeQuery);
    final provider = QueueProvider.forTesting(fakeClient);

    // Add a client in testing mode; geolocation is skipped and lat/lng are null.
    await provider.addClient('Sam');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('📍 Location not captured'), findsOneWidget);
  });
}
