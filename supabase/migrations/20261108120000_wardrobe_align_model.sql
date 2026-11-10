-- Align `wardrobe_items` with the WardrobeItem the app already builds.
--
-- develop's model carries `subcategory` (the fine scanner label, e.g. `Jeans`),
-- `brand` and `occasions`; the table only had `label`, so a row read back lost
-- two of them and derived the third. Now every field survives the round trip.
--
-- `occasions` is a closed set: it is what the chip filter and the matcher
-- compare, and `defaultOccasions()` in
-- flutter_app/lib/logic/garment_defaults.dart is the client-side source of the
-- defaults backfilled below.

alter table public.wardrobe_items
  add column if not exists subcategory text not null default '',
  add column if not exists brand text not null default '',
  add column if not exists occasions text[] not null default '{}';

comment on column public.wardrobe_items.subcategory is
  'Fine garment type from the classifier label list, e.g. `Jeans`; empty for '
  'items added by hand.';
comment on column public.wardrobe_items.occasions is
  'Subset of Formal | Smart-Casual | Kasual | Sport. Seeded from category '
  'exactly like defaultOccasions() on the client.';

-- Backfill existing rows with the same rule the client uses, so an old row and
-- a fresh scan agree.
update public.wardrobe_items
set occasions = case category
  when 'Outerwear' then array['Formal', 'Smart-Casual']
  else array['Kasual', 'Smart-Casual']
end
where occasions = '{}';

alter table public.wardrobe_items
  drop constraint if exists wardrobe_items_occasions_check;
alter table public.wardrobe_items
  add constraint wardrobe_items_occasions_check
  check (occasions <@ array['Formal', 'Smart-Casual', 'Kasual', 'Sport']::text[]);

-- A scan always reports a label, so backfill subcategory from it rather than
-- leaving a scanned item with an empty fine type.
update public.wardrobe_items
set subcategory = label
where subcategory = '' and label <> '';