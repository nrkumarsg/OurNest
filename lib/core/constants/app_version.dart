/// App version shown in Settings / About.
///
/// Must match `version:` in pubspec.yaml – `test/unit/honest_ui_phase_d_test.dart`
/// fails the build if they drift apart, so update both when releasing.
/// (package_info_plus would read it at runtime, but its current release needs
/// a newer Kotlin than this Android project uses – see audit Phase F.)
const String appVersionName = '1.2.3';
const String appBuildNumber = '6';
const String appVersionLabel = '$appVersionName (Build $appBuildNumber)';
