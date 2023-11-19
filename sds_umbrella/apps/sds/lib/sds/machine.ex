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
            # count of executed instructions
            i_count: 0,
            # count of executed pops
            p_count: 0,
            # count of executed syspops
            sp_count: 0,
            run_queue: :queue.new(),
            by_n_by_queue: :queue.new(),
            io_queue: :queue.new(),
            idle_queue: :queue.new(),
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
    # |> dbg()
    mach |> queue_new_process(p) |> update_memory(mem) |> update_this_id()
  end

  def queue_process(%__MODULE__{} = mach, process_id, which_queue)
      when is_integer(process_id) and is_atom(which_queue) do
    process = Map.get(mach.processes, process_id)

    cond do
      process == nil ->
        raise "unknown process #{process_id}"

      :queue.member(process_id, mach.by_n_by_queue) ->
        raise "process already queued on by_n_by queue"

      :queue.member(process_id, mach.run_queue) ->
        raise "process already queued on run queue"

      which_queue == :run ->
        handle_process_queuing(mach, process_id, :run_queue, :run_state)

      which_queue == :by_n_by ->
        handle_process_queuing(mach, process_id, :by_n_by_queue, :bynby_state)

      true ->
        raise "unknown queue #{which_queue}"
    end
  end

  def dequeue_process(%__MODULE__{} = mach, process_id, which_queue)
      when is_integer(process_id) and is_atom(which_queue) do
    queue_key =
      cond do
        which_queue == :run -> :run_queue
        which_queue == :by_n_by -> :by_n_by_queue
        true -> raise "dequeue from unknown queue: #{which_queue}"
      end

    new_process = %{Map.get(mach.processes, process_id) | state: :idle}
    new_queue = :queue.delete(process_id, Map.get(mach, queue_key))

    %{mach | processes: Map.put(mach.processes, process_id, new_process)}
    |> Map.put(queue_key, new_queue)
  end

  defp handle_process_queuing(%__MODULE__{} = mach, process_id, queue_key, state)
       when is_integer(process_id) and is_atom(queue_key) and is_atom(state) do
    the_queue = Map.get(mach, queue_key)
    new_process = %{Map.get(mach.processes, process_id) | state: state}
    new_processes = Map.put(mach.processes, process_id, new_process)
    new_queue = :queue.in(process_id, the_queue)
    Map.put(mach, queue_key, new_queue) |> Map.put(:processes, new_processes)
  end

  defp queue_new_process(%__MODULE__{} = mach, %Process{} = p) do
    %{
      mach
      | processes: Map.put(mach.processes, mach.this_id, p),
        idle_queue: :queue.in(mach.this_id, mach.idle_queue)
    }
  end

  defp update_this_id(%__MODULE__{} = mach), do: %{mach | this_id: mach.this_id + 1}

  defp update_memory(%__MODULE{} = mach, []), do: mach
  # no change if no memory to work through

  defp update_memory(%__MODULE{} = mach, content) when is_list(content) do
    # content is a list of {address, value} tuples
    # TODO this actually should be a memory function, not in Machine module!
    # |> dbg()
    used_page_indices =
      Enum.map(content, fn {a, _} -> Memory.page_of(a) end) |> Enum.uniq()

    pages_to_allocate =
      Enum.filter(0..Memory.get_max_virtual_page(), fn pg -> pg in used_page_indices end)

    # |> dbg()

    # |> dbg()
    new_mach = allocate_pages(mach, pages_to_allocate) |> set_memory(content)

    # new_process = %{Map.get(mach.processes, mach.this_id) | map: new_process_map} |> dbg
    # new_processes = Map.put(mach.processes, mach.this_id, new_process) |> dbg
    # %{mach | processes: new_processes, page_allocation: new_page_allocation} |> dbg

    new_mach
  end

  defp allocate_pages(%__MODULE__{} = mach, pages_to_allocate) do
    unallocated_pages =
      Enum.filter(Map.keys(mach.page_allocation), fn page_num ->
        Map.get(mach.page_allocation, page_num) == nil
      end)

    allocation_pairs = Enum.zip(unallocated_pages, pages_to_allocate)

    if length(allocation_pairs) != length(pages_to_allocate) do
      # This exception should not be caught; it should crash!
      raise("not enough memory")
    end

    new_machine_page_allocation =
      Enum.reduce(allocation_pairs, mach.page_allocation, fn {p_page, _}, allocation_map ->
        Map.put(allocation_map, p_page, mach.this_id)
      end)

    updated_process =
      Map.get(mach.processes, mach.this_id) |> Process.update_memory_map(allocation_pairs)

    new_processes = Map.put(mach.processes, mach.this_id, updated_process)
    %{mach | page_allocation: new_machine_page_allocation, processes: new_processes}
  end

  defp set_memory(%__MODULE__{} = mach, content) when is_list(content) and length(content) > 0 do
    # |> dbg()
    map = Map.get(mach.processes, mach.this_id) |> Map.get(:map)

    new_memory =
      Enum.reduce(content, mach.memory, fn {address, content}, mem ->
        Memory.write_mapped(mem, address, map, content)
      end)

    # |> dbg()

    %{mach | memory: new_memory}
  end
end
