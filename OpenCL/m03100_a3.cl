/**
 * Author......: Jens Steube <jens.steube@gmail.com>
 * License.....: MIT
 */

#define _DES_

#include "include/constants.h"
#include "include/kernel_vendor.h"

#define DGST_R0 0
#define DGST_R1 1
#define DGST_R2 2
#define DGST_R3 3

#include "include/kernel_functions.c"
#include "OpenCL/types_ocl.c"
#include "OpenCL/common.c"

#define COMPARE_S "OpenCL/check_single_comp4.c"
#define COMPARE_M "OpenCL/check_multi_comp4.c"

#define COMPUTE_S "OpenCL/m03100s.cl"
#define COMPUTE_M "OpenCL/m03100m.cl"

#define DES_CRYPT_ENCRYPT "OpenCL/m03100_des_crypt_encrypt.cl"
#define DES_CRYPT_KEYSETUP "OpenCL/m03100_des_crypt_keysetup.cl"

#define PERM_OP(a,b,tt,n,m) \
{                           \
  tt = a >> n;              \
  tt = tt ^ b;              \
  tt = tt & m;              \
  b = b ^ tt;               \
  tt = tt << n;             \
  a = a ^ tt;               \
}

#define HPERM_OP(a,tt,n,m)  \
{                           \
  tt = a << (16 + n);       \
  tt = tt ^ a;              \
  tt = tt & m;              \
  a  = a ^ tt;              \
  tt = tt >> (16 + n);      \
  a  = a ^ tt;              \
}

#define IP(l,r,tt)                     \
{                                      \
  PERM_OP (r, l, tt,  4, 0x0f0f0f0f);  \
  PERM_OP (l, r, tt, 16, 0x0000ffff);  \
  PERM_OP (r, l, tt,  2, 0x33333333);  \
  PERM_OP (l, r, tt,  8, 0x00ff00ff);  \
  PERM_OP (r, l, tt,  1, 0x55555555);  \
}

#define FP(l,r,tt)                     \
{                                      \
  PERM_OP (l, r, tt,  1, 0x55555555);  \
  PERM_OP (r, l, tt,  8, 0x00ff00ff);  \
  PERM_OP (l, r, tt,  2, 0x33333333);  \
  PERM_OP (r, l, tt, 16, 0x0000ffff);  \
  PERM_OP (l, r, tt,  4, 0x0f0f0f0f);  \
}

