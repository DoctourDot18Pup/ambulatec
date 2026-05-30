# Guía de pruebas — AmbulaTec

Documento de referencia para verificar el funcionamiento correcto de todas las funcionalidades de la aplicación antes de cada release.

---

## Preparación previa

### Cuentas necesarias

Crea **4 cuentas de Google distintas** y configura sus documentos en `Firestore → users → {uid}`:

| Cuenta | Rol | Campos requeridos en Firestore |
|--------|-----|-------------------------------|
| `admin@...` | Admin + Vendedor aprobado | `isAdmin: true`, `roles: ['vendor']`, `vendorStatus: 'approved'` |
| `vendor1@...` | Vendedor aprobado | `roles: ['vendor']`, `vendorStatus: 'approved'` |
| `vendor2@...` | Vendedor pendiente | `roles: ['vendor']`, `vendorStatus: 'pending'` |
| `buyer@...` | Comprador | `roles: ['buyer']` |

### Tarjeta de prueba (Stripe modo simulado)

| Campo | Valor |
|-------|-------|
| Número | `4242 4242 4242 4242` |
| Fecha | Cualquier fecha futura |
| CVC | Cualquier número de 3 dígitos |
| CP | Cualquier código postal |

> La app usa `useSimulatedPayment = true`; no se realizan cargos reales.

---

## Prueba 1 — Onboarding y autenticación

### 1.1 Primera apertura (dispositivo limpio)
1. Abre la app → deben aparecer las pantallas de **Onboarding** (slides introductorios).
2. Navega hasta el final → presiona "Comenzar" → redirige a `/login`.
3. Inicia sesión con Google (`buyer@...`).
4. Como es cuenta nueva sin roles → redirige a `/role-select`.
5. Selecciona "Comprador" → redirige a `/home`.

**Resultado esperado:** el flujo completo de primera vez funciona sin errores.

### 1.2 Segunda apertura
1. Cierra la app completamente y vuelve a abrirla.
2. Debe ir **directamente a `/login`**, sin mostrar el Onboarding.

**Resultado esperado:** el flag `onboarding_seen` en `SharedPreferences` persiste entre sesiones.

### 1.3 Sesión activa
1. Con sesión iniciada, cierra y reabre la app.
2. Debe ir **directamente a `/home`** sin pedir login.

### 1.4 Inicio de sesión en Web (Chrome)
> Aplica solo al ejecutar la app en el navegador (`flutter run -d chrome --web-port 8080`).

1. En `/login` debe aparecer el **botón oficial de Google** (renderizado por el SDK de Google Identity Services), no un botón personalizado.
2. Presiona el botón → aparece el selector de cuentas de Google.
3. Selecciona la cuenta → el indicador de carga reemplaza al botón **durante toda la carga** (mientras Firebase Auth y Firestore sincronizan).
4. Una vez completado, redirige a `/home` o `/role-select` sin que el botón de Google vuelva a aparecer.
5. **Prueba de segundo intento:** cierra sesión y vuelve a iniciar sesión → no debe aparecer el error `Bad state: init() has already been called`.

**Resultado esperado:** flujo web completo sin errores de doble inicialización ni flash del botón de login.

---

## Prueba 2 — Guards del router

Verifica que las redirecciones de seguridad funcionen correctamente:

| Escenario | Resultado esperado |
|-----------|-------------------|
| Sin sesión → intenta acceder a `/home` | Redirige a `/onboarding` o `/login` |
| `vendor2` (pendiente) → intenta ir a `/dashboard` | Redirige a `/vendor-verify` |
| `buyer` → intenta acceder a `/admin` manualmente | Redirige a `/home` |
| `admin` → accede a `/admin` | Muestra el panel correctamente |
| Usuario con sesión activa → intenta ir a `/login` | Redirige a `/home` o `/dashboard` según rol |
| Usuario sin roles → intenta ir a `/home` | Redirige a `/role-select` |

---

## Prueba 3 — Registro y aprobación de vendedor

### 3.1 Vendedor pendiente ve pantalla de espera
1. Inicia sesión con `vendor2@...`.
2. La app debe mostrar `/vendor-verify` con el mensaje de solicitud en revisión.
3. Cualquier intento de navegar a otra ruta debe redirigir de vuelta a `/vendor-verify`.

