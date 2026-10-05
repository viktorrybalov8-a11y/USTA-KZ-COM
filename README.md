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

Android-приложение уже зарегистрировано в Firebase-проекте `usta-kz` с package name `kz.nargizgryp.usta_kz` и App ID `1:923347040194:android:6fff16a782f9520195485b`. Firebase client options из `google-services.json` заданы как значения по умолчанию в `lib/firebase_config.dart`; при необходимости их можно переопределить через `--dart-define`. Эти параметры предназначены для клиентского приложения, а доступ к данным должен ограничиваться Firebase Authentication, Security Rules и App Check. Никогда не добавляйте service account JSON или приватный ключ подписи в приложение или репозиторий.

Cloud Firestore уже создан в регионе `asia-south1` (Mumbai) в production mode. Для MVP включён Email/Password provider; вход требует подтверждения почты, затем пользователь заполняет профиль и контактный телефон. Правила `firestore.rules` опубликованы и разрешают доступ только подтверждённым аккаунтам с ограничением по владельцу данных. Включены три составных индекса для объявлений, каталога мастеров и чатов. Phone Authentication отложен до добавления SHA-1 сертификата Android-приложения. В конфигурации указан bucket `usta-kz.firebasestorage.app`, но фото выключены по умолчанию: на тарифе Spark Firebase Console требует Blaze для Cloud Storage. Не включайте Storage без отдельного решения владельца проекта по биллингу.

При необходимости переопределите публичные Firebase options при сборке через `--dart-define`:

```sh
flutter pub get
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=usta-kz \
  --dart-define=FIREBASE_STORAGE_BUCKET=usta-kz.firebasestorage.app
```

Фото остаются выключенными, пока владелец проекта не подключит Cloud Storage и не будет готов включить его при сборке: `--dart-define=FIREBASE_STORAGE_ENABLED=true`.

Примените конфигурацию базы из каталога проекта с установленным Firebase CLI:

```sh
firebase use usta-kz
firebase deploy --only firestore:rules,firestore:indexes
```

Cloud Functions требуют привязать Cloud Billing и перевести Firebase-проект с Spark на Blaze. До этого пуши, серверные уведомления и админ-уведомления не выполняются. Не меняйте тариф и не добавляйте платёжные данные без отдельного решения владельца проекта. Чтобы назначить администратора, используйте Google Cloud Shell или доверенную машину с Application Default Credentials: `cd functions && npm install && node scripts/set_admin.mjs grant FIREBASE_USER_UID`. Доступ выдаётся только серверным Firebase Admin SDK; мобильный клиент не может назначить администратора. Для отзыва замените `grant` на `revoke`.

Перед настройкой `firebase deploy` нужно сверить регион базы Firestore с регионом функций и разрешить отправку Cloud Messaging. Скрипт администрирования и исходники Functions находятся в `functions/`.

Если Firebase Console ещё не включает Email/Password или правила Firestore не опубликованы, облачные вход и данные не заработают. В MVP телефонный SMS-вход, загрузка фото и серверные уведомления отложены; приложение показывает, что фото недоступны, и позволяет опубликовать заказ без них.

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
