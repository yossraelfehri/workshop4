import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart'; // ✅ Ajouté pour Provider
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart'; // ✅ Ajouté pour QueueProvider

void main() {
  testWidgets('App displays initial queue and adds a client', (WidgetTester tester) async {
    // ✅ Fournir QueueProvider dans l’arbre de widgets
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => QueueProvider(),
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    // ✅ Vérifie que la file est vide au départ
    expect(find.text('Clients in Queue: 0'), findsOneWidget);

    // ✅ Ajoute un client
    await tester.enterText(find.byType(TextField), 'John Doe');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // Rebuild après notifyListeners()

    // ✅ Vérifie que le client est affiché
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });
}