### 3.2 Admin aprueba al vendedor
1. Con la cuenta `admin@...`, navega a `/admin`.
2. `vendor2` aparece en la lista de vendedores pendientes.
3. Presiona **Aprobar**.
4. Regresa a la sesión de `vendor2`.
5. La app debe redirigir automáticamente al `/dashboard` (sin reiniciar sesión).

### 3.3 Admin rechaza a un vendedor
1. Crea una quinta cuenta y regístrala como vendedor (quedará en `pending`).
2. Desde `/admin`, presiona **Rechazar**.
3. El vendedor debe ver un mensaje de rechazo en `/vendor-verify`.

---

## Prueba 4 — Creación de publicación (Vendedor)

Con `vendor1@...` (aprobado):
1. Abre el `/dashboard` → presiona **"+ Nueva publicación"** → redirige a `/create-post`.
2. Completa: título, descripción, precio, categoría.
3. Sube una imagen desde la galería del dispositivo.
4. Presiona **Publicar**.

**Resultado esperado:**
- La publicación aparece en el feed de `/home` (comprobable con `buyer@...`).
- La imagen se sube correctamente a Cloudinary y se muestra en la tarjeta.

---

## Prueba 5 — Feed y búsqueda (Comprador)

Con `buyer@...`:

### 5.1 Feed principal
1. Abre `/home` → deben aparecer publicaciones de los vendedores aprobados.
2. Tap en una tarjeta → abre `/post/:id` con imagen, descripción, precio y botón **"Pedir"**.
3. Tap en el **nombre del vendedor** dentro de la tarjeta → abre `/vendor/:vendorId`.

### 5.2 Perfil público del vendedor
1. Verifica que se muestre: avatar, nombre, carrera, calificación (estrellas), estado (online/busy).
2. Presiona **Seguir** → el botón cambia a "Siguiendo". ⚠️ *Pendiente de implementar*
3. Presiona de nuevo → deja de seguir. ⚠️ *Pendiente de implementar*
4. La grilla de publicaciones activas del vendedor es visible.
5. Las reseñas aparecen debajo; presiona "Ver todas" → abre el modal con el listado completo.

> **Nota:** el botón de seguir no debe aparecer si el comprador visita su propio perfil de vendedor.

### 5.3 Búsqueda
1. Abre `/search`.
2. **Estado inicial** (sin texto): muestra la grilla de 6 categorías + lista horizontal de vendedores activos.
3. Escribe al menos 2 caracteres → aparecen resultados de posts y vendedores.
4. Tap en un resultado de post → navega a `/post/:id`.
5. Tap en un resultado de vendedor → navega a `/vendor/:vendorId`.
6. Borra el texto → vuelve al estado inicial.

---

## Prueba 6 — Flujo completo de orden

### Paso 1 — Comprador realiza el pedido
1. `buyer` abre un post → presiona **"Pedir"**.
2. En `/order-summary`: revisa producto, precio y escribe una nota de entrega.
3. Presiona **"Continuar al pago"** → `/payment`.
4. Ingresa la tarjeta de prueba y confirma.
5. Redirige a `/order-confirmed` con el número de orden.

### Paso 2 — Vendedor recibe y gestiona la orden

#### Opción A — Por notificación
6. `vendor1` recibe un **banner in-app** en la parte superior de la pantalla.
7. Tap en el banner → abre `/order-alert/:orderId` con los datos del pedido.
8. Dos acciones disponibles:
   - **Confirmar** → estado cambia a `confirmed`; abre el chat.
   - **Rechazar** → estado cambia a `rejected`; la orden termina.

#### Opción B — Desde el listado (si no vio la notificación)
6. `vendor1` navega a `/orders` → pestaña **"Pendientes"**.
7. Tap en la orden → `/order-detail/:orderId`.
8. Presiona **"Confirmar orden"** o **"Rechazar"** (con diálogo de confirmación).

