defmodule ProbabilisticBookReview.QuotientFilterTest do
  use ExUnit.Case, async: true
  import ProbabilisticBookReview.QuotientFilter

  describe "quotient/3" do
    test "works" do
      total_bits = 32
      f = Murmur.hash_x86_32("Copenhagen")
      q = 3
      {f_q, f_r} = quotient(f, total_bits, q)

      assert f_q == 1
      assert f_r == 149_805_275
    end
  end

  describe "update_metadata_flag" do
    setup do
      total_bits = 32
      f = Murmur.hash_x86_32("Copenhagen")
      q = 3
      {f_q, f_r} = quotient(f, total_bits, q)
      [f_q: f_q, f_r: f_r]
    end

    test "should correctly update flags", %{f_q: _f_q, f_r: f_r} do
      bucket = init_bucket(f_r)

      assert {<<0::1, 0::1, 1::1>>, ^f_r} = update_metadata_flag(bucket, :is_shifted, true)

      assert {<<0::1, 1::1, 1::1>>, ^f_r} =
               update_metadata_flag(bucket, :is_shifted, true)
               |> update_metadata_flag(:is_continuation, true)

      assert {<<1::1, 1::1, 1::1>>, ^f_r} =
               update_metadata_flag(bucket, :is_shifted, true)
               |> update_metadata_flag(:is_continuation, true)
               |> update_metadata_flag(:is_occupied, true)

      assert {<<0::1, 0::1, 0::1>>, ^f_r} =
               update_metadata_flag(bucket, :is_shifted, true)
               |> update_metadata_flag(:is_continuation, true)
               |> update_metadata_flag(:is_occupied, true)
               |> update_metadata_flag(:is_occupied, false)
               |> update_metadata_flag(:is_continuation, false)
               |> update_metadata_flag(:is_shifted, false)
    end
  end
end
