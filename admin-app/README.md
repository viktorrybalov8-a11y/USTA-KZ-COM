# USTA Администратор

Отдельное Android-приложение для просмотра заявок USTA Business и рекламы.

## Доступ и безопасность

- Вход только по email и паролю через Firebase Authentication.
- Подтверждённая почта обязательна.
- Приложение проверяет Firebase custom claim `admin: true`.
- Firestore Security Rules повторно проверяют права при чтении заявок и изменении статуса.
- Самостоятельная регистрация отключена. Администратора назначают через доверенный серверный Firebase Admin SDK.

Приложение использует тот же проект Firebase, что и USTA.KZ, и подписывается на push-уведомления о заказах. Для отправки администратору Firebase Messaging сохраняет токен этого устройства в его профиле. Никакие серверные ключи в APK не включаются.

Android-приложение уже зарегистрировано в проекте `usta-kz` с package name `kz.nargizgryp.usta_admin` и отдельным App ID, указанным в `lib/main.dart`. Для повторной регистрации можно переопределить его через `--dart-define=FIREBASE_APP_ID=...`. App ID основной версии USTA.KZ не используется.

## Сборка APK

Из корня репозитория:

```sh
cd admin-app
flutter create --platforms=android --org=kz.nargizgryp --project-name=usta_admin .
python3 ../tool/configure_admin_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

APK для проверки: `admin-app/build/app/outputs/flutter-apk/app-release.apk`.

В GitHub Actions собирается отдельный артефакт `USTA-Admin-installable-apk`.
