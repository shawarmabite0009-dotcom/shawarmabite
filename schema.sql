create table menu_items(
 id bigint generated always as identity primary key,
 category text not null check (category in ('shawarmas','sandwiches','rolls','sides')),
 name text not null check (char_length(name) between 1 and 80),
 note text check (char_length(note) <= 60),
 kind text not null default 'v' check (kind in ('v','c','e')),
 price int not null check (price between 0 and 10000),
 available boolean not null default true,
 sort int not null default 999);
create table site_photos(key text primary key, label text not null, url text);
create table profiles(
 id uuid primary key references auth.users on delete cascade,
 email text,
 role text not null default 'staff' check (role in ('owner','staff')));

create function my_role() returns text language sql stable security definer set search_path=public
as $$ select role from profiles where id = auth.uid() $$;

create function handle_new_user() returns trigger language plpgsql security definer set search_path=public
as $$ begin insert into profiles(id,email) values (new.id,new.email); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

alter table menu_items enable row level security;
alter table site_photos enable row level security;
alter table profiles enable row level security;

create policy "public reads menu" on menu_items for select to anon, authenticated using (true);
create policy "team adds menu" on menu_items for insert to authenticated with check (my_role() in ('owner','staff'));
create policy "team edits menu" on menu_items for update to authenticated using (my_role() in ('owner','staff')) with check (my_role() in ('owner','staff'));
create policy "owner deletes menu" on menu_items for delete to authenticated using (my_role() = 'owner');

create policy "public reads photos" on site_photos for select to anon, authenticated using (true);
create policy "team edits photos" on site_photos for update to authenticated using (my_role() in ('owner','staff')) with check (my_role() in ('owner','staff'));

create policy "read own profile or owner reads all" on profiles for select to authenticated using (id = auth.uid() or my_role() = 'owner');
create policy "owner changes roles" on profiles for update to authenticated using (my_role() = 'owner') with check (my_role() = 'owner');

insert into storage.buckets(id,name,public) values ('photos','photos',true);
create policy "team uploads photos" on storage.objects for insert to authenticated with check (bucket_id='photos' and my_role() in ('owner','staff'));
create policy "team replaces photos" on storage.objects for update to authenticated using (bucket_id='photos' and my_role() in ('owner','staff'));
create policy "team removes photos" on storage.objects for delete to authenticated using (bucket_id='photos' and my_role() in ('owner','staff'));
