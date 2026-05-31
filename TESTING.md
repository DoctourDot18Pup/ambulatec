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

## Prueba 1 — Onboarding y autenticación (CORRECTO)

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

## Prueba 2 — Guards del router (CORRECTO)

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

### 4.1 Complementos con precio (CORRECTO)

> Sección **"PERSONALIZACIONES"** al final del formulario de creación.

1. Presiona **"Agregar grupo"** → aparece una tarjeta de grupo.
2. Escribe el nombre del grupo (ej. *"Tamaño"* o *"Salsas"*).
3. Activa **"Selección múltiple"** si quieres permitir varias opciones a la vez (ej. salsas); déjalo apagado para selección única (ej. tamaño).
4. Por cada opción escribe su **nombre** y, opcionalmente, un **precio extra** en el campo `$` a la derecha (déjalo vacío o en 0 para que sea gratis).
5. Presiona **"Agregar opción"** para más opciones, o el ícono rojo para quitar una.
6. Publica y vuelve a abrir la publicación como `buyer@...`.

**Resultado esperado:**
- Los complementos **se guardan** y aparecen tanto al vendedor como al comprador.
- En `Firestore → posts → {id} → extras`, cada opción es un objeto `{label, price}`.

> **Nota de regresión:** anteriormente los complementos se perdían al publicar
> (el provider `autoDispose` se reseteaba). Verifica que una publicación nueva
> conserve los complementos. Las publicaciones creadas **antes** del fix no
> tienen complementos guardados.

---

## Prueba 5 — Feed y búsqueda (Comprador) (CORRECTO)

Con `buyer@...`:

### 5.1 Feed principal
1. Abre `/home` → deben aparecer publicaciones de los vendedores aprobados.
2. Tap en una tarjeta → abre `/post/:id` con imagen, descripción, precio y botón **"Pedir"**.
3. Tap en el **nombre del vendedor** dentro de la tarjeta → abre `/vendor/:vendorId`.

### 5.2 Perfil público del vendedor
1. Verifica que se muestre: avatar, nombre, carrera, calificación (estrellas), estado (online/busy).
2. Presiona **Seguir** → el botón cambia a "Siguiendo".
3. Presiona de nuevo → deja de seguir.
4. La grilla de publicaciones activas del vendedor es visible.
5. Las reseñas aparecen debajo; presiona "Ver todas" → abre el modal con el listado completo.

> **Nota:** el botón de seguir no debe aparecer si el comprador visita su propio perfil de vendedor.

### 5.3 Búsqueda (CORRECTO)
1. Abre `/search`.
2. **Estado inicial** (sin texto): muestra la grilla de 6 categorías + lista horizontal de vendedores activos.
3. Escribe al menos 2 caracteres → aparecen resultados de posts y vendedores.
4. **Búsqueda insensible a mayúsculas y por substring:** escribe una palabra que esté **en medio** del título (ej. `birria` para encontrar *"TACOS DE BIRRIA"*) y en minúsculas → debe encontrarlo igual. También matchea por **nombre del vendedor** y **categoría**.
5. Tap en un resultado de post → navega a `/post/:id`.
6. Tap en un resultado de vendedor → navega a `/vendor/:vendorId`.
7. Borra el texto → vuelve al estado inicial.

> **Nota de regresión:** antes la búsqueda solo coincidía por prefijo exacto y
> respetaba mayúsculas (ej. `tacos` no encontraba *"TACOS…"*). Ahora filtra del
> lado cliente con `contains` en minúsculas.

#### 5.3.1 Filtro por categoría (CORRECTO)
1. En el estado inicial, toca una de las tarjetas de **categoría** (ej. *"Bebidas"*).
2. **Resultado esperado:** navega a `/home` con el feed **filtrado por esa categoría** (no escribe el nombre en el buscador).
3. Toca *"Ver todo"* → el feed muestra todas las categorías.

> **Nota de regresión:** antes las categorías escribían su nombre como texto de
> búsqueda y hacían prefix-match sobre el título del producto, por lo que nunca
> coincidían. Ahora aplican el filtro real (`categoryFilterProvider`).

### 5.4 Sección de Vendedores (`/vendors`)

> Visible solo para compradores en la pestaña de navegación "Vendedores".

1. Con `buyer@...`, presiona la pestaña **"Vendedores"** en la barra inferior → navega a `/vendors`.
2. Se muestra la lista de **todos los vendedores aprobados**, ordenados de mayor a menor calificación.
3. Cada tarjeta muestra: avatar, nombre, estrellas, calificación numérica y número de reseñas.
4. Los vendedores sin reseñas no muestran la sección de estrellas.
5. Tap en una tarjeta → navega a `/vendor/:vendorId` con el perfil público del vendedor.

