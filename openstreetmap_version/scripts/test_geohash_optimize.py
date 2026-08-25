
import sqlite3
import os

BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'

def geohash_to_int(gh):
    val = 0
    for char in gh:
        val = (val << 5) | BASE32.index(char)
    return val

def int_to_gh(val, length):
    res = []
    for _ in range(length):
        res.append(BASE32[val & 31])
        val >>= 5
    return "".join(reversed(res))

def test_conversion():
    test_hashes = ["w4cm", "w4cmr", "w4cmrb", "s0000000"]
    for gh in test_hashes:
        i = geohash_to_int(gh)
        gh2 = int_to_gh(i, len(gh))
        print(f"{gh} -> {i} -> {gh2}")
        assert gh == gh2

def test_range_query():
    # Simulate length 7 prefix matching length 8 geohashes
    prefix = "w4cmrb1" # length 7
    start = geohash_to_int(prefix) << 5
    end = start + 31
    
    # All these should be in range
    for char in BASE32:
        gh8 = prefix + char
        val = geohash_to_int(gh8)
        assert start <= val <= end, f"Failed for {gh8}"
    
    # Something else should NOT be in range
    outside = "w4cmrb20"
    val_out = geohash_to_int(outside)
    assert not (start <= val_out <= end), f"Failed for {outside}"
    print("Range query logic verified!")

if __name__ == "__main__":
    test_conversion()
    test_range_query()
    print("All tests passed!")
