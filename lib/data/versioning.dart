class SerializeVersion {
  final int current;
  final int minimum;
  const SerializeVersion(this.current, this.minimum);
}

// 5: the runtime update switched embedded timestamps from raw source
// strings to ISO-8601 (deserialized as DateTimes).
const entrySerializeVersion = SerializeVersion(5, 1);
const extensionSerializeVersion = SerializeVersion(1, 1);
const categorySerializeVersion = SerializeVersion(1, 1);
