-- Cutouts stay on the device. Supabase keeps garment metadata only, so the
-- PNG bucket and the storage policies are retired and `image_path` (a Storage
-- object key) becomes `image_file` (a file name inside the app's documents
-- dir). Devices restore their own photos; a row from another phone simply has
-- no local file and the UI falls back to the placeholder.

alter table public.wardrobe_items
  rename column image_path to image_file;

comment on column public.wardrobe_items.image_file is
  'File name of the cutout in <app documents>/cutouts/ on the device that '
  'scanned it; empty when the photo is gone. Never an absolute path.';

-- Bucket `cutouts` is now unused. Its policies are gone, so nothing can read
-- or write it; the row itself must be removed from Dashboard → Storage
-- (Postgres cannot: storage.protect_delete blocks direct deletes).
drop policy if exists "cutouts are readable by their owner" on storage.objects;
drop policy if exists "cutouts are writable by their owner" on storage.objects;
drop policy if exists "cutouts are updatable by their owner" on storage.objects;
drop policy if exists "cutouts are deletable by their owner" on storage.objects;