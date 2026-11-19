import 'local_key_store_base.dart';
import 'local_key_store_io.dart'
    if (dart.library.html) 'local_key_store_web.dart' as impl;

export 'local_key_store_base.dart';

LocalKeyStore getLocalKeyStore() => impl.getLocalKeyStore();
