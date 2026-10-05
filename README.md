# USTA.KZ

Flutter MVP мобильного сервиса заказов и мастеров в Казахстане. Android-проект генерируется Flutter во время CI; исходники платформы намеренно не хранятся в репозитории.

## Что уже работает

- Вход по SMS через Firebase Phone Authentication и первичная настройка профиля.
- Общая лента заказов в Cloud Firestore: публикация, фильтр по категории и городу, поиск, просмотр, удаление владельцем.
- Фото заказа и фото профиля через Firebase Storage (до 4 фото на заказ, до 8 МБ каждое; фото профиля до 5 МБ).
- Каталог мастеров и компаний, индивидуальные чаты в реальном времени.
- Локальный демо-режим, если сборка выполнена без конфигурации Firebase.
- Правила безопасности Firestore и Storage, индексы запросов и тексты условий/конфиденциальности в приложении.

## Настройка Firebase

Создайте Android-приложение в проекте Firebase `usta-kz` с package name `kz.nargizgryp.usta_kz`. В Firebase Console включите Phone Authentication, создайте Firestore и Storage, зарегистрируйте SHA-1/SHA-256 ключи сборки для Phone Auth и проверьте разрешённые регионы SMS. Firebase API key, App ID, Sender ID и bucket — публичные идентификаторы клиента; не добавляйте service account JSON или приватные ключи в приложение и репозиторий.

Соберите приложение, передав клиентские параметры через `--dart-define`:

```sh
flutter pub get
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=usta-kz \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Примените конфигурацию базы из каталога проекта с установленным Firebase CLI:

```sh
firebase use usta-kz
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Без этих настроек сборка запускается в локальном демо-режиме. Phone Auth, общие заказы, чаты и фото в нём недоступны.

## Проверка и сборка

```sh
flutter create --platforms=android --org=kz.nargizgryp --project-name=usta_kz .
python3 tool/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions выполняет эти проверки и сохраняет тестовый APK как artifact. Для Google Play отдельно требуются Firebase-конфигурация в защищённых build secrets, production-правовая страница и контакт поддержки, приватный ключ подписи Android и сборка подписанного AAB. Включение SMS, развёртывание Firebase-правил и публикация APK/AAB не выполняются CI.

## Текущая граница MVP

Приложение не включает обработку платежей/покупку USTA Business, запуск платной рекламы, серверную админ-панель и отправку push-уведомлений. Такие функции требуют платёжного провайдера и проверки продуктов, а также доверенной серверной части; роль администратора нельзя выдавать из мобильного клиента. Условия и политика в приложении — стартовые тексты, перед публичным релизом их должен утвердить оператор сервиса и разместить по постоянным публичным URL.
