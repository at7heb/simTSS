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

  @n_virtual_pages 8

  test "initial process" do
    p = %Process{}
    assert p.registers == {0, 0, 0, 0, 0}
    assert is_tuple(p.map)
    assert tuple_size(p.map) == @n_virtual_pages
    assert p.i_count == 0
    assert p.r_count == 0
    assert p.w_count == 0
    assert p.state == nil
  end

  test "setup process" do
    p = %Process{}
    new_p = Process.setup(p, 0, 0, 0, 0o400)
    assert new_p.registers == {0, 0, 0, 0o400, 0}
    assert tuple_size(new_p.map) == @n_virtual_pages
  end
end
