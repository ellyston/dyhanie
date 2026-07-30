import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Политика конфиденциальности',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _H('1. Общие положения'),
          _P(
            'Приложение «Дыхание» — эфемерный мессенджер. '
            'Мы стремимся собирать минимум данных и не хранить переписку дольше необходимого.',
          ),
          _H('2. Какие данные используются'),
          _P(
            '• Username и аватар — хранятся локально на устройстве.\n'
            '• Код комнаты / dialogId — для соединения участников.\n'
            '• Сообщения — по умолчанию эфемерные (TTL), сервер используется временно для сигналинга.\n'
            '• Конфиги VPN — только ваши, приложение не предоставляет серверы.',
          ),
          _H('3. Серверы'),
          _P(
            'Сейчас для сигналинга и presence может использоваться Firebase (временный backend). '
            'В перспективе — минимальный свой сервер и P2P. '
            'Содержимое сообщений в сохранённом режиме остаётся на вашем устройстве.',
          ),
          _H('4. Права пользователя'),
          _P(
            'Вы можете очистить кэш, удалить чаты, сменить PIN и полностью стереть локальные данные '
            'через «Удалить всё» в профиле.',
          ),
          _H('5. Контакты'),
          _P(
            'По вопросам приватности: support@dyhanie.app\n\n'
            'Текст будет обновлён перед публикацией в магазинах.',
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
    );
  }
}