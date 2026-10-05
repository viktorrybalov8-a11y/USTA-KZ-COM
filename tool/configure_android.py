from pathlib import Path


gradle_file = Path("android/app/build.gradle.kts")
source = gradle_file.read_text()
source = source.replace("ndkVersion = flutter.ndkVersion", 'ndkVersion = "27.0.12077973"')
source = source.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")

if 'ndkVersion = "27.0.12077973"' not in source or "minSdk = 23" not in source:
    raise SystemExit("Flutter Android template changed; update tool/configure_android.py")

gradle_file.write_text(source)
