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

      iex(51)> add("Berlin", 10)
      <<1, 1::size(2)>>

      iex(6)> add("Copenhagen", 10)
      <<17, 0::size(2)>>
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

  def add(x, m) do
    init = init_bit_str(m)

    add(init, x, m)
  end

  def add(orig, x, m) do
    x
    |> run_all_hash_func()
    |> map_to_modulo(m)
    |> populate_bit_str(orig, m)
    |> tap(fn r -> inspect(r, base: :binary) end)
  end
end