__constant u32 c_SPtrans[8][64] =
{
  {
    0x02080800, 0x00080000, 0x02000002, 0x02080802,
    0x02000000, 0x00080802, 0x00080002, 0x02000002,
    0x00080802, 0x02080800, 0x02080000, 0x00000802,
    0x02000802, 0x02000000, 0x00000000, 0x00080002,
    0x00080000, 0x00000002, 0x02000800, 0x00080800,
    0x02080802, 0x02080000, 0x00000802, 0x02000800,
    0x00000002, 0x00000800, 0x00080800, 0x02080002,
    0x00000800, 0x02000802, 0x02080002, 0x00000000,
    0x00000000, 0x02080802, 0x02000800, 0x00080002,
    0x02080800, 0x00080000, 0x00000802, 0x02000800,
    0x02080002, 0x00000800, 0x00080800, 0x02000002,
    0x00080802, 0x00000002, 0x02000002, 0x02080000,
    0x02080802, 0x00080800, 0x02080000, 0x02000802,
    0x02000000, 0x00000802, 0x00080002, 0x00000000,
    0x00080000, 0x02000000, 0x02000802, 0x02080800,
    0x00000002, 0x02080002, 0x00000800, 0x00080802,
  },
  {
    0x40108010, 0x00000000, 0x00108000, 0x40100000,
    0x40000010, 0x00008010, 0x40008000, 0x00108000,
    0x00008000, 0x40100010, 0x00000010, 0x40008000,
    0x00100010, 0x40108000, 0x40100000, 0x00000010,
    0x00100000, 0x40008010, 0x40100010, 0x00008000,
    0x00108010, 0x40000000, 0x00000000, 0x00100010,
    0x40008010, 0x00108010, 0x40108000, 0x40000010,
    0x40000000, 0x00100000, 0x00008010, 0x40108010,
    0x00100010, 0x40108000, 0x40008000, 0x00108010,
    0x40108010, 0x00100010, 0x40000010, 0x00000000,
    0x40000000, 0x00008010, 0x00100000, 0x40100010,
    0x00008000, 0x40000000, 0x00108010, 0x40008010,
    0x40108000, 0x00008000, 0x00000000, 0x40000010,
    0x00000010, 0x40108010, 0x00108000, 0x40100000,
    0x40100010, 0x00100000, 0x00008010, 0x40008000,
    0x40008010, 0x00000010, 0x40100000, 0x00108000,
  },
  {
    0x04000001, 0x04040100, 0x00000100, 0x04000101,
    0x00040001, 0x04000000, 0x04000101, 0x00040100,
    0x04000100, 0x00040000, 0x04040000, 0x00000001,
    0x04040101, 0x00000101, 0x00000001, 0x04040001,
    0x00000000, 0x00040001, 0x04040100, 0x00000100,
    0x00000101, 0x04040101, 0x00040000, 0x04000001,
    0x04040001, 0x04000100, 0x00040101, 0x04040000,
    0x00040100, 0x00000000, 0x04000000, 0x00040101,
    0x04040100, 0x00000100, 0x00000001, 0x00040000,
    0x00000101, 0x00040001, 0x04040000, 0x04000101,
    0x00000000, 0x04040100, 0x00040100, 0x04040001,
    0x00040001, 0x04000000, 0x04040101, 0x00000001,
    0x00040101, 0x04000001, 0x04000000, 0x04040101,
    0x00040000, 0x04000100, 0x04000101, 0x00040100,
    0x04000100, 0x00000000, 0x04040001, 0x00000101,
    0x04000001, 0x00040101, 0x00000100, 0x04040000,
  },
  {
    0x00401008, 0x10001000, 0x00000008, 0x10401008,
    0x00000000, 0x10400000, 0x10001008, 0x00400008,
    0x10401000, 0x10000008, 0x10000000, 0x00001008,
    0x10000008, 0x00401008, 0x00400000, 0x10000000,
    0x10400008, 0x00401000, 0x00001000, 0x00000008,
    0x00401000, 0x10001008, 0x10400000, 0x00001000,
    0x00001008, 0x00000000, 0x00400008, 0x10401000,
    0x10001000, 0x10400008, 0x10401008, 0x00400000,
    0x10400008, 0x00001008, 0x00400000, 0x10000008,
    0x00401000, 0x10001000, 0x00000008, 0x10400000,
    0x10001008, 0x00000000, 0x00001000, 0x00400008,
    0x00000000, 0x10400008, 0x10401000, 0x00001000,
    0x10000000, 0x10401008, 0x00401008, 0x00400000,
    0x10401008, 0x00000008, 0x10001000, 0x00401008,
    0x00400008, 0x00401000, 0x10400000, 0x10001008,
    0x00001008, 0x10000000, 0x10000008, 0x10401000,
  },
  {
    0x08000000, 0x00010000, 0x00000400, 0x08010420,
    0x08010020, 0x08000400, 0x00010420, 0x08010000,
    0x00010000, 0x00000020, 0x08000020, 0x00010400,
    0x08000420, 0x08010020, 0x08010400, 0x00000000,
    0x00010400, 0x08000000, 0x00010020, 0x00000420,
    0x08000400, 0x00010420, 0x00000000, 0x08000020,
    0x00000020, 0x08000420, 0x08010420, 0x00010020,
    0x08010000, 0x00000400, 0x00000420, 0x08010400,
    0x08010400, 0x08000420, 0x00010020, 0x08010000,
    0x00010000, 0x00000020, 0x08000020, 0x08000400,
    0x08000000, 0x00010400, 0x08010420, 0x00000000,
    0x00010420, 0x08000000, 0x00000400, 0x00010020,
    0x08000420, 0x00000400, 0x00000000, 0x08010420,
    0x08010020, 0x08010400, 0x00000420, 0x00010000,
    0x00010400, 0x08010020, 0x08000400, 0x00000420,
    0x00000020, 0x00010420, 0x08010000, 0x08000020,
  },
  {
    0x80000040, 0x00200040, 0x00000000, 0x80202000,
    0x00200040, 0x00002000, 0x80002040, 0x00200000,
    0x00002040, 0x80202040, 0x00202000, 0x80000000,
    0x80002000, 0x80000040, 0x80200000, 0x00202040,
    0x00200000, 0x80002040, 0x80200040, 0x00000000,
    0x00002000, 0x00000040, 0x80202000, 0x80200040,
    0x80202040, 0x80200000, 0x80000000, 0x00002040,
    0x00000040, 0x00202000, 0x00202040, 0x80002000,
    0x00002040, 0x80000000, 0x80002000, 0x00202040,
    0x80202000, 0x00200040, 0x00000000, 0x80002000,
    0x80000000, 0x00002000, 0x80200040, 0x00200000,
    0x00200040, 0x80202040, 0x00202000, 0x00000040,
    0x80202040, 0x00202000, 0x00200000, 0x80002040,
    0x80000040, 0x80200000, 0x00202040, 0x00000000,
    0x00002000, 0x80000040, 0x80002040, 0x80202000,
    0x80200000, 0x00002040, 0x00000040, 0x80200040,
  },
  {
    0x00004000, 0x00000200, 0x01000200, 0x01000004,
    0x01004204, 0x00004004, 0x00004200, 0x00000000,
    0x01000000, 0x01000204, 0x00000204, 0x01004000,
    0x00000004, 0x01004200, 0x01004000, 0x00000204,
    0x01000204, 0x00004000, 0x00004004, 0x01004204,
    0x00000000, 0x01000200, 0x01000004, 0x00004200,
    0x01004004, 0x00004204, 0x01004200, 0x00000004,
    0x00004204, 0x01004004, 0x00000200, 0x01000000,
    0x00004204, 0x01004000, 0x01004004, 0x00000204,
    0x00004000, 0x00000200, 0x01000000, 0x01004004,
    0x01000204, 0x00004204, 0x00004200, 0x00000000,
    0x00000200, 0x01000004, 0x00000004, 0x01000200,
    0x00000000, 0x01000204, 0x01000200, 0x00004200,
    0x00000204, 0x00004000, 0x01004204, 0x01000000,
    0x01004200, 0x00000004, 0x00004004, 0x01004204,
    0x01000004, 0x01004200, 0x01004000, 0x00004004,
  },
  {
    0x20800080, 0x20820000, 0x00020080, 0x00000000,
    0x20020000, 0x00800080, 0x20800000, 0x20820080,
    0x00000080, 0x20000000, 0x00820000, 0x00020080,
    0x00820080, 0x20020080, 0x20000080, 0x20800000,
    0x00020000, 0x00820080, 0x00800080, 0x20020000,
    0x20820080, 0x20000080, 0x00000000, 0x00820000,
    0x20000000, 0x00800000, 0x20020080, 0x20800080,
    0x00800000, 0x00020000, 0x20820000, 0x00000080,
    0x00800000, 0x00020000, 0x20000080, 0x20820080,
    0x00020080, 0x20000000, 0x00000000, 0x00820000,
    0x20800080, 0x20020080, 0x20020000, 0x00800080,
    0x20820000, 0x00000080, 0x00800080, 0x20020000,
    0x20820080, 0x00800000, 0x20800000, 0x20000080,
    0x00820000, 0x00020080, 0x20020080, 0x20800000,
    0x00000080, 0x20820000, 0x00820080, 0x00000000,
    0x20000000, 0x20800080, 0x00020000, 0x00820080,
  }
};

