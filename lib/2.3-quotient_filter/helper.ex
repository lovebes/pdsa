defmodule ProbabilisticBookReview.QuotientFilter.Helper do
  @moduledoc """
  Helper functions for QuotientFilte

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

  def init_bucket(value \\ nil) do
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

  def flags(is_occupied, is_continuation, is_shifted)
      when is_integer(is_occupied) and is_integer(is_continuation) and is_integer(is_shifted) do
    <<is_occupied::1, is_continuation::1, is_shifted::1>>
  end
end
