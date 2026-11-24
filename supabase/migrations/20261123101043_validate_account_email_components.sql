create or replace function roro_private.validate_account_email() returns trigger
language plpgsql security invoker set search_path = '' as $fn$
begin
    if new.email is null or octet_length(new.email) > 254 or
       octet_length(split_part(new.email, '@', 1)) > 64 or
       new.email !~ $email$^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+([.][A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?([.][A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$$email$ then
        raise exception 'Enter a valid email address.' using errcode = '23514';
    end if;
    return new;
end;
$fn$;
