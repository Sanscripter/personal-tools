create extension if not exists pgcrypto;

create table if not exists public.admin_approval_requests (
    id bigint generated always as identity primary key,
    request_id uuid not null unique,
    request_secret text not null,
    action text not null,
    reason text,
    requester_host text,
    requester_user text,
    allowed_email text not null,
    status text not null default 'pending' check (status in ('pending', 'approved', 'denied', 'expired')),
    approved_by_email text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    expires_at timestamptz not null default (timezone('utc', now()) + interval '2 minutes')
);

create or replace function public.set_admin_approval_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists trg_admin_approval_updated_at on public.admin_approval_requests;
create trigger trg_admin_approval_updated_at
before update on public.admin_approval_requests
for each row
execute function public.set_admin_approval_updated_at();

alter table public.admin_approval_requests enable row level security;

create or replace function public.current_approval_secret()
returns text
language sql
stable
as $$
    select coalesce(
        nullif((current_setting('request.headers', true)::jsonb ->> 'x-approval-secret'), ''),
        ''
    );
$$;

create or replace function public.current_approval_email()
returns text
language sql
stable
as $$
    select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

drop policy if exists "approval request insert" on public.admin_approval_requests;
create policy "approval request insert"
on public.admin_approval_requests
for insert
to anon, authenticated
with check (
    length(coalesce(request_secret, '')) >= 20
    and length(trim(coalesce(allowed_email, ''))) > 3
);

drop policy if exists "approval request select by secret" on public.admin_approval_requests;
create policy "approval request select by secret"
on public.admin_approval_requests
for select
to anon, authenticated
using (
    request_secret = public.current_approval_secret()
);

drop policy if exists "approval request update by approver" on public.admin_approval_requests;
create policy "approval request update by approver"
on public.admin_approval_requests
for update
to authenticated
using (
    request_secret = public.current_approval_secret()
    and status = 'pending'
    and expires_at > timezone('utc', now())
    and public.current_approval_email() = lower(allowed_email)
)
with check (
    request_secret = public.current_approval_secret()
    and public.current_approval_email() = lower(allowed_email)
    and status in ('approved', 'denied')
    and approved_by_email = public.current_approval_email()
);

comment on table public.admin_approval_requests is 'One-time elevated command approvals for the Morgan Toolbox repo.';
