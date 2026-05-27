/// Stripe integration constants.
///
/// To enable real Stripe payments:
///   1. Set [publishableKey] to your Stripe test/live publishable key.
///   2. Set [useSimulatedPayment] to `false`.
///   3. Deploy the Firebase Function in `functions/index.js`.
///      (Requires Firebase Blaze plan for external network calls.)
class StripeConstants {
  StripeConstants._();

  /// Stripe publishable key (test mode).
  /// REPLACE with your real key from dashboard.stripe.com
  static const String publishableKey = 'pk_test_51RWYXZEHMOpPkWN3fzhI594A4zNvBxYRHKwtA3UYjtb6pDxiWiLNLS5IHK9KSEVYPuV0vfjpssCF8laCTSdoXylz00oDLe69w9';

  /// When `true`, the payment flow is fully simulated — no real Stripe or
  /// Firebase Function calls are made. Use this during development or when
  /// the Blaze plan is not available.
  ///
  /// Test cards:
  ///   - Approved:  4242 4242 4242 4242
  ///   - Rejected:  any number not starting with 4242
  static const bool useSimulatedPayment = true;
}
