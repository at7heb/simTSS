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
        run_queue: :queue.in(mach.run_queue, mach.this_id)
    }
  end

  defp update_this_id(%__MODULE__{} = mach), do: %{mach | this_id: mach.this_id + 1}

  defp update_memory(%__MODULE{} = mach, content) when is_list(content) do
    used_page_indices =
      Enum.reduce(content, fn {a, _} -> Memory.page_of(a) end)
      |> Enum.uniq()
    unallocated_pages = get_unallocated_pages(mach.page_allocation)
    # unallocated_pages are the virtual pages that are not allocated yet.
    new_page_allocation = Enum.reduce(unallocated_pages, mach.page_allocation, fn virtual_page, page_alloc -> allocate_page(virtual_page, page_alloc, mach.this_id) end)
    # new_page_allocation is
    this_process_page_allocation = Enum.filter(0..Memory.get_max_actual_page(), fn pg -> Map.get(new_page_allocation, pg) == {mach.this_id, _} end)
    # this is a list of the actual page numbers. need to make list of {virtual, actual} tuples and update the processes's map
    va_list = Enum.map(this_process_page_allocation, fn ndx -> {elem(Map.get(new_page_allocation, ndx), 1), ndx} end)
    new_process_map = Enum.reduce(va_list, Map.get(mach.processes, mach.this_id),
      fn {virt, actual}, map -> put_elem(map, virt, actual)
    end)
    new_process = %{Map.get(mach.processes, mach.this_id) | map: new_process_map}
    new_processes = Map.put(mach.processes, mach.this_id, new_process)
    %{mach | processes: new_processes, page_allocation: new_page_allocation}
  end

  defp get_unallocated_pages(page_allocation) do

  end
end
