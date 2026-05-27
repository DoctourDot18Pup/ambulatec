import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/stripe_constants.dart';

// ── CardDetails ────────────────────────────────────────────────────────────

/// Simple card data collected from the payment form.
/// Passed to [PaymentNotifier.confirmPayment].
class CardDetails {
  final String number; // may include spaces, e.g. "4242 4242 4242 4242"
  final String expiry; // e.g. "12 / 26"
  final String cvv;
  final String holderName;

  const CardDetails({
    required this.number,
    required this.expiry,
    required this.cvv,
    required this.holderName,
  });
}

// ── PaymentState ───────────────────────────────────────────────────────────

class PaymentState {
  final bool isLoading;
  final String? error;
  final String? clientSecret;
  final String? paymentIntentId;
  final bool success;

  const PaymentState({
    this.isLoading = false,
    this.error,
    this.clientSecret,
    this.paymentIntentId,
    this.success = false,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? clientSecret,
    String? paymentIntentId,
    bool? success,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      clientSecret: clientSecret ?? this.clientSecret,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      success: success ?? this.success,
    );
  }
}

// ── PaymentNotifier ────────────────────────────────────────────────────────

class PaymentNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() => const PaymentState();

  // ── Create PaymentIntent ──────────────────────────────────────────────────

  /// Creates a Stripe PaymentIntent for [amount] (in MXN).
  ///
  /// In simulated mode: generates a fake `pi_test_{timestamp}` ID after a
  /// short delay. In real mode: calls the `createPaymentIntent` Firebase
  /// Function (requires Blaze plan + deployed function).
  Future<void> createPaymentIntent(double amount, String orderId) async {
    state = const PaymentState(isLoading: true);
    try {
      if (StripeConstants.useSimulatedPayment) {
        // Simulate network delay.
        await Future.delayed(const Duration(milliseconds: 800));
        final piId =
            'pi_test_${DateTime.now().millisecondsSinceEpoch}';
        state = PaymentState(
          clientSecret: 'simulated_$piId',
          paymentIntentId: piId,
        );
      } else {
        // TODO(etapa-6): Enable when Firebase Blaze plan is available.
        // import 'package:cloud_functions/cloud_functions.dart';
        // final callable = FirebaseFunctions.instance
        //     .httpsCallable('createPaymentIntent');
        // final result = await callable.call({
        //   'amount': amount,
        //   'currency': 'mxn',
        //   'orderId': orderId,
        // });
        // state = PaymentState(
        //   clientSecret: result.data['clientSecret'] as String,
        //   paymentIntentId: result.data['paymentIntentId'] as String,
        // );
        throw UnimplementedError(
            'Real Stripe requires useSimulatedPayment = false '
            'AND a deployed Firebase Function.');
      }
    } catch (e) {
      state = PaymentState(error: e.toString());
    }
  }

  // ── Confirm payment ───────────────────────────────────────────────────────

  /// Confirms the payment using [details].
  ///
  /// In simulated mode: approves cards starting with `4242`, rejects others.
  /// In real mode: uses flutter_stripe to confirm via [clientSecret].
  Future<void> confirmPayment(
    CardDetails details,
    String clientSecret,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Simulate processing time.
      await Future.delayed(const Duration(milliseconds: 1500));

      if (StripeConstants.useSimulatedPayment) {
        final clean = details.number.replaceAll(' ', '');
        if (!clean.startsWith('4242')) {
          throw Exception(
              'Tarjeta rechazada. '
              'En modo de prueba usa 4242 4242 4242 4242.');
        }
        state = state.copyWith(isLoading: false, success: true);
      } else {
        // TODO(etapa-6): Enable when flutter_stripe is configured.
        // await Stripe.instance.confirmPayment(
        //   paymentIntentClientSecret: clientSecret,
        //   data: PaymentMethodParams.card(
        //     paymentMethodData: PaymentMethodData(
        //       billingDetails: BillingDetails(name: details.holderName),
        //     ),
        //   ),
        // );
        // state = state.copyWith(isLoading: false, success: true);
        throw UnimplementedError(
            'Real Stripe requires useSimulatedPayment = false.');
      }
    } catch (e) {
      state =
          state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() => state = const PaymentState();
}

// ── Providers ──────────────────────────────────────────────────────────────

final paymentProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

/// Stores the Firestore document ID of the just-confirmed order so that
/// [OrderConfirmedPage] can display it without route params.
final confirmedOrderIdProvider = StateProvider<String?>((ref) => null);
