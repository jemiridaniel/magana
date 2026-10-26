import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../library.dart';
import '../papers.dart';

/// "Full reading when online" (board 5e): a page read offline waits here, encrypted
/// on this phone, and gets the server's full reading (tables, columns, the letter
/// check, the second number pass) when the phone is back online. The reading goes to
/// My library; the photo is deleted. At most [max] wait; the oldest go first, and the
/// person is told (Capture says how many were dropped). Classroom phones and accounts
/// without My library never queue: nothing from them is kept.
class PhotoQueue {
  PhotoQueue({Vault? vault, QueueStore? store})
    : _vault = vault ?? ChannelVault(),
      _store = store ?? FileQueueStore();

  static const max = 20;

  final Vault _vault;
  final QueueStore _store;

  /// Waiting pages, oldest first (names start with the time they were kept).
  Future<List<String>> _items() async {
    try {
      return (await _store.names())..sort();
    } catch (_) {
      return []; // no app folder on this platform (the web): nothing waits
    }
  }

  Future<int> get length async => (await _items()).length;

  /// Keeps [bytes] encrypted for a full reading later. Returns how many of the
  /// oldest waiting pages were dropped to stay at [max].
  Future<int> add(Uint8List bytes, {required String mode, Paper? paper}) async {
    final name =
        '${DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0')}_${mode}_${paper?.name ?? 'none'}';
    await _store.write(name, await _vault.encrypt(bytes));
    final items = await _items();
    var dropped = 0;
    while (items.length - dropped > max) {
      await _store.delete(items[dropped]);
      dropped++;
    }
    return dropped;
  }

  /// Sends each waiting page to the server, oldest first, saves its full reading
  /// to My library and deletes the photo. Stops at the first page the server
  /// can't take now (still offline, asleep); a page the server refuses for good
  /// (unreadable, not allowed) is deleted. Returns how many readings were saved.
  Future<int> drain(MaganaApi api) async {
    var saved = 0;
    for (final name in await _items()) {
      final parts = name.split('_');
      final mode = parts.length > 1 ? parts[1] : 'school';
      final paper = parts.length > 2 && parts[2] != 'none'
          ? Paper.values.asNameMap()[parts[2]]
          : null;
      final Uint8List bytes;
      try {
        bytes = await _vault.decrypt(await _store.read(name));
      } catch (_) {
        await _store.delete(
          name,
        ); // can't be opened (the key is gone): never sent
        continue;
      }
      try {
        final result = await api.read(bytes, mode: mode);
        await Library.save(result, paper);
        saved++;
      } on ApiException catch (e) {
        if (const {
          'unreachable',
          'server_sleeping',
          'failed',
          'too_many_requests',
        }.contains(e.code)) {
          break; // try again later
        }
      }
      await _store.delete(name);
    }
    return saved;
  }

  /// Removes every waiting page.
  Future<void> clear() async {
    for (final name in await _items()) {
      await _store.delete(name);
    }
  }
}

/// Where waiting (already encrypted) pages are kept.
abstract class QueueStore {
  Future<List<String>> names();
  Future<void> write(String name, Uint8List bytes);
  Future<Uint8List> read(String name);
  Future<void> delete(String name);
}

/// The app's private support folder, `queue/`.
class FileQueueStore implements QueueStore {
  FileQueueStore({Future<Directory> Function()? folder})
    : _folder = folder ?? _defaultFolder;
  final Future<Directory> Function() _folder;

  static Future<Directory> _defaultFolder() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/queue');

  Future<File> _file(String name) async =>
      File('${(await _folder()).path}/$name.bin');

  @override
  Future<List<String>> names() async {
    final dir = await _folder();
    if (!await dir.exists()) return [];
    return [
      for (final f in await dir.list().toList())
        if (f is File && f.path.endsWith('.bin'))
          f.uri.pathSegments.last.replaceAll('.bin', ''),
    ];
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await (await _folder()).create(recursive: true);
    await (await _file(name)).writeAsBytes(bytes);
  }

  @override
  Future<Uint8List> read(String name) async =>
      (await _file(name)).readAsBytes();

  @override
  Future<void> delete(String name) async {
    final f = await _file(name);
    if (await f.exists()) await f.delete();
  }
}

/// Kept in memory (tests).
class MemoryQueueStore implements QueueStore {
  final items = <String, Uint8List>{};
  @override
  Future<List<String>> names() async => items.keys.toList();
  @override
  Future<void> write(String name, Uint8List bytes) async => items[name] = bytes;
  @override
  Future<Uint8List> read(String name) async => items[name]!;
  @override
  Future<void> delete(String name) async => items.remove(name);
}

/// The queue the app uses; tests replace it.
PhotoQueue photoQueue = PhotoQueue();

/// Encrypts waiting photos with a key kept in the Android Keystore.
abstract class Vault {
  Future<Uint8List> encrypt(Uint8List plain);
  Future<Uint8List> decrypt(Uint8List sealed);
}

class ChannelVault implements Vault {
  static const _channel = MethodChannel('magana/vault');

  @override
  Future<Uint8List> encrypt(Uint8List plain) async =>
      (await _channel.invokeMethod<Uint8List>('encrypt', {'bytes': plain}))!;

  @override
  Future<Uint8List> decrypt(Uint8List sealed) async =>
      (await _channel.invokeMethod<Uint8List>('decrypt', {'bytes': sealed}))!;
}

/// "Full reading when online": on unless the person turns it off.
class FullReadingSetting {
  static const _key = 'full_reading_online';
  static Future<bool> get() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? true;
  static Future<void> set(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_key, on);
}
