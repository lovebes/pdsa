defmodule ProbabilisticBookReview.QuotientFilterTest do
  use ExUnit.Case, async: true
  import ProbabilisticBookReview.QuotientFilter
  import ProbabilisticBookReview.QuotientFilter.Helper

  setup do
    total_bits = 32
    f = Murmur.hash_x86_32("Copenhagen")
    q = 3
    {f_q, f_r} = quotient(f, total_bits, q)
    [f_q: f_q, f_r: f_r]
  end

  describe "right_shift_buckets" do
    test "should not shift if bucket spot in queue is nil", %{f_q: _f_q, f_r: f_r} do
      bucket1 = init_bucket(f_r + 1)
      bucket2 = init_bucket(f_r + 2)
      bucket3 = init_bucket(f_r + 3)
      bucket4 = init_bucket(f_r + 4)

      bucket_list =
        init_bucket_list(8)
        |> update_bucket_at(bucket1, 0)
        |> update_bucket_at(bucket2, 2)

      right_shift_buckets(bucket_list, 0)
      |> update_bucket_at(bucket3, 0)
      |> right_shift_buckets(0)
      |> update_bucket_at(bucket4, 0)
    end
  end
end
