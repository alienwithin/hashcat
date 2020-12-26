u32 digest_tp[2];

digest_tp[0] = r0;
digest_tp[1] = r1;

if (check_2 (digest_tp,
             bitmaps_buf_s1_a,
             bitmaps_buf_s1_b,
             bitmaps_buf_s2_a,
             bitmaps_buf_s2_b,
             bitmap_mask,
             bitmap_shift1,
             bitmap_shift2))
{
  int digest_pos = find_hash_2 (digest_tp, digests_cnt, &digests_buf[DIGESTS_OFFSET]);

  if (digest_pos != -1)
  {
    if ((il_pos + slice) < il_cnt)
    {
      const u32 final_hash_pos = DIGESTS_OFFSET + digest_pos;

      if (atomic_inc (&hashes_shown[final_hash_pos]) == 0)
      {
        mark_hash (plains_buf, d_return_buf, SALT_POS, digests_cnt, digest_pos, final_hash_pos, gid, il_pos + slice, 0, 0);
      }
    }
  }
}