### Paso 3 — Chat y entrega
9. Con la orden confirmada, ambos acceden a `/chat/:orderId`.
10. El chip de **cuenta atrás de 10 minutos** es visible en la parte superior.
11. Ambas partes pueden enviar mensajes de texto.
12. `vendor1` presiona **"Marcar como entregado"** → diálogo de confirmación → orden pasa a `delivered`.

### Paso 4 — Reseña del comprador
13. `buyer` recibe notificación de entrega.
14. Va a `/orders` → pestaña "Historial" → la orden aparece como **"Entregada"**.
15. Abre el detalle → botón **"Dejar reseña"** → `/review/:orderId`.
16. Selecciona de 1 a 5 estrellas y escribe un comentario → envía.
17. La reseña aparece en `/vendor/:vendorId` de `vendor1`.

---

## Prueba 7 — Página de órdenes

### Vista comprador (`buyer`)
| Pestaña | Órdenes esperadas |
|---------|------------------|
| Activas | `pending`, `confirmed` |
| Historial | `delivered`, `cancelled`, `rejected` |

### Vista vendedor (`vendor1`)
| Pestaña | Órdenes esperadas |
|---------|------------------|
| Todas | Todas las órdenes |
| Pendientes | `pending`, `confirmed` |
| Entregadas | `delivered` |

- Tap en cualquier tarjeta → `/order-detail/:orderId`.
- El detalle muestra: imagen del producto, timeline (Creado / Confirmado / Entregado), datos del comprador/vendedor y botones de acción según rol y estado.

---

## Prueba 8 — Dashboard y ganancias (Vendedor)

Con `vendor1` (con al menos una orden entregada):

### 8.1 Dashboard
1. Navega a `/dashboard`.
2. Verifica que los **stats** muestren valores correctos: órdenes activas, ganancias totales, pedidos pendientes.
3. La **gráfica semanal** muestra los puntos de ganancias por día.
4. Presiona **"Ver ganancias →"** → navega a `/earnings`.

### 8.2 Página de ganancias
1. Muestra la gráfica `fl_chart` con puntos interactivos por día.
2. El desglose semanal lista cada semana con su total.
3. Los valores coinciden con las órdenes entregadas registradas en Firestore.

---

## Prueba 9 — Perfil de usuario

Con cualquier cuenta:
1. Navega a `/profile`.
2. Presiona **"Cerrar sesión"** → redirige a `/login`.

### 9.1 Editar nombre ✅
1. Desde `/profile`, presiona **"Editar perfil"** → aparece el bottom sheet de edición.
2. Modifica el campo **Nombre completo**.
3. Presiona **"Guardar"** → el indicador de carga aparece mientras se guarda.
4. El sheet se cierra automáticamente al completarse.
5. El nuevo nombre se refleja **inmediatamente** en el header del perfil y en cualquier otra pantalla donde aparezca (chat, reseñas, detalle de orden).
6. Recarga la app → el nombre persiste (está en Firestore).

**Resultado esperado:** la actualización propaga a toda la app sin recargar manualmente.

### 9.2 Cambiar foto de perfil ✅
1. Abre el bottom sheet de **"Editar perfil"**.
2. Toca el **avatar** → se abre el selector de imágenes del dispositivo/navegador.
3. Selecciona una imagen → la previsualización se actualiza en el círculo del sheet.
4. Presiona **"Guardar"** → la imagen se sube a Cloudinary y la URL se guarda en Firestore.
5. El avatar se actualiza en el header del perfil y en el chip de usuario en el chat.

**Resultado esperado:** la foto de perfil cambia correctamente y se muestra en toda la app.

### 9.3 Biografía ⚠️ *Pendiente de implementar*
> Esta funcionalidad aún no está disponible. Cuando se implemente, verificar que el campo "Biografía" en el formulario de edición de perfil guarde y persista el texto en Firestore.

---

## Prueba 10 — Panel de administración

Con `admin@...`:
1. Navega a `/admin`.
2. La lista de vendedores pendientes es correcta.
3. Aprueba un vendedor → desaparece de la lista + `vendorStatus` cambia a `approved` en Firestore.
4. Rechaza otro vendedor → desaparece de la lista + `vendorStatus` cambia a `rejected`.

