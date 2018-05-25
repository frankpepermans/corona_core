abstract class TearOffAndValueObjectSchema {
  dynamic getValueFromKey(String key);

  List<TearOffAndValueObjectSchema> expand(
      [List<TearOffAndValueObjectSchema> list]);

  Map<String, dynamic> toJSON();

  Function(dynamic, String, dynamic) getTearOffForKey(String key);
}
