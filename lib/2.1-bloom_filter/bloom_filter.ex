defmodule ProbabilisticBookReview.BloomFilter do
  @moduledoc """
  Bloom filter search:
    Search time complexity: O(1)
      - total hashing takes K times, one per hash, assuming constant-time hash algorithm
      - O(1) lookup in filter
      *** NOT dependent on data size! Amazing

  Postgres indexing algorithm: CREATE INDEX => uses B-tree typically.

    Assuming data to lookup isn't the primary key,
    Using B-tree on the index will mean the data is something sortable.
    = self-balancing tree data structure

    Search time complexity: O(log n)

  ## Examples

      iex> ProbabilisticBookReview.BloomFilter.add("Rome", 10)
      <<2, 0::size(2)>>

      iex> add("Berlin", 10)
      <<1, 1::size(2)>>

      iex> add("Copenhagen", 10)
      <<17, 0::size(2)>>

      iex> filter = add("Dublin", 10)
      iex> filter = add(filter, "Copenhagen")
      iex> test(filter, "Rome")
      false
      iex> test(filter, "Dublin")
      true

  """
  use Bitwise
  import ProbabilisticBookReview.BinaryHelper

  @hash_funcs [&Murmur.hash_x86_32/1, &Fnv1a.hash/1]

  def run_all_hash_func(x) do
    for hash_func <- @hash_funcs do
      hash_func.(x)
    end
  end

  def map_to_modulo(hash_output_list, m) do
    hash_output_list
    |> Enum.map(&rem(&1, m))
  end

  def populate_bit_str(idx_list, prev_bitstring, m) do
    idx_list
    |> Enum.reduce(prev_bitstring, fn curr, acc ->
      bor_bitstring(acc, mark_bit_str(acc, curr), m)
    end)
  end

  def add(x, m) when is_binary(x) and is_integer(m) do
    init = init_bit_str(m)

    add(init, x)
  end

  def add(orig, x) when is_bitstring(orig) and is_binary(x) do
    m = bit_size(orig)

    get_bit_array(x, m)
    |> populate_bit_str(orig, m)
    |> tap(fn r -> to_list(r) |> IO.inspect(label: "final added") end)
  end

  defp get_bit_array(x, m) do
    x
    |> run_all_hash_func()
    |> map_to_modulo(m)
  end

  def test(filter, x) do
    m = bit_size(filter)

    x
    |> get_bit_array(m)
    |> bits_in_filter?(filter)
  end

  def bits_in_filter?(modulo_list, filter) do
    init_bit_str =
      filter
      |> bit_size()
      |> init_bit_str()

    padded_filter =
      filter
      |> IO.inspect(label: "filter")
      |> tap(fn r -> to_list(r) |> IO.inspect(label: "filter") end)
      |> pad_to_binary()
      |> :binary.decode_unsigned()

    padded_hashed =
      modulo_list
      |> Enum.reduce(init_bit_str, fn curr, acc ->
        mark_bit_str(acc, curr)
      end)
      |> IO.inspect(label: "hashed value to compare")
      |> tap(fn r -> to_list(r) |> IO.inspect(label: "hashed modulo list") end)
      |> pad_to_binary()
      |> :binary.decode_unsigned()

    padded_hashed == (padded_hashed &&& padded_filter)
  end

  @doc """
  Count unique elements in the filter.
  Due to nature of false positives of Bloom filters, this is an estimate.

  Since identical elemtns added into the filter won't change the number of bits,
  this will return estimation for number of unique elements, otherwise known
  as `cardinality`.

  This is an extension of Linear Counting algorithm.
  """
  def unique_elements(filter, k) do
    m = bit_size(filter)
    counted = for(<<bit::1 <- filter>>, do: bit) |> Enum.sum()

    cond do
      counted < k -> 0
      counted == k -> 1
      counted == m -> m / k
      true -> -m / k * :math.log(1 - counted / m)
    end
    |> round()
  end
end
