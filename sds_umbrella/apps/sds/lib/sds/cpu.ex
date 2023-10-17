defmodule Sds.Cpu do
  @moduledoc """
  Execute some SDS 940 instructions. All syspops are simulated by elixir code.
  This returns a Cpu structure, which contains the result process and memory
  and the instruction, pop, syspop, and reduction counts.

  A reduction is a simulated instruction, pop, or syspop.

  Normally the reduction count in the returned structure will be zero.
  If it is non-zero,something happened. Could be innocent, like reading from a
  human input device, or it could be problematic, like exceeding the maximum indirection count

  The main public function is run, which starts with a process and a memory and executes rc instructions

  """
  alias Sds.Process
  alias Sds.Memory
  alias Sds.Machine

  import Bitwise

  defstruct machine: nil,
            process: nil,
            memory: nil,
            i_count: 0,
            p_count: 0,
            sp_count: 0,
            r_count: 0

  # 10 equals infinity!
  @max_indirects 10
  @word_mask 0o77777777
  @sign_mask 0o40000000
  @valu_mask 0o37777777
  @carry_mask 0o100000000
  @addr_mask 0o37777
  @expn_mask 0o777
  @expn_sign 0o400
  @expn_cmpl 0o77777000
  @word_mask48 0o7777777777777777
  @sign_mask48 0o4000000000000000

  def new(%Machine{} = mach, rc \\ 1) when is_integer(rc) do
    with {:ok, id} <- {:ok, :queue.head(mach.run_queue)},
         {:ok, m} <- {:ok, mach.memory},
         {:ok, p} <- {:ok, Map.get(mach.processes, id)} do
      %__MODULE__{machine: mach, process: p, memory: m, r_count: rc}
    end
  end

  def run(%__MODULE__{} = c) do
    # simplify things to reduce amount of garbage generated.
    registers = Process.get_registers(c.process)
    counts = Process.get_counts(c.process)
    map = Process.get_map(c.process)
    memory = c.memory
    rc = c.r_count

    {status, new_registers, new_memory, new_map, new_counts} =
      run(registers, memory, map, counts, rc, :continue)

    new_process =
      Process.set_registers(c.process, new_registers)
      |> Process.set_counts(
        new_counts.i_count,
        new_counts.p_count,
        new_counts.sp_count,
        new_counts.r_count,
        new_counts.w_count
      )
      |> Process.set_map(new_map)

    process_status =
      case status do
        :quantum_expired -> :continue
        :allocate_page -> :more_memory
        :illegal_status -> :kill_process
        :halt -> :make_zombie
      end

    # %{c | process: new_process}
    # %{c | memory: new_memory}
    {process_status, %{c | process: new_process, memory: new_memory}}
  end

  @spec run({any, any, any, any, any}, any, any, any, any, any) ::
          {:allocate_page, {any, any, any, any, any}, any, any, any}
          | {:illegal_status, {any, any, any, any, any}, any, any, any}
          | {:quantum_expired, {any, any, any, any, any}, any, any, any}
          | {:halt, {any, any, any, any, any}, any, any, any}
  def run({_, _, _, _, _} = registers, memory, map, counts, 0, :continue) do
    {:quantum_expired, registers, memory, map, counts}
  end

  def run({_, _, _, pc, _} = registers, memory, map, counts, rc, :continue)
      when pc >= 0 and pc <= @addr_mask do
    # |> dbg
    {pc, rc}
    {mem, instruction} = fetch_instruction(pc, memory, map) |> dbg
    # |> dbg
    counts = %{counts | r_count: counts.r_count + 1}
    registers |> dbg

    if instruction >= 2 ** 24 do
      raise "no assigned memory at address #{pc}"
    end

    <<sys::1, indexed::1, pop::1, opcode::6, ind::1, address::14>> = <<instruction::24>>
    # weird bug: why can't this be here & must be after this???????
    # {registers, memory, map, counts, _reason} = exec940(sys, indexed, pop, opcode, ind, address, counts, registers, mem, map)
    counts =
      cond do
        sys == 0 && pop == 0 ->
          %{counts | i_count: counts.i_count + 1}

        sys == 1 && pop == 1 ->
          %{counts | sp_count: counts.sp_count + 1}

        sys == 0 && pop == 1 ->
          %{counts | p_count: counts.p_count + 1}

        true ->
          raise "malformed"
          # true -> raise "instruction at #{pc}: #{instruction} is malformed"
      end

    {registers, memory, map, counts, reason} =
      exec940(sys, indexed, pop, opcode, ind, address, counts, registers, mem, map)

    run(registers, memory, map, counts, rc - 1, reason)
  end

  def run({_, _, _, _, _} = registers, memory, map, counts, _, reason) do
    status =
      case reason do
        :new_mem -> :allocate_page
        :halt -> :halt
        _ -> :illegal_status
      end

    {status, registers, memory, map, counts}
  end

  # LDA
  def exec940(0, x, 0, 0o76, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    registers = set_reg_a(registers, word)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # LDB
  def exec940(0, x, 0, 0o75, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    registers = set_reg_b(registers, word)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # LDX
  def exec940(0, x, 0, 0o71, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    registers = set_reg_x(registers, word)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # STA
  def exec940(0, x, 0, 0o35, ind, addr, counts, registers, memory, map) do
    {memory, counts} =
      store_memory(x, ind, addr, counts, reg_a(registers), reg_x(registers), memory, map)

    {pc_next(registers), memory, map, counts, :continue}
  end

  # STB
  def exec940(0, x, 0, 0o36, ind, addr, counts, registers, memory, map) do
    {memory, counts} =
      store_memory(x, ind, addr, counts, reg_b(registers), reg_x(registers), memory, map)

    {pc_next(registers), memory, map, counts, :continue}
  end

  # STX
  def exec940(0, x, 0, 0o37, ind, addr, counts, registers, memory, map) do
    {memory, counts} =
      store_memory(x, ind, addr, counts, reg_x(registers), reg_x(registers), memory, map)

    {pc_next(registers), memory, map, counts, :continue}
  end

  # EAX
  def exec940(0, x, 0, 0o77, ind, addr, counts, registers, memory, map) do
    # {memory, counts} =
    #   store_memory(x, ind, addr, counts, reg_x(registers), reg_x(registers), memory, map)
    {count, effective_address} =
      get_effective_address(x, ind, addr, reg_x(registers), memory, map, @max_indirects)

    counts = %{counts | r_count: counts.r_count + count + 1}
    {set_reg_x(registers, effective_address) |> pc_next(), memory, map, counts, :continue}
  end

  # XMA
  def exec940(0, x, 0, 0o62, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    {memory, counts} =
      store_memory(x, ind, addr, counts, reg_a(registers), reg_x(registers), memory, map)

    {set_reg_a(registers, word) |> pc_next(), memory, map, counts, :continue}
  end

  # BRU
  def exec940(0, x, 0, 0o01, ind, addr, counts, registers, memory, map) do
    {count, effective_address} =
      get_effective_address(x, ind, addr, reg_x(registers), memory, map, @max_indirects)

    counts = %{counts | r_count: counts.r_count + count}
    registers = set_reg_pc(registers, effective_address)
    {registers, memory, map, counts, :continue}
  end

  # ADD
  def exec940(0, x, 0, 0o55, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {new_a, new_x, new_ovf} = add(reg_a(registers), word, 0, reg_x(registers), reg_ovf(registers))
    registers = set_reg_a(registers, new_a) |> set_reg_x(new_x) |> set_reg_ovf(new_ovf)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # ADC
  def exec940(0, x, 0, 0o57, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {new_a, new_x, new_ovf} =
      add(reg_a(registers), word, reg_x(registers) >>> 23 &&& 1, reg_x(registers), 0)

    registers = set_reg_a(registers, new_a) |> set_reg_x(new_x) |> set_reg_ovf(new_ovf)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # ADM
  def exec940(0, x, 0, 0o63, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {sum, ovf} = add_simple(reg_a(registers), word, reg_ovf(registers))
    {memory, counts} = store_memory(x, ind, addr, counts, sum, reg_x(registers), memory, map)
    {set_reg_ovf(registers, ovf) |> pc_next(), memory, map, counts, :continue}
  end

  # MIN
  def exec940(0, x, 0, 0o61, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {sum, ovf} = add_simple(1, word, reg_ovf(registers))
    {memory, counts} = store_memory(x, ind, addr, counts, sum, reg_x(registers), memory, map)
    {set_reg_ovf(registers, ovf) |> pc_next(), memory, map, counts, :continue}
  end

  # SUB
  def exec940(0, x, 0, 0o54, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {new_a, new_x, new_ovf} =
      add(reg_a(registers), bxor(word, @word_mask), 1, reg_x(registers), reg_ovf(registers))

    registers = set_reg_a(registers, new_a) |> set_reg_x(new_x) |> set_reg_ovf(new_ovf)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # SUC
  def exec940(0, x, 0, 0o56, ind, addr, counts, registers, memory, map) do
    {memory, word, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if word >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    {new_a, new_x, new_ovf} =
      add(
        reg_a(registers),
        bxor(word, @word_mask),
        reg_x(registers) >>> 23 &&& 1,
        reg_x(registers),
        0
      )

    registers = set_reg_a(registers, new_a) |> set_reg_x(new_x) |> set_reg_ovf(new_ovf)
    {pc_next(registers), memory, map, counts, :continue}
  end

  # MUL
  def exec940(0, x, 0, 0o64, ind, addr, counts, registers, memory, map) do
    {memory, m0, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if m0 >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    n0 = reg_a(registers)
    {m1, n1} = {abs24(m0), abs24(n0)}
    scaled_product = 2 * m1 * n1

    signed_scaled_product =
      if (bxor(m0, n0) &&& @sign_mask) != 0 do
        neg48(scaled_product)
      else
        scaled_product
      end

    new_ovf =
      if (scaled_product &&& @sign_mask48) != 0 do
        # only if m0 = n0 = 0o40000000, then scaled_product is 0o4000000000000000
        1
      else
        reg_ovf(registers)
      end

    <<a::24, b::24>> = <<signed_scaled_product::48>>

    {set_reg_a(registers, a) |> set_reg_b(b) |> set_reg_ovf(new_ovf) |> pc_next(), memory, map,
     counts, :continue}
  end

  # DIBV
  def exec940(0, x, 0, 0o65, ind, addr, counts, registers, memory, map) do
    {memory, dvzr, counts} = load_memory(x, ind, addr, counts, registers, memory, map)

    if dvzr >= 2 ** 24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end

    dvdnd = reg_a(registers) <<< 24 ||| reg_b(registers)
    udvzr = abs24(dvzr)
    udvdnd = abs48(dvdnd)
    uquot = div(div(udvdnd, 2), udvzr)
    urmdr = rem(div(udvdnd, 2), udvzr)
    signs_same = (bxor(reg_a(registers), dvzr) &&& @sign_mask) == 0
    pztv_dvdnd = (reg_a(registers) &&& @sign_mask) == 0

    {new_a, new_b} =
      case {signs_same, pztv_dvdnd} do
        {true, true} -> {uquot, urmdr}
        {true, false} -> {uquot, neg24(urmdr)}
        {false, true} -> {neg24(uquot), urmdr}
        {false, false} -> {neg24(uquot), neg24(urmdr)}
      end
  end

  # NOP
  def exec940(0, _, 0, 0o20, _, _, counts, registers, memory, map) do
    {pc_next(registers), memory, map, counts, :continue}
  end

  # register change
  # O 46 00001    # Clear A
  # O 46 00002    # Clear B
  # O 46 00003    # Clear AB
  # 2 46 00000    # Clear X
  # 2 46 00003    # Clear A, B and X
  # o 46 oooo4    Copy A into B
  # 0 46 00010    Copy B into A
  # 0 46 00014    Exchange A into B
  # 0 46 00012    Copy B into A, Clearing B
  # o 46 00005    Copy A into B, Clearing A
  # O 46 00200    Copy X into A
  # o 46 oo4oo    Copy A into X
  # o 46 oo6oo    Exchange X and A
  # O 46 00020    Copy B into X
  # o 46 ooo4o    Copy X into B
  # 0 46 00060    Exchange X and B
  # 0 46 00122    Store Exponent
  # o 46 00140    Load Exponent
  # o 46 00160    Exchange Exponents
  # 0 46 01000    Copy negative into A
  # 0 46 Oo401    Copy A to X, clear A
  # REGISTER CHANGE
  def exec940(0, x, 0, 0o46, 0 = _ind, addr, counts, registers, memory, map) do
    {a0, b0, x0, _, _} = registers

    {a1, b1, x1} =
      case {x, addr} do
        {0, 0o0001} ->
          {0, b0, x0}

        {0, 0o0002} ->
          {a0, 0, x0}

        {0, 0o0003} ->
          {0, 0, x0}

        {1, 0o0000} ->
          {a0, b0, 0}

        {1, 0o0003} ->
          {0, 0, 0}

        {0, 0o0004} ->
          {a0, a0, x0}

        {0, 0o0010} ->
          {b0, b0, x0}

        {0, 0o0014} ->
          {b0, a0, x0}

        {0, 0o0012} ->
          {b0, 0, x0}

        {0, 0o0005} ->
          {0, a0, x0}

        {0, 0o0200} ->
          {x0, b0, x0}

        {0, 0o0400} ->
          {a0, b0, a0}

        {0, 0o0600} ->
          {x0, b0, a0}

        {0, 0o0020} ->
          {a0, b0, b0}

        {0, 0o0040} ->
          {a0, x0, x0}

        {0, 0o0060} ->
          {a0, x0, b0}

        {0, 0o0122} ->
          {a0, b0, sign_extended_exponent(b0)}

        {0, 0o0140} ->
          {a0, (b0 &&& @expn_cmpl) ||| (x0 &&& @expn_mask), x0}

        {0, 0o0160} ->
          {a0, (b0 &&& @expn_cmpl) ||| (x0 &&& @expn_mask), sign_extended_exponent(b0)}

        {0, 0o1000} ->
          {bxor(a0, @word_mask) + 1 &&& @word_mask, b0, x0}

        {0, 0o0401} ->
          {0, b0, a0}
      end

    {registers |> set_reg_a(a1) |> set_reg_b(b1) |> set_reg_x(x1) |> pc_next(), memory, map,
     counts, :continue}
  end

  # HALT
  def exec940(0, _, 0, 0o00, 0 = _, _, counts, registers, memory, map) do
    {registers |> pc_next(), memory, map, counts, :halt}
  end

  def load_memory(x, ind, addr, counts, x_reg, memory, map) do
    {count, effective_address} =
      get_effective_address(x, ind, addr, x_reg, memory, map, @max_indirects)

    # count = reads of memory due to indirection

    counts = %{counts | r_count: counts.r_count + count + 1}
    {memory, word} = Memory.read_mapped(memory, effective_address, map)
    {memory, word, counts}
  end

  def store_memory(x, ind, addr, counts, value, x_reg, memory, map) do
    {count, effective_address} =
      get_effective_address(x, ind, addr, x_reg, memory, map, @max_indirects)

    # count = reads of memory due to indirection

    counts = %{counts | w_count: counts.w_count + 1, r_count: counts.r_count + count}
    # {memory, word} = Memory.read_mapped(memory, effective_address, map)
    {effective_address, value} |> dbg
    new_memory = Memory.write_mapped(memory, effective_address, map, value)
    {new_memory, counts}
  end

  def add(a1, a2, carry, x, ovf)
      when a1 <= @word_mask and a2 <= @word_mask and carry <= 1 and x <= @word_mask do
    a3 = a1 + a2 + carry
    carry = (a3 &&& @carry_mask) >>> 24

    new_x =
      if carry == 1 do
        x ||| @sign_mask
      else
        x &&& @valu_mask
      end

    new_ovf = ovf_from_add(a1, a2, a3, ovf)

    {a3 &&& @word_mask, new_x, new_ovf}
  end

  #     {sum, ovf} = add_simple(reg_a(registers), word, reg_ovf(registers))
  def add_simple(v1, v2, ovf) do
    sum = v1 + v2 &&& @word_mask
    ovf = ovf_from_add(v1, v2, sum, ovf)
    {sum, ovf}
  end

  def ovf_from_add(a1, a2, sum, ovf) do
    ov1 = bxor(bxor(a1, a2) >>> 23, 1)
    ov2 = bxor(a1, sum) >>> 23

    if (ov1 &&& ov2) != 0 do
      1
    else
      ovf
    end
  end

  def get_effective_address(x, ind, addr, x_reg, _memory, _map, ct) when ct <= 0,
    do: raise("indirect loop #{x} #{ind} #{addr} #{x_reg}")

  def get_effective_address(0 = _x, 0 = _ind, addr, _x_reg, _memory, _map, ct),
    do: {@max_indirects - ct, addr}

  def get_effective_address(1 = _x, 0 = _ind, addr, x_reg, _memory, _map, ct),
    do: {@max_indirects - ct, addr + (x_reg &&& @addr_mask)}

  def get_effective_address(x, 1 = _ind, addr, x_reg, memory, map, ct) do
    x_value =
      case x do
        0 -> 0
        1 -> x_reg &&& @addr_mask
      end

    {new_memory, word} = Memory.read_mapped(memory, addr + x_value &&& @addr_mask, map)
    <<_::1, x::1, _::7, ind::1, address::14>> = <<word::24>>
    get_effective_address(x, ind, address, x_reg, new_memory, map, ct - 1)
  end

  def fetch_instruction(pc, memory, map) do
    Memory.read_mapped(memory, pc, map)
  end

  def reg_x(registers), do: elem(registers, 2)
  def reg_pc(registers), do: elem(registers, 3)
  def reg_a(registers), do: elem(registers, 0)
  def reg_b(registers), do: elem(registers, 1)
  def reg_ovf(registers), do: elem(registers, 4)

  def set_reg_a(registers, value), do: put_elem(registers, 0, value &&& @word_mask)
  def set_reg_b(registers, value), do: put_elem(registers, 1, value &&& @word_mask)
  def set_reg_x(registers, value), do: put_elem(registers, 2, value &&& @word_mask)
  def set_reg_pc(registers, value), do: put_elem(registers, 3, value &&& @addr_mask)
  def set_reg_ovf(registers, value), do: put_elem(registers, 4, value &&& 1)

  def pc_next(registers) do
    new_pc = reg_pc(registers) + 1 &&& @addr_mask
    set_reg_pc(registers, new_pc)
  end

  def pc_skip(registers) do
    new_pc = reg_pc(registers) + 2 &&& @addr_mask
    set_reg_pc(registers, new_pc)
  end

  defp sign_extended_exponent(exp) when is_integer(exp) do
    if (exp &&& @expn_sign) != 0 do
      (exp &&& @expn_mask) ||| @expn_cmpl
    else
      exp &&& @expn_mask
    end
  end

  defp abs24(a) when is_integer(a) and a <= @valu_mask, do: a
  defp abs24(a) when is_integer(a), do: neg24(a)
  defp neg24(a) when is_integer(a), do: bxor(a, @word_mask) + 1 &&& @word_mask
  defp abs48(a) when is_integer(a) and a < @sign_mask48, do: a
  defp abs48(a) when is_integer(a), do: neg48(a)
  defp neg48(a) when is_integer(a), do: bxor(a, @word_mask48) + 1 &&& @word_mask48
end
