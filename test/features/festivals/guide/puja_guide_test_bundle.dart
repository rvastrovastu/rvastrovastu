import 'dart:io';

import 'package:flutter/services.dart';

/// Reads assets straight from the project folder.
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}
