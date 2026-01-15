import 'package:light_sdk/light_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('SOL PDA static constant matches derivation', () async {
    final derived = await LightSystemProgram.deriveCompressedSolPda();
    final constant = LightSystemProgram.solPoolPda;

    // The important thing is that our static constant matches what we derive
    expect(derived, equals(constant));
    expect(
      derived.toBase58(),
      equals('CHK57ywWSDncAoRu1F8QgwYJeXuAJyyBYT4LixLXvMZ1'),
    );
  });

  test('SOL PDA derivation is deterministic', () async {
    final pda1 = await LightSystemProgram.deriveCompressedSolPda();
    final pda2 = await LightSystemProgram.deriveCompressedSolPda();

    expect(pda1, equals(pda2));
  });
}
