import 'dart:typed_data';

/// Minimal Borsh writer for instruction serialization.
class BorshWriter {
  BorshWriter();

  final BytesBuilder _buffer = BytesBuilder();

  /// Write a boolean as u8 (0/1).
  void writeBool(bool value) => writeU8(value ? 1 : 0);

  /// Write an unsigned 8-bit value.
  void writeU8(int value) {
    _validateRange(value, 0, 0xFF);
    _buffer.add([value]);
  }

  /// Write an unsigned 16-bit value (little-endian).
  void writeU16(int value) {
    _validateRange(value, 0, 0xFFFF);
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Write an unsigned 32-bit value (little-endian).
  void writeU32(int value) {
    _validateRange(value, 0, 0xFFFFFFFF);
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Write an unsigned 64-bit value (little-endian) from BigInt.
  void writeU64(BigInt value) => _buffer.add(u64(value));

  /// Write a signed 8-bit value (two's complement).
  void writeI8(int value) {
    _validateRange(value, -0x80, 0x7F);
    _buffer.add([value & 0xFF]);
  }

  /// Write a signed 16-bit value (little-endian, two's complement).
  void writeI16(int value) {
    _validateRange(value, -0x8000, 0x7FFF);
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Write a signed 32-bit value (little-endian, two's complement).
  void writeI32(int value) {
    _validateRange(value, -0x80000000, 0x7FFFFFFF);
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Write a signed 64-bit value (little-endian, two's complement) from BigInt.
  void writeI64(BigInt value) => _buffer.add(i64(value));

  /// Write a fixed array of bytes.
  void writeFixedArray(List<int> bytes) => _buffer.add(bytes);

  /// Write a byte vector with u32 length prefix.
  void writeVec(Uint8List bytes) {
    writeU32(bytes.length);
    _buffer.add(bytes);
  }

  /// Write an optional value with discriminator byte followed by encoder.
  void writeOption<T>(T? value, void Function(T v) encode) {
    if (value == null) {
      writeU8(0);
      return;
    }
    writeU8(1);
    encode(value);
  }

  /// Get the serialized bytes.
  Uint8List toBytes() => _buffer.toBytes();

  /// Static helper: encode u16 as bytes.
  static Uint8List u16(int value) {
    _validateRange(value, 0, 0xFFFF);
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Static helper: encode u32 as bytes.
  static Uint8List u32(int value) {
    _validateRange(value, 0, 0xFFFFFFFF);
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Static helper: encode u64 as bytes from BigInt.
  static Uint8List u64(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('u64 cannot be negative');
    }
    final max = BigInt.one << 64;
    if (value >= max) {
      throw ArgumentError('u64 overflow: $value');
    }
    final bytes = Uint8List(8);
    var temp = value;
    for (var i = 0; i < 8; i++) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp >>= 8;
    }
    return bytes;
  }

  /// Static helper: encode i8 as bytes.
  static Uint8List i8(int value) {
    _validateRange(value, -0x80, 0x7F);
    return Uint8List.fromList([value & 0xFF]);
  }

  /// Static helper: encode i16 as bytes.
  static Uint8List i16(int value) {
    _validateRange(value, -0x8000, 0x7FFF);
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Static helper: encode i32 as bytes.
  static Uint8List i32(int value) {
    _validateRange(value, -0x80000000, 0x7FFFFFFF);
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Static helper: encode i64 as bytes from BigInt.
  static Uint8List i64(BigInt value) {
    _validateI64Range(value);
    final bytes = Uint8List(8);
    var temp = value.toUnsigned(64);
    for (var i = 0; i < 8; i++) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp >>= 8;
    }
    return bytes;
  }

  static void _validateRange(int value, int min, int max) {
    if (value < min || value > max) {
      throw ArgumentError('Value $value out of range [$min, $max]');
    }
  }

  static void _validateI64Range(BigInt value) {
    final min = -(BigInt.one << 63);
    final max = (BigInt.one << 63) - BigInt.one;
    if (value < min || value > max) {
      throw ArgumentError('Value $value out of range [$min, $max]');
    }
  }
}
