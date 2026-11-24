insert into storage.buckets (id, name, public, file_size_limit) values
    ('roro-interface', 'roro-interface', true, 16777216),
    ('roro-media', 'roro-media', false, 16777216),
    ('roro-sources', 'roro-sources', false, 16777216);

create policy "Members can read released Roro media"
on storage.objects for select to authenticated
using (bucket_id = 'roro-media' and (storage.foldername(name))[1] = 'releases');
