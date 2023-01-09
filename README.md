# pg-id

Postgres function to generate sortable, prefixed, base58 IDs. E.g. `user_5xZiDpFgozVMj`.

1. It's like [Stripe prefixed IDs](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a#make-it-human-readable), but the IDs are sortable. Or...
2. Like [ULID](https://github.com/ulid/spec), but with fewer random bits, output as Base58, and with an optional prefix.

### Installation
Run [`gen_id.sql`](./gen_id.sql) or paste the SQL on the psql command line.

### Usage
``` sql
SELECT gen_id();
    gen_id
---------------
 5xZiDpFgozVMj
(1 row)
```

#### Usage with prefix
``` sql
SELECT gen_id('user');
    gen_id
---------------
 user_5xZiDpFgozVMj
(1 row)
```

### ID Format
How the base 58 ID looks like and how you can extract the timestamp (Base58 => Hex-timestamp => Milliseconds => Timestamp)
```
    acc_5xZiDpFgozVMj       Base58 (output format of the ID)
        5xZiDpFgozVMj       Base58 (if no prefix is used)
              /\
             /  \
 0185837f00de   19e63eca    Hex (same ID – after any prefix - as Base58 above, but decoded to Hex)
|------------| |--------|
   Timestamp   Randomness
     48bits      32bits
       |
       |
 1672948416734              Integer (milliseconds since epoch from hex-timestamp above)
       |
       |
 Jan. 5, 2023 19:53:36.734  Timestamp (UTC from milliseconds above)
```

### Components

**Timestamp**
- 48 bit integer
- UNIX-time in milliseconds
- Won't run out of space 'til the year 10889 AD.

**Randomness**
- 32 bits
- => 4.3 Billion IDs per millisecond

### Testing
pg-id is tested using [pgTAP](https://pgtap.org), see [`gen_id_test.sql`](./gen_id_test.sql).

### postgres-ulid
See also https://github.com/chrhansen/postgres-ulid that follows the ULID spec, but allows for output in hex, base32 (ULID default), and base58.
