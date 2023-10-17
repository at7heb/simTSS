defmodule DivTest do
  import Bitwise

  @word_mask 0o77777777
  @sign_mask 0o40000000
  @max_int   0o37777777
  @even_mask 0o77777776
  @word_mask48 0o7777777777777777
  @sign_mask48 0o4000000000000000
  # @word_mask32 0xFFFFFFFF

  # DIV
  def div_ex(a, b, dvzr) do
    dvdnd = (a &&& @word_mask) <<< 24 ||| (b &&& @even_mask)
    udvzr = abs24(dvzr)
    udvdnd = abs48(dvdnd)
    uquot = div(div(udvdnd, 2), udvzr)
    urmdr = rem(div(udvdnd, 2), udvzr)
    signs_same = (bxor(a, dvzr) &&& @sign_mask) == 0
    pztv_dvdnd = (a &&& @sign_mask) == 0

    {new_a, new_b} =
      case {signs_same, pztv_dvdnd} do
        {true, true} -> {uquot, urmdr}
        {true, false} -> {uquot, neg24(urmdr)}
        {false, true} -> {neg24(uquot), urmdr}
        {false, false} -> {neg24(uquot), neg24(urmdr)}
      end

    # IO.puts(
    #   "regs: #{Integer.to_string(a <<< 24 ||| b, 8)} quo: #{Integer.to_string(new_a, 8)} rem #{Integer.to_string(new_b, 8)}."
    # )

    {new_a, new_b}
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
    {dvdh, dvdl, dvr, ovf, quo} = div_setup(ar, br, m)

    dvdh = dvdh - dvr &&& @word_mask
    a = %{h: dvdh, l: dvdl, d: dvr, q: quo, a: ar, b: br, m: m, o: ovf} # |> dbg

    res =
      Enum.reduce(0..22, a, fn _e, a -> div_iteration(a) end)
      |> div_cleanup()

    {res.q, res.b, res.o}
  end

  defp div_iteration(acc) do
    t =
      (acc.h &&& @word_mask) == acc.h and
        (acc.l &&& @word_mask) == acc.l and
        (acc.q &&& @word_mask) == acc.q and
        (acc.d &&& @word_mask) == acc.d

    if not t, do: throw("not 24 bits #{acc}")

    nq = (acc.q <<< 1 ||| bxor(1, acc.h >>> 23)) &&& @word_mask
    nh = (acc.h <<< 1 ||| acc.l >>> 23) &&& @word_mask
    nl = acc.l <<< 1 &&& @word_mask

    adj =
      if (nq &&& 1) != 0, do: -acc.d, else: acc.d

    nh = (nh + adj) &&& @word_mask
    # IO.puts("regs: #{Integer.to_string(nh <<< 24 ||| nl, 8)} quo: #{Integer.to_string(nq, 8)}.")
    %{acc | h: nh, l: nl, q: nq}
  end

  defp div_setup(a_reg, b_reg, mem_word) do
    quo = 0
    dvr = abs24(mem_word)
    dvdnd = (a_reg <<< 24 ||| b_reg) |> abs48
    <<dvdh::24, dvdl::24>> = <<dvdnd::48>>

    ovf =
      if dvdh > dvr or
           (dvdh == dvr and
              (dvdl != 0 or (bxor(a_reg, mem_word) &&& @sign_mask) != 0)) do
        1
      else
        0
      end

    {dvdh, dvdl, dvr, ovf, quo}
  end

  # quo = quo << 1;                                         /* shift quo */
  # if (dvdh & SIGN)                                        /* last op -? restore */
  #   dvdh = (dvdh + dvr) & DMASK;
  # else quo = quo | 1;                                     /* +, set quo bit */
  # if (TSTS (ar ^ m))                                      /* sign of quo */
  #   A = NEG (quo);
  # else A = quo;                                           /* A = quo */
  # if (TSTS (ar))                                          /* sign of rem */
  #   B = NEG (dvdh);
  # else B = dvdh;                                          /* B = rem */

  def div_cleanup(reg) do
    nq = reg.q <<< 1

    {nh, nq} =
      cond do
        (reg.h &&& @sign_mask) != 0 -> {(reg.h + reg.d) &&& @word_mask, nq}
        true -> {reg.h, nq ||| 1}
      end

    {Integer.to_string(reg.a, 8), Integer.to_string(reg.m, 8), Integer.to_string(nq, 8), 0 != (bxor(reg.a, reg.m) &&& @sign_mask)} |> dbg

    na = if (bxor(reg.a, reg.m) &&& @sign_mask) != 0, do: neg24(nq), else: nq
    nb = if (reg.a &&& @sign_mask) != 0, do: neg24(nh), else: nh
    %{reg | h: nh, q: nq, a: na, b: nb}
  end

  def div_dw(a, b, m) do
    div_dw(((a <<< 24) ||| b) &&& @word_mask48, m)
  end

  def div_dw(s_dvdnd, m) do
    # {s_dvdnd, m} |> dbg
    dvdnd = abs48(s_dvdnd)
    dvdnd_neg? = (s_dvdnd &&& @sign_mask48) != 0
    dvsr_neg? = (m &&& @sign_mask) != 0
    dvsr = ((m <<< 24) &&& @word_mask48) |> abs48()
    ovf = if dvdnd > dvsr, do: 1, else: 0
    state = {dvdnd, dvsr, 0}
    new_state = Enum.reduce(0..23, state, fn _i, s -> div_dw_iter(s) end)
    {reg, _, quo} = new_state
    # {dvdnd_neg?, dvsr_neg?} |> dbg
    {quo, rem} = case {dvdnd_neg?, dvsr_neg?} do
      {false, false} -> {quo, reg >>> 25}
      {true, false}  -> {neg24(quo), neg24(reg >>> 25)}
      {false, true}  -> {neg24(quo), reg >>> 25}
      {true, true}   -> {quo, neg24(reg >>> 25)}
    end

    # IO.puts("dw: #{Integer.to_string(dvdnd,8)} / #{Integer.to_string(dvsr>>>24, 8)} ==> #{Integer.to_string(quo, 8)} rem #{Integer.to_string(rem, 8)}")
    {quo, rem, ovf}
  end

  def div_dw_iter({dvdnd, dvsr, quo} = _state) do
    # IO.puts("#{Integer.to_string(dvdnd,8)} / #{Integer.to_string(dvsr, 8)} ==> #{Integer.to_string(quo, 8)}")
    {q_bit, sub} = if dvdnd >= dvsr, do: {1, dvsr}, else: {0, 0}
    {(dvdnd-sub) <<< 1, dvsr, (quo <<< 1) ||| q_bit}
  end

  def abs24(m) when (m &&& @sign_mask) == 0, do: m
  def abs24(m), do: neg24(m)

  def neg24(m) do
    # will be positive, so make 2s complement & return
    bxor(m, @word_mask) + 1 &&& @word_mask
  end

  def is_neg24(m), do: (m &&& @sign_mask) != 0

  def abs48(m) when (m &&& @sign_mask48) === 0, do: m
  def abs48(m), do: neg48(m)

  def neg48(m), do: bxor(m, @word_mask48) + 1 &&& @word_mask48

  def random_test(n\\500) do
    n0 = div(n, 2); n1 = n - n0
    # compr = fn {q0, r0, o0} = _a, {q1, r1, o1} = _b -> (q0 == q1 and r0 == r1 and o0 == 0 and o1 == 0) or (o0 == 1 and o1 == 1) end
    compr = fn {q0, r0, o0} = _a, {q1, r1, o1} = _b -> (q0 == q1 and r0 == r1 and o0 == 0 and o1 == 0) end
    n_rands = fn n, max -> Enum.map(1..n, fn _i -> :rand.uniform(max) end) |> Enum.sort(&(abs24(&1) <= abs24(&2))) |> List.to_tuple() end
    test_vector0 = Enum.map(1..n0, fn _i -> (a=n_rands.(3, @word_mask); {elem(a,0), elem(a,2) &&& @even_mask, elem(a,1)}) end)
    test_vector1 = Enum.map(1..n1, fn _i -> (a=n_rands.(3, @word_mask); {elem(a,0), elem(a,1) &&& @even_mask, elem(a,2)}) end)
    test_vector = test_vector0 ++ test_vector1
    test_interm = Enum.map(test_vector,
          fn v -> (a0 = DivTest.div_dw(elem(v,0), elem(v,1), elem(v,2));
                   a1 = DivTest.div_c(elem(v,0), elem(v,1), elem(v,2));
                   {compr.(a0, a1), v, a0, a1})
          end)
    Enum.filter(test_interm, fn {r, _v, _a0, _a1} = _result -> not r end)
    |> Enum.map(fn {_, p, a0, a1} = _v -> "#{problem2s(p)} #{answer2s(a0)} #{answer2s(a1)}" end)
    |> Enum.join("\n")
    |> IO.puts()
  end

  def problem2s({a, b, m} = _prob), do: "a=#{Integer.to_string(signed(a,b), 8)} m=#{Integer.to_string(signed(m),8)}"

  def answer2s({q, r, o} = _answer), do: "q=#{Integer.to_string(signed(q), 8)} r=#{Integer.to_string(signed(r), 8)} o=#{Integer.to_string(o, 8)}"

  def signed(a, b) do
    x = a <<< 24 ||| b
    cond do
      (x &&& @sign_mask48) != 0 -> (x - 0o7777777777777777 -1)
      true -> x
    end
  end

  def signed(a) do
    cond do
      (a &&& @sign_mask) != 0 -> (a - @word_mask - 1)
      true -> a
    end
  end
