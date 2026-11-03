import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/core/storage/atomic_json_file.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: data directory supports atomic create, backup and replace',
    (tester) async {
      final specified = const String.fromEnvironment('STORAGE_TEST_DIR');
      final directory = specified.isEmpty
          ? await Directory.systemTemp.createTemp('weils-storage-')
          : Directory(specified);
      final probe = File(
        '${directory.path}${Platform.pathSeparator}.weils-write-probe-$pid-${DateTime.now().microsecondsSinceEpoch}.json',
      );
      try {
        final storage = AtomicJsonFile(probe);
        await storage.write({'probe': 1});
        await storage.write({'probe': 2});
        expect(await probe.readAsString(), '{"probe":2}');
        expect(await storage.backup.readAsString(), '{"probe":1}');
      } finally {
        for (final suffix in ['', '.bak', '.tmp']) {
          final file = File('${probe.path}$suffix');
          if (await file.exists()) await file.delete();
        }
        if (specified.isEmpty) await directory.delete();
      }
    },
  );
}
