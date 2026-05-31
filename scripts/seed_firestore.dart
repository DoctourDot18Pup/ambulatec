// ignore_for_file: avoid_print
/// Seed script — inserts 4 sample posts into Firestore.
///
/// Run with:
///   flutter run -t scripts/seed_firestore.dart -d chrome
///
/// (or any connected device / emulator)
library;

import 'package:ambulatec/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final col = firestore.collection('posts');
  final now = DateTime.now();

  final posts = [
    // ── 1. Sandwich 2×1 (30 min) ───────────────────────────────────────
    {
      'vendorId': 'seed_vendor_1',
      'vendorName': 'Mariana López',
      'vendorCareer': 'Ing. Sistemas',
      'vendorPhotoUrl': null,
      'vendorStatus': 'active',
      'title': 'Sandwich de jamón y queso',
      'description':
          'Sandwich fresco hecho al momento con pan integral, jamón, queso '
          'manchego, lechuga y jitomate. ¡Perfecto para el receso!',
      'mediaUrls': [
        'https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800&q=80',
      ],
      'category': 'comida',
      'price': 35.0,
      'originalPrice': 70.0,
      'hasOffer': true,
      'offerType': 'twoForOne',
      'discountPercent': null,
      'offerExpiresAt':
          Timestamp.fromDate(now.add(const Duration(minutes: 30))),
      'createdAt': Timestamp.fromDate(now),
      'isActive': true,
    },

    // ── 2. Gelatina (sin oferta) ───────────────────────────────────────
    {
      'vendorId': 'seed_vendor_2',
      'vendorName': 'Carlos Ramírez',
      'vendorCareer': 'Ing. Industrial',
      'vendorPhotoUrl': null,
      'vendorStatus': 'active',
      'title': 'Gelatina de frutas',
      'description':
          'Gelatina de sabores con trozos de fruta natural. Disponible en '
          'fresa, mango y piña. Sin conservadores.',
      'mediaUrls': [
        'https://images.unsplash.com/photo-1571942676516-bcab84649e44?w=800&q=80',
      ],
      'category': 'postres',
      'price': 20.0,
      'originalPrice': null,
      'hasOffer': false,
      'offerType': null,
      'discountPercent': null,
      'offerExpiresAt': null,
      'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
      'isActive': true,
    },

    // ── 3. Café -40% (20 min) ─────────────────────────────────────────
    {
      'vendorId': 'seed_vendor_3',
      'vendorName': 'Sofía Hernández',
      'vendorCareer': 'Ing. Bioquímica',
      'vendorPhotoUrl': null,
      'vendorStatus': 'busy',
      'title': 'Café de olla',
      'description':
          'Café de olla tradicional con canela y piloncillo. Caliente y listo '
          'para llevar en vaso térmico de 16 oz.',
      'mediaUrls': [
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&q=80',
      ],
      'category': 'bebidas',
      'price': 18.0,
      'originalPrice': 30.0,
      'hasOffer': true,
      'offerType': 'percent',
      'discountPercent': 40,
      'offerExpiresAt':
          Timestamp.fromDate(now.add(const Duration(minutes: 20))),
      'createdAt':
          Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
      'isActive': true,
    },

    // ── 4. Brownies (sin oferta) ──────────────────────────────────────
    {
      'vendorId': 'seed_vendor_4',
      'vendorName': 'Diego Morales',
      'vendorCareer': 'Ing. Mecatrónica',
      'vendorPhotoUrl': null,
      'vendorStatus': 'active',
      'title': 'Brownies de chocolate',
      'description':
          'Brownies caseros de chocolate semi-amargo, esponjosos por dentro '
          'y con costra crujiente. Pieza individual o pack de 3.',
      'mediaUrls': [
        'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=800&q=80',
      ],
      'category': 'postres',
      'price': 25.0,
      'originalPrice': null,
      'hasOffer': false,
      'offerType': null,
      'discountPercent': null,
      'offerExpiresAt': null,
      'createdAt':
          Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
      'isActive': true,
    },
  ];

  print('Seeding ${posts.length} posts...');
  for (final post in posts) {
    final ref = await col.add(post);
    print('  - ${post['title']} -> ${ref.id}');
  }
  print('Done!');

  runApp(const _SeedDoneApp());
}

class _SeedDoneApp extends StatelessWidget {
  const _SeedDoneApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0A0F0A),
        body: Center(
          child: Text(
            'Seed completado',
            style: TextStyle(color: Color(0xFFC9A96E), fontSize: 24),
          ),
        ),
      ),
    );
  }
}
