# Proyecto: Control de Fichero — JPRM (retiro/devolución de material con NFC)

## Qué es esto
Sistema para controlar el préstamo de fichas físicas (material) de pacientes
en la División Junta Permanente de Reconocimientos Médicos (JPRM). Hay
personal autorizado a retirar material del archivo, cada uno con (o va a
tener) una tarjeta NFC.

Hay dos apps separadas:

1. **`app.html`** — la usa el personal operativo, sin login. Flujo:
   - Apoya su tarjeta NFC en el celular → la app la identifica contra la
     lista de personal autorizado.
   - **Vínculo de teléfono**: la primera vez que se usa una tarjeta, el
     teléfono desde el que se escaneó queda vinculado automáticamente a esa
     persona. Si después alguien intenta usar la misma tarjeta desde OTRO
     teléfono, el sistema lo rechaza ("esta tarjeta ya está vinculada a otro
     teléfono"). Esto se resuelve desde `admin.html` (botón "Desvincular
     tel.", que libera la tarjeta para que se vuelva a vincular con el
     próximo uso).
   - Elige "Retirar material" o "Devolver material" y busca escribiendo el
     LP (legajo) o el nombre y apellido. Puede agregar uno o varios antes de
     confirmar.
   - Al retirar, queda registrado quién, qué material y a qué hora. Si ese
     material ya está afuera con otra persona, el sistema lo bloquea y
     avisa. Al devolver, se cierra ese préstamo.
   - Panel "Fichas afuera": ve en tiempo real qué material está afuera y
     hace cuánto.
   - **`app.html` NO permite cargar material nuevo ni personal nuevo** — eso
     es exclusivo del panel de administración.

2. **`admin.html`** — panel de administración, **acceso exclusivo de
   David** mediante login (Supabase Auth, email + contraseña). Desde acá se
   hace todo lo que antes estaba mezclado en `app.html`:
   - **Material**: carga masiva (pegar filas `LP` + `nombre y apellido`
     copiadas de Excel) o carga individual. Buscador para revisar lo ya
     cargado.
   - **Personal autorizado**: alta de tarjetas NFC nuevas (nombre + escanear
     tarjeta), activar/desactivar el acceso de cada persona sin borrar su
     historial, y desvincular el teléfono de alguien si cambió de celular o
     hay que reasignar la tarjeta.

Está pensado para uso en celular Android con Chrome (usa la Web NFC API,
que solo funciona ahí, con HTTPS). `admin.html` también necesita un
Android/Chrome con NFC para el paso de "escanear tarjeta" al dar de alta a
alguien — si David lo abre desde una compu, todo funciona excepto ese botón.

**QR pausado (decisión de David, 2026-07-15):** el flujo original
identificaba el material escaneando un QR pegado en el sobre físico. Se
dejó en pausa porque las fichas no tienen etiquetas impresas todavía. Hoy la
identificación es por búsqueda de LP/nombre. `generar_qr.html` queda
armado y sin tocar para cuando se retome esa parte.

## Stack
- Frontend: HTML + JS vanilla, un archivo por pantalla (mismo patrón que el
  resto de mis proyectos: autocontenido, sin build step).
- Backend: **el mismo proyecto Supabase que ya uso para Presentismo y
  Ascenso** (David ya lo tiene armado, no crear uno nuevo). `admin.html`
  usa Supabase Auth (email/contraseña) igual que el sistema de Ascenso.
- QR (en pausa): librería `html5-qrcode` / `qrcode` — hoy ni `app.html` ni
  `admin.html` la usan; `generar_qr.html` sigue igual, sin usar todavía.
- Hosting: GitHub Pages, repo `fichero-jprm` en la cuenta
  `jprmpresentismo-max` (la cuenta `chacalumes2653` mencionada originalmente
  no estaba logueada en el navegador de Cowork al momento del deploy; David
  eligió seguir con `jprmpresentismo-max`).

## Estado del deploy (hecho el 2026-07-15)
- Repo: https://github.com/jprmpresentismo-max/fichero-jprm (público)
- App operativa: https://jprmpresentismo-max.github.io/fichero-jprm/app.html
- Panel admin: https://jprmpresentismo-max.github.io/fichero-jprm/admin.html
- Generador QR (sin usar por ahora): https://jprmpresentismo-max.github.io/fichero-jprm/generar_qr.html
- GitHub Pages activado, source = rama `main`, carpeta raíz.

## Archivos en esta carpeta
- `schema.sql` → crea las tablas `personal_autorizado` (ahora con
  `device_token` / `device_vinculado_en`), `fichas`, `prestamos`, con RLS, y
  la función `jprm_identificar` (security definer) que hace el
  reconocimiento + vínculo de teléfono de forma segura sin necesidad de
  abrir `personal_autorizado` a escrituras anónimas. **Falta ejecutarlo**
  en el SQL Editor del proyecto Supabase (es seguro volver a correrlo si ya
  se había ejecutado una versión anterior: usa `create table if not
  exists` y `drop policy if exists` antes de recrear cada política).
