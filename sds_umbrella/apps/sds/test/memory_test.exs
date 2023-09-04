defmodule MemoryTest do
  use ExUnit.Case
  alias Sds.Memory
  # doctest MemoryMemoryTest

  test "initial memory" do
    m = %Memory{}
    assert m.r_count == 0
    assert m.w_count == 0
    assert m.pmem == %{}
    assert Memory.get_memory_size() == 65536
  end

  test "write memory" do
    m = %Memory{}
    m = Enum.reduce(0..31, m, fn page, mem -> Memory.write(mem, page * 2048, page * 2048) end)
    assert m.r_count == 0
    assert m.w_count == 32
    assert Map.get(m.pmem, 16384) == 16384
  end

  test "read memory" do
    m = %Memory{}
    {m, val} = Memory.read(m, 0)
    assert val == 2 ** 32
    assert m.r_count == 1
    assert m.w_count == 0
    assert m.pmem == %{}
  end

  test "write and read" do
    m = %Memory{}
    m = Enum.reduce(0..2047, m, fn address, mem -> Memory.write(mem, address, address * 2) end)

    vals =
      Enum.map(0..2047, fn address ->
        {_, v} = Memory.read(m, address)
        v
      end)

    assert length(vals) == 2048
    assert Enum.max(vals) == 4094
    assert Enum.min(vals) == 0
    assert Enum.sum(vals) == div(2048 * 4094, 2)
    assert {m.w_count, m.r_count} == {2048, 0}

    m =
      Enum.reduce(0..2047, m, fn address, mem ->
        {m1, _} = Memory.read(mem, address)
        m1
      end)

    assert {m.w_count, m.r_count} == {2048, 2048}
  end

  test "write sequential" do
    m = %Memory{}
    count = 65536
    address_range = 0..(count - 1)
    m = Enum.reduce(address_range, m, fn address, m -> Memory.write(m, address, 2 * address) end)

    vals =
      Enum.map(address_range, fn address ->
        {_, v} = Memory.read(m, address)
        v
      end)

    assert m.w_count == count
    # I know, it doesn't need the div if no "* 2"
    assert Enum.sum(vals) == div(count * 2 * (count - 1), 2)
  end
end
