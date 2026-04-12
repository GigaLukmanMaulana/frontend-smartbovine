// web/firebase-messaging-sw.js

// 1. Import library SDK (Gunakan versi compat agar stabil di Service Worker)
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// 2. Konfigurasi yang lu dapet tadi
const firebaseConfig = {
  apiKey: "AIzaSyBAvqKUiVFdlBOL5LBI6fA_qTz2H6J7NAQ",
  authDomain: "smartsapi.firebaseapp.com",
  databaseURL: "https://smartsapi-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "smartsapi",
  storageBucket: "smartsapi.firebasestorage.app",
  messagingSenderId: "897665279105",
  appId: "1:897665279105:web:bf96e1290097b28d5a5980",
  measurementId: "G-K1KG8171WQ"
};

// 3. Inisialisasi
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// 4. Handle notifikasi saat background/tab ditutup
messaging.onBackgroundMessage((payload) => {
  console.log('[BG] Notifikasi diterima: ', payload);

  const notificationTitle = payload.notification.title || "Update SmartSapi";
  const notificationOptions = {
    body: payload.notification.body || "Ada info baru untuk sapi Anda.",
    icon: '/icons/Icon-192.png', // Sesuaikan dengan path icon di folder web lu
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});