import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'first_screen.dart';
import 'package:flutter/foundation.dart';

// =============================================
// Handler untuk notifikasi saat app di background/terminated
// =============================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[BG] Notifikasi diterima: ${message.notification?.title}');
  
  // Tampilkan local notification di background juga
  final notification = message.notification;
  if (notification != null) {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smartbovine_alerts',
          'Peringatan SmartBovine',
          channelDescription: 'Notifikasi peringatan kesehatan sapi dari AI',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}

// =============================================
// Plugin & Channel untuk local notification
// =============================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'smartbovine_alerts',
  'Peringatan SmartBovine',
  description: 'Notifikasi peringatan kesehatan sapi dari AI',
  importance: Importance.max, // max agar muncul sebagai heads-up
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Buat notification channel di Android
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // 3. Init local notifications plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle ketika user tap notifikasi
        debugPrint('[TAP] Notifikasi di-tap: ${response.payload}');
      },
    );

    // 4. Set foreground notification presentation (iOS)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // 5. Request permission (support web & mobile)
  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

  // 6. Subscribe ke topic 'peringatan_sapi' (hanya mobile)
  if (!kIsWeb) {
    await FirebaseMessaging.instance.subscribeToTopic('peringatan_sapi');
    debugPrint('[FCM] Subscribed ke topic: peringatan_sapi');
  }

  // 7. Debug: Print FCM Token untuk testing
  String? token = await FirebaseMessaging.instance.getToken();
  debugPrint('[FCM] Device Token: $token');

  // =============================================
  // 8. LISTENER: Tampilkan notifikasi saat app di FOREGROUND
  // =============================================
  if (!kIsWeb) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FG] Pesan masuk: ${message.notification?.title}');

      RemoteNotification? notification = message.notification;

      // Tampilkan sebagai local notification agar muncul di HP
      // Tidak perlu cek android != null karena beberapa device tidak mengisi field ini
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              styleInformation: BigTextStyleInformation(
                notification.body ?? '',
                contentTitle: notification.title,
              ),
            ),
          ),
          payload: message.data['sapi_id'],
        );
        debugPrint('[FG] Local notification ditampilkan!');
      } else {
        debugPrint('[FG] notification payload null, cek data: ${message.data}');
      }
    });
  }

  // =============================================
  // 9. LISTENER: Handle ketika user tap notifikasi (app dari background)
  // =============================================
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('[OPEN] App dibuka dari notifikasi: ${message.data}');
    // Bisa navigasi ke halaman notifikasi di sini
  });

  // 10. Check apakah app dibuka dari terminated state via notifikasi
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('[INIT] App dibuka dari notifikasi (terminated): ${initialMessage.data}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBovine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const FirstScreen(),
    );
  }
}