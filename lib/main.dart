import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _tratarPushEmSegundoPlano(RemoteMessage mensagem) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_tratarPushEmSegundoPlano);
  runApp(const AplicativoWhyPhy());
}
