-- Saved combinations and the weekly planner.
--
-- Both live next to wardrobe_items so a user's whole wardrobe follows the
-- account instead of the handset. A combination points at wardrobe_items ids
-- (never names), and a planner entry points at one combination, so renaming a
-- garment or an outfit keeps every reference intact.

create table if not exists public.outfit_looks (
  id uuid primary key,
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  item_ids uuid[] not null default '{}',
  threshold real not null default 0.6
    check (threshold >= 0 and threshold <= 1),
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists outfit_looks_owner_created_idx
  on public.outfit_looks (owner_id, created_at desc);

alter table public.outfit_looks enable row level security;

create policy "outfits are readable by their owner"
  on public.outfit_looks for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "outfits are insertable by their owner"
  on public.outfit_looks for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "outfits are editable by their owner"
  on public.outfit_looks for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "outfits are deletable by their owner"
  on public.outfit_looks for delete
  to authenticated
  using (auth.uid() = owner_id);

drop trigger if exists outfit_looks_touch_updated_at on public.outfit_looks;
create trigger outfit_looks_touch_updated_at
  before update on public.outfit_looks
  for each row execute function public.touch_updated_at();

create table if not exists public.planner_entries (
  id uuid primary key,
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  day date not null,
  outfit_id uuid not null
    references public.outfit_looks (id) on delete cascade,
  occasion text not null default '',
  complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One outfit per day, so planning the same date twice updates that entry
  -- instead of stacking two.
  unique (owner_id, day)
);

create index if not exists planner_entries_owner_day_idx
  on public.planner_entries (owner_id, day);

alter table public.planner_entries enable row level security;

create policy "planner entries are readable by their owner"
  on public.planner_entries for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "planner entries are insertable by their owner"
  on public.planner_entries for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "planner entries are editable by their owner"
  on public.planner_entries for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "planner entries are deletable by their owner"
  on public.planner_entries for delete
  to authenticated
  using (auth.uid() = owner_id);

drop trigger if exists planner_entries_touch_updated_at on public.planner_entries;
create trigger planner_entries_touch_updated_at
  before update on public.planner_entries
  for each row execute function public.touch_updated_at();