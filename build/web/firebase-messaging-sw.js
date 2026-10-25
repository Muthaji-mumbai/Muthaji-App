/* Firebase Cloud Messaging service worker for Flutter Web */

importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

// TODO: Replace with your Firebase web config from Firebase Console → Project settings → Web app
firebase.initializeApp({
  apiKey: "AIzaSyA8aMOr_tiQ6smcs0rXZY1W3Kjk1hKBeIA",
  authDomain: "soloshine-906d5.firebaseapp.com",
  projectId: "soloshine-906d5",
  storageBucket: "soloshine-906d5.firebasestorage.app",
  messagingSenderId: "129231948033",
  appId: "1:129231948033:web:97d57a3bdac43a8ea0f300",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Notification';
  const options = {
    body: payload.notification?.body || '',
    data: payload.data || {},
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});

// Handle notification click to open route if provided
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const route = event.notification?.data?.route;
  const urlToOpen = route ? new URL(route, self.location.origin).href : self.location.origin;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(urlToOpen);
      }
    })
  );
});


