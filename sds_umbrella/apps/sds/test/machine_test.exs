defmodule MachineTest do
  use ExUnit.Case
  alias Sds.Machine
  alias Sds.Memory
  alias Sds.Process

  # doctest MachineTest

  test "initial machine" do
    m = Machine.new()
    assert m != nil
    assert is_struct(m, Machine)
    mem = m.memory
    assert is_struct(mem, Memory)
    pmem = mem.pmem
    assert is_map(pmem)
    assert map_size(pmem) == 0
  end

  test "set process" do
    process = Process.setup(%Process{}, 0, 0, 0, 0)
    mem = [{0o200, 0o020_00000}, {0o201, 0o076_00210}, {0o202, 0}, {0o210, 0o76543210}]
    mach = Machine.new()
    mach1 = Machine.add_process(mach, process, mem)
    assert is_struct(mach1, Machine)
    assert :queue.is_empty(mach.run_queue)
    assert :queue.is_empty(mach.by_n_by_queue)
  end

  test "queue and dequeue processes" do
    process1 = Process.setup(%Process{}, 0, 0, 0, 0)
    process2 = Process.setup(%Process{}, 0, 0, 0, 0)
    mem = [{0o200, 0o020_00000}, {0o201, 0o076_00210}, {0o202, 0}, {0o210, 0o76543210}]
    mach = Machine.new()
    mach1 = Machine.add_process(mach, process1, mem)
            |> Machine.add_process(process2, mem)
            |> Machine.queue_process(1, :run)
            |> Machine.queue_process(2, :by_n_by)
    assert is_struct(mach1, Machine)
    refute :queue.is_empty(mach1.run_queue)
    refute :queue.is_empty(mach1.by_n_by_queue)

    mach2 = Machine.dequeue_process(mach1, 1, :run)
            |> Machine.dequeue_process(2, :by_n_by)
    assert :queue.is_empty(mach2.run_queue)
    assert :queue.is_empty(mach2.by_n_by_queue)
          end
end
