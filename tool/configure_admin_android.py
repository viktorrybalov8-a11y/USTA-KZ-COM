from pathlib import Path

gradle_file = Path("admin-app/android/app/build.gradle.kts")
source = gradle_file.read_text()
source = source.replace("ndkVersion = flutter.ndkVersion", 'ndkVersion = "27.0.12077973"')
source = source.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
if 'ndkVersion = "27.0.12077973"' not in source or "minSdk = 23" not in source:
    raise SystemExit("Flutter Android template changed; update tool/configure_admin_android.py")
gradle_file.write_text(source)

manifest_file = Path("admin-app/android/app/src/main/AndroidManifest.xml")
manifest = manifest_file.read_text()
manifest = manifest.replace('android:label="usta_admin"', 'android:label="USTA Администратор"')
manifest_file.write_text(manifest)
