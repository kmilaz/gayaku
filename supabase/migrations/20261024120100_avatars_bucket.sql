-- Avatar storage: private bucket, one folder per user.
--
-- Object names must be `avatars/<user-id>/<file>`, so the folder check below is
-- what keeps one user out of another user's files. No UI uploads yet; the
-- bucket and its rules land now so the policy is reviewed together with the
-- profiles table instead of being bolted on later.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

create policy "avatars are readable by their owner"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars are writable by their owner"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars are updatable by their owner"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars are deletable by their owner"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
