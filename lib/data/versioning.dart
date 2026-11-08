class SerializeVersion {
  final int current;
  final int minimum;
  const SerializeVersion(this.current, this.minimum);
}

// 5: the runtime update switched embedded timestamps from raw source
// strings to ISO-8601 (deserialized as DateTimes).
// 7: episode data is an object keyed by episode id, which sync merges per
// episode and per field.
const entrySerializeVersion = SerializeVersion(7, 1);
const extensionSerializeVersion = SerializeVersion(1, 1);
const categorySerializeVersion = SerializeVersion(1, 1);
