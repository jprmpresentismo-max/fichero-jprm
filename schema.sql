-- ============================================================
-- SISTEMA DE CONTROL DE FICHERO - JPRM
-- Ejecutar este script completo en Supabase > SQL Editor
-- ============================================================

-- Personal autorizado a retirar/devolver material (fichas)
create table if not exists personal_autorizado (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  nfc_uid text unique not null,
  activo boolean not null default true,
  device_token text,               -- identifica el único teléfono vinculado a esta persona
  device_vinculado_en timestamptz, -- cuándo se vinculó ese teléfono
  creado_en timestamptz not null default now()
);

-- Fichas de pacientes / material (una fila por ficha física)
create table if not exists fichas (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,        -- identificador interno (hoy no se imprime, QR en pausa)
  legajo text,                        -- "LP"
  nombre_paciente text not null,
  creado_en timestamptz not null default now()
);

-- Movimientos: cada retiro genera una fila; al devolver se completa hora_devolucion
create table if not exists prestamos (
  id uuid primary key default gen_random_uuid(),
  ficha_id uuid not null references fichas(id),
  persona_retira_id uuid not null references personal_autorizado(id),
  persona_devuelve_id uuid references personal_autorizado(id),
  hora_retiro timestamptz not null default now(),
  hora_devolucion timestamptz
);

-- Índice para encontrar rápido si una ficha está "afuera"
create index if not exists idx_prestamos_abiertos
  on prestamos (ficha_id)
  where hora_devolucion is null;

-- ============================================================
-- Seguridad
-- ============================================================
-- El panel de administración (admin.html) usa Supabase Auth: solo quien
-- tenga un usuario creado en Authentication > Users puede cargar personal
-- autorizado y material (fichas). La app operativa (app.html) usa la clave
-- anon sin login, así que sus escrituras están limitadas a lo mínimo
-- necesario: registrar movimientos (retiro/devolución) y, mediante la
-- función jprm_identificar de abajo, vincular el teléfono la primera vez
-- que alguien usa su tarjeta.
-- ============================================================
alter table personal_autorizado enable row level security;
alter table fichas enable row level security;
alter table prestamos enable row level security;

-- personal_autorizado: cualquiera puede leer (la app necesita mostrarlo),
-- pero solo un admin autenticado puede dar de alta o modificar directamente
-- (activar/desactivar, desvincular teléfono). El vínculo de teléfono en el
-- primer uso NO pasa por estas políticas: lo hace la función
-- jprm_identificar más abajo, que corre con privilegios propios.
drop policy if exists "lectura_personal" on personal_autorizado;
create policy "lectura_personal" on personal_autorizado for select using (true);

drop policy if exists "escritura_personal" on personal_autorizado;
create policy "escritura_personal" on personal_autorizado
  for insert with check (auth.role() = 'authenticated');

drop policy if exists "update_personal" on personal_autorizado;
create policy "update_personal" on personal_autorizado
  for update using (auth.role() = 'authenticated');

-- fichas: cualquiera puede leer/buscar (la app las necesita para el
-- retiro/devolución), pero solo un admin autenticado puede cargarlas
-- (carga individual o masiva desde admin.html).
drop policy if exists "lectura_fichas" on fichas;
create policy "lectura_fichas" on fichas for select using (true);

drop policy if exists "escritura_fichas" on fichas;
create policy "escritura_fichas" on fichas
  for insert with check (auth.role() = 'authenticated');

-- prestamos: uso interno, se mantiene abierto como antes (solo lo escribe
-- app.html al confirmar un retiro/devolución).
drop policy if exists "lectura_prestamos" on prestamos;
create policy "lectura_prestamos" on prestamos for select using (true);

drop policy if exists "escritura_prestamos" on prestamos;
create policy "escritura_prestamos" on prestamos for insert with check (true);

drop policy if exists "update_prestamos" on prestamos;
create policy "update_prestamos" on prestamos for update using (true);

-- ============================================================
-- Función: identifica a la persona por su tarjeta NFC y vincula el
-- teléfono desde el que escanea. Si es la primera vez que se usa esa
-- tarjeta, el teléfono actual queda vinculado automáticamente. Si ya
-- estaba vinculada a otro teléfono, devuelve telefono_ok = false y
-- app.html rechaza el acceso.
--
-- Corre con "security definer" (privilegios del dueño de la función) para
-- poder hacer ese único UPDATE puntual sin necesidad de abrir la tabla
-- personal_autorizado a escrituras anónimas en general.
-- ============================================================
create or replace function jprm_identificar(p_nfc_uid text, p_device_id text)
returns table (id uuid, nombre text, telefono_ok boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v personal_autorizado;
begin
  select * into v from personal_autorizado
    where nfc_uid = p_nfc_uid and activo = true
    limit 1;

  if v.id is null then
    return; -- tarjeta no reconocida o desactivada: no devuelve filas
  end if;

  if v.device_token is null then
    update personal_autorizado
      set device_token = p_device_id, device_vinculado_en = now()
      where personal_autorizado.id = v.id;
    v.device_token := p_device_id;
  end if;

  return query select v.id, v.nombre, (v.device_token = p_device_id);
end;
$$;

grant execute on function jprm_identificar(text, text) to anon;
