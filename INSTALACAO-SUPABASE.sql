-- Execute no SQL Editor do mesmo projeto Supabase usado pelo Album V5.
-- Primeiro crie sua conta em Authentication > Users > Add user.
-- Depois substitua SEU_EMAIL_AQUI pelo e-mail cadastrado e execute o arquivo inteiro.
create table if not exists public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admin_users enable row level security;
drop policy if exists "admin pode consultar propria autorizacao" on public.admin_users;
create policy "admin pode consultar propria autorizacao" on public.admin_users for select to authenticated using (user_id = (select auth.uid()));

insert into public.admin_users(user_id)
select id from auth.users where lower(email)=lower('SEU_EMAIL_AQUI')
on conflict (user_id) do nothing;

create or replace function public.is_album_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.admin_users a where a.user_id = (select auth.uid()));
$$;
revoke all on function public.is_album_admin() from public;
grant execute on function public.is_album_admin() to authenticated;

create table if not exists public.eventos (
  id text primary key,
  nome text not null,
  data_evento date,
  created_at timestamptz not null default now()
);
alter table public.eventos enable row level security;
drop policy if exists "administrador gerencia eventos" on public.eventos;
create policy "administrador gerencia eventos" on public.eventos for all to authenticated
using ((select public.is_album_admin())) with check ((select public.is_album_admin()));

-- A tabela fotos já existe na Engine V5. Acrescentamos permissões administrativas.
drop policy if exists "administrador consulta fotos" on public.fotos;
create policy "administrador consulta fotos" on public.fotos for select to authenticated using ((select public.is_album_admin()));
drop policy if exists "administrador exclui fotos" on public.fotos;
create policy "administrador exclui fotos" on public.fotos for delete to authenticated using ((select public.is_album_admin()));

-- Supabase Storage: o bucket 'fotos-eventos' deve continuar público para leitura dos convidados.
drop policy if exists "administrador exclui arquivos" on storage.objects;
create policy "administrador exclui arquivos" on storage.objects for delete to authenticated
using (bucket_id = 'fotos-eventos' and (select public.is_album_admin()));
drop policy if exists "administrador baixa arquivos" on storage.objects;
create policy "administrador baixa arquivos" on storage.objects for select to authenticated
using (bucket_id = 'fotos-eventos' and (select public.is_album_admin()));

-- Não apague as políticas públicas de INSERT/SELECT já usadas pelo álbum V5.
-- IMPORTANTE: confira se não existem políticas públicas de DELETE/UPDATE nas tabelas fotos
-- e storage.objects. Somente o administrador deve poder excluir fotos.
