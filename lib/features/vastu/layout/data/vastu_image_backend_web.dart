import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Plan pictures in the browser's IndexedDB (database `rv_astro_vastu`,
/// store `vastu_plans`, keyed by file name). IndexedDB holds far more than
/// localStorage's few megabytes, enough for many full-size plans.
class VastuImageBackend {
  const VastuImageBackend();

  static const _database = 'rv_astro_vastu';
  static const _store = 'vastu_plans';
  static Future<web.IDBDatabase>? _opening;

  Future<web.IDBDatabase> _db() {
    final existing = _opening;
    if (existing != null) return existing;
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_database, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_store)) db.createObjectStore(_store);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('IndexedDB open failed'));
    }).toJS;
    final opening = completer.future;
    _opening = opening;
    // Let a later call retry if opening failed.
    opening.then<void>((_) {}, onError: (Object _) => _opening = null);
    return opening;
  }

  /// Runs one request against the store and waits for its result.
  Future<JSAny?> _run(
    String mode,
    web.IDBRequest Function(web.IDBObjectStore store) action,
  ) async {
    final db = await _db();
    final transaction = db.transaction(_store.toJS, mode);
    final request = action(transaction.objectStore(_store));
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('IndexedDB $mode failed'));
    }).toJS;
    return completer.future;
  }

  Future<void> write(String name, Uint8List bytes) =>
      _run('readwrite', (store) => store.put(bytes.toJS, name.toJS));

  Future<Uint8List?> read(String name) async {
    final value = await _run('readonly', (store) => store.get(name.toJS));
    if (value == null || value.isUndefinedOrNull) return null;
    return (value as JSUint8Array).toDart;
  }

  Future<void> delete(String name) =>
      _run('readwrite', (store) => store.delete(name.toJS));

  Future<void> deleteAll() => _run('readwrite', (store) => store.clear());
}
