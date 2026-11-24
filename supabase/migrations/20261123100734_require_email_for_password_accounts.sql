-- Supabase Auth stores the email and bcrypt hash in auth.users.
create schema if not exists roro_private;
revoke all on schema roro_private from public, anon, authenticated;
create function roro_private.validate_account_email() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
    if new.email is null or octet_length(new.email) > 254 or
       new.email !~ '^[^[:space:]@]+@[^[:space:]@.]+([.][^[:space:]@.]+)+$' then
        raise exception 'Enter a valid email address.' using errcode = '23514';
    end if;
    return new;
end;
$$;
revoke all on function roro_private.validate_account_email() from public, anon, authenticated;
create trigger roro_password_account_email
before insert or update of email, encrypted_password on auth.users
for each row when (coalesce(new.encrypted_password, '') <> '')
execute function roro_private.validate_account_email();
