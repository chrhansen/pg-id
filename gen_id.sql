CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- The generated ID has 6 timestamp bytes (ms precision) + 4 random bytes =>
-- output is Base58 encoded, with an optional prefix:
-- gen_id() => 5xXBF6THVcCpa
-- gen_id('user') => user_5xXBF6THVcCpa

-- Like Stripe IDs (designed for humans to read), but not all bytes are random
-- to improve indexing. Inspired by https://github.com/ulid/spec
-- https://github.com/chrhansen/pg-id

CREATE OR REPLACE FUNCTION gen_id(prefix text default NULL) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    timestamp     BYTEA := E'\\000\\000\\000\\000\\000\\000';
    unix_time     BIGINT;
    ulid          BYTEA;
    return_string TEXT;
BEGIN
    -- 6 timestamp bytes => millisecond precision
    unix_time := (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT;
    FOR i IN 0..5 LOOP
        timestamp := SET_BYTE(timestamp, i, (unix_time >> (40 - i * 8))::BIT(8)::INTEGER);
    END LOOP;

    -- 4 entropy bytes => I.e. ~4.3 Billion IDs per millisecond
    ulid := timestamp || gen_random_bytes(4);

    return_string := RIGHT(ulid::text, - 2);

    return_string := hex_to_base58(return_string);

    IF prefix IS NOT NULL THEN
        return_string := prefix || '_' || return_string;
    END IF;

    RETURN return_string;
END;
$$;

CREATE OR REPLACE FUNCTION hex_to_base58(hexstr TEXT) RETURNS TEXT AS $$
DECLARE
    bytes BYTEA := ('\x' || hexstr)::BYTEA;
    leading_zeroes INT := 0;
    num DECIMAL(40,0) := 0;
    base DECIMAL(40,0) := 1;

     -- Bitcoin
    base58_alphabet TEXT := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    byte_value INT;
    byte_val INT;
    byte_values INT[] DEFAULT ARRAY[]::INT[];
    modulo INT;
    base_enc_string TEXT := '';
BEGIN
    FOR hex_index IN REVERSE ((length(hexstr) / 2) - 1)..0 LOOP
        byte_value := get_byte(bytes, hex_index);
        IF byte_value = 0 THEN
            leading_zeroes := leading_zeroes + 1;
        ELSE
            leading_zeroes := 0;
            num := num + (base * byte_value);
        END IF;
        base := base * 256;
    END LOOP;

    WHILE num > 0 LOOP
        modulo := num % length(base58_alphabet);
        num := div(num, length(base58_alphabet));
        byte_values := array_append(byte_values, modulo);
    END LOOP;

    FOREACH byte_val IN ARRAY byte_values
    LOOP
        base_enc_string := SUBSTRING(base58_alphabet, byte_val + 1, 1) || base_enc_string;
    END LOOP;

    base_enc_string := repeat(SUBSTRING(base58_alphabet, 1, 1), leading_zeroes) || base_enc_string;

    RETURN base_enc_string;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