**Resultado esperado:** lista actualizada en tiempo real desde Firestore, ordenada por rating sin requerir índice compuesto.

---

## Prueba 6 — Flujo completo de orden (CORRECTO)

### Paso 1 — Comprador especifica cantidad, complementos y envía solicitud
1. `buyer` abre un post (que tenga complementos definidos, ver Prueba 4.1) → en `/post/:id`.
2. **Complementos con precio:** la sección de personalizaciones muestra cada opción como chip; si tiene precio aparece **"+$X"** junto a la opción. Selecciona algunas (única o múltiple según el grupo).
3. Ajusta la **CANTIDAD** con los botones **−** / **+**.
4. **Desglose en tiempo real:** debajo del stepper aparece el desglose — *Producto $X*, cada complemento de pago *+$Y*, subtotal por unidad y **Total** — todo se recalcula al cambiar opciones o cantidad.
5. Escribe la nota de entrega (obligatorio) y, opcionalmente, adjunta una foto de referencia.
6. Presiona **"Enviar solicitud"** → navega a `/order-summary`.
7. Verifica que el resumen muestre:
   - La cantidad seleccionada debajo del nombre del producto.
   - La tarjeta **"PERSONALIZACIONES"** con cada opción elegida y su precio (o *"Gratis"*).
   - La tarjeta de total **desglosada**: Producto, cada extra de pago, subtotal por unidad, cantidad y **Total a pagar**.
8. Presiona **"Enviar solicitud al vendedor"** → navega a `/order-confirmed` con texto **"¡Solicitud enviada!"**.
9. En `/orders` → pestaña "Activos": la orden aparece con estado **"En espera"**.

> **Cálculo:** el precio unitario guardado en la orden = precio base + suma de
> complementos de pago; el total = unitario × cantidad. Esto hace que, si el
> vendedor reajusta la cantidad más adelante, los complementos se conserven.

### Paso 2 — Vendedor recibe la solicitud y puede ajustar cantidad

#### Opción A — Por notificación
9. `vendor1` recibe un **banner in-app** → tap abre `/order-alert/:orderId`.
10. La tarjeta del producto muestra la cantidad solicitada con un stepper **−/+** editable.
11. Si el vendedor tiene menos unidades, ajusta la cantidad con el stepper → el precio se recalcula.
12. Dos acciones disponibles:
    - **Aceptar pedido** → guarda la cantidad final, estado pasa a `awaiting_payment`, abre el chat.
    - **Rechazar** → estado pasa a `rejected`; la orden termina.

#### Opción B — Desde el listado
9. `vendor1` navega a `/orders` → pestaña **"Pendientes"** → tap en la orden → `/order-detail/:orderId`.

### Paso 3 — Chat y ajuste post-aceptación (`awaiting_payment`)
13. En `/chat/:orderId`, el vendedor ve el panel **"AJUSTAR CANTIDAD"** con el stepper y el total actual.
14. Si necesita modificar de nuevo → cambia la cantidad → el botón **"Generar nuevo cobro"** aparece.
15. Presiona **"Generar nuevo cobro"** → aparece un mensaje del sistema con el total actualizado (ej. *"El vendedor ajustó la cantidad a 2. Nuevo total: $30"*).
16. El comprador ve el panel de pago con el precio actualizado: **"Proceder al pago — $XX"**.

### Paso 4 — Pago del comprador
17. `buyer` presiona **"Proceder al pago — $XX"** → navega a `/payment`.
18. Ingresa la tarjeta de prueba (`4242 4242 4242 4242`) y confirma.
19. La orden pasa a `confirmed`; aparece mensaje del sistema *"¡Pago recibido!"*.

### Paso 5 — Entrega
20. `vendor1` ve el botón **"Marcar como entregado"** → confirma en el diálogo → orden pasa a `delivered`.
21. **`buyer` es redirigido automáticamente** a `/review/:orderId` para dejar la reseña.

### Paso 6 — Reseña del comprador
22. En `/review/:orderId`: selecciona de 1 a 5 estrellas, elige etiquetas opcionales y escribe comentario.
23. Presiona **"Enviar reseña"** → snackbar *"¡Gracias por tu reseña!"* → redirige a `/home`.
24. La reseña aparece en `/vendor/:vendorId` de `vendor1` (sección overview para compradores).
25. `vendor1` puede ver la reseña en su página **"Mis reseñas"** (`/my-reviews`).

