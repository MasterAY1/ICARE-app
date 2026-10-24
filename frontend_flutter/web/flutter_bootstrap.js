{{flutter_js}}
{{flutter_build_config}}

// Force cache busting on main.dart.js for instant deployment updates
if (window._flutter && window._flutter.buildConfig && window._flutter.buildConfig.builds) {
  var buster = Date.now();
  for (var i = 0; i < window._flutter.buildConfig.builds.length; i++) {
    var b = window._flutter.buildConfig.builds[i];
    if (b.mainJsPath) {
      b.mainJsPath = b.mainJsPath + '?v=' + buster;
    }
  }
}

_flutter.loader.load();
