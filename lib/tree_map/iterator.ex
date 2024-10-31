defmodule TreeMap.Iterator do

  @type t(item) :: (-> result(item))
  @type result(item) :: :done | {item, t(item)}
  @type predicate(item) :: (item -> boolean)

  @doc """
  TreeMap iterator stopping when p is false

  ## Examples
      iex> iter = 1 |> from(& &1 + 1) |> take_while(fn i -> i <= 5 end) |> take_while(fn i -> i <= 10 end)
      iex> {item, iter} = iter.()
      iex> item
      1
      iex> {item, iter} = iter.()
      iex> item
      2
      iex> {item, iter} = iter.()
      iex> item
      3
      iex> {item, iter} = iter.()
      iex> item
      4
      iex> {item, iter} = iter.()
      iex> item
      5
      iex> iter.()
      :done
  """
  @spec take_while(t(item), predicate(item)) :: t(item) when item: var
  def take_while(iter, p) do
    fn ->
      case iter.() do
        :done -> :done
        {item, new_iter} ->
          if p.(item) do
            {item, take_while(new_iter, p)}
          else
            :done
          end
      end
    end
  end

  @doc """
  TreeMap iterator starting when p is false

  ## Examples
      iex> iter = 1 |> from(& &1 + 1) |> take_while(fn i -> i <= 10 end) |> drop_while(fn i -> i <= 5 end)
      iex> {item, iter} = iter.()
      iex> item
      6
      iex> {item, iter} = iter.()
      iex> item
      7
      iex> {item, iter} = iter.()
      iex> item
      8
      iex> {item, iter} = iter.()
      iex> item
      9
      iex> {item, iter} = iter.()
      iex> item
      10
      iex> iter.()
      :done

      iex> iter = 1 |> from(& &1 + 1) |> take_while(fn i -> i <= 4 end) |> drop_while(fn i -> i <= 5 end)
      iex> iter.()
      iex> :done
  """
  @spec drop_while(t(item), predicate(item)) :: t(item) when item: var
  def drop_while(iter, p),  do: fn -> drop_while_rec(iter.(), p) end

  @spec drop_while_rec(result(item), predicate(item)) :: result(item) when item: var
  def drop_while_rec(:done, _p), do: nil
  def drop_while_rec({item, iter} = result, p) do
    IO.inspect(item, label: "drop_while_rec")
    if p.(item) do
      drop_while_rec(iter.(), p)
    else
      result
    end
  end

  @doc """
  infinite iterator starting at start and use next to generate next item

  ## Examples
      iex> iter = 1 |> from(& &1 + 1)
      iex> {item, iter} = iter.()
      iex> item
      1
      iex> {item, _iter} = iter.()
      iex> item
      2
  """
  @spec from(item, (item -> item)) :: t(item) when item: var
  def from(start, next), do: fn -> {start, from(next.(start), next)} end


  @doc """
  TreeMap iterator that filters items pass predicate

  ## Examples
      iex> iter = 1 |> from(& &1 + 1) |> take_while(fn i -> i <= 10 end) |> filter(fn i -> rem(i, 2) == 0 end)
      iex> {item, iter} = iter.()
      iex> item
      2
      iex> {item, iter} = iter.()
      iex> item
      4
      iex> {item, iter} = iter.()
      iex> item
      6
      iex> {item, iter} = iter.()
      iex> item
      8
      iex> {item, iter} = iter.()
      iex> item
      10
      iex> iter.()
      :done
  """
  @spec filter(t(item), predicate(item)) :: t(item) when item: var
  def filter(iter, p), do: fn -> filter_rec(iter.(), p) end

  defp filter_rec(:done, _p), do: :done
  defp filter_rec({new_item, new_iter}, p) do
    if p.(new_item) do
      {new_item, filter(new_iter, p)}
    else
      filter_rec(new_iter.(), p)
    end
  end

  @doc """
  Convert iterator to list

  ## Examples
      iex> from(1, & &1+1) |> take_while(& &1 <= 10) |> to_list()
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  """
  @spec to_list(t(item)) :: [item] when item: var
  def to_list(iter), do: to_list_rec(iter.())

  @spec to_list_rec(result(item)) :: [item] when item: var
  def to_list_rec(:done), do: []
  def to_list_rec({item, iter}), do: [item | to_list_rec(iter.())]

  @doc """
  Map function over iterator to produce new iterator

  ## Examples
      iex> from(1, & &1+1) |> take_while(& &1 <= 10) |> map(& &1 * 2) |> to_list()
      [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
  """
  @spec map(t(item), (item->other)) :: t(other) when item: var, other: var
  def map(iter, f) do
    fn ->
      case iter.() do
        :done -> :done
        {item, new_iter} -> {f.(item), map(new_iter, f)}
      end
    end
  end

  @doc """
  Convert iterator to stream

  ## Examples
      iex> from(1, & &1+1) |> to_stream() |> Stream.take_while(& &1 <= 10) |> Stream.map(& &1 * 2) |> Enum.to_list()
      [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
      iex> from(1, & &1+1) |> take_while(& &1 <= 10) |> to_stream()  |> Stream.map(& &1 * 2) |> Enum.to_list()
      [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
  """
  @spec to_stream(t(item)) :: Enumerable.t(item) when item: var
  def to_stream(iter) do
    Stream.resource(
      fn -> iter end,
      fn iter ->
        case iter.() do
          :done -> {:halt, iter}
          {item, new_iter} -> {[item], new_iter}
        end
      end,
      fn _iter -> nil end
    )
  end
end
