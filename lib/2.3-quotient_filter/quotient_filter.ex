defmodule ProbabilisticBookReview.QuotientFilter do
  @moduledoc """
  Reasoning for use
  ------------------
  Supports basic operations of Bloom filters, with better data locality
  (meaning it is okay with when data is beyond the size of main memory)
  and requiring only a small number of contiguous disk access.

  Performance
  ------------
  Comparable permformance with Bloom filter in space and time,
  BUT ALSO:
  - supports deletions
  - dynamically resized or merged
  """

  @doc """
  Fingerprint f in algorithm is partitioned into _q_ most significant bits (the _quotient_)
  and _r_ least significant bits (the _remainder_) using the quotienting technique,
  suggested by Donald Knuth.

  Returns {f_q, f_r}, product of the quotient technique (div, rem)

  Conditions:
  ============
  * |fingerprint| > num_total_bits

  ## Explanation of metadata flags is `1` if:
  `is_occupied`: the index of the bucket list has been filled
    - it might end up somewhere to the right of the "correct" position (aka "canonical" bucket),
      but we still flip the bit at the index of the canonical bucket
    - Important!: this flag is set at the bucket at the canonical index

  `is_shifted`: Flips in the bucket in question.
    Flips to `1` whenever a bucket has to shift due to inserting new bucket into the queue.

  `is_continuation`: flips to `1` if and only if canonical bucket is occupied,
    and then a subsequent bucket falls in the same canonical bucket index.
    - This is a case for right-shifting buckets.
    - The bit flips on the bucket being inserted.

  ## Metadata flags structure
  - `<<is_occupied::1, is_continuation::1, is_shifted::1>>

  ## Glossary
  * `bucket_list`: Quotient filter
    - named this way throughout the module because suggested implementation is a list/array

  """
  @spec quotient(fingerprint :: integer(), num_total_bits :: integer(), num_q_bits :: integer()) ::
          {f_quotient :: integer(), f_remainder :: integer()}
  def quotient(fingerprint, num_total_bits, num_q_bits) do
    f = fingerprint
    q = num_q_bits
    r = num_total_bits - q

    two_pow_r = Integer.pow(2, r)

    f_r = rem(f, two_pow_r)
    f_q = div(f, two_pow_r)

    {f_q, f_r}
  end

  def hash_to_n_bit_fingerprint(hash, n) do
    r = Integer.pow(2, n)

    rem(hash, r)
  end

  # Bucket operations

  def init_bucket(value) do
    {<<0::1, 0::1, 0::1>>, value}
  end

  def update_metadata_flag({metadata, stored_value} = _bucket, type, boolean_value)
      when is_boolean(boolean_value) do
    {boolean_value
     |> boolean_to_integer()
     |> then(&set_metadata_flag(metadata, type, &1)), stored_value}
  end

  def boolean_to_integer(bool) do
    if bool, do: 1, else: 0
  end

  def set_metadata_flag(<<_is_occupied::1, rest::2>>, :is_occupied, value)
      when is_integer(value) do
    <<value::1, rest::2>>
  end

  def set_metadata_flag(
        <<is_occupied::1, _is_continuation::1, is_shifted::1>>,
        :is_continuation,
        value
      )
      when is_integer(value) do
    <<is_occupied::1, value::1, is_shifted::1>>
  end

  def set_metadata_flag(<<rest::2, _is_shifted::1>>, :is_shifted, value)
      when is_integer(value) do
    <<rest::2, value::1>>
  end

  def update_bucket_value({metadata, _value} = _bucket, new_bucket_value) do
    {metadata, new_bucket_value}
  end

  def bucket_value({_metadata, value}), do: value

  @doc """
  Checks if the value in a bucket is empty.

  In this concept, "empty" means if the value is `nil`.
  """
  def is_bucket_value_empty?({_metadata, nil}), do: true
  def is_bucket_value_empty?({_metadata, _rest}), do: false

  # bucket list functions

  def init_bucket_list(bucket_length) do
    for _n <- 1..bucket_length do
      init_bucket(nil)
    end
  end

  def bucket_at_bucket_list(bucket_list, idx) do
    bucket_list
    |> Enum.at(idx)
  end

  def size_of_bucket_list(bucket_list) do
    bucket_list |> length
  end

  def update_bucket_at(bucket_list, bucket, idx) do
    List.replace_at(bucket_list, idx, bucket)
  end

  @doc """
  Right shifts the buckets in bucket list with respective to incoming bucket index.
  Expectation is the usage of this function follows the Quotient filter
  rules for performing right shift.

  ## When to use:
  If f_q_ is the same, then there is a soft collision.

  Resolve by using this function which will put the incoming bucket into the already
  occupying position in bucket list, and then shift the original bucket
  to the next sequential position in bucket list.

  ## NOTE: this does not clean up the bucket at the previous position.
  It is the responsibility of the caller of this function to update
  the target position with a bucket. If not, the resulting bucket will
  keep that bucket in place (one at incoming index)

  ## Outcome:
  This action sets `is_continuation`, `is_shifted` bits to 1.

  """
  def right_shift_buckets(bucket_list, idx) do
    prev = bucket_list |> bucket_at_bucket_list(idx)

    i = idx + 1

    do_right_shift(bucket_list, i, bucket_at_bucket_list(bucket_list, i), prev)
  end

  defp do_right_shift(bucket_list, i, {_metadata, nil}, prev) do
    prepped_for_insert =
      prev
      |> update_metadata_flag(:is_continuation, true)
      |> update_metadata_flag(:is_shifted, true)

    bucket_list |> update_bucket_at(prepped_for_insert, i)
  end

  defp do_right_shift(bucket_list, i, curr, prev) do
    m = size_of_bucket_list(bucket_list)
    updated_bucket_list = bucket_list |> update_bucket_at(prev, i)

    prev = curr
    next_i = if i + 1 > m, do: 0, else: i + 1
    next_curr = updated_bucket_list |> bucket_at_bucket_list(next_i)
    do_right_shift(updated_bucket_list, next_i, next_curr, prev)
  end

  @doc """
  Scanning the Quotient filter to find the run

  Starts by walking backward from canonical bucket for _f_ to find the beginning of the cluster.
  As soon as the cluster's start is found,
  it goes forward again
  to find the location of the first remainder for the bucket _f_q_,
  that is the actual start of the run _r_start_.

  ## A "cluster":
  Sequence of one or more consecutive runs with no empty buckets.
  This shows these properties:
    * All clusters are immediately preceded by an empty bucket
    * `is_shifted` bit of its first value (ie. first bucket of cluster) is _never set_.

  ## Argument explanation
    * `f_q`: canonical bucet index _f_q_ of the quotient filter(`bucket_list`)
      - f_q is incremental, 0 to [whatever modulus was used] - 1
    * `bucket_list`: Quotient filter

  """
  def scan_for_run(f_q, bucket_list) do
    bucket_at_idx = bucket_at_bucket_list(bucket_list, f_q)

    r_start = get_start_of_cluster(bucket_at_idx, f_q, bucket_list)
    idx = r_start

    r_start = walk_to_get_f_q_run_start(bucket_list, f_q, idx, r_start)

    r_end = r_start + 1
    r_end = do_get_run_end(bucket_at_bucket_list(bucket_list, r_end), r_end, bucket_list)

    {r_start, r_end}
  end

  defp walk_to_get_f_q_run_start(_bucket_list, f_q, f_q, r_start) do
    r_start
  end

  defp walk_to_get_f_q_run_start(bucket_list, f_q, idx, r_start) do
    r_start = r_start + 1
    r_start = to_next_run_start(bucket_at_bucket_list(bucket_list, r_start), r_start, bucket_list)

    idx = idx + 1
    idx = to_next_canonical_bucket(bucket_at_bucket_list(bucket_list, idx), idx, bucket_list)

    walk_to_get_f_q_run_start(bucket_list, f_q, idx, r_start)
  end

  defp to_next_canonical_bucket({<<1::1, _::2>>, _value}, idx, _bucket_list) do
    idx
  end

  defp to_next_canonical_bucket(_, idx, bucket_list) do
    to_next_canonical_bucket(bucket_at_bucket_list(bucket_list, idx + 1), idx + 1, bucket_list)
  end

  defp to_next_run_start({<<_::1, 0::1, _::0>>, _value}, r_start, _bucket_list) do
    r_start
  end

  defp to_next_run_start(_, r_start, bucket_list) do
    to_next_run_start(bucket_at_bucket_list(bucket_list, r_start + 1), r_start + 1, bucket_list)
  end

  defp get_start_of_cluster({<<_::2, 1::1>>, _value}, idx, bucket_list) do
    get_start_of_cluster(bucket_at_bucket_list(bucket_list, idx - 1), idx - 1, bucket_list)
  end

  defp get_start_of_cluster(_bucket, idx, _bucket_list) do
    idx
  end

  defp do_get_run_end({<<_::1, 0::1, _::1>>, _value}, r_end, _bucket_list) do
    r_end
  end

  defp do_get_run_end(_bucket, r_end, bucket_list) do
    do_get_run_end(bucket_at_bucket_list(bucket_list, r_end + 1), r_end + 1, bucket_list)
  end
end
