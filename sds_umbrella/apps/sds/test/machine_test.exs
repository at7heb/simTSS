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
    mem = %Memory{}
    mach = Machine.new()
    mach1 = Machine.add_process(mach, process, mem)
    assert is_struct(mach1, Machine)
  end
end