Verifica que una cuenta sin `isAdmin: true` no pueda acceder a esta ruta (ver Prueba 2).

---

## Prueba 11 — Notificaciones push (Android / Web)

### Android
1. `buyer` realiza una orden a `vendor1` con la app de `vendor1` en **segundo plano**.
2. `vendor1` debe recibir una **notificación push** del sistema operativo.
3. Tap en la notificación → abre la app directamente en `/order-alert/:orderId`.

### Web
1. Abre la app en Chrome → acepta el permiso de notificaciones cuando se solicite.
2. Verifica en **DevTools → Application → Service Workers** que `firebase-messaging-sw.js` esté activo.
3. Con la pestaña en segundo plano, realiza una orden → debe aparecer una notificación de sistema.

---

## Prueba 12 — Preferencias de notificaciones ✅

Con cualquier cuenta autenticada:

### 12.1 Acceso a la página
1. Navega a `/profile` → presiona **"Notificaciones"** → redirige a `/notifications`.
2. La página tiene dos secciones visibles: **PREFERENCIAS** e **HISTORIAL**.

### 12.2 Toggle de notificaciones
1. El switch **"Notificaciones en la app"** aparece activado por defecto.
2. Desactívalo → el subtítulo cambia a *"Los avisos de pedidos no se mostrarán."*
3. Cierra la app completamente y vuelve a abrirla → el switch sigue **desactivado**.
4. Con el toggle desactivado, pide una orden desde otra cuenta → el **banner in-app no debe aparecer** en la app del vendedor/comprador.
5. Reactiva el toggle → los banners vuelven a aparecer normalmente.

**Resultado esperado:** la preferencia persiste en `SharedPreferences` y suprime los banners de forma inmediata.

### 12.3 Historial de notificaciones
1. Verifica que la lista muestre notificaciones **leídas y no leídas** (sin filtro de estado).
2. Las no leídas aparecen con el **texto en negrita** y un **punto dorado** a la derecha.
3. Las leídas aparecen con texto normal y sin punto.
4. El tiempo relativo es correcto: "hace X min", "hace X h", "ayer", "hace X días".
5. Tap en una notificación de tipo `new_order` → navega a `/chat/:orderId` y la marca como leída.
6. Tap en una notificación de tipo `order_delivered` → navega a `/review/:orderId` y la marca como leída.
7. El punto dorado desaparece de la notificación tocada.

### 12.4 Marcar todas como leídas
1. Cuando hay al menos una notificación sin leer → el botón **"Marcar todo"** aparece en el AppBar.
2. Presiona **"Marcar todo"** → todos los puntos dorados desaparecen.
3. El botón **"Marcar todo"** desaparece del AppBar.
4. Verifica en `Firestore → notifications` que los documentos tengan `status: 'read'`.

### 12.5 Sin historial
1. Con una cuenta nueva (sin órdenes) → la sección HISTORIAL muestra el ícono vacío y el texto *"Sin notificaciones aún"*.

---

## Prueba 13 — Ayuda y soporte ✅

Con cualquier cuenta autenticada:

### 13.1 Apertura del sheet
1. Navega a `/profile` → presiona **"Ayuda y soporte"** → aparece un bottom sheet.
2. El sheet muestra el título "Ayuda y soporte" con el subtítulo *"¿En qué podemos ayudarte?"*.
3. Se listan **5 categorías** con icono y chevron:
   - Reportar un problema
   - Problemas con mi cuenta
   - Reportar a un usuario
   - Sugerencia de mejora
   - Otro

### 13.2 Flujo con sub-opciones (Reportar un problema)
1. Presiona **"Reportar un problema"** → el sheet anima a la vista de opciones.
2. El título cambia a *"Reportar un problema"* con flecha de retroceso.
3. Se muestran 6 sub-opciones:
   - No puedo cerrar sesión
   - No puedo enviar mensajes
   - No puedo realizar un pedido
   - Mi pago no se procesó
   - La app no carga o se cierra
   - Otro problema técnico
4. Presiona la flecha de retroceso → regresa a la pantalla de categorías.
5. Selecciona una sub-opción (ej. *"No puedo enviar mensajes"*) → anima a la vista de detalles.

