defmodule CpuTest do
  use ExUnit.Case
  alias Sds.Machine
  alias Sds.Memory
  alias Sds.Process
  alias Sds.Cpu

  # doctest MachineTest

  test "initial cpu" do
    process = Process.setup(%Process{}, 0, 0, 0)
    mem = [{0o200, 0o020_00000}, {0o201, 0o076_00210}, {0o202, 0}, {0o210, 0o76543210}]
    mach = Machine.new() |> Machine.add_process(process, mem)
    pid = (:queue.head(mach.idle_queue))
    mach1 = Machine.queue_process(mach, pid, :run)
    cpu = Cpu.new(mach1, 3) #
    |> Cpu.run() # |> dbg
  end

end
