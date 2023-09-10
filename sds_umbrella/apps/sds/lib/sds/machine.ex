defmodule Sds.Machine do
  @moduledoc """
  This is a simulated SDS 940 user process simulator.
  It comprises a memory and a process queue.
  It simulates @n_instructions and then switches to the next processes
  processes is a map of integer -> process
  the queues are erlang queues
  page_allocation maps actual_page_index -> {process, virtual_page_index}
     *** _OR_ ***
  page_allocation maps actual_page_index -> nil
  """

  alias Sds.Memory
  alias Sds.Process

  defstruct processes: %{},
            memory: %Memory{},
            i_count: 0,
            p_count: 0,
            sp_count: 0,
            run_queue: :queue.new(),
            by_n_by_queue: :queue.new(),
            io_queue: :queue.new(),
            page_allocation: %{},
            this_id: 1

  def new do
    n_page_allocation =
      Enum.reduce(0..Memory.get_max_actual_page(), %{}, fn ndx, pa_map ->
        Map.put(pa_map, ndx, nil)
      end)

    %{%__MODULE__{} | page_allocation: n_page_allocation}
  end

  def add_process(%__MODULE__{} = mach, %Process{} = p, %Memory{} = mem) do
    mach |> queue_new_process(p) |> update_memory(mem) |> update_this_id()
  end

  defp queue_new_process(%__MODULE__{} = mach, %Process{} = p) do
    %{
      mach
      | processes: Map.put(mach.processes, mach.this_id, p),
        run_queue: :queue.in(mach.run_queue, p)
    }
  end

  defp update_this_id(%__MODULE__{} = mach), do: %{mach | this_id: mach.this_id + 1}

  defp update_memory(%__MODULE{} = mach, content) when is_list(content) do
    used_page_indices =
      Enum.reduce(content, fn {a, _} -> Memory.page_of(a) end)
      |> Enum.uniq()

    n_m = Enum.reduce(0..(Memory.get_max_virtual_page() - 1), mach)

    {:ok, {0, 0, 0, 0, 0, 0, 0, 0}}
  end
end