### 6.1 Rechazo y reactivación de publicación (CORRECTO)

1. `vendor1` recibe una solicitud y presiona **Rechazar** (en `/order-alert/:id` o `/order-detail/:id`).
2. La orden pasa a `rejected` y la **publicación asociada se desactiva** (deja de aparecer en el feed).
3. `vendor1` abre la orden rechazada en `/order-detail/:orderId` (o en el chat).
4. Aparece el aviso *"Rechazaste este pedido y la publicación se desactivó…"* con el botón **"Reactivar publicación"**.
5. Presiona **"Reactivar publicación"** → confirma en el diálogo.
6. **Resultado esperado:**
   - La publicación vuelve a aparecer en el catálogo (`isActive: true`).
   - El comprador recibe una notificación de tipo `post_reactivated` y un mensaje del sistema en el chat.
   - El botón **desaparece** (la orden queda marcada con `postReactivated: true`); no se puede reactivar dos veces.

---

## Prueba 7 — Página de órdenes (CORRECTO)

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
- Si la orden tiene complementos, aparece la sección **"PERSONALIZACIONES"** con el desglose: Producto, cada complemento con su precio (o *"Gratis"*) y el subtotal por unidad × cantidad.

---

## Prueba 8 — Dashboard y ganancias (Vendedor)

Con `vendor1` (con al menos una orden entregada):

### 8.1 Dashboard
1. Navega a `/dashboard`.
2. Verifica que los **stats** muestren valores correctos: órdenes activas, ganancias totales, pedidos pendientes.
3. La **gráfica semanal** muestra los puntos de ganancias por día.
4. Presiona **"Ver ganancias →"** → navega a `/earnings`.
5. **Campana de notificaciones:** el ícono de campana en el encabezado muestra un **badge rojo** con el número de notificaciones sin leer (o *"9+"*), se ve relleno/dorado cuando hay pendientes. Tap → navega a `/notifications`.

> **Nota de regresión (rendimiento):** la carga del dashboard y del panel de
> admin ya no depende de índices compuestos de Firestore (se quitó el `orderBy`
> de las consultas y se ordena del lado cliente). Antes el panel se quedaba
> "colgado" esperando el índice; ahora carga de inmediato.

### 8.2 Página de ganancias
1. Muestra la gráfica `fl_chart` con puntos interactivos por día.
2. El desglose semanal lista cada semana con su total.
3. Los valores coinciden con las órdenes entregadas registradas en Firestore.

---

## Prueba 9 — Perfil de usuario (CORRECTO)

Con cualquier cuenta:
1. Navega a `/profile`.
2. Presiona **"Cerrar sesión"** → redirige a `/login`.

### 9.1 Editar nombre (CORRECTO)
1. Desde `/profile`, presiona **"Editar perfil"** → aparece el bottom sheet de edición.
2. Modifica el campo **Nombre completo**.
3. Presiona **"Guardar"** → el indicador de carga aparece mientras se guarda.
4. El sheet se cierra automáticamente al completarse.
5. El nuevo nombre se refleja **inmediatamente** en el header del perfil y en cualquier otra pantalla donde aparezca (chat, reseñas, detalle de orden).
6. Recarga la app → el nombre persiste (está en Firestore).

**Resultado esperado:** la actualización propaga a toda la app sin recargar manualmente.

### 9.2 Cambiar foto de perfil (CORRECTO)
1. Abre el bottom sheet de **"Editar perfil"**.
2. Toca el **avatar** → se abre el selector de imágenes del dispositivo/navegador.
3. Selecciona una imagen → la previsualización se actualiza en el círculo del sheet.
4. Presiona **"Guardar"** → la imagen se sube a Cloudinary y la URL se guarda en Firestore.
5. El avatar se actualiza en el header del perfil y en el chip de usuario en el chat.

**Resultado esperado:** la foto de perfil cambia correctamente y se muestra en toda la app.

### 9.3 Mis reseñas — Solo vendedores (`/my-reviews`)

1. Con `vendor1@...` (con al menos una reseña recibida), navega a `/profile`.
2. En la lista de opciones aparece el tile **"Mis reseñas"** con ícono de estrella.
3. Tap → navega a `/my-reviews`.
4. La página muestra:
   - **Card de resumen**: calificación promedio en grande, estrellas, total de reseñas y barras de frecuencia de etiquetas (*"LO QUE MÁS DESTACAN"*).
   - **Lista paginada**: las primeras 5 reseñas con título del pedido, comprador, fecha, estrellas, etiquetas y comentario.