__constant u32 c_skb[8][64] =
{
  {
    0x00000000, 0x00000010, 0x20000000, 0x20000010,
    0x00010000, 0x00010010, 0x20010000, 0x20010010,
    0x00000800, 0x00000810, 0x20000800, 0x20000810,
    0x00010800, 0x00010810, 0x20010800, 0x20010810,
    0x00000020, 0x00000030, 0x20000020, 0x20000030,
    0x00010020, 0x00010030, 0x20010020, 0x20010030,
    0x00000820, 0x00000830, 0x20000820, 0x20000830,
    0x00010820, 0x00010830, 0x20010820, 0x20010830,
    0x00080000, 0x00080010, 0x20080000, 0x20080010,
    0x00090000, 0x00090010, 0x20090000, 0x20090010,
    0x00080800, 0x00080810, 0x20080800, 0x20080810,
    0x00090800, 0x00090810, 0x20090800, 0x20090810,
    0x00080020, 0x00080030, 0x20080020, 0x20080030,
    0x00090020, 0x00090030, 0x20090020, 0x20090030,
    0x00080820, 0x00080830, 0x20080820, 0x20080830,
    0x00090820, 0x00090830, 0x20090820, 0x20090830,
  },
  {
    0x00000000, 0x02000000, 0x00002000, 0x02002000,
    0x00200000, 0x02200000, 0x00202000, 0x02202000,
    0x00000004, 0x02000004, 0x00002004, 0x02002004,
    0x00200004, 0x02200004, 0x00202004, 0x02202004,
    0x00000400, 0x02000400, 0x00002400, 0x02002400,
    0x00200400, 0x02200400, 0x00202400, 0x02202400,
    0x00000404, 0x02000404, 0x00002404, 0x02002404,
    0x00200404, 0x02200404, 0x00202404, 0x02202404,
    0x10000000, 0x12000000, 0x10002000, 0x12002000,
    0x10200000, 0x12200000, 0x10202000, 0x12202000,
    0x10000004, 0x12000004, 0x10002004, 0x12002004,
    0x10200004, 0x12200004, 0x10202004, 0x12202004,
    0x10000400, 0x12000400, 0x10002400, 0x12002400,
    0x10200400, 0x12200400, 0x10202400, 0x12202400,
    0x10000404, 0x12000404, 0x10002404, 0x12002404,
    0x10200404, 0x12200404, 0x10202404, 0x12202404,
  },
  {
    0x00000000, 0x00000001, 0x00040000, 0x00040001,
    0x01000000, 0x01000001, 0x01040000, 0x01040001,
    0x00000002, 0x00000003, 0x00040002, 0x00040003,
    0x01000002, 0x01000003, 0x01040002, 0x01040003,
    0x00000200, 0x00000201, 0x00040200, 0x00040201,
    0x01000200, 0x01000201, 0x01040200, 0x01040201,
    0x00000202, 0x00000203, 0x00040202, 0x00040203,
    0x01000202, 0x01000203, 0x01040202, 0x01040203,
    0x08000000, 0x08000001, 0x08040000, 0x08040001,
    0x09000000, 0x09000001, 0x09040000, 0x09040001,
    0x08000002, 0x08000003, 0x08040002, 0x08040003,
    0x09000002, 0x09000003, 0x09040002, 0x09040003,
    0x08000200, 0x08000201, 0x08040200, 0x08040201,
    0x09000200, 0x09000201, 0x09040200, 0x09040201,
    0x08000202, 0x08000203, 0x08040202, 0x08040203,
    0x09000202, 0x09000203, 0x09040202, 0x09040203,
  },
  {
    0x00000000, 0x00100000, 0x00000100, 0x00100100,
    0x00000008, 0x00100008, 0x00000108, 0x00100108,
    0x00001000, 0x00101000, 0x00001100, 0x00101100,
    0x00001008, 0x00101008, 0x00001108, 0x00101108,
    0x04000000, 0x04100000, 0x04000100, 0x04100100,
    0x04000008, 0x04100008, 0x04000108, 0x04100108,
    0x04001000, 0x04101000, 0x04001100, 0x04101100,
    0x04001008, 0x04101008, 0x04001108, 0x04101108,
    0x00020000, 0x00120000, 0x00020100, 0x00120100,
    0x00020008, 0x00120008, 0x00020108, 0x00120108,
    0x00021000, 0x00121000, 0x00021100, 0x00121100,
    0x00021008, 0x00121008, 0x00021108, 0x00121108,
    0x04020000, 0x04120000, 0x04020100, 0x04120100,
    0x04020008, 0x04120008, 0x04020108, 0x04120108,
    0x04021000, 0x04121000, 0x04021100, 0x04121100,
    0x04021008, 0x04121008, 0x04021108, 0x04121108,
  },
  {
    0x00000000, 0x10000000, 0x00010000, 0x10010000,
    0x00000004, 0x10000004, 0x00010004, 0x10010004,
    0x20000000, 0x30000000, 0x20010000, 0x30010000,
    0x20000004, 0x30000004, 0x20010004, 0x30010004,
    0x00100000, 0x10100000, 0x00110000, 0x10110000,
    0x00100004, 0x10100004, 0x00110004, 0x10110004,
    0x20100000, 0x30100000, 0x20110000, 0x30110000,
    0x20100004, 0x30100004, 0x20110004, 0x30110004,
    0x00001000, 0x10001000, 0x00011000, 0x10011000,
    0x00001004, 0x10001004, 0x00011004, 0x10011004,
    0x20001000, 0x30001000, 0x20011000, 0x30011000,
    0x20001004, 0x30001004, 0x20011004, 0x30011004,
    0x00101000, 0x10101000, 0x00111000, 0x10111000,
    0x00101004, 0x10101004, 0x00111004, 0x10111004,
    0x20101000, 0x30101000, 0x20111000, 0x30111000,
    0x20101004, 0x30101004, 0x20111004, 0x30111004,
  },
  {
    0x00000000, 0x08000000, 0x00000008, 0x08000008,
    0x00000400, 0x08000400, 0x00000408, 0x08000408,
    0x00020000, 0x08020000, 0x00020008, 0x08020008,
    0x00020400, 0x08020400, 0x00020408, 0x08020408,
    0x00000001, 0x08000001, 0x00000009, 0x08000009,
    0x00000401, 0x08000401, 0x00000409, 0x08000409,
    0x00020001, 0x08020001, 0x00020009, 0x08020009,
    0x00020401, 0x08020401, 0x00020409, 0x08020409,
    0x02000000, 0x0A000000, 0x02000008, 0x0A000008,
    0x02000400, 0x0A000400, 0x02000408, 0x0A000408,
    0x02020000, 0x0A020000, 0x02020008, 0x0A020008,
    0x02020400, 0x0A020400, 0x02020408, 0x0A020408,
    0x02000001, 0x0A000001, 0x02000009, 0x0A000009,
    0x02000401, 0x0A000401, 0x02000409, 0x0A000409,
    0x02020001, 0x0A020001, 0x02020009, 0x0A020009,
    0x02020401, 0x0A020401, 0x02020409, 0x0A020409,
  },
  {
    0x00000000, 0x00000100, 0x00080000, 0x00080100,
    0x01000000, 0x01000100, 0x01080000, 0x01080100,
    0x00000010, 0x00000110, 0x00080010, 0x00080110,
    0x01000010, 0x01000110, 0x01080010, 0x01080110,
    0x00200000, 0x00200100, 0x00280000, 0x00280100,
    0x01200000, 0x01200100, 0x01280000, 0x01280100,
    0x00200010, 0x00200110, 0x00280010, 0x00280110,
    0x01200010, 0x01200110, 0x01280010, 0x01280110,
    0x00000200, 0x00000300, 0x00080200, 0x00080300,
    0x01000200, 0x01000300, 0x01080200, 0x01080300,
    0x00000210, 0x00000310, 0x00080210, 0x00080310,
    0x01000210, 0x01000310, 0x01080210, 0x01080310,
    0x00200200, 0x00200300, 0x00280200, 0x00280300,
    0x01200200, 0x01200300, 0x01280200, 0x01280300,
    0x00200210, 0x00200310, 0x00280210, 0x00280310,
    0x01200210, 0x01200310, 0x01280210, 0x01280310,
  },
  {
    0x00000000, 0x04000000, 0x00040000, 0x04040000,
    0x00000002, 0x04000002, 0x00040002, 0x04040002,
    0x00002000, 0x04002000, 0x00042000, 0x04042000,
    0x00002002, 0x04002002, 0x00042002, 0x04042002,
    0x00000020, 0x04000020, 0x00040020, 0x04040020,
    0x00000022, 0x04000022, 0x00040022, 0x04040022,
    0x00002020, 0x04002020, 0x00042020, 0x04042020,
    0x00002022, 0x04002022, 0x00042022, 0x04042022,
    0x00000800, 0x04000800, 0x00040800, 0x04040800,
    0x00000802, 0x04000802, 0x00040802, 0x04040802,
    0x00002800, 0x04002800, 0x00042800, 0x04042800,
    0x00002802, 0x04002802, 0x00042802, 0x04042802,
    0x00000820, 0x04000820, 0x00040820, 0x04040820,
    0x00000822, 0x04000822, 0x00040822, 0x04040822,
    0x00002820, 0x04002820, 0x00042820, 0x04042820,
    0x00002822, 0x04002822, 0x00042822, 0x04042822
  }
};

