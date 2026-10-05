import 'package:flutter/material.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(privacy ? 'Политика конфиденциальности' : 'Условия использования')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: privacy
              ? const [
                  Text('Политика конфиденциальности', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('USTA.KZ использует номер телефона для входа и защиты аккаунта. Имя, город, тип профиля и выбранное фото показываются в каталоге мастеров и компаниям. Телефон заказа виден пользователям, которым доступен заказ.'),
                  SizedBox(height: 12),
                  Text('Заказы, профили и переписка хранятся в Firebase. Фото загружаются в Firebase Storage. Firebase Auth может обрабатывать номер телефона для отправки SMS и предотвращения злоупотреблений.'),
                  SizedBox(height: 12),
                  Text('Не размещайте секретные или платёжные данные в заказах и сообщениях. Чтобы запросить исправление или удаление данных, обратитесь к оператору приложения USTA.KZ.'),
                ]
              : const [
                  Text('Условия использования', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('USTA.KZ помогает заказчикам находить мастеров и компаниям. Пользователь отвечает за достоверность опубликованных сведений, цену, телефон и содержание сообщений.'),
                  SizedBox(height: 12),
                  Text('Не публикуйте незаконные, вводящие в заблуждение, оскорбительные материалы или чужие персональные данные без согласия. Оператор может удалить нарушающие правила материалы и ограничить доступ к сервису.'),
                  SizedBox(height: 12),
                  Text('USTA.KZ не является стороной договорённостей между заказчиком и исполнителем. Проверяйте квалификацию, стоимость и условия работ самостоятельно.'),
                ],
        ),
      );
}