5. Si hay más de 5 reseñas → aparece el botón **"Mostrar más (N restantes)"** al final.
6. Presiona el botón → se cargan 5 reseñas adicionales.
7. Cuando todas están visibles → el botón desaparece.

**Resultado esperado:** el card de resumen siempre refleja el total de reseñas; la paginación carga en bloques de 5.

---

## Prueba 10 — Panel de administración

Con `admin@...`:
1. Navega a `/admin` → el panel tiene **dos pestañas**: **"Vendedores"** y **"Reportes"**, cada una con un contador entre paréntesis (pendientes / abiertos).

### 10.1 Pestaña Vendedores
1. La lista de vendedores pendientes es correcta.
2. Aprueba un vendedor → desaparece de la lista + `vendorStatus` cambia a `approved` en Firestore.
3. Rechaza otro vendedor → desaparece de la lista + `vendorStatus` cambia a `rejected`.

### 10.2 Pestaña Reportes (CORRECTO)
1. Cambia a la pestaña **"Reportes"** → se listan los tickets de la colección `support_tickets`, más recientes primero.
2. Cada tarjeta muestra: tema, sub-opción, detalle, autor (nombre + email), fecha y estado (**Abierto** / **Resuelto**).
3. Si el reporte vino del **chat** (ver Prueba 13.6), muestra además el **contexto del pedido** (`#AT-XXXXXX` y sobre quién es).
4. Presiona **"Marcar como resuelto"** → el estado cambia a *Resuelto* y el contador de la pestaña baja.
5. Presiona **"Reabrir"** → vuelve a *Abierto*.

Verifica que una cuenta sin `isAdmin: true` no pueda acceder a esta ruta (ver Prueba 2).

---

## Prueba 11 — Notificaciones push (Android / Web)

### Android
1. `buyer` realiza una orden a `vendor1` con la app de `vendor1` **abierta o recién minimizada**.
2. `vendor1` debe recibir una **notificación local** del sistema operativo.
3. Tap en la notificación → abre la app directamente en `/order-alert/:orderId`.

> **Limitación conocida (decisión de diseño del demo):**
> Las notificaciones locales se generan mediante un *listener* de Firestore que
> corre **dentro de la app**. Android mantiene vivo el proceso solo unos minutos
> tras minimizar; después lo congela (Doze / restricciones de batería) y el
> listener deja de recibir eventos, por lo que **no llegan notificaciones con la
> app cerrada o en segundo plano prolongado**. Esto es una limitación del SO, no
> un error de código.
>
> La solución correcta (push real con la app cerrada) requiere un **emisor FCM
> del lado servidor** — una Cloud Function (plan Blaze de Firebase). Como este es
> un proyecto demostrativo sin presupuesto, se optó por **no** habilitarlo. El
> **historial de notificaciones dentro de la app siempre funciona** (Prueba 12.3).

### Web (CORRECTO)
1. Abre la app en Chrome → acepta el permiso de notificaciones cuando se solicite.
2. Verifica en **DevTools → Application → Service Workers** que `firebase-messaging-sw.js` esté activo.
3. Con la pestaña en segundo plano, realiza una orden → debe aparecer una notificación de sistema.

---

## Prueba 12 — Preferencias de notificaciones (CORRECTO)

Con cualquier cuenta autenticada:

### 12.1 Acceso a la página (CORRECTO)
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

## Prueba 13 — Ayuda y soporte (CORRECTO)

Con cualquier cuenta autenticada:

### 13.1 Apertura del sheet (CORRECTO)
1. Navega a `/profile` → presiona **"Ayuda y soporte"** → aparece un bottom sheet.
2. El sheet muestra el título "Ayuda y soporte" con el subtítulo *"¿En qué podemos ayudarte?"*.
3. Se listan **5 categorías** con icono y chevron:
   - Reportar un problema
   - Problemas con mi cuenta
   - Reportar a un usuario
   - Sugerencia de mejora
   - Otro

### 13.2 Flujo con sub-opciones (Reportar un problema) (CORRECTO)
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

### 13.3 Vista de detalles y envío (CORRECTO)
1. La vista muestra:
   - Chip dorado con la categoría seleccionada.
   - Chip secundario con la sub-opción seleccionada.
   - Campo de texto opcional con contador hasta 500 caracteres.
   - Botón **"Enviar reporte"**.
