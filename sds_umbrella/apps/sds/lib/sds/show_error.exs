defmodule ShowError do
  import Bitwise

  @word_mask48 0o7777777777777777
  @sign_mask48 0o4000000000000000
  @word_mask 0o77777777
  @sign_mask 0o40000000

  def signed(a, b) do
    x = a <<< 24 ||| b

    cond do
      # (x &&& @sign_mask48) != 0 -> (x - @word_mask48 -1)
      (x &&& @sign_mask48) != 0 -> x - 0o7777777777777777 - 1
      true -> x
    end

    cond do
      (x &&& @sign_mask48) != 0 -> x - @word_mask48 - 1
      true -> x
    end
  end

  def signed_error(a, b) do
    x = a <<< 24 ||| b

    cond do
      (x &&& @sign_mask48) != 0 -> x - @word_mask48 - 1
      true -> x
    end
  end

  def signed(a) do
    cond do
      (a &&& @sign_mask) != 0 -> a - @word_mask - 1
      true -> a
    end
  end
end

{ShowError.signed(0o77777777, 0o77777733), ShowError.signed_error(0o77777777, 0o77777734),
 ShowError.signed(0o77777777)}
|> dbg

# {ShowError.signed(0o77777777,0o77777733), ShowError.signed(0o77777777)} |> dbg
