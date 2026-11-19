abstract class LocalKeyStore {
  Future<String?> readKey(String name);
  Future<void> writeKey(String name, String value);
  Future<void> deleteKey(String name);
}
