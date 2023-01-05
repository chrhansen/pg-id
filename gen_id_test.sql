-- Install pgTAP: https://pgxn.org/dist/pgtap/ and paste all this in psql or run
-- psql -d <db-with-pg-functions> -Xf gen_id_test.sql

CREATE EXTENSION IF NOT EXISTS pgtap;

BEGIN;

-- #################################################
-- Helper function: user_5xZSA9yfP6E1b => 1672920637420 (ms since epoch)
-- Edited from https://stackoverflow.com/a/66425745/1213651
CREATE OR REPLACE FUNCTION base58_id_to_ms(encoded_id TEXT)
    RETURNS BIGINT AS $$
DECLARE
    -- Bitcoin base58 alphabet
    alphabet TEXT := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    c CHAR(1) := null;
    p INT := null;
    raw_num  DECIMAL(40,0) := 0;
    uuid_str VARCHAR(32) := '';
    ms BIGINT;
BEGIN
    -- Remove prefix if present
    encoded_id := REGEXP_SUBSTR(encoded_id, '[^_]*$');

    FOR i IN 1..CHAR_LENGTH(encoded_id) LOOP
        c := SUBSTRING(encoded_id FROM i FOR 1);
        p := POSITION(c IN alphabet);
        raw_num := (raw_num * length(alphabet)) + (p - 1);
    END LOOP;

    FOR i IN 0..31 LOOP
        uuid_str := CONCAT(uuid_str, TO_HEX(MOD(raw_num, 16)::INT));
        raw_num := DIV(raw_num, 16);
    END LOOP;

    uuid_str := REPLACE(REVERSE(uuid_str), '-', '');

    -- Not used     Time 6 bytes Random 4 bytes
    -- 000000000000 018581d71fec b613ffde
    uuid_str := SUBSTRING(uuid_str, 13, 12);

    -- Hex-string to integer (milli seconds)
    ms := ('x' || lpad(uuid_str, 16, '0'))::bit(64)::bigint;
    return ms;
END;$$
LANGUAGE PLPGSQL;
-- End of helper function base58_id_to_ms(encoded_id TEXT)
-- #################################################

-- Plan count should be the number of tests
SELECT plan(6);

-- #################################################
-- 1. Function definition checks
-- #################################################
SELECT has_function(
    'gen_id',
    ARRAY ['text'],
    'gen_id exists'
);

-- #################################################
-- 2. Test output format
-- #################################################

SELECT matches(
    gen_id(),
    '^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{10,14}$',
    '10 byte hex, should have 10 to 14 base58 chars.'
);

SELECT is(
    base58_id_to_ms(gen_id())
    BETWEEN extract(epoch from now()) * 1000 - 2
    AND     extract(epoch from now()) * 1000 + 2,
    TRUE,
    'The timestamp part should be within 2 ms of current epoch.'
);

-- #################################################
-- 5. ULID with prefix
-- #################################################

SELECT matches(
    gen_id( 'user'),
    '^user_+["123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"]{10,14}$',
    'Format with `user_`-prefix.'
);

SELECT is(
    base58_id_to_ms(gen_id('acc'))
    BETWEEN extract(epoch from now()) * 1000 - 2
    AND     extract(epoch from now()) * 1000 + 2,
    TRUE,
    'The timestamp part should be within 2 ms of current epoch.'
);

ROLLBACK;
