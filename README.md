# pg-id

1. Like ULID, but with fewer random bits, and output as Base58, with an optional prefix. Or;
1. Like Stripe prefixed IDs, but the IDs are lexicographically sortable.


E.g.

##### Default
```sql
select gen_id();
    gen_id
---------------
 5xZiDpFgozVMj
(1 row)
```

##### With prefix
``` sql
select gen_id('user');
    gen_id
---------------
 user_5xZiDpFgozVMj
(1 row)
```

## ID Format
```
    acc_5xZiDpFgozVMj     Base58 (output format of the ID)
        5xZiDpFgozVMj     Base58 (if no prefix is used)

 0185837f00de   19e63eca  Hex (same ID – after any prefix - as Base58 above, but decoded to Hex)
|------------| |--------|
   Timestamp   Randomness
     48bits      32bits
```

### Components

**Timestamp**
- 48 bit integer
- UNIX-time in milliseconds
- Won't run out of space 'til the year 10889 AD.

**Randomness**
- 32 bits
- => 4.3 Billion IDs per millisecond

## Testing
pg-id is tested using [pgTAP](https://pgtap.org), see [`gen_id_test.sql`](./gen_id_test.sql).
