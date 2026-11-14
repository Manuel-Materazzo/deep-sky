/// Immutable metadata describing the host platform capabilities exposed
/// through the native Android channel (APP-02).
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.packageName,
    required this.androidApiLevel,
    required this.versionName,
    required this.versionCode,
    required this.supportsRequestInstallPackages,
  });

  factory PlatformCapabilities.fromMap(Map<Object?, Object?> map) {
    return PlatformCapabilities(
      packageName: map['packageName'] as String? ?? '',
      androidApiLevel: (map['androidApiLevel'] as num?)?.toInt() ?? 0,
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      supportsRequestInstallPackages:
          map['supportsRequestInstallPackages'] as bool? ?? false,
    );
  }

  final String packageName;
  final int androidApiLevel;
  final String versionName;
  final int versionCode;
  final bool supportsRequestInstallPackages;
}
