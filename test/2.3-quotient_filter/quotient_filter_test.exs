defmodule ProbabilisticBookReview.QuotientFilterTest do
  use ExUnit.Case, async: true
  import ProbabilisticBookReview.QuotientFilter

  setup do
    total_bits = 32
    f = Murmur.hash_x86_32("Copenhagen")
    q = 3
    {f_q, f_r} = quotient(f, total_bits, q)
    [f_q: f_q, f_r: f_r]
  end

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

  describe "update_bucket_value" do
    test "updates value in bucket", %{f_q: _f_q, f_r: f_r} do
      bucket = init_bucket(f_r)
      new_val = 333_333_333
      assert {_metadata, ^new_val} = update_bucket_value(bucket, new_val)
    end
  end

  describe "init_bucket_list" do
    test "should create list of nil" do
      init_metadata = <<0::1, 0::1, 0::1>>
      assert init_bucket_list(3) |> length == 3

      assert init_bucket_list(8) |> Enum.all?(&is_nil(&1))
    end
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
        |> IO.inspect(label: "initial")

      right_shift_buckets(bucket_list, 0)
      |> update_bucket_at(bucket3, 0)
      |> IO.inspect()
      |> right_shift_buckets(0)
      |> update_bucket_at(bucket4, 0)
      |> IO.inspect()
    end
  end
end
