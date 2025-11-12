import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart'; // ✅ Nécessaire pour Provider
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart'; // ✅ Nécessaire pour QueueProvider

void main() {
  testWidgets('should add a new client to the list on button tap', (WidgetTester tester) async {
    // ✅ Injecte QueueProvider dans l’arbre de test
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => QueueProvider(),
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    // ✅ Ajoute un client
    await tester.enterText(find.byType(TextField), 'Client A');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // ✅ Vérifie que le client est affiché
    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });

  testWidgets('should remove a client from the list when the delete button is tapped', (WidgetTester tester) async {
    // ✅ Injecte QueueProvider ici aussi (corrigé)
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => QueueProvider(),
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    // ✅ Ajoute un client
    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // ✅ Trouve et appuie sur le bouton de suppression
    final deleteButton = find.descendant(
      of: find.byType(ListTile).first,
      matching: find.byIcon(Icons.delete),
    );
    await tester.tap(deleteButton);
    await tester.pump();

    // ✅ Vérifie que le client a été supprimé
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Clients in Queue: 0'), findsOneWidget);
  });

  testWidgets('should remove the first client from the list when "Next Client" is tapped', (WidgetTester tester) async {
    // ✅ Injecte QueueProvider dans le test
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => QueueProvider(),
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    // ✅ Ajoute deux clients
    await tester.enterText(find.byType(TextField), 'Client A');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Client B');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // ✅ Appuie sur le bouton "Next Client"
    await tester.tap(find.byKey(const Key('nextClientButton')));
    await tester.pump();

    // ✅ Vérifie que seul Client B reste
    expect(find.text('Client A'), findsNothing);
    expect(find.text('Client B'), findsOneWidget);
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
  });
}
