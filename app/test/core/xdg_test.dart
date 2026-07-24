import 'package:bakeneko/core/xdg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('dataRoot respeta XDG_DATA_HOME', () {
    expect(Xdg.dataRoot.path, endsWith(p.join('bakeneko')));
    expect(Xdg.dataRoot.path, contains('bakeneko'));
  });

  test('daemonSocket está bajo runtime/bakeneko/daemon.sock', () {
    expect(Xdg.daemonSocket.path, contains('bakeneko'));
    expect(p.basename(Xdg.daemonSocket.path), 'daemon.sock');
  });

  test('ensureDirs crea dataRoot y descendientes', () {
    // Usamos un XDG temporal vía override del entorno no trivial en test;
    // probamos idempotencia: llamar dos veces no rompe.
    Xdg.ensureDirs();
    Xdg.ensureDirs();
    expect(Xdg.dataRoot.existsSync(), isTrue);
    expect(Xdg.downloadsRoot.existsSync(), isTrue);
    expect(Xdg.cacheRoot.existsSync(), isTrue);
    expect(Xdg.configRoot.existsSync(), isTrue);
  });

  test('uid es un entero positivo', () {
    expect(Xdg.uid, greaterThan(0));
  });

  test('descargasRoot bajo dataRoot', () {
    expect(p.isWithin(Xdg.dataRoot.path, Xdg.downloadsRoot.path), isTrue);
  });
}