#define BOX(i,n,S) (S)[(n)][(i)]

#ifndef IS_APPLE
#include DES_CRYPT_ENCRYPT
#endif

#ifndef IS_APPLE
#include DES_CRYPT_KEYSETUP
#endif

static void overwrite_at (u32 sw[16], const u32 w0, const u32 salt_len)
{
  #if defined cl_amd_media_ops
  switch (salt_len)
  {
    case  0:  sw[0] = w0;
              break;
    case  1:  sw[0] = amd_bytealign (w0, sw[0] << 24, 3);
              sw[1] = amd_bytealign (sw[1] >>  8, w0, 3);
              break;
    case  2:  sw[0] = amd_bytealign (w0, sw[0] << 16, 2);
              sw[1] = amd_bytealign (sw[1] >> 16, w0, 2);
              break;
    case  3:  sw[0] = amd_bytealign (w0, sw[0] <<  8, 1);
              sw[1] = amd_bytealign (sw[1] >> 24, w0, 1);
              break;
    case  4:  sw[1] = w0;
              break;
    case  5:  sw[1] = amd_bytealign (w0, sw[1] << 24, 3);
              sw[2] = amd_bytealign (sw[2] >>  8, w0, 3);
              break;
    case  6:  sw[1] = amd_bytealign (w0, sw[1] << 16, 2);
              sw[2] = amd_bytealign (sw[2] >> 16, w0, 2);
              break;
    case  7:  sw[1] = amd_bytealign (w0, sw[1] <<  8, 1);
              sw[2] = amd_bytealign (sw[2] >> 24, w0, 1);
              break;
    case  8:  sw[2] = w0;
              break;
    case  9:  sw[2] = amd_bytealign (w0, sw[2] << 24, 3);
              sw[3] = amd_bytealign (sw[3] >>  8, w0, 3);
              break;
    case 10:  sw[2] = amd_bytealign (w0, sw[2] << 16, 2);
              sw[3] = amd_bytealign (sw[3] >> 16, w0, 2);
              break;
    case 11:  sw[2] = amd_bytealign (w0, sw[2] <<  8, 1);
              sw[3] = amd_bytealign (sw[3] >> 24, w0, 1);
              break;
    case 12:  sw[3] = w0;
              break;
    case 13:  sw[3] = amd_bytealign (w0, sw[3] << 24, 3);
              sw[4] = amd_bytealign (sw[4] >>  8, w0, 3);
              break;
    case 14:  sw[3] = amd_bytealign (w0, sw[3] << 16, 2);
              sw[4] = amd_bytealign (sw[4] >> 16, w0, 2);
              break;
    case 15:  sw[3] = amd_bytealign (w0, sw[3] <<  8, 1);
              sw[4] = amd_bytealign (sw[4] >> 24, w0, 1);
              break;
    case 16:  sw[4] = w0;
              break;
    case 17:  sw[4] = amd_bytealign (w0, sw[4] << 24, 3);
              sw[5] = amd_bytealign (sw[5] >>  8, w0, 3);
              break;
    case 18:  sw[4] = amd_bytealign (w0, sw[4] << 16, 2);
              sw[5] = amd_bytealign (sw[5] >> 16, w0, 2);
              break;
    case 19:  sw[4] = amd_bytealign (w0, sw[4] <<  8, 1);
              sw[5] = amd_bytealign (sw[5] >> 24, w0, 1);
              break;
    case 20:  sw[5] = w0;
              break;
    case 21:  sw[5] = amd_bytealign (w0, sw[5] << 24, 3);
              sw[6] = amd_bytealign (sw[6] >>  8, w0, 3);
              break;
    case 22:  sw[5] = amd_bytealign (w0, sw[5] << 16, 2);
              sw[6] = amd_bytealign (sw[6] >> 16, w0, 2);
              break;
    case 23:  sw[5] = amd_bytealign (w0, sw[5] <<  8, 1);
              sw[6] = amd_bytealign (sw[6] >> 24, w0, 1);
              break;
    case 24:  sw[6] = w0;
              break;
    case 25:  sw[6] = amd_bytealign (w0, sw[6] << 24, 3);
              sw[7] = amd_bytealign (sw[7] >>  8, w0, 3);
              break;
    case 26:  sw[6] = amd_bytealign (w0, sw[6] << 16, 2);
              sw[7] = amd_bytealign (sw[7] >> 16, w0, 2);
              break;
    case 27:  sw[6] = amd_bytealign (w0, sw[6] <<  8, 1);
              sw[7] = amd_bytealign (sw[7] >> 24, w0, 1);
              break;
    case 28:  sw[7] = w0;
              break;
    case 29:  sw[7] = amd_bytealign (w0, sw[7] << 24, 3);
              sw[8] = amd_bytealign (sw[8] >>  8, w0, 3);
              break;
    case 30:  sw[7] = amd_bytealign (w0, sw[7] << 16, 2);
              sw[8] = amd_bytealign (sw[8] >> 16, w0, 2);
              break;
    case 31:  sw[7] = amd_bytealign (w0, sw[7] <<  8, 1);
              sw[8] = amd_bytealign (sw[8] >> 24, w0, 1);
              break;
  }
  #else
  switch (salt_len)
  {
    case  0:  sw[0] =  w0;
              break;
    case  1:  sw[0] = (sw[0] & 0x000000ff) | (w0 <<  8);
              sw[1] = (sw[1] & 0xffffff00) | (w0 >> 24);
              break;
    case  2:  sw[0] = (sw[0] & 0x0000ffff) | (w0 << 16);
              sw[1] = (sw[1] & 0xffff0000) | (w0 >> 16);
              break;
    case  3:  sw[0] = (sw[0] & 0x00ffffff) | (w0 << 24);
              sw[1] = (sw[1] & 0xff000000) | (w0 >>  8);
              break;
    case  4:  sw[1] =  w0;
              break;
    case  5:  sw[1] = (sw[1] & 0x000000ff) | (w0 <<  8);
              sw[2] = (sw[2] & 0xffffff00) | (w0 >> 24);
              break;
    case  6:  sw[1] = (sw[1] & 0x0000ffff) | (w0 << 16);
              sw[2] = (sw[2] & 0xffff0000) | (w0 >> 16);
              break;
    case  7:  sw[1] = (sw[1] & 0x00ffffff) | (w0 << 24);
              sw[2] = (sw[2] & 0xff000000) | (w0 >>  8);
              break;
    case  8:  sw[2] =  w0;
              break;
    case  9:  sw[2] = (sw[2] & 0x000000ff) | (w0 <<  8);
              sw[3] = (sw[3] & 0xffffff00) | (w0 >> 24);
              break;
    case 10:  sw[2] = (sw[2] & 0x0000ffff) | (w0 << 16);
              sw[3] = (sw[3] & 0xffff0000) | (w0 >> 16);
              break;
    case 11:  sw[2] = (sw[2] & 0x00ffffff) | (w0 << 24);
              sw[3] = (sw[3] & 0xff000000) | (w0 >>  8);
              break;
    case 12:  sw[3] =  w0;
              break;
    case 13:  sw[3] = (sw[3] & 0x000000ff) | (w0 <<  8);
              sw[4] = (sw[4] & 0xffffff00) | (w0 >> 24);
              break;
    case 14:  sw[3] = (sw[3] & 0x0000ffff) | (w0 << 16);
              sw[4] = (sw[4] & 0xffff0000) | (w0 >> 16);
              break;
    case 15:  sw[3] = (sw[3] & 0x00ffffff) | (w0 << 24);
              sw[4] = (sw[4] & 0xff000000) | (w0 >>  8);
              break;
    case 16:  sw[4] =  w0;
              break;
    case 17:  sw[4] = (sw[4] & 0x000000ff) | (w0 <<  8);
              sw[5] = (sw[5] & 0xffffff00) | (w0 >> 24);
              break;
    case 18:  sw[4] = (sw[4] & 0x0000ffff) | (w0 << 16);
              sw[5] = (sw[5] & 0xffff0000) | (w0 >> 16);
              break;
    case 19:  sw[4] = (sw[4] & 0x00ffffff) | (w0 << 24);
              sw[5] = (sw[5] & 0xff000000) | (w0 >>  8);
              break;
    case 20:  sw[5] =  w0;
              break;
    case 21:  sw[5] = (sw[5] & 0x000000ff) | (w0 <<  8);
              sw[6] = (sw[6] & 0xffffff00) | (w0 >> 24);
              break;
    case 22:  sw[5] = (sw[5] & 0x0000ffff) | (w0 << 16);
              sw[6] = (sw[6] & 0xffff0000) | (w0 >> 16);
              break;
    case 23:  sw[5] = (sw[5] & 0x00ffffff) | (w0 << 24);
              sw[6] = (sw[6] & 0xff000000) | (w0 >>  8);
              break;
    case 24:  sw[6] =  w0;
              break;
    case 25:  sw[6] = (sw[6] & 0x000000ff) | (w0 <<  8);
              sw[7] = (sw[7] & 0xffffff00) | (w0 >> 24);
              break;
    case 26:  sw[6] = (sw[6] & 0x0000ffff) | (w0 << 16);
              sw[7] = (sw[7] & 0xffff0000) | (w0 >> 16);
              break;
    case 27:  sw[6] = (sw[6] & 0x00ffffff) | (w0 << 24);
              sw[7] = (sw[7] & 0xff000000) | (w0 >>  8);
              break;
    case 28:  sw[7] =  w0;
              break;
    case 29:  sw[7] = (sw[7] & 0x000000ff) | (w0 <<  8);
              sw[8] = (sw[8] & 0xffffff00) | (w0 >> 24);
              break;
    case 30:  sw[7] = (sw[7] & 0x0000ffff) | (w0 << 16);
              sw[8] = (sw[8] & 0xffff0000) | (w0 >> 16);
              break;
    case 31:  sw[7] = (sw[7] & 0x00ffffff) | (w0 << 24);
              sw[8] = (sw[8] & 0xff000000) | (w0 >>  8);
              break;
  }
  #endif
}

