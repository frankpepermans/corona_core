import 'dart:typed_data';

class DataType {
  static int INT = 1;
  static int DOUBLE = 2;
  static int BOOL = 3;
  static int STRING = 4;
  static int DATE_TIME = 5;
  static int ITERABLE = 6;
  static int OTHER = 7;
}

void write(List<int> data, Uint8List encoded) {
  data.add(encoded.length);
  data.addAll(encoded);
}

Uint8List writeBool(bool value) => new Uint8List.fromList(
    value == null ? const <int>[0] : value ? const <int>[1] : const <int>[2]);

bool readBool(Uint8List encoded) {
  final int value = encoded[0];

  if (value == 0)
    return null;
  else if (value == 1)
    return true;
  else if (value == 2) return false;

  throw new Exception('Cannot decode $encoded to a boolean value');
}

Uint8List writeInt(int value) {
  if (value == null) return new Uint8List.fromList(const <int>[0]);

  final bool isZero = value == 0;
  final bool isPositive = value >= 0;
  final List<int> encoded = <int>[isZero ? 1 : isPositive ? 2 : 3];

  if (!isZero) {
    value = value < 0 ? -value : value;

    _writeIntImpl(value, encoded);
  }

  return new Uint8List.fromList(encoded);
}

Uint8List writeUint(int value) {
  if (value == 0) return new Uint8List.fromList(const <int>[0]);

  final List<int> encoded = <int>[];

  _writeIntImpl(value, encoded);

  return new Uint8List.fromList(encoded);
}

int readInt(Uint8List encoded) {
  final int sign = encoded.first;

  if (sign == 0) return null;

  final bool isZero = sign == 1;
  int value = 0;

  if (isZero) return value;

  final bool isPositive = sign == 2;

  for (int i = 1, offset = 0, len = encoded.length; i < len; i++, offset += 8)
    value |= encoded[i] << offset;

  return isPositive ? value : -value;
}

int readUint(Uint8List encoded) {
  int value = 0;

  for (int i = 0, offset = 0, len = encoded.length; i < len; i++, offset += 8)
    value |= encoded[i] << offset;

  return value;
}

Uint8List writeDouble(double value) {
  if (value == null) return new Uint8List.fromList(const <int>[0]);

  final List<int> result = <int>[1];
  int fp = 0;

  while (value.remainder(1.0) != .0) {
    value *= 10;

    fp++;
  }

  final Uint8List encoded = writeUint(value.toInt());

  result.add(value.sign == -1.0 ? 0 : 1);
  result.add(fp);
  result.add(encoded.length);
  result.addAll(encoded);

  return new Uint8List.fromList(result);
}

double readDouble(Uint8List encoded) {
  if (encoded[0] == 0) return null;

  final bool isPositive = encoded[1] == 1;
  final int fp = encoded[2];
  final int len = encoded[3];
  double value = readUint(encoded.sublist(4, len + 4)) / (fp * 10);

  return isPositive ? value : -value;
}

Uint8List writeDateTime(DateTime value) {
  if (value == null) return new Uint8List.fromList(const <int>[0]);

  final List<int> result = <int>[1];

  result.addAll(writeUint(value.millisecondsSinceEpoch));

  return new Uint8List.fromList(result);
}

DateTime readDateTime(Uint8List encoded) {
  if (encoded[0] == 0) return null;
  
  return new DateTime.fromMillisecondsSinceEpoch(readUint(encoded.sublist(1)));
}

void _writeIntImpl(int value, List<int> encoded) {
  encoded.add(value & 0xff);

  value >>= 8;

  if (value > 0) {
    _writeIntImpl(value, encoded);
  }
}

Uint8List writeString(String value) {
  if (value == null) return new Uint8List.fromList(const <int>[0]);

  final List<int> result = <int>[1];

  value.codeUnits.map(writeUint).forEach((Uint8List encoded) {
    result.add(encoded.length);
    result.addAll(encoded);
  });

  return new Uint8List.fromList(result);
}

String readString(Uint8List encoded) {
  if (encoded[0] == 0) return null;

  final List<int> charCodes = <int>[];
  final int len = encoded.length;
  int i = 1, size;

  while (i < len) {
    size = encoded[i];

    charCodes.add(readUint(encoded.sublist(i + 1, i + size + 1)));

    i += size + 1;
  }

  return new String.fromCharCodes(charCodes);
}

Uint8List writeIterable<T>(Iterable<T> value, Uint8List encoder(T value)) {
  if (value == null) return new Uint8List.fromList(const <int>[0]);

  final List<int> encoded = <int>[1];
  final int len = value.length;
  final Uint8List size = writeUint(len);

  encoded.add(size.length);
  encoded.addAll(size);

  value.map(encoder).forEach((Uint8List element) {
    encoded.addAll(writeUint(element.length));
    encoded.addAll(element);
  });

  return new Uint8List.fromList(encoded);
}

List<T> readIterable<T>(Uint8List encoded, T decoder(Uint8List value)) {
  if (encoded[0] == 0) return null;

  final int size = readUint(new Uint8List.fromList(<int>[encoded[1]]));
  final int len = readUint(encoded.sublist(2, 2 + size));
  final List<T> result = new List<T>(len);
  int index = 2 + size;

  for (int i = 0; i < len; i++) {
    int fragmentLen = readUint(new Uint8List.fromList(<int>[encoded[index]]));

    result[i] = decoder(encoded.sublist(index + 1, index + fragmentLen + 1));

    index += fragmentLen + 1;
  }

  return new List<T>.unmodifiable(result);
}
