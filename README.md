# USTA.KZ

Flutter MVP мобильного сервиса заказов и мастеров в Казахстане. Android-проект генерируется Flutter во время CI; исходники платформы намеренно не хранятся в репозитории.

## Что уже работает

- Вход по SMS через Firebase Phone Authentication и первичная настройка профиля.
- Общая лента заказов в Cloud Firestore: публикация, фильтр по категории и городу, поиск, просмотр, удаление владельцем.
- Фото заказа и фото профиля через Firebase Storage (до 4 фото на заказ, до 8 МБ каждое; фото профиля до 5 МБ).
- Каталог мастеров и компаний, индивидуальные чаты в реальном времени.
- Уведомления о новых заказах, сообщениях и заявках; Cloud Functions рассылают push и сохраняют уведомления в ленту.
- Заявки на USTA Business (9 999 ₸/мес) и рекламу; админ-раздел для обработки заявок с доступом через Firebase custom claim.
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
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Cloud Functions требуют привязать Cloud Billing и перевести Firebase-проект с Spark на Blaze. До этого пуши, серверные уведомления и админ-уведомления не выполняются. Настройте бюджетные уведомления и проверьте биллинг/лимиты перед развертыванием. Чтобы назначить администратора, используйте Google Cloud Shell или доверенную машину с Application Default Credentials: `cd functions && npm install && node scripts/set_admin.mjs grant FIREBASE_USER_UID`. Доступ выдаётся только серверным Firebase Admin SDK; мобильный клиент не может назначить администратора. Для отзыва замените `grant` на `revoke`.

Перед настройкой `firebase deploy` нужно сверить регион базы Firestore с регионом функций и разрешить отправку Cloud Messaging. Скрипт администрирования и исходники Functions находятся в `functions/`.

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

USTA Business и реклама сейчас принимают заявки; оплата картой, списание 9 999 ₸ и автоматическая активация подписки не включены. Админ-раздел показывает и обновляет статусы заявок после серверной выдачи custom claim. Push-код готов, но начинает отправлять реальные уведомления после настройки Firebase, регистрации приложения и развёртывания Cloud Functions. Для платежей потребуется выбрать провайдера, настроить серверную проверку платежа и условия возврата. Условия и политика в приложении — стартовые тексты, перед публичным релизом их должен утвердить оператор сервиса и разместить по постоянным публичным URL.
