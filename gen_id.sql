CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- 6 timestamp bytes (ms precision) + 4 random bytes => output as
-- gen_id() => 5xXBF6THVcCpa
-- gen_id('user') => user_5xXBF6THVcCpa
-- Read more: https://github.com/chrhansen/pg-id

CREATE OR REPLACE FUNCTION gen_id(prefix text default NULL) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    timestamp     BYTEA := E'\\000\\000\\000\\000\\000\\000';
    unix_time     BIGINT;
    ulid          BYTEA;
    return_string TEXT;
BEGIN
    -- 6 timestamp bytes
    unix_time := (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT;
    timestamp := SET_BYTE(timestamp, 0, (unix_time >> 40)::BIT(8)::INTEGER);
    timestamp := SET_BYTE(timestamp, 1, (unix_time >> 32)::BIT(8)::INTEGER);
    timestamp := SET_BYTE(timestamp, 2, (unix_time >> 24)::BIT(8)::INTEGER);
    timestamp := SET_BYTE(timestamp, 3, (unix_time >> 16)::BIT(8)::INTEGER);
    timestamp := SET_BYTE(timestamp, 4, (unix_time >> 8)::BIT(8)::INTEGER);
    timestamp := SET_BYTE(timestamp, 5, unix_time::BIT(8)::INTEGER);
    -- 4 entropy bytes (a ULID would use 10 bytes)
    ulid := timestamp || gen_random_bytes(4);

    -- Remove the leading '\x' and just keep the rest of the hex-characters
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

    -- The final encoded string
    base_enc_string TEXT := '';
BEGIN
    -- Convert 'hexstr', to the base10 ('normal' digits) 'num'
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

    -- Convert the base10-'num', to the characters in Base58
    WHILE num > 0 LOOP
        modulo := num % length(base58_alphabet);
        num := div(num, length(base58_alphabet));
        byte_values := array_append(byte_values, modulo);
    END LOOP;

    -- Convert the byte_values using characters from Base58. By prepending to
    -- 'base_enc_string' the order of 'byte_values' is reversed.
    FOREACH byte_val IN ARRAY byte_values
    LOOP
        base_enc_string := SUBSTRING(base58_alphabet, byte_val + 1, 1) || base_enc_string;
    END LOOP;

    -- Prepend first Base58-character to account for leading zeroes in 'hexstr'
    base_enc_string := repeat(SUBSTRING(base58_alphabet, 1, 1), leading_zeroes) || base_enc_string;

    RETURN base_enc_string;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
