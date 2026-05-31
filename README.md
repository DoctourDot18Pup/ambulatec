# AmbulaTec

> Marketplace de comida y productos entre estudiantes del **TecNM Celaya**.  
> Vendedores publican ofertas con countdown, compradores pagan y coordinan la entrega vía chat efímero.

**Stack:** Flutter 3.38 · Firebase · Stripe (simulado) · Cloudinary · Riverpod · Go Router  
**Plataformas:** Web (Chrome/PWA) · Android · iOS  
**Idioma:** Español (es-MX)

---

## Índice

1. [Características](#características)
2. [Arquitectura](#arquitectura)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Flujo de una orden](#flujo-de-una-orden)
5. [Rutas](#rutas)
6. [Configuración inicial](#configuración-inicial)
7. [Variables de configuración](#variables-de-configuración)
8. [Ejecutar la app](#ejecutar-la-app)
9. [Índices de Firestore](#índices-de-firestore)
10. [Roles y permisos](#roles-y-permisos)
11. [Notificaciones](#notificaciones)
12. [Pagos con Stripe](#pagos-con-stripe)
13. [Cloudinary (imágenes)](#cloudinary-imágenes)
14. [Widgets compartidos](#widgets-compartidos)
15. [Tema visual](#tema-visual)
16. [Seguridad y archivos sensibles](#seguridad-y-archivos-sensibles)
17. [Comandos de referencia](#comandos-de-referencia)

---

## Características

### Compradores
| Feature | Descripción |
|---|---|
| **Feed** | Listado de publicaciones activas filtrado por categoría (Comida / Bebidas / Postres / Snacks / Otros) |
| **Seguir vendedores** | Chip "Siguiendo" en las cards y toggle en el perfil público del vendedor |
| **Detalle de post** | Galería de imágenes, precio con/sin oferta, countdown de oferta, botón de compra |
| **Checkout** | Resumen de orden con imagen de entrega opcional, nota de ubicación |
| **Pago Stripe** | Formulario de tarjeta simulado; `4242 4242 4242 4242` = aprobado |
| **Chat con vendedor** | Mensajes en tiempo real durante 24 horas tras la confirmación |
| **Historial de órdenes** | Tabs Activas / Historial; tarjeta con estado y acciones contextuales |
| **Detalle de orden** | Imagen del producto, timeline de estados, nota de entrega, botón "Ir al chat" / "Dejar reseña" |
| **Reseñas** | 1–5 estrellas + etiquetas rápidas (Puntual, Amable…) + comentario opcional |
| **Búsqueda** | Debounce 300 ms, prefijo en título de post y nombre de vendedor, grid de categorías |
| **Perfil** | Foto de Google, historial de compras, opciones de cuenta |

### Vendedores
| Feature | Descripción |
|---|---|
| **Dashboard** | Stats (ganancias hoy / órdenes hoy / posts activos), gráfico semanal fl_chart, lista de órdenes recientes |
| **Crear publicación** | Título, descripción, precio, categoría, hasta 3 imágenes Cloudinary, oferta con duración configurable (15/30/60 min) |
| **Alerta de nueva orden** | Banner in-app con countdown de 10 min para aceptar/rechazar |
| **Gestión de órdenes** | Tabs Todas / Pendientes / Entregadas; detalle con botones Confirmar / Rechazar / Marcar entregado |
| **Chat con comprador** | Chat en tiempo real; botón "Marcar como entregado" cuando la orden está confirmada |
| **Ganancias** | Tabs Hoy / Semana / Mes; gráfico de línea semanal; % de cambio vs período anterior |
| **Disponibilidad** | Toggle Activo / En espera / Offline persistido en Firestore |
| **Perfil público** | Visible para compradores en `/vendor/:id`; muestra posts activos y reseñas |

### Admin
| Feature | Descripción |
|---|---|
| **Panel de aprobación** | Lista de vendedores `status == pending`; botones Aprobar / Rechazar con diálogo de confirmación |
| **Acceso restringido** | Guard en GoRouter: solo usuarios con `isAdmin: true` en Firestore acceden a `/admin` |

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                       Flutter App                       │
│                                                         │
│  Presentation ──► Providers (Riverpod) ──► Data layer  │
│                                                         │
│  • ConsumerWidget / ConsumerStatefulWidget              │
│  • No setState() en ningún archivo nuevo               │
│  • AsyncValue.guard() para mutaciones                   │
│  • autoDispose en providers de página                   │
└──────────────┬──────────────────────────┬───────────────┘
               │                          │
        ┌──────▼──────┐           ┌───────▼──────┐
        │  Firestore  │           │  Cloudinary  │
        │  Auth       │           │  (imágenes)  │
        │  Messaging  │           └──────────────┘
        │  Storage    │
        └─────────────┘
```

**Decisiones técnicas destacadas:**
- **Riverpod 2.x**: `StreamProvider` para datos en tiempo real, `FutureProvider.autoDispose` para búsqueda con debounce, `NotifierProvider` para controladores con estado
- **GoRouter + RouterNotifier**: redirect reactivo según auth + rol + onboarding; guard de admin
- **AdaptiveScaffold**: BottomNav < 1024 px / sidebar 240 px ≥ 1024 px; misma lógica de navegación en ambos
- **Firestore in-app notifications**: campo `recipientId` unifica vendedor (`new_order`) y comprador (`order_delivered`) en una sola colección; sin Blaze plan requerido
- **Debounce de búsqueda**: `FutureProvider.autoDispose` + `await Future.delayed(300ms)` — Riverpod recrea el provider cuando cambia la query, cancelando la petición anterior

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # Colecciones, Cloudinary, FCM VAPID, timeouts
│   │   └── stripe_constants.dart     # Publishable key, modo simulado
│   ├── router/
│   │   └── app_router.dart           # GoRouter + RouterNotifier (redirect logic)
│   ├── services/
│   │   └── notification_service.dart # FCM init (web VAPID / Android nativo)
│   └── theme/
│       ├── app_colors.dart           # Design tokens (bgPrimary, accentGold, etc.)
│       ├── app_text_styles.dart      # Escala tipográfica con Google Fonts Inter
│       └── app_theme.dart            # ThemeData oscuro
│
├── features/
│   ├── admin/
│   │   ├── presentation/admin_page.dart
│   │   └── providers/pending_vendors_provider.dart
│   │
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_controller.dart  # Google Sign-In, setVendorAvailability
│   │   │   ├── auth_provider.dart    # authStateProvider (Firebase Auth stream)
│   │   │   └── user_provider.dart    # userProvider (Firestore doc stream)
│   │   ├── domain/
│   │   │   ├── user_model.dart       # roles, vendorStatus, vendorRating, isAdmin
│   │   │   └── vendor_verification_data.dart
│   │   └── presentation/
│   │       ├── login_page.dart
│   │       ├── onboarding_page.dart
│   │       └── role_select_page.dart
│   │
│   ├── chat/
│   │   ├── domain/message_model.dart
│   │   ├── presentation/chat_page.dart  # Mensajes RT + ExpiryBar + DeliverButton
│   │   └── providers/
│   │       ├── chat_controller.dart     # sendMessage, confirmOrder, rejectOrder, markDelivered
│   │       └── chat_provider.dart       # chatMessagesProvider, orderByIdProvider, countdownProvider
│   │
│   ├── feed/
│   │   ├── data/
│   │   │   ├── category_filter_provider.dart
│   │   │   ├── filtered_posts_provider.dart
│   │   │   ├── follow_controller.dart   # toggleFollow (Firestore subcollection)
│   │   │   └── following_provider.dart
│   │   ├── domain/
│   │   │   ├── follow_model.dart
│   │   │   └── post_model.dart          # OfferType, VendorAvailability, offerBadgeText
│   │   ├── presentation/
│   │   │   ├── home_page.dart           # Grid responsivo + filtros de categoría
│   │   │   ├── post_detail_page.dart    # Galería, countdown oferta, flujo de compra
│   │   │   ├── search_page.dart         # TextField autofocus, grid de categorías, resultados
│   │   │   └── widgets/post_card.dart   # Thumbnail, oferta badge, status dot, "Siguiendo"
│   │   └── providers/search_provider.dart  # searchQueryProvider, searchResultsProvider, activeVendorsProvider
│   │
│   ├── orders/
│   │   ├── domain/order_model.dart      # OrderStatus enum, chatExpiresAt
│   │   ├── presentation/
│   │   │   ├── order_alert_page.dart    # Alerta de nueva orden (countdown 10 min)
│   │   │   ├── order_confirmed_page.dart
│   │   │   ├── order_detail_page.dart   # Imagen + timeline + acciones por rol/estado
│   │   │   ├── order_summary_page.dart
│   │   │   ├── orders_page.dart         # Tabs Activas/Historial (buyer) o Todas/Pendientes/Entregadas (vendor)
│   │   │   ├── payment_page.dart        # Formulario Stripe
│   │   │   └── review_page.dart         # Estrellas + etiquetas + comentario
│   │   └── providers/
│   │       ├── buyer_orders_provider.dart
│   │       ├── current_order_provider.dart  # Draft para el checkout
│   │       ├── orders_provider.dart          # Auto-switch vendor/buyer según rol
│   │       ├── payment_provider.dart
│   │       └── pending_notifications_provider.dart
│   │
│   ├── profile/
│   │   ├── domain/review_model.dart
│   │   ├── presentation/
│   │   │   ├── profile_page.dart         # Perfil propio (stats, posts, opciones)
│   │   │   └── vendor_profile_page.dart  # Perfil público (posts activos + reseñas + seguir)
│   │   └── providers/
│   │       ├── profile_provider.dart
│   │       ├── review_controller.dart    # submitReview + recalculo de rating
│   │       └── vendor_reviews_provider.dart
│   │
│   └── vendor/
│       ├── presentation/
│       │   ├── create_post_page.dart     # Formulario + upload Cloudinary + oferta
│       │   ├── dashboard_page.dart       # Stats + fl_chart + órdenes recientes
│       │   ├── earnings_page.dart        # Tabs Hoy/Semana/Mes + gráfico de línea
│       │   └── vendor_verify_page.dart
│       └── providers/
│           ├── earnings_provider.dart    # DayEarnings, EarningsData, % cambio
│           ├── vendor_posts_provider.dart
│           └── vendor_stats_provider.dart
│
└── shared/
    └── widgets/
        ├── adaptive_scaffold.dart        # BottomNav (< 1024) / Sidebar (≥ 1024)
        ├── animated_counter_widget.dart  # TweenAnimationBuilder 0 → value (800 ms)
        ├── countdown_chip_widget.dart    # StreamBuilder sobre Stream.periodic (1 s)
        ├── empty_state_widget.dart       # Icono + título + subtítulo + acción opcional
        ├── notification_banner.dart      # OverlayEntry con slide + auto-dismiss 5 s
        ├── rating_stars_widget.dart      # Display (decimal) + Selection (tappable + AnimatedScale)
        └── status_dot_widget.dart        # Dot animado (pulse) para 'active' / estático para 'busy'/'offline'
```

---

## Flujo de una orden

```
COMPRADOR                            VENDEDOR
─────────                            ────────
[Feed] → toca post
[Detalle post]
  └─ "Comprar" ──────────────────► Notificación in-app
[Resumen + nota de entrega]         [/order-alert/:id]
[Pago Stripe] ──────────────────►   Countdown 10 min
[Orden confirmada]                   Acepta ─────────────────────► status: confirmed
                                     Rechaza ────────────────────► status: rejected
                                                                         │
                                                                         ▼
                                                               [Chat activo 24 h]
                                                               Ambos pueden escribir
                                                                         │
COMPRADOR recibe mensaje ◄──────────────────────────────────────────────┘
                                                               Vendedor marca entregado
                                                               [Detalle orden] o [Chat]
                                                                         │
COMPRADOR recibe notificación ◄──────────────────────────────────────────┘
  └─ "Dejar reseña" ──────────────► reseña guardada
                                     rating de vendedor actualizado
```

---

## Rutas

| Ruta | Página | Acceso |
|---|---|---|
| `/` | Redirect a `/onboarding` | — |
| `/onboarding` | Presentación | Público |
| `/login` | Google Sign-In | Público |
| `/role-select` | Elegir rol | Auth |
| `/vendor-verify` | Verificación de vendedor | Auth |
| `/home` | Feed de publicaciones | Auth |
| `/search` | Búsqueda | Auth |
| `/orders` | Mis pedidos / mis ventas | Auth |
| `/profile` | Perfil propio | Auth |
| `/dashboard` | Dashboard de vendedor | Vendedor |
| `/earnings` | Ganancias | Vendedor |
| `/create-post` | Nueva publicación | Vendedor |
| `/post/:postId` | Detalle de publicación | Auth |
| `/vendor/:vendorId` | Perfil público del vendedor | Auth |
| `/order-summary` | Resumen antes de pagar | Auth |
| `/payment` | Formulario de pago Stripe | Auth |
| `/order-confirmed` | Confirmación post-pago | Auth |
| `/order-detail/:orderId` | Detalle + acciones de orden | Auth |
| `/chat/:orderId` | Chat comprador ↔ vendedor | Auth |
| `/order-alert/:orderId` | Alerta de nueva orden | Vendedor |
| `/review/:orderId` | Dejar reseña | Comprador |
| `/admin` | Panel de aprobación | Admin |

---

## Configuración inicial

### 1. Prerrequisitos

```bash
flutter --version   # ≥ 3.38.8 stable
dart --version      # ≥ 3.10.7
```

### 2. Clonar y obtener dependencias

```bash
git clone <repo-url>
cd ambulatec
flutter pub get
```

### 3. Firebase

El proyecto ya está configurado con `flutterfire`. Si necesitas reconfigurar:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=ambulatec-6d892
```

Esto regenera `lib/firebase_options.dart` y `android/app/google-services.json`.

### 4. Android — SHA-1 para Google Sign-In

Para que **Google Sign-In funcione en Android**, el SHA-1 del keystore debe estar registrado en Firebase Console:

```bash
# SHA-1 del keystore debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Ir a **Firebase Console → Project Settings → Android app → Agregar huella digital**.

---

## Variables de configuración

### `lib/core/constants/app_constants.dart`

```dart
// Cloudinary
static const String cloudinaryCloudName = 'dpjozkpnr';
static const String cloudinaryUploadPreset = 'ambulatec_uploads';

// FCM Web Push VAPID key
// Firebase Console → Project Settings → Cloud Messaging → Web push certificates
static const String fcmVapidKey = '<tu-vapid-key>';

// Timeouts
static const int orderConfirmationTimeoutMinutes = 10;
static const int chatExpirationHours = 24;
```

### `lib/core/constants/stripe_constants.dart`

```dart
// Stripe (modo simulado activo por defecto)
static const String publishableKey = 'pk_test_...';
static const bool useSimulatedPayment = true;
```

---

## Ejecutar la app

```bash
# ── Desarrollo ─────────────────────────────────────────────────
flutter run -d chrome --web-port=8080     # Web

flutter run -d android                    # Android (con USB debugging o emulador)

flutter emulators --launch <id>           # Iniciar emulador AVD (necesita Google APIs)
flutter run -d emulator-5554             # Correr en emulador específico

# ── Builds ─────────────────────────────────────────────────────
flutter build web --release              # Web optimizado → build/web/
flutter build apk --debug               # APK debug → build/app/outputs/flutter-apk/
flutter build apk --release             # APK release (requiere signing config)

# ── Calidad ────────────────────────────────────────────────────
flutter analyze                          # Análisis estático (0 issues)
flutter test                             # Tests unitarios
```

> **Tip Android:** Para FCM en Android se necesita un dispositivo físico o un emulador AVD con imagen **"Google APIs"** (no "Google Play"). Los emuladores estándar no tienen Play Services.

---

## Índices de Firestore

Todos los índices están en estado **Habilitado**. Si necesitas recrearlos:

| Colección | Campo 1 | Campo 2 | Campo 3 |
|---|---|---|---|
| `posts` | `isActive` ASC | `createdAt` DESC | — |
| `orders` | `vendorId` ASC | `createdAt` DESC | — |
| `orders` | `buyerId` ASC | `createdAt` DESC | — |
| `orders` | `vendorId` ASC | `status` ASC | `createdAt` DESC |
| `notifications` | `recipientId` ASC | `status` ASC | `createdAt` DESC |
| `reviews` | `vendorId` ASC | `createdAt` DESC | — |
| `users` | `vendorStatus` ASC | `createdAt` DESC | — |

Para crear un índice: **Firebase Console → Firestore → Índices → Agregar índice compuesto**.

---

## Roles y permisos

### Asignar rol admin

En **Firebase Console → Firestore → `users` → documento del usuario**, agregar:

```json
{
  "isAdmin": true
}
```

El guard en `RouterNotifier.redirect` redirige a `/home` si `isAdmin != true` al intentar acceder a `/admin`.

### Flujo de registro de vendedor

1. Usuario crea cuenta → selecciona rol "Vendedor" en `/role-select`
2. Completa formulario de verificación (credencial / foto) en `/vendor-verify`
3. `vendorStatus` queda en `pending`
4. Admin aprueba desde `/admin` → `vendorStatus = approved`, `roles` incluye `'vendor'`
5. Router redirige automáticamente a `/dashboard`

---

## Notificaciones

### In-app banners (sin Blaze plan)

Toda la mensajería in-app funciona a través de la colección `notifications` de Firestore:

```
notifications/{id}
  recipientId: string   ← UID del destinatario
  type: 'new_order' | 'order_delivered'
  orderId: string
  status: 'unread' | 'read'
  createdAt: timestamp
```

El `_NotificationWrapper` en `main.dart` escucha esta colección y muestra el banner con `OverlayEntry`. El banner se auto-descarta a los 5 segundos.

### FCM push (opcional, requiere Blaze plan)

| Plataforma | Mecanismo | Requisito |
|---|---|---|
| Web | Token con VAPID key | Blaze plan + servidor para enviar |
| Android | Token nativo | Google Play Services |
| iOS | Token nativo | APNs certificate |

El token FCM se imprime en consola debug al iniciar la app:
```
[FCM] Token (native): <token>
```

---

## Pagos con Stripe

### Modo simulado (por defecto)

`useSimulatedPayment = true` en `stripe_constants.dart` omite la llamada a Stripe y a Firebase Functions. El pago siempre es exitoso con cualquier tarjeta válida.

**Tarjetas de prueba:**
| Resultado | Número |
|---|---|
| Aprobada | `4242 4242 4242 4242` |
| Rechazada | `4000 0000 0000 0002` |
| Fondos insuficientes | `4000 0000 0000 9995` |

Fecha de expiración: cualquier fecha futura. CVC: cualquier 3 dígitos.

### Activar pagos reales

1. Cambiar `useSimulatedPayment = false`
2. Colocar el `publishableKey` real de [dashboard.stripe.com](https://dashboard.stripe.com)
3. Desplegar la Firebase Function en `functions/index.js` (requiere Blaze plan)
4. La Function crea el `PaymentIntent` en el servidor y devuelve el `clientSecret`

---

## Cloudinary (imágenes)

Las imágenes se suben directamente desde el cliente a Cloudinary usando **unsigned upload**:

```
Cloud name:    dpjozkpnr
Upload preset: ambulatec_uploads  (modo unsigned)
```

Se usa en:
- **Publicaciones**: hasta 3 imágenes del producto (`post_images/`)
- **Verificación de vendedor**: credencial de estudiante (`vendor_ids/`)
- **Nota de entrega**: foto opcional de ubicación (inline en OrderSummary)

---

## Widgets compartidos

| Widget | Ubicación | Uso |
|---|---|---|
| `AdaptiveScaffold` | `shared/widgets/` | Wrapper principal con nav. Recibe `currentIndex: 0–4` |
| `AnimatedCounterWidget` | `shared/widgets/` | Anima un número de 0 → value en 800 ms |
| `CountdownChipWidget` | `shared/widgets/` | Cuenta regresiva via `Stream.periodic(1s)` |
| `EmptyStateWidget` | `shared/widgets/` | Estado vacío: icono + título + subtítulo + acción |
| `NotificationBanner` | `shared/widgets/` | Slide-in banner sobre `OverlayEntry`, auto-dismiss 5 s |
| `RatingStarsWidget` | `shared/widgets/` | Modo display (decimales) o selección (tappable) |
| `StatusDotWidget` | `shared/widgets/` | Dot animado pulsante para `active`, estático para otros |

---

## Tema visual

```dart
// Paleta de colores
AppColors.bgPrimary    = #0A0F0A  // Fondo principal
AppColors.bgSurface    = #111A11  // AppBar, nav
AppColors.bgCard       = #1C2B1C  // Cards, inputs
AppColors.accentGold   = #C9A96E  // Acento primario, precios, tabs
AppColors.accentGreen  = #2D6A4F  // Avatares, burbujas de chat propio
AppColors.textPrimary  = #F0EDE6  // Texto principal
AppColors.textSecondary= #8A9E8A  // Texto secundario, hints
AppColors.success      = #4CAF78  // Confirmado, entregado
AppColors.error        = #E05C5C  // Rechazado, countdown urgente
AppColors.borderOverlay= rgba(255,255,255,0.06) // Bordes sutiles

// Tipografía
// Google Fonts Inter — h1(28/700) h2(22/600) h3(18/600) body(15/400) caption(12/500)
```

Breakpoint de layout: **1024 px** — por debajo BottomNav, por encima sidebar de 240 px.

---

## Seguridad y archivos sensibles

Los siguientes archivos contienen claves y **no deben subirse a git**:

```
android/app/google-services.json    # → ya en android/.gitignore
ios/Runner/GoogleService-Info.plist  # → para cuando se configure iOS
lib/firebase_options.dart           # → generado por flutterfire
```

La clave VAPID y las claves de Stripe en `app_constants.dart` / `stripe_constants.dart` son **claves de prueba** (prefijo `pk_test_`). En producción, moverlas a variables de entorno o a un servidor seguro.

---

## Comandos de referencia

```bash
# Análisis y compilación
flutter analyze                          # debe retornar "No issues found!"
flutter build web --release              # → build/web/
flutter build apk --debug               # → build/app/outputs/flutter-apk/app-debug.apk

# Firebase
flutterfire configure                   # Reconfigurar Firebase
firebase deploy --only firestore:rules  # Desplegar reglas de seguridad
firebase deploy --only functions        # Desplegar Cloud Functions (Blaze)

# Dependencias
flutter pub get                         # Instalar dependencias
flutter pub upgrade --major-versions    # Actualizar a versiones mayores
flutter pub outdated                    # Ver paquetes desactualizados
```

---

## Dependencias principales

| Paquete | Versión | Uso |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `go_router` | ^15.1.2 | Navegación declarativa + guards |
| `firebase_core` | — | Inicialización Firebase |
| `cloud_firestore` | — | Base de datos en tiempo real |
| `firebase_auth` | — | Autenticación Google |
| `firebase_messaging` | — | FCM push notifications |
| `flutter_stripe` | ^12.6.0 | Formulario de pago |
| `fl_chart` | ^0.69.0 | Gráficos de ganancias |
| `cached_network_image` | — | Imágenes con caché |
| `google_fonts` | — | Inter font |
| `image_picker` | — | Cámara / galería |
| `http` | — | Upload a Cloudinary |

---

*Desarrollado para el proyecto integrador de TecNM Celaya.*
