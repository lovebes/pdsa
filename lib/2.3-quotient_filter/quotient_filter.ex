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
  Right shifts the buckets in queue with respective to incoming bucket index.

  ## When to use:
  If f_q_ is the same, then there is a soft collision.

  Resolve by using this function which will put the incoming bucket into the already
  occupying position in queue, and then shift the original bucket
  to the next sequential position in queue.

  ## NOTE: this does not clean up the bucket at the previous position.
  It is the responsibility of the caller of this function to update
  the target position with a bucket. If not, the resulting bucket will
  keep that bucket in place (one at incoming index)

  ## Outcome:
  This action sets `is_continuation`, `is_shifted` bits to 1.

  """
  def right_shift_queue(bucket_list, idx) do
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
end
