# Panduan anggota — login Supabase

Dua hal berbeda, jangan dicampur:

| Mau apa | Di mana |
| --- | --- |
| Masuk ke **dashboard** Supabase (bikin project, lihat tabel) | akun supabase.com, sekali per orang atau satu akun tim |
| Masuk ke **aplikasi Gayaku** (login/daftar di HP) | akun Supabase **Auth** di project tim, dibuat dari dalam app |

Kamu butuh: Flutter SDK, HP Android (atau emulator), dan akses ke project Supabase tim.

## 1. Akun dashboard

1. Buka <https://supabase.com/dashboard>, daftar pakai email kampus (gratis).
2. Minta **project ref** ke ketua tim (yang sudah punya project). Satu project untuk semua; jangan bikin project baru per orang — migrasi dan data akan terpecah.
3. Ketua menambahkan kamu lewat *Project Settings → Team → Invite*, atau kamu cukup menerima kredensial aplikasi (langkah 3) tanpa akses dashboard.

## 2. Migrasi (sekali, oleh yang punya dashboard)

SQL editor → tempel isi file di `supabase/migrations/` **berurutan sesuai nama file**:

```
20261024120000_profiles.sql
20261024120100_avatars_bucket.sql
20261103090000_wardrobe_items.sql
20261103091500_wardrobe_local_images.sql
20261108120000_wardrobe_align_model.sql
20261108160000_outfits_and_planner.sql
```

Atau lewat CLI:

```bash
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase db push
```

Cek berhasil: *Table Editor* menampilkan `profiles` dan `wardrobe_items`; *Storage* punya bucket private `avatars` (bucket `cutouts` sudah pensiun).

## 3. Ambil dua nilai untuk app

*Project Settings → API*:

- **Project URL** — bentuknya `https://<project-ref>.supabase.co`
- **publishable key** (project lama menulis **anon** key) — kunci publik, aman masuk repo/build lokal

**Jangan pernah** pakai/commit `service_role` atau `secret` key. Itu melewati RLS.

## 4. Jalankan app

```bash
cd flutter_app
flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Build APK:

```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Tanpa dua flag itu app jalan di `DemoAuthService`: email/password apa pun diterima, tidak ada data yang dikirim ke Supabase. Kalau login berhasil walau password ngawur, berarti flag-nya lupa dipasang.

## 5. Daftar & login di app

1. Buka app → **Daftar** → isi nama, email, password (minimal 6 karakter).
2. Kalau *email confirmation* masih aktif di project, app kembali ke layar login dengan pesan cek email. Untuk demo, matikan dulu: *Authentication → Providers → Email → Confirm email = off*.
3. Login dengan akun yang sama. Setelah masuk, buka *Table Editor → profiles*: harus muncul satu baris dengan `display_name` dari form.
4. Akun uji cepat boleh dibuat manual: *Authentication → Users → Add user* (email + password, centang auto-confirm).

## 6. Bukti RLS jalan

Di SQL editor, jalankan sebagai anon:

```sql
select * from profiles;          -- kosong: benar, bukan bug
select auth.uid();               -- null di SQL editor
```

`profiles` dan `wardrobe_items` hanya mengembalikan baris milik user yang sedang login. Kalau SQL editor menampilkan semua baris, itu karena editor memakai `service_role`, bukan karena policy bocor.

## 7. Kalau gagal

| Gejala | Sebab | Perbaikan |
| --- | --- | --- |
| Login apa pun berhasil | flag `--dart-define` tidak terpasang | jalankan ulang dengan dua flag |
| `Invalid login credentials` | user belum ada / password salah | buat user di *Authentication → Users* |
| Daftar sukses tapi tidak bisa login | email confirmation masih aktif | matikan *Confirm email* |
| `new row violates row-level security policy` | migrasi `profiles` belum dijalankan / trigger sign-up belum ada | jalankan migrasi berurutan |
| `relation "wardrobe_items" does not exist` | migrasi `20261103090000` terlewat | jalankan file itu |
| Scan tersimpan tanpa gambar | `image_file` hanya nama file di HP; foto tidak diunggah | sesuai desain — lihat ADR-0001 (on-device) |

## 8. Yang masih harus dikerjakan sebelum pamer

- Layar wardrobe masih membaca SQLite lokal (`wardrobeItems`), bukan `wardrobeService.items()`. Jadi data Supabase belum muncul di grid.
- `subcategory`, `brand`, `occasions` belum punya kolom di `wardrobe_items`; saat ini `occasions` diturunkan dari `formality`.
- Saved looks, favorit, weekly planner masih di memori.