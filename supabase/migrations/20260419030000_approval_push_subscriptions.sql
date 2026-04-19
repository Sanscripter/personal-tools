create table if not exists public.approval_push_subscriptions (
    id bigint generated always as identity primary key,
    user_id uuid,
    user_email text not null,
    endpoint text not null unique,
    subscription jsonb not null,
    user_agent text,
    is_active boolean not null default true,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    last_used_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_approval_push_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists trg_approval_push_updated_at on public.approval_push_subscriptions;
create trigger trg_approval_push_updated_at
before update on public.approval_push_subscriptions
for each row
execute function public.set_approval_push_updated_at();

alter table public.approval_push_subscriptions enable row level security;

comment on table public.approval_push_subscriptions is 'Saved web push subscriptions for phone approval notifications.';