#ifndef IS_APPLE
#include COMPUTE_M
#include COMPUTE_S
#endif

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_m04 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
  __local u32 s_SPtrans[8][64];
  __local u32 s_skb[8][64];

  /**
   * base
   */

  const u32 gid = get_global_id (0);
  const u32 lid = get_local_id (0);

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = 0;
  w[ 5] = 0;
  w[ 6] = 0;
  w[ 7] = 0;
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = 0;
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len;

  /**
   * sbox, kbox
   */

  s_SPtrans[0][lid] = c_SPtrans[0][lid];
  s_SPtrans[1][lid] = c_SPtrans[1][lid];
  s_SPtrans[2][lid] = c_SPtrans[2][lid];
  s_SPtrans[3][lid] = c_SPtrans[3][lid];
  s_SPtrans[4][lid] = c_SPtrans[4][lid];
  s_SPtrans[5][lid] = c_SPtrans[5][lid];
  s_SPtrans[6][lid] = c_SPtrans[6][lid];
  s_SPtrans[7][lid] = c_SPtrans[7][lid];

  s_skb[0][lid] = c_skb[0][lid];
  s_skb[1][lid] = c_skb[1][lid];
  s_skb[2][lid] = c_skb[2][lid];
  s_skb[3][lid] = c_skb[3][lid];
  s_skb[4][lid] = c_skb[4][lid];
  s_skb[5][lid] = c_skb[5][lid];
  s_skb[6][lid] = c_skb[6][lid];
  s_skb[7][lid] = c_skb[7][lid];

  barrier (CLK_LOCAL_MEM_FENCE);

  if (gid >= gid_max) return;

  /**
   * main
   */

  #ifdef IS_APPLE
  #include COMPUTE_M
  #else
  m03100m (s_SPtrans, s_skb, w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_scryptV_buf, bitmap_mask, bitmap_shift1, bitmap_shift2, salt_pos, loop_pos, loop_cnt, bfs_cnt, digests_cnt, digests_offset);
  #endif
}

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_m08 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
  __local u32 s_SPtrans[8][64];
  __local u32 s_skb[8][64];

  /**
   * base
   */

  const u32 gid = get_global_id (0);
  const u32 lid = get_local_id (0);

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = 0;
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len;

  /**
   * sbox, kbox
   */

  s_SPtrans[0][lid] = c_SPtrans[0][lid];
  s_SPtrans[1][lid] = c_SPtrans[1][lid];
  s_SPtrans[2][lid] = c_SPtrans[2][lid];
  s_SPtrans[3][lid] = c_SPtrans[3][lid];
  s_SPtrans[4][lid] = c_SPtrans[4][lid];
  s_SPtrans[5][lid] = c_SPtrans[5][lid];
  s_SPtrans[6][lid] = c_SPtrans[6][lid];
  s_SPtrans[7][lid] = c_SPtrans[7][lid];

  s_skb[0][lid] = c_skb[0][lid];
  s_skb[1][lid] = c_skb[1][lid];
  s_skb[2][lid] = c_skb[2][lid];
  s_skb[3][lid] = c_skb[3][lid];
  s_skb[4][lid] = c_skb[4][lid];
  s_skb[5][lid] = c_skb[5][lid];
  s_skb[6][lid] = c_skb[6][lid];
  s_skb[7][lid] = c_skb[7][lid];

  barrier (CLK_LOCAL_MEM_FENCE);

  if (gid >= gid_max) return;

  /**
   * main
   */

  #ifdef IS_APPLE
  #include COMPUTE_M
  #else
  m03100m (s_SPtrans, s_skb, w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_scryptV_buf, bitmap_mask, bitmap_shift1, bitmap_shift2, salt_pos, loop_pos, loop_cnt, bfs_cnt, digests_cnt, digests_offset);
  #endif
}

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_m16 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
}

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_s04 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
  __local u32 s_SPtrans[8][64];
  __local u32 s_skb[8][64];

  /**
   * base
   */

  const u32 gid = get_global_id (0);
  const u32 lid = get_local_id (0);

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = 0;
  w[ 5] = 0;
  w[ 6] = 0;
  w[ 7] = 0;
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = 0;
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len;

  /**
   * sbox, kbox
   */

  s_SPtrans[0][lid] = c_SPtrans[0][lid];
  s_SPtrans[1][lid] = c_SPtrans[1][lid];
  s_SPtrans[2][lid] = c_SPtrans[2][lid];
  s_SPtrans[3][lid] = c_SPtrans[3][lid];
  s_SPtrans[4][lid] = c_SPtrans[4][lid];
  s_SPtrans[5][lid] = c_SPtrans[5][lid];
  s_SPtrans[6][lid] = c_SPtrans[6][lid];
  s_SPtrans[7][lid] = c_SPtrans[7][lid];

  s_skb[0][lid] = c_skb[0][lid];
  s_skb[1][lid] = c_skb[1][lid];
  s_skb[2][lid] = c_skb[2][lid];
  s_skb[3][lid] = c_skb[3][lid];
  s_skb[4][lid] = c_skb[4][lid];
  s_skb[5][lid] = c_skb[5][lid];
  s_skb[6][lid] = c_skb[6][lid];
  s_skb[7][lid] = c_skb[7][lid];

  barrier (CLK_LOCAL_MEM_FENCE);

  if (gid >= gid_max) return;

  /**
   * main
   */

  #ifdef IS_APPLE
  #include COMPUTE_S
  #else
  m03100s (s_SPtrans, s_skb, w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_scryptV_buf, bitmap_mask, bitmap_shift1, bitmap_shift2, salt_pos, loop_pos, loop_cnt, bfs_cnt, digests_cnt, digests_offset);
  #endif
}

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_s08 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
  __local u32 s_SPtrans[8][64];
  __local u32 s_skb[8][64];

  /**
   * base
   */

  const u32 gid = get_global_id (0);
  const u32 lid = get_local_id (0);

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = 0;
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len;

  /**
   * sbox, kbox
   */

  s_SPtrans[0][lid] = c_SPtrans[0][lid];
  s_SPtrans[1][lid] = c_SPtrans[1][lid];
  s_SPtrans[2][lid] = c_SPtrans[2][lid];
  s_SPtrans[3][lid] = c_SPtrans[3][lid];
  s_SPtrans[4][lid] = c_SPtrans[4][lid];
  s_SPtrans[5][lid] = c_SPtrans[5][lid];
  s_SPtrans[6][lid] = c_SPtrans[6][lid];
  s_SPtrans[7][lid] = c_SPtrans[7][lid];

  s_skb[0][lid] = c_skb[0][lid];
  s_skb[1][lid] = c_skb[1][lid];
  s_skb[2][lid] = c_skb[2][lid];
  s_skb[3][lid] = c_skb[3][lid];
  s_skb[4][lid] = c_skb[4][lid];
  s_skb[5][lid] = c_skb[5][lid];
  s_skb[6][lid] = c_skb[6][lid];
  s_skb[7][lid] = c_skb[7][lid];

  barrier (CLK_LOCAL_MEM_FENCE);

  if (gid >= gid_max) return;

  /**
   * main
   */

  #ifdef IS_APPLE
  #include COMPUTE_S
  #else
  m03100s (s_SPtrans, s_skb, w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_scryptV_buf, bitmap_mask, bitmap_shift1, bitmap_shift2, salt_pos, loop_pos, loop_cnt, bfs_cnt, digests_cnt, digests_offset);
  #endif
}

__kernel void __attribute__((reqd_work_group_size (64, 1, 1))) m03100_s16 (__global pw_t *pws, __global kernel_rule_t *rules_buf, __global comb_t *combs_buf, __constant u32 * words_buf_r, __global void *tmps, __global void *hooks, __global u32 *bitmaps_buf_s1_a, __global u32 *bitmaps_buf_s1_b, __global u32 *bitmaps_buf_s1_c, __global u32 *bitmaps_buf_s1_d, __global u32 *bitmaps_buf_s2_a, __global u32 *bitmaps_buf_s2_b, __global u32 *bitmaps_buf_s2_c, __global u32 *bitmaps_buf_s2_d, __global plain_t *plains_buf, __global digest_t *digests_buf, __global u32 *hashes_shown, __global salt_t *salt_bufs, __global void *esalt_bufs, __global u32 *d_return_buf, __global u32 *d_scryptV_buf, const u32 bitmap_mask, const u32 bitmap_shift1, const u32 bitmap_shift2, const u32 salt_pos, const u32 loop_pos, const u32 loop_cnt, const u32 bfs_cnt, const u32 digests_cnt, const u32 digests_offset, const u32 combs_mode, const u32 gid_max)
{
}