end

import Bitwise

DivTest.random_test(10) |> dbg

# DivTest.div_ex(0, 2, 1) |> dbg
# DivTest.div_ex(0, 2, 2) |> dbg
# DivTest.div_ex(0, 6, 2) |> dbg
# DivTest.div_ex(0, 0o10, 2) |> dbg
# DivTest.div_ex(0, 0o16, 3) |> dbg
# DivTest.div_ex(0o100, 0o25252726, 0o12525253) |> dbg

# DivTest.div_c(0, 2, 1) |> dbg
# DivTest.div_c(0, 4, 1) |> dbg
# DivTest.div_c(0, 4, 2) |> dbg
# DivTest.div_c(0, 2*21, 7) |> dbg
# DivTest.div_c(0, 2*21+1, 7) |> dbg
# DivTest.div_c(0, 2*21+2, 7) |> dbg
# DivTest.div_c(0, 2*21+3, 7) |> dbg
# DivTest.div_c(0, 2*21+4, 7) |> dbg
# DivTest.div_c(0, 2*21+5, 7) |> dbg
# DivTest.div_c(0, 2*21+6, 7) |> dbg
# DivTest.div_c(0, 2*21, 3) |> dbg

# DivTest.div_dw(0, 2, 1) # |> dbg
# DivTest.div_dw(0, 4, 1) # |> dbg
# DivTest.div_dw(0, 4, 2) # |> dbg
# DivTest.div_dw(0, 2*21, 7) # |> dbg
# DivTest.div_dw(0, 2*21+1, 7) # |> dbg
# DivTest.div_dw(0, 2*21+2, 7) # |> dbg
# DivTest.div_dw(0, 2*21+3, 7) # |> dbg
# DivTest.div_dw(0, 2*21+4, 7) # |> dbg
# DivTest.div_dw(0, 2*21+5, 7) # |> dbg
# DivTest.div_dw(0, 2*21+6, 7) # |> dbg
# DivTest.div_dw(0, 2*21, 3) # |> dbg
# t = 0o301*0o12525253 * 2
# DivTest.div_dw(t, 0o12525253)
# DivTest.div_dw(t+2, 0o12525253)
# DivTest.div_dw(t+4, 0o12525253)
# DivTest.div_ex((t >>> 24) &&& 0o7777777, t &&& 0o7777777, 0o12525253)
# DivTest.div_dw(0o301*2, 3)
# DivTest.div_dw(0, 0o16, 3)
# Enum.map(1..50, fn n -> DivTest.div_dw(0, 2*n, 3) end)
# Enum.map(1..50, fn n -> DivTest.div_dw(0, 2*n, 7) end)
# Enum.map(1..50, fn n -> DivTest.div_dw(2*n, 7) end)

# Enum.map(1..5, fn v -> IO.puts("-#{v} --> #{Integer.to_string(DivTest.neg48(v), 8)}") end)
# IO.puts("  --- Negative Dividends ---")
# Enum.map(1..50, fn n -> (DivTest.div_dw(DivTest.neg48(2*n), 7); DivTest.div_dw((2*n), 7)) end)

# Enum.map(1..50, fn n -> DivTest.div_c(0, 2*n, 7) |> dbg; DivTest.div_dw(2*n, 7) |> dbg end)
