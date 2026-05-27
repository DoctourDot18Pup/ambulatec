// AmbulaTec — Firebase Cloud Messaging service worker.
//
// This file enables background push notifications on web.
// It must live at the root of the "web/" folder so the browser
// can register it at the scope "/".
//
// ⚠️  These scripts are loaded inside a Service Worker — they must use
//     the Firebase *compat* SDK (not the modular SDK).

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAbA9Y3ye-2gJR0jI3yQpDBRPlwAW-gKNc',
  authDomain: 'ambulatec-6d892.firebaseapp.com',
  projectId: 'ambulatec-6d892',
  storageBucket: 'ambulatec-6d892.firebasestorage.app',
  messagingSenderId: '553891451539',
  appId: '1:553891451539:web:ecdd3166b3c67344eb7366',
});

const messaging = firebase.messaging();

// Handle messages received while the app is in the background or closed.
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message:', payload);

  const title = payload.notification?.title ?? 'AmbulaTec';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
  };

  return self.registration.showNotification(title, options);
});
