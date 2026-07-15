# Proyecto: Control de Fichero — JPRM (retiro/devolución de fichas con NFC)

## Qué es esto
Sistema para controlar el préstamo de fichas físicas de pacientes en la División
Junta Permanente de Reconocimientos Médicos (JPRM). Hay personal autorizado a
retirar fichas del archivo, cada uno con (o va a tener) una tarjeta NFC.
El flujo:

1. La persona apoya su tarjeta NFC en el celular → la app la identifica contra
   la lista de personal autorizado (si no está registrada o está desactivada,
   se le niega el acceso).
2. Elige "Retirar" o "Devolver" y busca la ficha escribiendo el LP (legajo) o
   el nombre y apellido del paciente. Si la ficha no existe todavía, se puede
   cargar ahí mismo (LP + nombre) y queda agregada a la selección.
3. Al retirar, queda registrado quién, qué ficha y a qué hora. Si esa ficha
   ya está afuera con otra persona, el sistema lo bloquea y avisa.
4. Al devolver, se cierra ese préstamo con la hora de devolución.
5. Hay un panel para ver en tiempo real qué fichas están afuera y hace
   cuánto tiempo.
6. Desde "Personal" se registran tarjetas NFC nuevas y se puede activar/
   desactivar el acceso de cada persona sin borrar su historial.

Está pensado para uso en celular Android con Chrome (usa la Web NFC API,
que solo funciona ahí, con HTTPS).

**QR pausado (decisión de David, 2026-07-15):** el flujo original identificaba
la ficha escaneando un QR pegado en el sobre físico. Eso se dejó en pausa
porque las fichas todavía no tienen etiquetas impresas. Mientras tanto, la
identificación de la ficha es por búsqueda de LP/nombre directamente en la
app (ver `app.html`). El archivo `generar_qr.html` queda armado y sin tocar
para cuando se retome esa parte — en ese momento conviene reconectar QR como
una segunda forma de buscar la ficha (más rápida), no como reemplazo de la
búsqueda por nombre.

## Stack
- Frontend: HTML + JS vanilla, un archivo por pantalla (mismo patrón que el
  resto de mis proyectos: autocontenido, sin build step).
- Backend: **el mismo proyecto Supabase que ya uso para Presentismo y
  Ascenso** (David ya lo tiene armado, no crear uno nuevo).
- QR (en pausa): librería `html5-qrcode` para leer, `qrcode` para generar —
  hoy `app.html` NO la usa; `generar_qr.html` sigue igual, sin usar todavía.
- Hosting: GitHub Pages, repo `fichero-jprm` en la cuenta `jprmpresentismo-max`
  (la cuenta `chacalumes2653` mencionada originalmente no estaba logueada en
  el navegador de Cowork al momento del deploy; David eligió seguir con
  `jprmpresentismo-max` en su lugar — si se prefiere mudar el repo a
  `chacalumes2653` más adelante, es un simple transfer de repo en GitHub).

## Estado del deploy (hecho el 2026-07-15)
- Repo: https://github.com/jprmpresentismo-max/fichero-jprm (público)
- App: https://jprmpresentismo-max.github.io/fichero-jprm/app.html
- Generador QR (sin usar por ahora): https://jprmpresentismo-max.github.io/fichero-jprm/generar_qr.html
- GitHub Pages activado, source = rama `main`, carpeta raíz.

## Archivos en esta carpeta
- `schema.sql` → crea las tablas `personal_autorizado`, `fichas`, `prestamos`
  en Supabase, con RLS básico (políticas abiertas para la clave anon, uso
  interno). **Falta ejecutarlo** en el SQL Editor del proyecto Supabase. No
  necesitó cambios para la búsqueda por LP/nombre (el campo `legajo` ya
  existía y se usa como "LP" en la interfaz).
- `app.html` → la app operativa: identificación NFC, retiro/devolución por
  búsqueda de LP/nombre (con alta de ficha nueva inline si no existe), panel
  de fichas afuera, y gestión de personal autorizado (alta de tarjetas +
  activar/desactivar acceso). **Ya está deployado, pero con credenciales
  Supabase placeholder — no funciona hasta completarlas.**
- `generar_qr.html` → herramienta para dar de alta fichas en bloque (pegando
  legajo + nombre desde Excel) y generar/imprimir etiquetas QR. **En pausa,
  no tocar por ahora** — se retoma cuando David decida imprimir etiquetas.

## Lo que falta para dejarlo funcionando
1. **Credenciales de Supabase**: `app.html` (y `generar_qr.html` cuando se
   retome) tienen placeholders `SUPABASE_URL` / `SUPABASE_ANON_KEY` sin
   completar. Hay que pedirle a David la URL y anon key de su proyecto
   existente (Settings → API en Supabase).
2. **Correr `schema.sql`** en ese proyecto Supabase (SQL Editor → pegar y
   ejecutar). No pisa ninguna tabla existente, son tablas nuevas.
3. **Registrar al personal autorizado** desde la sección "Personal" de
   `app.html` (cada uno apoya su tarjeta NFC + se escribe su nombre).
4. **Cargar las primeras fichas**: como no hay QR todavía, se cargan sobre la
   marcha la primera vez que alguien las busca y no aparecen (LP + nombre),
   directamente desde el flujo de retiro/devolución.
5. **Probar el flujo completo** con una ficha de prueba antes de dar por
   cerrado: retirar, ver que aparece en "Fichas afuera", devolver, ver que
   desaparece. Probar también el bloqueo (intentar retirar una ficha que ya
   está afuera) y que desactivar a alguien en "Personal" le corte el acceso.
6. **(Más adelante) Retomar QR**: cuando David tenga el listado real de
   pacientes y quiera imprimir etiquetas, correr `generar_qr.html` y
   reconectar el escaneo QR en `app.html` como atajo adicional a la búsqueda.

## Decisiones ya tomadas (no volver a preguntar)
- QR pausado por ahora; búsqueda por LP/nombre es el mecanismo actual para
  identificar fichas (ver arriba). No proponer volver a QR salvo que David lo
  pida.
- Repo y Pages quedaron en la cuenta `jprmpresentismo-max`, no en
  `chacalumes2653` — decisión de David tomada durante el deploy.
- Mismo proyecto Supabase que Presentismo/Ascenso, no uno nuevo.
- RLS abierto con clave anon (aceptable para uso interno en red de la
  dependencia); si más adelante se quiere reforzar, migrar a Supabase Auth
  como en el sistema de Ascenso. El repo es público, así que la anon key va a
  quedar visible en el código una vez cargada — David ya fue avisado de esto
  y lo acepta por ahora.
- Sin límite fijo de fichas por retiro: se pueden agregar una o varias en la
  misma sesión, cada una queda como una fila independiente en `prestamos`.
- La gestión de personal ahora permite desactivar el acceso de alguien sin
  borrar su historial de movimientos (columna `activo` en
  `personal_autorizado`, ya contemplada en el `schema.sql` original).

## Sobre David (contexto general)
Trabaja en la JPRM de la Policía Federal Argentina, gestiona legajos,
evaluaciones médicas y sistemas administrativos del personal. Ya tiene en
producción: sistema de presentismo QR/NFC con Supabase, sistema de
evaluación médica de ascensos (Anexo III-VI digital), y un sistema de
gestión de sobres con código de barras para el archivo físico. Prefiere
entregables simples, autocontenidos, sin dependencias pesadas.
