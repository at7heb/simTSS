defmodule Sds.Process do
  @moduledoc """
  a process comprises the registers, the memory and the map, and state
  instruction, memory read, and memory write counts are also available
  but not crucial to execution.
  """
  defstruct registers: {0, 0, 0, 0, 0},
            map: {nil, nil, nil, nil, nil, nil, nil, nil},
            account: "@7hb",
            name: "",
            id: -1,
            # :{run|bynby|dead}_state
            state: :idle,
            # instructions executed
            i_count: 0,
            # pops executed
            p_count: 0,
            # syspops executed
            sp_count: 0,
            # memory reads
            r_count: 0,
            # memory writes
            w_count: 0

  # @n_virtual_pages 8
  @max_reg 16_777_215
  @max_pc 16_383

  # @allowable_states [:idle, :run_state, :bynby_state]

  @doc """
  set up registers; memory is set up when process is added to the machine
  """
  def setup(%__MODULE__{} = p, a \\ 0, b \\ 0, x \\ 0, pc \\ 0o200, ovf \\ 0) do
    new_registers = registers(a, b, x, pc, ovf)
    %{p | registers: new_registers}
  end

  @doc """
  get the specified register
  """
  def get_register(%__MODULE__{registers: r} = _process, register)
      when is_atom(register) and is_tuple(r) do
    case register do
      :a -> registera(r)
      :b -> registerb(r)
      :x -> registerx(r)
      :pc -> registerpc(r)
      :ovf -> registerovf(r)
    end
  end

  @doc """
  get the memory map
  """
  def get_map(%__MODULE__{map: map} = _process), do: map

  @doc """
  set the memory map
  """
  def set_map(%__MODULE__{} = p, n_map), do: %{p | map: n_map}

  def get_id(%__MODULE__{id: id} = _process), do: id

  def set_id(%__MODULE__{id: -1} = p, id) do
    %{p | id: id}
  end

  def set_id(%__MODULE__{} = _p, _id), do: raise("setting process ID a second time")

  def get_counts(%__MODULE__{} = p) do
    %{
      i_count: p.i_count,
      p_count: p.p_count,
      sp_count: p.sp_count,
      r_count: p.r_count,
      w_count: p.w_count
    }
  end

  def set_counts(%__MODULE__{} = p, i_count, p_count, sp_count, r_count, w_count) do
    %{
      p
      | i_count: i_count,
        p_count: p_count,
        sp_count: sp_count,
        r_count: r_count,
        w_count: w_count
    }
  end

  @doc """
  registers must be in range 0 <= register < max
  max is 2^24 for a, b, x
  max is 2^14 for pc
  max is 1 for ovf

  The guards are applied one at a time. This might be ugly!??!
  """

  def get_registers(%__MODULE__{registers: registers} = _p), do: registers(registers)

  def registers({a, b, x, pc, ovf}), do: registers(a, b, x, pc, ovf)

  def registers(a, b, x, pc, ovf \\ 0) when is_integer(a) and a >= 0 and a <= @max_reg,
    do: registers1(a, b, x, pc, ovf)

  def registers1(a, b, x, pc, ovf) when is_integer(b) and b >= 0 and b <= @max_reg,
    do: registers2(a, b, x, pc, ovf)

  def registers2(a, b, x, pc, ovf) when is_integer(x) and x >= 0 and x <= @max_reg,
    do: registers3(a, b, x, pc, ovf)

  def registers3(a, b, x, pc, ovf) when is_integer(pc) and pc >= 0 and pc <= @max_pc,
    do: registers4(a, b, x, pc, ovf)

  def registers4(a, b, x, pc, ovf) when is_integer(ovf) and ovf >= 0 and ovf <= 1,
    do: {a, b, x, pc, ovf}

  def update_memory_map(%__MODULE__{map: process_map} = proc, allocation_pairs) do
    # allocation_pairs: [{physical page, process page}]
    # physical page is 0..31 for a 64K memory machine.
    # process page is 0..7 since process can only access 16K
    # dbg(process_map)
    # dbg(allocation_pairs)
    reallocations =
      Enum.filter(allocation_pairs, fn {_phys, proc} -> elem(process_map, proc) != nil end)

    if length(reallocations) != 0 do
      raise("memory reallocation not implemented")
    end

    new_map =
      Enum.reduce(allocation_pairs, process_map, fn {phys, virt}, p_map ->
        put_elem(p_map, virt, phys)
      end)

    # |> dbg()

    %{proc | map: new_map}
  end

  def set_state(%__MODULE__{} = p, state) when is_atom(state) do
    if state not in [nil, :idle, :runnable] do
      raise "process state #{state} unknown"
    end

    %{p | state: state}
  end

  def get_state(%__MODULE__{state: state} = _p), do: state

  def set_registers(%__MODULE__{} = p, {a, b, x, pc, ovf} = registers)
      when a >= 0 and a <= @max_reg and b >= 0 and b <= @max_reg and
             x >= 0 and x <= @max_reg and pc >= 0 and pc <= @max_pc and ovf >= 0 and ovf <= 1 do
    %{p | registers: registers}
  end

  defp registera({a, _, _, _, _} = _registers), do: a
  defp registerb({_, b, _, _, _} = _registers), do: b
  defp registerx({_, _, x, _, _} = _registers), do: x
  defp registerpc({_, _, _, pc, _} = _registers), do: pc
  defp registerovf({_, _, _, _, o} = _registers), do: o

  # defp set_registera({} = r, a), do: put_elem(r, a, 0)
  # defp set_registerb({} = r, b), do: put_elem(r, b, 1)
  # defp set_registerx({} = r, x), do: put_elem(r, x, 2)
  # defp set_registerpc({} = r, pc), do: put_elem(r, pc, 3)
  # defp set_registerovf({} = r, ovf), do: put_elem(r, ovf, 4)
end
