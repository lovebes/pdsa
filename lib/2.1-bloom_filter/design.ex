defmodule ProbabilisticBookReview.BloomFilter.Design do
  @moduledoc """
  Functions to analyze/design the bloom filter variables

  m: length of the filter (# of bits)
  n: expected size of elements to store
  k: # of hash functions

  Choice of m depends on the (estimated) number of elemenst n that are expected to be
  added, and m should be quite large compared to n.
  """

  @doc """
  This is lower bound of the probability of false positive for bloom filter.
  """
  def p_false_positive(n, m, k) do
    (1 - :math.exp(-k * n / m)) |> :math.pow(k)
  end

  @doc """
  Length of filter must grow linearly with number of elements to keep target P_fp
  """
  def filter_length_m(p_fp, n) do
    (-n * :math.log(p_fp) / (:math.log(2) |> :math.pow(2)))
    |> round()
  end

  @doc """
  Given ratio of m/n, P_fp can be tuned by minimizing it in equation of p_false_positive/3

  Since k must be an integer, the smaller sub-optimal values are preferred.
  """
  def optimal_k(n, m) do
    (m / n * :math.log(2))
    |> trunc()
  end

  @doc """
  Implementatin of Kirsch-Mitzenmacher hash function generations
  https://www.eecs.harvard.edu/~michaelm/postscripts/tr-02-05.pdf

  A technique from the hashing literature is to use two hash functions h1(x) and h2(x) to
  simulate additional hash functions of the form gi(x) = h1(x) + ih2(x).

  - Context i will range from 0 up to some number k−1
  - hash values are to be used with modulo the size of the relevant hash table

  Returns all modulo values for each "simulated" k.

  ## Examples

      iex> kirsch_mitzenmacher_hash_modulo_for_k(&Murmur.hash_x86_32/1, &Fnv1a.hash/1, "Berlin", 9, 10)
      [9, 6, 3, 0, 7, 4, 1, 8, 5]

  """
  def kirsch_mitzenmacher_hash_modulo_for_k(hash_func1, hash_func2, value, k, m) do
    0..(k - 1)
    |> Enum.map(fn i ->
      (hash_func1.(value) + i * hash_func2.(value)) |> rem(m)
    end)
  end
end
