-- Wardrobe items: one row per scanned garment.
--
-- Columns mirror the ScanResult the scanner emits (label, category,
-- suggestedName, confidence, colorName, dominantColor, formality) plus the
-- cutout PNG that landed in the private `cutouts` bucket. `labels.json` stays
-- the single source of truth for the 18 YOLO labels on the client, so `label`
-- is free text here; the five categories are the closed set the app filters on.

create table if not exists public.wardrobe_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  label text not null,
  category text not null check (
    category in ('Tops', 'Bottoms', 'Outerwear', 'Shoes', 'Accessories')
  ),
  color_name text not null default '',
  dominant_color text not null default '#000000'
    check (dominant_color ~ '^#[0-9A-Fa-f]{6}$'),
  formality smallint not null default 3 check (formality between 1 and 5),
  confidence real check (confidence is null or (confidence >= 0 and confidence <= 1)),
  image_path text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists wardrobe_items_owner_created_idx
  on public.wardrobe_items (owner_id, created_at desc);

alter table public.wardrobe_items enable row level security;

-- owner_id defaults to auth.uid(), so a client cannot insert on behalf of
-- another user: the with check below rejects any other value.
create policy "wardrobe items are readable by their owner"
  on public.wardrobe_items for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "wardrobe items are insertable by their owner"
  on public.wardrobe_items for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "wardrobe items are editable by their owner"
  on public.wardrobe_items for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "wardrobe items are deletable by their owner"
  on public.wardrobe_items for delete
  to authenticated
  using (auth.uid() = owner_id);

drop trigger if exists wardrobe_items_touch_updated_at on public.wardrobe_items;
create trigger wardrobe_items_touch_updated_at
  before update on public.wardrobe_items
  for each row execute function public.touch_updated_at();

-- Cutouts: the transparent-background PNG the scanner produces, one folder per
-- user, named `cutouts/<uid>/<object>.png`. Deleted together with its row by
-- the app, since Postgres cannot reach into storage on delete.
insert into storage.buckets (id, name, public)
values ('cutouts', 'cutouts', false)
on conflict (id) do nothing;

create policy "cutouts are readable by their owner"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'cutouts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cutouts are writable by their owner"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'cutouts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cutouts are updatable by their owner"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'cutouts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cutouts are deletable by their owner"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'cutouts' and (storage.foldername(name))[1] = auth.uid()::text);