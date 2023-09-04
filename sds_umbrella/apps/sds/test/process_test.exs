defmodule ProcessTest do
  use ExUnit.Case
  alias Sds.Process
  # doctest MemoryMemoryTest

  # defstruct registers: {0, 0, 0, 0, 0},
  #           map: {},
  #           memory: [],
  #           state: nil,
  #           i_count: 0,
  #           r_count: 0,
  #           w_count: 0

  test "initial process" do
    p = %Process{}
    assert p.registers == {0, 0, 0, 0, 0}
    assert p.map == {}
    assert p.memory == []
    assert p.i_count == 0
    assert p.r_count == 0
    assert p.w_count == 0
    assert p.state == nil
  end
end
