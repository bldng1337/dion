class SerializeVersion {
  final int current;
  final int minimum;
  const SerializeVersion(this.current, this.minimum);
}

const entrySerializeVersion = SerializeVersion(3, 1);
const extensionSerializeVersion = SerializeVersion(1, 1);
const categorySerializeVersion = SerializeVersion(1, 1);
