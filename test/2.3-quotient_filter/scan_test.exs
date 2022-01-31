defmodule ProbabilisticBookReview.QuotientFilter.ScanTest do
  use ExUnit.Case, async: true
  import ProbabilisticBookReview.QuotientFilter.Scan
  import ProbabilisticBookReview.QuotientFilter.Helper

  setup do
    total_bits = 32
    f = Murmur.hash_x86_32("Copenhagen")
    q = 3
    {f_q, f_r} = quotient(f, total_bits, q)
    [f_q: f_q, f_r: f_r]
  end

  describe "scan_for_run/2" do
    test "correctly scans for a run" do
      # idx 1-5 is a cluster (inclusive)
      # idx 1-3 is a run (inclusive)
      # idx 4, idx 5 are single element runs
      bucket_list = [
        init_bucket(),
        {flags(1, 0, 0), :value1},
        {flags(1, 1, 1), :value2},
        {flags(0, 1, 1), :value3},
        {flags(1, 0, 1), :value4},
        {flags(0, 0, 1), :value5},
        init_bucket(),
        {flags(1, 0, 0), :value7}
      ]

      {r_start, r_end} = scan_for_run(bucket_list, 2)
      # so f_q is 2, which in bucket_list - is still the run for canonical bucket index 1.
      # therefore the function will scan to get to idx: 4
      assert {4, 5} = {r_start, r_end}
    end
  end
end
