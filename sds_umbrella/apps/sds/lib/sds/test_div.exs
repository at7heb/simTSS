defmodule DivTest do

  import Bitwise

@word_mask 0o77777777
@sign_mask 0o40000000
@word_mask48 0o7777777777777777
@sign_mask48 0o4000000000000000
@word_mask32 0xffffffff

# DIV
  def div_ex(a, b, dvzr) do
    dvdnd = ((a &&& @word_mask) <<< 24) ||| (b &&& @word_mask)
    udvzr = abs24(dvzr)
    udvdnd = abs48(dvdnd)
    uquot = div(div(udvdnd,2), udvzr)
    urmdr = rem(div(udvdnd,2), udvzr)
    signs_same = (bxor(reg_a(registers), dvzr) &&& @sign_mask) == 0
    pztv_dvdnd = (reg_a(registers) &&& @sign_mask) == 0
    {new_a, new_b} = case {signs_same, pztv_dvdnd} do
      {true, true} -> {uquot, urmdr}
      {true, false} -> {uquot, neg24(urmdr)}
      {false, true} -> {neg24(uquot), urmdr}
      {false, false} -> {neg24(uquot), neg24(urmdr)}
    end
  end

  @doc """
  void Div48 (uint32 ar, uint32 br, uint32 m)
{
int32 i;
uint32 quo = 0;                                         /* quotient */
uint32 dvdh = ar, dvdl = br;                            /* dividend */
uint32 dvr = ABS (m);                                   /* make dvr pos */

if (TSTS (dvdh)) {                                      /* dvd < 0? */
    dvdl = (((dvdl ^ DMASK) + 2) & (DMASK & ~1)) |      /* 23b negate */
        (dvdl & 1);                                     /* low bit unch */
    dvdh = ((dvdh ^ DMASK) + (dvdl <= 1)) & DMASK;
    }
if ((dvdh > dvr) ||                                     /* divide fail? */
   ((dvdh == dvr) && dvdl) ||
   ((dvdh == dvr) && !TSTS (ar ^ m)))
   OV = 1;
dvdh = (dvdh - dvr) & DMASK;                            /* initial sub */
for (i = 0; i < 23; i++) {                              /* 23 iterations */
    quo = (quo << 1) | ((dvdh >> 23) ^ 1);              /* quo bit = ~sign */
    dvdh = ((dvdh << 1) | (dvdl >> 23)) & DMASK;        /* shift divd */
    dvdl = (dvdl << 1) & DMASK;
    if (quo & 1)                                        /* test ~sign */
        dvdh = (dvdh - dvr) & DMASK;                    /* sign was +, sub */
    else dvdh = (dvdh + dvr) & DMASK;                   /* sign was -, add */
    }
quo = quo << 1;                                         /* shift quo */
if (dvdh & SIGN)                                        /* last op -? restore */
    dvdh = (dvdh + dvr) & DMASK;
else quo = quo | 1;                                     /* +, set quo bit */
if (TSTS (ar ^ m))                                      /* sign of quo */
    A = NEG (quo);
else A = quo;                                           /* A = quo */
if (TSTS (ar))                                          /* sign of rem */
    B = NEG (dvdh);
else B = dvdh;                                          /* B = rem */
return;
}
  """
  def div_c(ar, br, m) do
    quo = 0
    dvdh = ar; dvdl = br
    dvr = abs24(m)

    {dvdh, dvdl} = if is_neg24(dvdh) do
      lt =0
    end
  end

  def abs24(m) when (m &&& @sign_mask) == 0, do: m
  def abs24(m), do: neg24(m)

  def neg24(m) do
    if (m &&& @sign_mask) == 0 do
      -m # positive, so just negate to get equiv of 32 bits
    else
      # will be positive, so make 2s complement & return
      (bxor(m, @word_mask) + 1) &&& @word_mask
    end
  end

  def is_neg24(a), do: (a &&& @sign_mask) != 0
end
