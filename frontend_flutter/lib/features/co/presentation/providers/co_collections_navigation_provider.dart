import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared navigation state for CO Daily Collections tabs & entry modes.
/// Kept in a lightweight standalone file so Cashbook and Collections can
/// route cleanly without circular imports.
final collectionsTabProvider =
    StateProvider<int>((ref) => 0); // 0=Record, 1=History, 2=Reversals
final collectionsModeProvider = StateProvider<String>(
  (ref) => 'Group Collection Sheet',
); // or 'Single Client Quick Entry'
