const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Stripe = require('stripe');

admin.initializeApp();

// ── FCM push notifications (requires Blaze plan — disabled) ───────────────
// Push notifications are handled client-side via flutter_local_notifications.
// Uncomment and deploy only if upgrading to Firebase Blaze plan.

/*
/**
 * sendPushNotification — Firestore trigger.
 *
 * Fires whenever a new document is created in the `notifications` collection.
 * Reads the recipient's FCM tokens from their user document and sends a
 * targeted push notification with the correct title, body and deep-link route.
 *
 * Token cleanup: invalid / expired tokens are removed from Firestore so the
 * array stays tidy over time.
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const recipientId = data.recipientId;
    if (!recipientId) return null;

    // ── Fetch FCM tokens ─────────────────────────────────────────────────
    const userSnap = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .get();

    const tokens = userSnap.data()?.fcmTokens || [];
    if (tokens.length === 0) return null;

    // ── Build message payload ────────────────────────────────────────────
    const type = data.type || '';
    const productTitle = data.productTitle || 'tu pedido';
    const buyerName = data.buyerName || 'Un comprador';
    const orderId = data.orderId || '';

    let title, body, route;

    switch (type) {
      case 'new_order':
        title = '¡Nuevo pedido!';
        body = `${buyerName} quiere: ${productTitle}`;
        route = `/order-alert/${orderId}`;
        break;
      case 'awaiting_payment':
        title = '¡Vendedor aceptó tu pedido!';
        body = `Procede al pago para confirmar: ${productTitle}`;
        route = `/chat/${orderId}`;
        break;
      case 'payment_received':
        title = '¡Pago recibido!';
        body = `${buyerName} pagó por ${productTitle}`;
        route = `/chat/${orderId}`;
        break;
      case 'order_delivered':
        title = '¡Tu pedido llegó!';
        body = `Califica tu experiencia con ${productTitle}`;
        route = `/review/${orderId}`;
        break;
      default:
        return null;
    }

    // ── Send via FCM multicast ───────────────────────────────────────────
    const message = {
      tokens,
      notification: { title, body },
      data: { route, orderId },
      android: {
        priority: 'high',
        notification: { channelId: 'ambulatec_orders', sound: 'default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // ── Prune invalid tokens ─────────────────────────────────────────────
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error?.code || '';
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
    }

    return null;
  });
*/

// REEMPLAZAR con tu secret key de Stripe (modo test)
// NUNCA commits esta clave en git — usa Firebase environment config en producción:
//   firebase functions:config:set stripe.secret="sk_test_..."
const stripe = new Stripe(
  functions.config().stripe?.secret || 'sk_test_REEMPLAZAR'
);

/**
 * createPaymentIntent — callable HTTPS function.
 *
 * Expected data:
 *   { amount: number, currency: string, orderId: string }
 *
 * Returns:
 *   { clientSecret: string, paymentIntentId: string }
 *
 * Deploy:
 *   cd functions && npm install && cd .. && firebase deploy --only functions
 *
 * NOTE: Requires Firebase Blaze plan (pay-as-you-go) to call external APIs
 * like Stripe. The Spark (free) plan blocks outbound network calls.
 */
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado.'
    );
  }

  const { amount, currency, orderId } = data;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Monto inválido.'
    );
  }

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Stripe uses cents
      currency: currency || 'mxn',
      metadata: {
        orderId: orderId,
        userId: context.auth.uid,
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
