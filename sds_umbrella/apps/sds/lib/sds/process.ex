defmodule Sds.Process do
  @moduledoc """
  a process comprises the registers, the memory and the map, and state
  instruction, memory read, and memory write counts are also available
  but not crucial to execution.
  """
  defstruct registers: {0,0,0,0,0}, map: {}, memory: [], state: :nil, i_count: 0, r_count: 0, w_count: 0

  def setup(%__MODULE__{} = p, memory, map, pc, a, b, x) do
    new_registers = registers(a, b, x, pc)
    %{p | registers: new_registers, memory: memory, map: map}
  end

  @doc """
  get the specified register
  """
  def get_register(%__MODULE__{registers: r} = _process, register) when is_atom(register) and is_tuple(r) do
    case register do
      :a -> registera(r)
      :b -> registerb(r)
      :x -> registerx(r)
      :pc -> registerpc(r)
      :ovf -> registerovf(r)
    end
  end

  @doc """
  get the memory map and memory content
  """
  def get_memory_info(%__MODULE__{map: map, memory: memory} = _process), do: {memory, map}

  defp registers(a, b, x, pc, ovf \\ 0), do: {a, b, x, pc, ovf}

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