2. Presiona la flecha → regresa a la selección de sub-opción.
3. Escribe texto en el campo (opcional) → presiona **"Enviar reporte"**.
4. Aparece el indicador de carga en el botón mientras se guarda.

### 13.4 Pantalla de éxito (CORRECTO)
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

### 13.6 Reporte desde el chat (contextual) (CORRECTO)

> Reportar directamente donde ocurre el problema, no solo desde el perfil.

1. Dentro de un `/chat/:orderId`, abre el menú **⋮** (esquina superior derecha) → **"Reportar un problema"**.
2. Se abre el mismo sheet de soporte, pero con un aviso dorado *"Reporte vinculado a tu pedido con [contraparte]"* en el primer paso.
3. Completa y envía el reporte.
4. Verifica en `Firestore → support_tickets` que el documento incluye además `orderId`, `reportedUserId` y `reportedUserName`.
5. El reporte aparece en `/admin` → pestaña **"Reportes"** mostrando el contexto del pedido (ver Prueba 10.2).

---

## Resumen de rutas a cubrir

| Ruta | Quién la prueba |
|------|----------------|
| `/onboarding` | Usuario nuevo |
| `/login` | Todos |
| `/role-select` | Usuario recién registrado |
| `/vendor-verify` | Vendedor pendiente |
| `/home` | Comprador |
| `/vendors` | Comprador |
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
- [ ] Creación de publicación con imagen y complementos opcionales **con precio**
- [ ] Los complementos se **guardan** y aparecen al vendedor y al comprador (regresión del bug `autoDispose`)
- [ ] Publicación inactiva muestra overlay **"No disponible"** en el feed
- [ ] Stepper de cantidad en `/post/:id` actualiza el total en tiempo real
- [ ] Complementos con precio muestran `+$X` y el **desglose** (producto + extras + total) en `/post/:id`, `/order-summary` y `/order-detail`
- [ ] `/order-summary` muestra cantidad y desglose `N × $precio = $total`
- [ ] Vendedor puede ajustar cantidad en `/order-alert/:id` antes de aceptar
- [ ] Panel de ajuste de cantidad en chat (`awaiting_payment`) genera nuevo cobro con mensaje del sistema
- [ ] Al marcar entregado, el comprador es **redirigido automáticamente** a `/review/:orderId`
- [ ] Flujo completo de orden: solicitud → ajuste cantidad → pago → entrega → reseña automática
- [ ] Chat visible solo mientras la orden está activa
- [ ] Foto de entrega adjunta es visible para el vendedor en `/order-detail/:id`
- [ ] Banner de notificación in-app al recibir una orden
- [ ] El banner **no aparece** cuando el toggle de notificaciones está desactivado
- [ ] Stats del dashboard reflejan datos reales de Firestore
- [ ] Búsqueda devuelve resultados para posts y vendedores
- [ ] Búsqueda funciona por **substring** e **insensible a mayúsculas** (`birria` encuentra "TACOS DE BIRRIA")
- [ ] Las tarjetas de **categoría** en `/search` filtran el feed (no escriben en el buscador)
- [ ] `/vendors` muestra lista de vendedores aprobados ordenados por rating
- [ ] Vendedor puede **reactivar** una publicación rechazada desde `/order-detail`; el botón desaparece tras reactivar
- [ ] Campana del dashboard muestra badge de no leídas y navega a `/notifications`
- [ ] Dashboard y `/admin` cargan sin demora (sin dependencia de índices compuestos)
- [ ] Cierre de sesión y limpieza de estado
- [ ] Editar nombre desde perfil → persiste en Firestore y se actualiza en toda la app
- [ ] Cambiar foto de perfil → sube a Cloudinary y se muestra el avatar actualizado
- [ ] `/my-reviews` muestra card de resumen + lista paginada (5 por página) de reseñas del vendedor
- [ ] Toggle de notificaciones persiste entre sesiones (SharedPreferences)
- [ ] Historial de notificaciones muestra leídas y no leídas; tap marca como leída
- [ ] "Marcar todo" elimina todos los puntos de no leído
- [ ] Formulario de soporte envía ticket a Firestore (`support_tickets`) con `status: 'open'`
- [ ] Flujo de soporte sin sub-opciones (Sugerencia / Otro) salta directamente a detalles
- [ ] Reporte desde el chat (**⋮ → Reportar un problema**) guarda el contexto del pedido (`orderId`, `reportedUserId`)
- [ ] Panel de admin tiene pestaña **"Reportes"**; permite marcar resuelto / reabrir
