defmodule Sds.Machine do
  @moduledoc """
  This is a simulated SDS 940 user process simulator.
  It comprises a memory and a process queue.
  It simulates @n_instructions and then switches to the next processes
  """

  alias Sds.Memory
  alias Sds.Process

  defstruct processes: [],
            memory: %Memory{},
            i_count: 0,
            p_count: 0,
            sp_count: 0,
            run_queue: :queue.new(),
            by_n_by_queue: :queue.new(),
            io_queue: :queue.new()

  def new, do: %__MODULE__{}

  def add_process(%__MODULE__{} = mach, %Process{} = p, %Memory{} = mem) do
    {n_memory, map} = update_memory(mach.memory, mem)
    new_p = Process.set_map(p, map)
    n_processes = [new_p | mach.processes]
    n_run_queue = :queue.in(mach.run_queue, new_p)
    %{mach | processes: n_processes, run_queue: n_run_queue, memory: n_memory}
  end

  defp update_memory(%Memory{} = mm, content) when is_list(content) do
    {mm, {0, 0, 0, 0, 0, 0, 0, 0}}
  end
end
