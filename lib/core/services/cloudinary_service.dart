import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

// ── Exception ──────────────────────────────────────────────────────────────

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}

// ── Service ────────────────────────────────────────────────────────────────

class CloudinaryService {
  final Dio _dio;

  CloudinaryService() : _dio = Dio();

  /// Uploads [imageBytes] to Cloudinary under [folder] and returns the
  /// `secure_url` of the uploaded image.
  ///
  /// Throws [CloudinaryUploadException] on failure.
  Future<String> uploadImage(Uint8List imageBytes, String folder) async {
    try {
      final formData = FormData.fromMap({
        'upload_preset': AppConstants.cloudinaryUploadPreset,
        'folder': folder,
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dio.post(
        AppConstants.cloudinaryUploadUrl,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.statusCode != 200) {
        throw CloudinaryUploadException(
            'Status ${response.statusCode}: ${response.data}');
      }

      final secureUrl = response.data['secure_url'] as String?;
      if (secureUrl == null) {
        throw const CloudinaryUploadException(
            'No se recibió secure_url de Cloudinary.');
      }

      return secureUrl;
    } on DioException catch (e) {
      final serverMsg =
          e.response?.data?['error']?['message'] as String? ??
              e.message ??
              'Error de red';
      throw CloudinaryUploadException(serverMsg);
    }
  }
}
