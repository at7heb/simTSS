defmodule Sds.Memory do
  @moduledoc """
  Provide the memory for the 940, with the specified number of pages
  Each memory word is an integer between 0 and 16777215 inclusive.
  Reads of unassigned memory return 2^32; it is up to the caller to handle properly
  Illegal addresses will cause exceptions
  The value written to memory must be within the given range. Out of range values
  will cause exceptions

  There are two interfaces
  * read/write with a raw address in the range of @n_pages * @page_size
  * read/write with a memory map and an address

  There is also a method to delete a page for use when the OS releases a page
  """
  defstruct r_count: 0, w_count: 0, pmem: %{}

  @n_pages 32
  @n_virtual_pages 8
  @page_size 2048
  @max_virtual_address 16383

  @doc """
  return the memory size in words
  """
  def get_memory_size, do: @n_pages * @page_size

  def get_max_virtual_page, do: @n_virtual_pages - 1

  def get_max_actual_page, do: @n_pages - 1

  @doc """
  read a value given absolute addressing of the @n_pages memory. Keep track of # of reads.
  """
  def read(%__MODULE__{} = mem, address)
      when is_integer(address) and address >= 0 and address < @n_pages * @page_size do
    new_r_count = mem.r_count + 1
    new_mem = %{mem | r_count: new_r_count}
    content = Map.get(mem.pmem, address, 2 ** 32)
    {new_mem, content}
  end

  @doc """
  write a value to a given absolute address of the @n_pages memory. Track # of writes
  16777216
  """
  def write(%__MODULE__{} = mem, address, content)
      when is_integer(address) and address >= 0 and address < @n_pages * @page_size and
             is_integer(content) and content >= 0 and content < 256 * 256 * 256 do
    new_w_count = mem.w_count + 1
    new_pmem = Map.put(mem.pmem, address, content)
    %{mem | w_count: new_w_count, pmem: new_pmem}
  end

  @doc """
  read a value given a memory map and an address.
  The memory map is a tuple with 8 integers, representing the 8 pages of the SDS 940 hardware.
  An unassigned page is represented by -1; legal page numbers are 0 <= page_number < @n_pages
  The virtual address is in the range [0, 16383]

  exceptions for out of range parameters will happen through guards in the called functions
  """
  def read_mapped(%__MODULE__{} = mem, v_address, map) do
    absolute_address = get_absolute_address(v_address, map)
    read(mem, absolute_address)
  end

  @doc """
  write a value into memory at the given virtual address
  """
  def write_mapped(%__MODULE__{} = mem, v_address, map, content) do
    absolute_address = get_absolute_address(v_address, map)
    write(mem, absolute_address, content)
  end

  def set_up(%__MODULE__{pmem: pmem} = mem, map, content) when is_list(content) do
    #
    n_pmem =
      Enum.reduce(content, pmem, fn {a, c}, m -> Map.put(m, get_absolute_address(map, a), c) end)
  end

  @doc """
  get the virtual page index (0..7) of the virtual address
  """
  def page_of(a) when is_integer(a) and a >= 0 and a <= @max_virtual_address,
    do: div(a, @page_size)

  # @doc """
  # translate a mapped virtual address into an absolute address
  # """
  defp get_absolute_address(v_address, map)
       when is_integer(v_address) and v_address >= 0 and v_address < @n_virtual_pages * @page_size and
              is_tuple(map) and tuple_size(map) == @n_virtual_pages do
    v_page = div(v_address, @page_size)
    address_in_page = rem(v_address, @page_size)
    p_page = elem(map, v_page)
    # the return value
    p_page * @page_size + address_in_page
  end
end
