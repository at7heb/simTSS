defmodule CpuTest do
  use ExUnit.Case
  alias Sds.Machine
  alias Sds.Memory
  alias Sds.Process
  alias Sds.Cpu

  # doctest MachineTest

  test "initial cpu" do
    process = Process.setup(%Process{}, 0, 0, 0)

    mem = [
      {0o200, 0o020_00000},
      {0o201, 0o076_00310},
      {0o202, 0o046_01000},
      {0o203, 0o035_00311},
      {0o204, 0o046_00005},
      {0o205, 0o036_00312},
      {0o206, 0o046_00122},
      {0o207, 0o037_00313},
      {0o210, 0},
      {0o310, 0o76543210}
    ]

    mach = Machine.new() |> Machine.add_process(process, mem)
    pid = :queue.head(mach.idle_queue)
    mach1 = Machine.queue_process(mach, pid, :run)
    #
    cpu =
      Cpu.new(mach1, 15)
      # |> dbg
      |> Cpu.run()
  end
end
