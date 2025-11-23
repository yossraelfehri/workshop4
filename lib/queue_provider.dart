import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'local_queue_service.dart';
import 'package:waiting_room_app/models/client.dart';
import 'geolocation_service.dart';

/// QueueProvider manages the waiting queue, local persistence and best-effort
/// sync to Supabase. It exposes a `forTesting` constructor so tests can inject
/// a fake Supabase-like client and use an in-memory local DB.
class QueueProvider extends ChangeNotifier {
  final dynamic _supabase; // SupabaseClient at runtime, or a test/fake client
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  /// When true, the provider will avoid realtime subscriptions and use an
  /// in-memory DB for tests.
  final bool isTesting;

  List<Client> _clients = [];
  List<Client> get clients => _clients;

  QueueProvider()
      : _supabase = Supabase.instance.client,
        _localDb = LocalQueueService(),
        _geoService = GeolocationService(),
        isTesting = false {
    _init();
  }

  QueueProvider.forTesting(dynamic client)
      : _supabase = client,
        _localDb = LocalQueueService(inMemory: true),
        _geoService = GeolocationService(),
        isTesting = true {
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadQueue();
    } catch (e) {
      // ignore: avoid_print
      print('QueueProvider initialization failed: $e');
    }
  }

  Future<void> _loadQueue() async {
    // Load local immediately
    final rows = await _localDb.getClients();
    _clients = rows.map((m) => Client.fromMap(m)).toList();
    notifyListeners();

    // Try to sync unsynced rows
    await _syncLocalToRemote();

    // Fetch remote records to merge (skip in testing to avoid network)
    if (!isTesting) {
      await _fetchRemoteClients();
      _setupRealtimeSubscription();
    }
  }

  Future<void> _fetchRemoteClients() async {
    try {
      final resp = await _supabase.from('clients').select();
      List<dynamic>? rows;
      // Real Supabase returns a response with `.data` and `.error`.
      try {
        final err = resp.error;
        if (err != null) {
          // ignore: avoid_print
          print('Supabase select error: $err');
        } else {
          rows = resp.data as List<dynamic>?;
        }
      } catch (_) {
        // Some fakes return the list directly
        if (resp is List) rows = resp;
      }

      if (rows != null && rows.isNotEmpty) {
        for (var r in rows) {
          try {
            final map = Map<String, dynamic>.from(r as Map);
            map['is_synced'] = 1;
            await _localDb.insertClientLocally(map);
          } catch (e) {
            // ignore individual row failures
            // ignore: avoid_print
            print('Failed to persist remote row: $e');
          }
        }

        final refreshed = await _localDb.getClients();
        _clients = refreshed.map((m) => Client.fromMap(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to fetch remote clients: $e');
    }
  }

  /// Best-effort sync of local unsynced rows to Supabase.
  /// Tries upsert/insert using list payloads (real client) then falls back to
  /// map payloads (test fakes). Marks rows as synced locally on success.
  Future<void> _syncLocalToRemote() async {
    final unsynced = await _localDb.getUnsyncedClients();

    for (var clientRow in unsynced) {
      final remoteClient = Map<String, dynamic>.from(clientRow)..remove('is_synced');
      final id = remoteClient['id']?.toString() ?? '';
      bool synced = false;

      // Helper to inspect a response-like object for `.error`.
      bool responseHasError(dynamic resp) {
        try {
          return resp.error != null;
        } catch (_) {
          return false;
        }
      }

      // Try upsert(list)
      try {
        final upsertResp = await _supabase.from('clients').upsert([remoteClient]);
        // Debug: log response/error when available
        try {
          // ignore: avoid_print
          print('upsert(list) response for $id: ${upsertResp}');
        } catch (_) {}
        if (!responseHasError(upsertResp)) synced = true;
      } catch (_) {
        // ignore and try other shapes
      }

      // Try insert(list)
      if (!synced) {
        try {
          final insertResp = await _supabase.from('clients').insert([remoteClient]);
          try {
            // ignore: avoid_print
            print('insert(list) response for $id: ${insertResp}');
          } catch (_) {}
          if (!responseHasError(insertResp)) synced = true;
        } catch (_) {}
      }

      // Try upsert(map)
      if (!synced) {
        try {
          final upsertResp2 = await _supabase.from('clients').upsert(remoteClient);
          try {
            // ignore: avoid_print
            print('upsert(map) response for $id: ${upsertResp2}');
          } catch (_) {}
          if (!responseHasError(upsertResp2)) synced = true;
        } catch (_) {}
      }

      // Try insert(map)
      if (!synced) {
        try {
          final insertResp2 = await _supabase.from('clients').insert(remoteClient);
          try {
            // ignore: avoid_print
            print('insert(map) response for $id: ${insertResp2}');
          } catch (_) {}
          if (!responseHasError(insertResp2)) synced = true;
        } catch (e) {
          // ignore
          // ignore: avoid_print
          print('Remote insert failed for $id: $e');
        }
      }

      if (synced) {
        try {
          await _localDb.markClientAsSynced(id);
        } catch (e) {
          // ignore: avoid_print
          print('Marking local client as synced failed for $id: $e');
        }
      }
    }
  }

  /// Add a client locally and try to sync. In testing mode we wait for sync so
  /// tests can assert deterministically.
  Future<void> addClient(String name) async {
    final id = const Uuid().v4();
    double? lat;
    double? lng;
    if (!isTesting) {
      try {
        final pos = await _geoService.getCurrentPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      } catch (_) {
        // ignore geolocation failures for UX
      }
    }

    final clientMap = {
      'id': id,
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'is_synced': 0,
    };

    await _localDb.insertClientLocally(clientMap);

    final client = Client.fromMap(clientMap);
    _clients.add(client);
    _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();

    if (isTesting) {
      // keep tests deterministic
      await _syncLocalToRemote();
    } else {
      unawaited(_syncLocalToRemote());
    }
  }

  /// Remove client locally and attempt remote delete.
  Future<void> removeClient(String id) async {
    try {
      await _localDb.deleteClient(id);
    } catch (e) {
      // ignore: avoid_print
      print('Local delete failed for $id: $e');
    }

    _clients.removeWhere((c) => c.id == id);
    notifyListeners();

    // Try remote delete
    try {
      final del = _supabase.from('clients').delete();
      // Many clients support `.match` for deleting by map, tests' fake uses match
      try {
        await del.match({'id': id});
      } catch (_) {
        // fallback to trying to await the builder directly (some fakes)
        try {
          await del;
        } catch (e) {
          // ignore
          // ignore: avoid_print
          print('Remote delete also failed for $id: $e');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Remote delete failed for $id: $e');
    }
  }

  /// Pops the next client and removes them (same as removeClient but returns the client)
  Future<Client?> nextClient() async {
    if (_clients.isEmpty) return null;
    final client = _clients.removeAt(0);
    notifyListeners();
    await removeClient(client.id);
    return client;
  }

  void _setupRealtimeSubscription() {
    // For now, skip realtime wiring — keep this stub so tests/consumers can
    // call it without failure. Realtime can be added later with proper
    // subscription lifecycle handling.
  }

  Future<void> close() => _localDb.close();
}

