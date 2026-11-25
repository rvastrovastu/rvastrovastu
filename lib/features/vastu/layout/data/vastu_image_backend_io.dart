import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Plan pictures in the app's documents folder, under vastu_plans/.
class VastuImageBackend {
  const VastuImageBackend();

  Future<Directory> _dir({bool create = true}) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vastu_plans');
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> write(String name, Uint8List bytes) async {
    final file = File('${(await _dir()).path}/$name');
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> read(String name) async {
    final file = File('${(await _dir()).path}/$name');
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> delete(String name) async {
    final file = File('${(await _dir()).path}/$name');
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final dir = await _dir(create: false);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
