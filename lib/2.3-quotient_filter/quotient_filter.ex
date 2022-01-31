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

  import ProbabilisticBookReview.QuotientFilter.Helper

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
end
