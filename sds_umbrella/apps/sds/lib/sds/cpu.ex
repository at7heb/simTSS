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

  defstruct machine: nil, process: nil, memory: nil, i_count: 0, p_count: 0, sp_count: 0, r_count: 0

  @max_indirects 10 # 10 equals infinity!
  @word_mask 0o77777777
  @addr_mask 0o37777


  def new(%Machine{} = mach, rc \\ 1000) when is_integer(rc) do
    with  {:ok, id} <- {:ok, :queue.head(mach.run_queue)},
          {:ok, m} <- {:ok, mach.memory},
          {:ok, p} <- {:ok, Map.get(mach.processes, id)}
    do
      %__MODULE__{ machine: mach, process: p, memory: m, r_count: rc}
    end
  end

  def run(%__MODULE__{} = c) do
    # simplify things to reduce amount of garbage generated.
    registers = Process.get_registers(c.process)
    counts = Process.get_counts(c.process)
    map = Process.get_map(c.process)
    memory = c.memory
    rc = c.r_count
    {status, new_registers, new_memory, new_map, new_counts} = run(registers, memory, map, counts, rc, :continue)
  end

  def run({_, _, _, pc, _} = registers, memory, map, counts, 0, _) do
    {:quantum_expired, registers, memory, map, counts}
  end

  def run({_, _, _, pc, _} = registers, memory, map, counts, rc, :continue) do
      {mem, instruction} = fetch_instruction(pc, memory, map)
      counts = %{counts | r_count: counts.r_count + 1}
      if instruction >= 2**24 do
        raise "no assigned memory at address #{pc}"
      end
      <<sys::1, indexed::1, pop::1, opcode::6, ind::1, address::14>> = <<instruction::24>>
      # {registers, memory, map, counts, _reason} = exec940(sys, indexed, pop, opcode, ind, address, counts, registers, mem, map)
      counts = (cond do
        (sys == 0 && pop == 0) -> %{counts | i_count: counts.i_count + 1}
        (sys == 1 && pop == 1) -> %{counts | sp_count: counts.sp_count + 1}
        (sys == 0 && pop == 1) -> %{counts | p_count: counts.p_count + 1}
        true -> raise "malformed"
        # true -> raise "instruction at #{pc}: #{instruction} is malformed"
      end)
      {registers, memory, map, counts, _reason} = exec940(sys, indexed, pop, opcode, ind, address, counts, registers, mem, map)
      run(registers, memory, map, counts, rc - 1, :continue)
  end

  def run({_, _, _, pc, _} = registers, memory, map, counts, _, reason) do
    status = case reason do
      :new_mem -> :allocate_page
      _ -> :illegal_status
    end
  end

  def exec940(0, x, 0, 0o76, ind, addr, counts, registers, memory, map) do
    {count, effective_address} = get_effective_address(x, ind, addr, registers, memory, map, @max_indirects)
    counts = %{counts | r_count: counts.r_count + count}
    {memory, word} = Memory.read_mapped(memory, effective_address, map)
    if word >= 2**24 do
      raise "read unassigned memory at #{reg_pc(registers)}"
    end
    registers = set_reg_a(registers, word)
  end

  def get_effective_address(x, ind, addr, registers, _memory, _map, 0), do: raise "indirect loop #{x} #{ind} #{addr} #{registers}"
  def get_effective_address(0 = _x, 0 = _ind, addr, _registers, _memory, _map, ct), do: {@max_indirects - ct, addr}
  def get_effective_address(1 = _x, 0 = _ind, addr, registers, _memory, _map, ct), do: {@max_indirects - ct, addr + (reg_x(registers) &&& 0o37777)}
  def get_effective_address(x, 1 = _ind, addr, registers, memory, map, ct) do
    x_value = case x do
      0 -> 0
      1 -> reg_x(registers) &&& 0o37777
    end
    {new_memory, word} = Memory.read_mapped(memory, (addr + x_value) &&& 0o37777, map)
    <<_::1, x::1, _::7, ind::1, address::14>> = <<word::24>>
    get_effective_address(x, ind, addr, registers, new_memory, map, ct-1)
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
end
