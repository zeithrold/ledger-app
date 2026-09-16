import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/governance/analyze.dart' as governance;

void main() {
  test('Windows separators produce the same repository path as POSIX', () {
    final windows = ['lib', 'core', 'file.dart'].join(String.fromCharCode(92));
    expect(governance.repositoryPath(windows), 'lib/core/file.dart');
    expect(
      governance.repositoryPath('lib/core/file.dart'),
      'lib/core/file.dart',
    );
  });
  group('CLI', cliTests);
  test('feature cycles cannot hide behind public entrypoints', () {
    expect(
      governance.featureCycles([
        (source: 'lib/features/a/x.dart', target: 'lib/features/b/b.dart'),
        (source: 'lib/features/b/x.dart', target: 'lib/features/a/a.dart'),
      ]),
      ['a -> b -> a'],
    );
    expect(
      governance.featureCycles([
        (source: 'lib/features/a/x.dart', target: 'lib/features/a/y.dart'),
        (source: 'lib/features/a/x.dart', target: 'lib/features/b/b.dart'),
      ]),
      isEmpty,
    );
  });
  test('boundary paths normalize package aliases and all IO adapters', () {
    expect(
      governance.resolveDependency(
        'lib/core/x.dart',
        'package:ledger_app/core/../features/a/a.dart',
      ),
      'lib/features/a/a.dart',
    );
    expect(
      governance.resolveDependency('lib/core/x.dart', 'dart:async'),
      'dart:async',
    );
    for (final target in ['lib/shared/x.dart', 'lib/app/router.dart']) {
      expect(
        governance.violation((source: 'lib/core/x.dart', target: target)),
        'core-presentation',
      );
    }
    expect(
      governance.violation((
        source: 'lib/shared/x.dart',
        target: 'lib/features/a/a.dart',
      )),
      'shared-feature',
    );
    for (final target in [
      'dart:io',
      'package:flutter_secure_storage/flutter_secure_storage.dart',
    ]) {
      expect(
        governance.violation((source: 'lib/features/a/x.dart', target: target)),
        'presentation-io',
      );
    }
    expect(
      governance.violation((
        source: 'lib/main.dart',
        target: 'lib/app/app.dart',
      )),
      isNull,
    );
  });
  test(
    'parser covers multiline, export, relative and conditional directives',
    () {
      const source =
          "import 'a.dart' if (dart.library.io) 'b.dart';\n"
          "export\n 'package:ledger_app/features/books/internal.dart';\n"
          "part 'piece.dart';\n// import 'ignored.dart';";
      expect(governance.directiveUris(source), [
        'a.dart',
        'b.dart',
        'package:ledger_app/features/books/internal.dart',
        'piece.dart',
      ]);
      expect(
        governance.resolveDependency('lib/core/x.dart', '../features/y.dart'),
        'lib/features/y.dart',
      );
    },
  );
  test('boundaries reject reverse, private and direct IO dependencies', () {
    expect(
      governance.violation((
        source: 'lib/core/x.dart',
        target: 'lib/features/a/a.dart',
      )),
      'core-presentation',
    );
    expect(
      governance.violation((
        source: 'lib/features/a/x.dart',
        target: 'lib/features/b/private.dart',
      )),
      'feature-private-import',
    );
    expect(
      governance.violation((
        source: 'lib/features/a/x.dart',
        target: 'lib/features/b/b.dart',
      )),
      isNull,
    );
    expect(
      governance.violation((
        source: 'lib/shared/x.dart',
        target: 'package:http/http.dart',
      )),
      'presentation-io',
    );
    expect(
      governance.violation((
        source: 'lib/shared/x.dart',
        target: 'lib/app/router.dart',
      )),
      'composition-root',
    );
    expect(
      governance.violation((
        source: 'lib/shared/x.dart',
        target: 'lib/app/theme/ledger_tokens.dart',
      )),
      isNull,
    );
  });
  test('inventory includes code without imports but excludes comments', () {
    expect(governance.executableLines('// comment\nint answer() => 42;\n'), [
      2,
    ]);
    expect(governance.executableLines('// only a comment\n'), isEmpty);
    expect(
      governance.executableLines('void f() {\n print(1);\n}\n'),
      contains(2),
    );
    expect(
      governance.executableLines('int value = 1;\nvoid f() {\nvar x = 2;\n}\n'),
      containsAll([1, 3]),
    );
  });
}

void cliTests() {
  late Directory temporary;
  late Directory previous;
  setUp(() {
    previous = Directory.current;
    temporary = Directory.systemTemp.createTempSync('ledger-architecture-');
    Directory.current = temporary;
    Directory('lib/core').createSync(recursive: true);
    Directory('tool/governance').createSync(recursive: true);
    File('tool/governance/architecture-exceptions.json').writeAsStringSync(
      jsonEncode({'schema_version': 1, 'exceptions': <Object>[]}),
    );
    exitCode = 0;
  });
  tearDown(() {
    Directory.current = previous;
    temporary.deleteSync(recursive: true);
    exitCode = 0;
  });
  test(
    'CLI inventories previously unimported source and checks a valid graph',
    () {
      Directory('coverage/tool').createSync(recursive: true);
      File('coverage/tool/stale.json').writeAsStringSync('{}');
      governance.main(['--clean-tool-coverage']);
      expect(Directory('coverage/tool').existsSync(), isFalse);
      governance.main(['--clean-tool-coverage']);
      File('lib/core/example.dart').writeAsStringSync('int answer() => 42;');
      File(
        'tool/governance/example.dart',
      ).writeAsStringSync('int tool() => 1;');
      governance.main(['--inventory']);
      final inventory =
          jsonDecode(File('coverage/source-inventory.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        (inventory['files'] as Map<String, dynamic>).keys,
        containsAll(['lib/core/example.dart', 'tool/governance/example.dart']),
      );
      governance.main([]);
      expect(exitCode, 0);
    },
  );
  test('CLI fails new violations and permits only a current explicit edge', () {
    File(
      'lib/core/example.dart',
    ).writeAsStringSync("import '../features/x.dart';");
    governance.main([]);
    expect(exitCode, 1);
    final exception = {
      'edge': 'core-presentation|lib/core/example.dart|lib/features/x.dart',
      'owner': 'test-owner',
      'reason': 'test-reason',
      'expires': '9999-01-01',
    };
    File('tool/governance/architecture-exceptions.json').writeAsStringSync(
      jsonEncode({
        'schema_version': 1,
        'exceptions': [exception],
      }),
    );
    exitCode = 0;
    governance.main([]);
    expect(exitCode, 0);
    exception['expires'] = '2000-01-01';
    File('tool/governance/architecture-exceptions.json').writeAsStringSync(
      jsonEncode({
        'schema_version': 1,
        'exceptions': [exception],
      }),
    );
    governance.main([]);
    expect(exitCode, 1);
    File('lib/core/example.dart').writeAsStringSync('int answer() => 42;');
    exception['expires'] = '9999-01-01';
    File('tool/governance/architecture-exceptions.json').writeAsStringSync(
      jsonEncode({
        'schema_version': 1,
        'exceptions': [exception],
      }),
    );
    exitCode = 0;
    governance.main([]);
    expect(exitCode, 1);
  });
  test('CLI fails cyclic public feature imports', () {
    Directory('lib/features/a').createSync(recursive: true);
    Directory('lib/features/b').createSync(recursive: true);
    File('lib/features/a/a.dart').writeAsStringSync("import '../b/b.dart';");
    File('lib/features/b/b.dart').writeAsStringSync("import '../a/a.dart';");
    governance.main([]);
    expect(exitCode, 1);
  });
}
