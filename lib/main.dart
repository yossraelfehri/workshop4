import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Small fake client used when Supabase isn't configured at runtime so the app
// still renders for development or demo purposes.
class _DevFakeQuery {
  final List<Map<String, dynamic>> calls = [];
  Future<void> insert(Map<String, dynamic> data) async => calls.add(data);
  Future<void> delete() async {}
  Future<void> match(Map<String, dynamic> _) async {}
}

class _DevFakeClient {
  final _DevFakeQuery q = _DevFakeQuery();
  dynamic from(String _) => q;
}

/// App entrypoint: attempts to initialize Supabase from environment (.env).
/// If not provided, runs with a fake client so the UI is visible.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Explicitly load the .env asset packaged with the app.
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // If .env is missing (especially on web), don't crash — fall back to dev fake client.
    // flutter_dotenv throws a FileNotFoundError on web when assets/.env is not present.
    // We'll handle missing env gracefully below.
    // Print for debugging.
    // ignore: avoid_print
    print('.env not found or failed to load: $e');
  }

  final url = dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null;
  final key = dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null;

  if (url != null && key != null && url.isNotEmpty && key.isNotEmpty) {
    // Initialize Supabase with the loaded values.
    await Supabase.initialize(url: url, anonKey: key);
    // ignore: avoid_print
    print('Supabase initialized with URL: ${url}');
    runApp(const WaitingRoomApp());
  } else {
    // Run in dev mode without Supabase configured
    runApp(WaitingRoomApp.withClient(_DevFakeClient()));
  }
}

class WaitingRoomApp extends StatelessWidget {
  final dynamic client;

  const WaitingRoomApp({super.key, this.client});

  WaitingRoomApp.withClient(this.client, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => client != null ? QueueProvider.forTesting(client) : QueueProvider(),
      child: MaterialApp(
        title: 'Waiting Room',
        theme: ThemeData(primarySwatch: Colors.blue),
            home: const WaitingRoomScreen(),
      ),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Show a small dev banner when using the fake client so it's obvious the app
            // is running in dev mode (no Supabase configured).
            Consumer<QueueProvider>(
              builder: (context, provider, _) {
                if (provider.isTesting) {
                  return Container(
                    width: double.infinity,
                    color: Colors.yellow[700],
                    padding: const EdgeInsets.all(8),
                    child: const Text('DEV MODE — Supabase not configured', textAlign: TextAlign.center),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Enter name'),
                    onSubmitted: (name) {
                      context.read<QueueProvider>().addClient(name);
                      controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                      final name = controller.text.trim();
                      // Debug: log tap during tests
                      if (context.read<QueueProvider>().isTesting) {
                        // ignore: avoid_print
                        print('Add button tapped with name="$name"');
                      }
                      if (name.isNotEmpty) {
                        context.read<QueueProvider>().addClient(name);
                        controller.clear();
                      }
                    },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Show a simple clients count so tests can assert on it
            Consumer<QueueProvider>(
              builder: (context, provider, _) => Text('Clients in Queue: ${provider.clients.length}'),
            ),
            Expanded(
              child: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  // Debug: print provider state during tests to help diagnose
                  // why widget tests sometimes don't observe UI updates.
                  if (provider.isTesting) {
                    // ignore: avoid_print
                    print('WaitingRoomScreen.build - provider.clients=${provider.clients.map((c) => c.name).toList()}');
                  }

                  if (provider.clients.isEmpty) {
                    return const Center(child: Text('No one in queue yet...'));
                  }

                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(client.name),
                          subtitle: Text(
                            client.lat == null
                                ? '📍 Location not captured'
                                : '📍 ${client.lat!.toStringAsFixed(4)}, ${client.lng!.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              context.read<QueueProvider>().removeClient(client.id);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const Key('nextClientButton'),
              onPressed: () {
                context.read<QueueProvider>().nextClient();
              },
              icon: const Icon(Icons.arrow_forward, color: Colors.green),
              label: const Text('Next Client'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
