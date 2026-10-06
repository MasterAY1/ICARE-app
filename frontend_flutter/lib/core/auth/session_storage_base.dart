abstract class SessionStorage {
  Future<void> saveSession(String token, String userJson);
  Future<Map<String, String>?> getSession();
  Future<void> clearSession();
}
