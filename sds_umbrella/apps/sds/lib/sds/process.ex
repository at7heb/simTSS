defmodule Sds.Process do
  @moduledoc """
  a process comprises the registers, the memory and the map, and state
  instruction, memory read, and memory write counts are also available
  but not crucial to execution.
  """
  defstruct registers: {0, 0, 0, 0, 0},
            map: {},
            account: "@7hb",
            name: "",
            state: nil,
            i_count: 0,
            p_count: 0,
            sp_count: 0,
            r_count: 0,
            w_count: 0

  @n_virtual_pages 8

  @doc """
  set up registers; memory is set up when process is added to the machine
  """
  def setup(%__MODULE__{} = p, pc, a, b, x, ovf \\ 0)
      when is_tuple(map) and tuple_size(map) == @n_virtual_pages and is_list(memory) do
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
  def set_map(%__MODULE__{} - p, n_map), do: %{p | map: n_map}

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
