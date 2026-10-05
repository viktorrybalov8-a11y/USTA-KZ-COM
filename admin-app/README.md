# USTA Администратор

Отдельное Android-приложение для просмотра заявок USTA Business и рекламы.

## Доступ и безопасность

- Вход только по email и паролю через Firebase Authentication.
- Подтверждённая почта обязательна.
- Приложение проверяет Firebase custom claim `admin: true`.
- Firestore Security Rules повторно проверяют права при чтении заявок и изменении статуса.
- Самостоятельная регистрация отключена. Администратора назначают через доверенный серверный Firebase Admin SDK.

Приложение использует тот же проект Firebase, что и USTA.KZ. Никакие серверные ключи в APK не включаются.

## Сборка APK

Из корня репозитория:

```sh
cd admin-app
flutter create --platforms=android --org=kz.nargizgryp --project-name=usta_admin .
python3 ../tool/configure_admin_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK для проверки: `admin-app/build/app/outputs/flutter-apk/app-debug.apk`.

В GitHub Actions собирается отдельный артефакт `USTA-Admin-debug-apk`.
