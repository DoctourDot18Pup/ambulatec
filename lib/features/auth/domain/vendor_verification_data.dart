/// Data required to submit a vendor verification request.
///
/// [idFrontPath] and [idBackPath] are local file paths (or blob URLs on web)
/// obtained from [image_picker] before uploading to Firebase Storage.
class VendorVerificationData {
  final String fullName;
  final String career;
  final String controlNumber;
  final String idFrontPath;
  final String idBackPath;

  const VendorVerificationData({
    required this.fullName,
    required this.career,
    required this.controlNumber,
    required this.idFrontPath,
    required this.idBackPath,
  });
}