- `app.html` → app operativa para el personal (ver arriba). Con
  credenciales Supabase placeholder — no funciona hasta completarlas.
- `admin.html` → panel de administración con login, exclusivo para David.
  También con credenciales placeholder.
- `generar_qr.html` → en pausa, no tocar por ahora.

## Estado de la carga de datos (hecho el 2026-07-15)
Las credenciales de Supabase ya están cargadas en `app.html` y `admin.html`,
el `schema.sql` ya corrió en el proyecto, David ya fue invitado como usuario
admin, y **la tabla `fichas` ya tiene cargado el listado completo de
personal de la PFA**: 28.464 filas, extraídas de `SuboNuevoJunta24.mdb`
(columna `legajo` = LP, `nombre_paciente` = "APELLIDO, NOMBRE"). Verificado
con `select count(*) from fichas;` → 28464. La carga se hizo desde el SQL
Editor de Supabase en 10 tandas (INSERT de ~3000 filas cada una), seteando
el contenido del editor directamente vía `monaco.editor` en vez de tipear o
pegar (para evitar el bug de corrupción de texto al tipear bloques grandes
en el editor Monaco). Los archivos SQL temporales usados para la carga ya
fueron borrados del repo.

## Lo que falta para dejarlo funcionando
1. **Probar que David pueda entrar a `admin.html`**: David tiene que
   revisar su email (`carlosdaviddiaz1992@gmail.com`) para aceptar la
   invitación de Supabase Auth y elegir su contraseña, y después probar el
   login en `admin.html`.
2. **Registrar al personal autorizado** desde `admin.html` → Personal
   autorizado (cada uno apoya su tarjeta NFC + se escribe su nombre). El
   vínculo con el teléfono de cada uno se hace solo, la primera vez que esa
   persona use `app.html` con su tarjeta.
3. **Probar el flujo completo**: buscar una ficha por LP o nombre, retirar,
   ver que aparece en "Fichas afuera", devolver, ver que desaparece. Probar
   el bloqueo por material ya afuera, y probar que usar la misma tarjeta
   desde un segundo teléfono se rechace (y que "Desvincular tel." en el
   panel lo habilite de nuevo).
4. **(Más adelante) Retomar QR**: si David quiere imprimir etiquetas, correr
   `generar_qr.html` y evaluar si conviene sumarlo como atajo adicional en
   `app.html`.

## Decisiones ya tomadas (no volver a preguntar)
- QR pausado por ahora; búsqueda por LP/nombre es el mecanismo actual. No
  proponer volver a QR salvo que David lo pida.
- Repo y Pages quedaron en la cuenta `jprmpresentismo-max`, no en
  `chacalumes2653` — decisión de David tomada durante el deploy.
- Mismo proyecto Supabase que Presentismo/Ascenso, no uno nuevo.
- **Carga de material y de personal autorizado: exclusiva del panel
  `admin.html`, con login de Supabase Auth.** `app.html` (personal
  operativo, sin login) solo puede leer/buscar material y registrar
  movimientos de retiro/devolución — no puede dar de alta fichas ni
  personas. Esto quedó reforzado a nivel de RLS (INSERT en `fichas` y
  `personal_autorizado` requiere `auth.role() = 'authenticated'`), no
  depende solo de que la interfaz no lo muestre.
- **Vínculo de teléfono por persona**: cada tarjeta NFC queda atada al
  primer teléfono desde el que se usa (columna `device_token`). Escanear la
  misma tarjeta desde otro teléfono se rechaza hasta que un admin la
  desvincule desde `admin.html`. Esto se resuelve con la función SQL
  `jprm_identificar` (security definer), no con una política RLS abierta,
  para no exponer `personal_autorizado` a escrituras anónimas arbitrarias.
- El repo es público, así que la anon key de Supabase queda visible en el
  código una vez cargada. Las escrituras sensibles (alta de material y de
  personal) están protegidas por RLS + login, así que exponer la anon key
  ya no alcanza para hacerlas — David fue avisado y lo acepta.
- Sin límite fijo de material por retiro: se pueden agregar uno o varios en
  la misma sesión, cada uno queda como una fila independiente en
  `prestamos`.

## Sobre David (contexto general)
Trabaja en la JPRM de la Policía Federal Argentina, gestiona legajos,
evaluaciones médicas y sistemas administrativos del personal. Ya tiene en
producción: sistema de presentismo QR/NFC con Supabase, sistema de
evaluación médica de ascensos (Anexo III-VI digital), y un sistema de
gestión de sobres con código de barras para el archivo físico. Prefiere
entregables simples, autocontenidos, sin dependencias pesadas.
