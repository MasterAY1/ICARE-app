import 'session_storage_base.dart';
import 'session_storage_io.dart'
    if (dart.library.html) 'session_storage_web.dart';

export 'session_storage_base.dart';

final SessionStorage sessionStorage = getSessionStorage();
