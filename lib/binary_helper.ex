defmodule ProbabilisticBookReview.BinaryHelper do
  use Bitwise

  def init_bit_str(m) do
    <<0::size(m)>>
  end

  def pad_to_binary(bit_str) do
    left_pad_amt = 8 - rem(bit_size(bit_str), 8)

    <<0::size(left_pad_amt), (<<bit_str::bitstring>>)>>
  end

  def remove_binary_pad(binary_padded, m) do
    left_pad_amt = bit_size(binary_padded) - m

    cond do
      left_pad_amt > 0 ->
        <<_::size(left_pad_amt), rest::bits>> = binary_padded
        rest

      left_pad_amt == 0 ->
        binary_padded

      left_pad_amt < 0 ->
        abs_amt = abs(left_pad_amt)
        <<0::size(abs_amt), binary_padded::binary>>
    end
  end

  def mark_bit_str(<<_::1, rest::bits>>, 0) do
    <<1::1, rest::bits>>
  end

  def mark_bit_str(bit_str, idx) do
    <<left::size(idx), _::1, rest::bits>> = bit_str
    <<left::size(idx), 1::1, rest::bits>>
  end

  def bor_bitstring(left, right, m) do
    (left |> pad_to_binary() |> :binary.decode_unsigned() |||
       right |> pad_to_binary() |> :binary.decode_unsigned())
    |> :binary.encode_unsigned()
    |> remove_binary_pad(m)
  end

  def to_list(bit_str) do
    for <<(one::1 <- <<bit_str::bits>>)>> do
      :binary.decode_unsigned(<<0::size(7), one::1>>)
    end
  end
end