### 13.3 Vista de detalles y envío
1. La vista muestra:
   - Chip dorado con la categoría seleccionada.
   - Chip secundario con la sub-opción seleccionada.
   - Campo de texto opcional con contador hasta 500 caracteres.
   - Botón **"Enviar reporte"**.
2. Presiona la flecha → regresa a la selección de sub-opción.
3. Escribe texto en el campo (opcional) → presiona **"Enviar reporte"**.
4. Aparece el indicador de carga en el botón mientras se guarda.

### 13.4 Pantalla de éxito
1. Tras el envío exitoso → aparece la pantalla de éxito con:
   - Círculo verde con ícono de paloma.
   - Texto *"¡Mensaje enviado!"*
   - Subtítulo *"Recibimos tu reporte. Un administrador lo revisará pronto."*
   - Botón **"Cerrar"**.
2. Presiona **"Cerrar"** → el sheet se cierra.
3. Verifica en `Firestore → support_tickets` que se creó el documento con los campos: `userId`, `userEmail`, `userName`, `topic`, `option`, `details`, `status: 'open'`, `createdAt`.

### 13.5 Flujo sin sub-opciones (Sugerencia de mejora)
1. Selecciona **"Sugerencia de mejora"** → el sheet salta directamente a la vista de detalles (sin pantalla de sub-opciones).
2. Solo aparece el chip dorado con la categoría (sin chip de sub-opción).
3. Completa el envío → pantalla de éxito funciona igual.

---

## Resumen de rutas a cubrir

| Ruta | Quién la prueba |
|------|----------------|
| `/onboarding` | Usuario nuevo |
| `/login` | Todos |
| `/role-select` | Usuario recién registrado |
| `/vendor-verify` | Vendedor pendiente |
| `/home` | Comprador |
| `/post/:id` | Comprador |
| `/search` | Comprador |
| `/order-summary` | Comprador |
| `/payment` | Comprador |
| `/order-confirmed` | Comprador |
| `/orders` | Comprador + Vendedor |
| `/order-detail/:id` | Comprador + Vendedor |
| `/order-alert/:id` | Vendedor |
| `/chat/:id` | Comprador + Vendedor |
| `/review/:id` | Comprador |
| `/vendor/:id` | Comprador |
| `/profile` | Todos |
| `/my-reviews` | Vendedor |
| `/notifications` | Todos |
| `/dashboard` | Vendedor |
| `/earnings` | Vendedor |
| `/create-post` | Vendedor |
| `/admin` | Admin |

---

## Checklist rápido de regresión

Antes de cada release, verifica que estos puntos críticos sigan funcionando:

- [ ] Login con Google y redirección por rol
- [ ] Login con Google en Web sin error `Bad state: init()` en segundo intento
- [ ] El botón de login no reaparece brevemente tras autenticarse (spinner continuo hasta redirigir)
- [ ] Guard de vendedor pendiente (`/vendor-verify`)
- [ ] Guard de admin (`/admin` solo para `isAdmin: true`)
- [ ] Creación de publicación con imagen
- [ ] Flujo completo de orden: pedir → pagar → confirmar → entregar → reseñar
- [ ] Chat visible solo mientras la orden está activa
- [ ] Banner de notificación in-app al recibir una orden
- [ ] El banner **no aparece** cuando el toggle de notificaciones está desactivado
- [ ] Stats del dashboard reflejan datos reales de Firestore
- [ ] Búsqueda devuelve resultados para posts y vendedores
- [ ] Cierre de sesión y limpieza de estado
- [ ] Editar nombre desde perfil → persiste en Firestore y se actualiza en toda la app
- [ ] Cambiar foto de perfil → sube a Cloudinary y se muestra el avatar actualizado
- [ ] Toggle de notificaciones persiste entre sesiones (SharedPreferences)
- [ ] Historial de notificaciones muestra leídas y no leídas; tap marca como leída
- [ ] "Marcar todo" elimina todos los puntos de no leído
- [ ] Formulario de soporte envía ticket a Firestore (`support_tickets`) con `status: 'open'`
- [ ] Flujo de soporte sin sub-opciones (Sugerencia / Otro) salta directamente a detalles
