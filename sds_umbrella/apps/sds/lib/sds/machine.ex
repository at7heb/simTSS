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

  def add_process(%__MODULE__{} = mach, %Process{} = p, mem) when is_list(mem) do
    mach |> queue_new_process(p) |> update_memory(mem) |> update_this_id() |> dbg()
  end

  defp queue_new_process(%__MODULE__{} = mach, %Process{} = p) do
    %{
      mach
      | processes: Map.put(mach.processes, mach.this_id, p),
        run_queue: :queue.in(mach.this_id, mach.run_queue)
    }
  end

  defp update_this_id(%__MODULE__{} = mach), do: %{mach | this_id: mach.this_id + 1}

  defp update_memory(%__MODULE{} = mach, []), do: mach
  # no change if no memory to work through

  defp update_memory(%__MODULE{} = mach, content) when is_list(content) do
    # content is a list of {address, value} tuples
    #TODO this actually should be a memory function, not in Machine module!
    used_page_indices =
      Enum.map(content, fn {a, _} -> Memory.page_of(a) end)
      |> Enum.uniq() |> dbg()
    pages_to_allocate = Enum.filter(0..Memory.get_max_virtual_page(), fn pg -> pg not in used_page_indices end) |> dbg()
    new_mach = allocate_pages(mach, pages_to_allocate) |> set_memory(content) |> dbg()

    # new_process = %{Map.get(mach.processes, mach.this_id) | map: new_process_map} |> dbg
    # new_processes = Map.put(mach.processes, mach.this_id, new_process) |> dbg
    # %{mach | processes: new_processes, page_allocation: new_page_allocation} |> dbg

    new_mach
  end

  defp allocate_pages(%__MODULE__{} = mach, pages_to_allocate) do
    unallocated_pages = Enum.filter(Map.keys(mach.page_allocation), fn page_num -> Map.get(mach.page_allocation, page_num) == nil end)
    allocation_pairs = Enum.zip(unallocated_pages, pages_to_allocate)
    if length(allocation_pairs) != length(pages_to_allocate) do
      raise("not enough memory") # This exception should not be caught; it should crash!
    end
    new_machine_page_allocation = Enum.reduce(allocation_pairs, mach.page_allocation,
      fn {p_page, _}, allocation_map -> Map.put(allocation_map, p_page, mach.this_id) end)
    updated_process = Map.get(mach.processes, mach.this_id) |> Process.update_memory_map(allocation_pairs)
    new_processes = Map.put(mach.processes, mach.this_id, updated_process)
    %{mach | page_allocation: new_machine_page_allocation, processes: new_processes}
  end

  defp set_memory(%__MODULE__{} = mach, content) when is_list(content) and length(content) > 0 do
    map = Map.get(mach.processes, mach.this_id) |> Map.get(:map) |> dbg()
    new_memory = Enum.reduce(content, mach.memory, fn {address, content}, mem -> Memory.write_mapped(mem, address, map, content) end) |> dbg()
    %{mach | memory: new_memory}
  end
end
