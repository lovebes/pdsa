defmodule ProbabilisticBookReview.QuotientFilter.Scan do
  @moduledoc """
  Scanning the Quotient filter to find the run

  Starts by walking backward from canonical bucket for _f_ to find the beginning of the cluster.
  As soon as the cluster's start is found,
  it goes forward again
  to find the location of the first remainder for the bucket _f_q_,
  that is the actual start of the run _r_start_.

  Returns `{r_start, r_end}` where:
    - `r_start` is the index of bucket that is the start of the run for the canonical bucket index.
      - expect it to fall on `f_q` OR later than that index.
      - the bucket `r_start` lands on has following characteristics:
        - `is_continuation` is 0, meaning it is the start of the run
        - `is_shifted` can be 0 (if it is `f_q`) or 1 (if later than `f_q`)

    - `r_end` is the index for next bucket that is empty.

  ## A "cluster":
  Sequence of one or more consecutive runs with no empty buckets.
  This shows these properties:
    * All clusters are immediately preceded by an empty bucket
    * `is_shifted` bit of its first value (ie. first bucket of cluster) is _never set_.

  ## Argument explanation
    * `bucket_list`: Quotient filter
    * `f_q`: canonical bucet index _f_q_ of the quotient filter(`bucket_list`)
      - f_q is incremental, 0 to [whatever modulus was used] - 1

  """
  import ProbabilisticBookReview.QuotientFilter.Helper

  @doc """
  Scanning the Quotient filter to find the run

  Starts by walking backward from canonical bucket for _f_ to find the beginning of the cluster.
  As soon as the cluster's start is found,
  it goes forward again
  to find the location of the first remainder for the bucket _f_q_,
  that is the actual start of the run _r_start_.

  Returns `{r_start, r_end}` where:
    - `r_start` is the index of bucket that is the start of the run for the canonical bucket index.
      - expect it to fall on `f_q` OR later than that index.
      - the bucket `r_start` lands on has following characteristics:
        - `is_continuation` is 0, meaning it is the start of the run
        - `is_shifted` can be 0 (if it is `f_q`) or 1 (if later than `f_q`)

    - `r_end` is the index for next bucket that is empty.

  ## A "cluster":
  Sequence of one or more consecutive runs with no empty buckets.
  This shows these properties:
    * All clusters are immediately preceded by an empty bucket
    * `is_shifted` bit of its first value (ie. first bucket of cluster) is _never set_.

  ## Argument explanation
    * `bucket_list`: Quotient filter
    * `f_q`: canonical bucet index _f_q_ of the quotient filter(`bucket_list`)
      - f_q is incremental, 0 to [whatever modulus was used] - 1

  """
  def scan_for_run(bucket_list, f_q) do
    bucket_at_idx = bucket_at_bucket_list(bucket_list, f_q)

    r_start = get_start_of_cluster(bucket_at_idx, f_q, bucket_list)
    idx = r_start
    # now walk r_start and idx until idx reaches f_q,
    # making r_start land on f_q (if run starts there) or go past it to get to the correct run belonging to f_q

    r_start = walk_to_get_f_q_run_start(bucket_list, f_q, idx, r_start)

    r_end = r_start + 1
    r_end = do_get_run_end(bucket_at_bucket_list(bucket_list, r_end), r_end, bucket_list)

    {r_start, r_end}
  end

  defp get_start_of_cluster({<<_::2, 1::1>>, _value}, idx, bucket_list) do
    get_start_of_cluster(bucket_at_bucket_list(bucket_list, idx - 1), idx - 1, bucket_list)
  end

  defp get_start_of_cluster(_bucket, idx, _bucket_list) do
    idx
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

  defp to_next_run_start({<<_::1, 0::1, _::1>>, _value}, r_start, _bucket_list) do
    r_start
  end

  defp to_next_run_start(_, r_start, bucket_list) do
    to_next_run_start(bucket_at_bucket_list(bucket_list, r_start + 1), r_start + 1, bucket_list)
  end

  defp to_next_canonical_bucket({<<1::1, _::2>>, _value}, idx, _bucket_list) do
    idx
  end

  defp to_next_canonical_bucket(_, idx, bucket_list) do
    to_next_canonical_bucket(bucket_at_bucket_list(bucket_list, idx + 1), idx + 1, bucket_list)
  end

  defp do_get_run_end({<<_::1, 0::1, _::1>>, _value}, r_end, _bucket_list) do
    r_end
  end

  defp do_get_run_end(_bucket, r_end, bucket_list) do
    do_get_run_end(bucket_at_bucket_list(bucket_list, r_end + 1), r_end + 1, bucket_list)
  end
end
