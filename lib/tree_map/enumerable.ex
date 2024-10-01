defimpl Enumerable, for: TreeMap do
  @moduledoc """
  https://blog.brettbeatty.com/elixir/custom_data_structures/enumerable
  http://blog.plataformatec.com.br/2015/05/introducing-reducees/
  https://groups.google.com/g/elixir-lang-talk/c/zNMFKOA-I7c
  """
  @empty nil


  @doc """
  Size

  ## Examples
      iex> TreeMap.new(Enum.zip(1..7, 1..7)) |> Enum.count
      7
  """
  def count(%TreeMap{root: _, size: size}), do: {:ok, size}

  @doc """
  Test membership

  ## Examples
      iex> TreeMap.new([]) |> Enumerable.member?({2, :a})
      {:ok, false}

      iex> TreeMap.new([{2, :c}]) |> Enumerable.member?({2, :c})
      {:ok, true}

      iex> TreeMap.new([{2, :d}]) |> Enumerable.member?({2, :c})
      {:ok, false}
  """
  def member?(%TreeMap{root: root}, {k, v}), do: {:ok, TreeMap.get_rec?(root, k) == v}

  @doc """
  Reducer

  ## Examples
      iex> TreeMap.new([{1, :a}, {2, :b}, {3, :c}, {4, :d}, {5, :e}, {6, :f}, {7, :g}]) |> Enum.map(fn {k, v} -> {2 * k, v} end)
      [{2, :a}, {4, :b}, {6, :c}, {8, :d}, {10, :e}, {12, :f}, {14, :g}]

      iex> TreeMap.new([{1, :a}, {2, :b}, {3, :c}, {4, :d}, {5, :e}, {6, :f}, {7, :g}]) |> Enum.take(4)
      [{1, :a}, {2, :b}, {3, :c}, {4, :d}]

      iex> TreeMap.new([{1, :a}, {2, :b}]) |> Enum.zip(11..13)
      [{{1, :a}, 11}, {{2, :b}, 12}]

      iex> 1..2 |> Enum.zip(TreeMap.new([{11, :a}, {12, :b}, {13, :c}]))
      [{1, {11, :a}}, {2, {12, :b}}]
  """

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(tree, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(tree, &1, fun)}
  def reduce(%TreeMap{root: root}, {:cont, _} = state, fun), do: reduce({root, []}, state, fun)

  def reduce({@empty, []}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce({@empty, [{item, right} | as]}, {:cont, acc}, fun),
    do: reduce({right, as}, fun.(item, acc), fun)

  def reduce({{left, key, value, _, right}, as}, {:cont, acc}, fun),
    do: reduce({left, [{{key, value}, right} | as]}, {:cont, acc}, fun)

  @doc """
  Slicing

  ## Examples
      iex> {:ok, 7, slicer} = TreeMap.new([{1, :a}, {2, :b}, {3, :c}, {4, :d}, {5, :e}, {6, :f}, {7, :g}]) |> Enumerable.slice()
      ...> slicer.(2, 4)
      [{3, :c}, {4, :d}, {5, :e}, {6, :f}]
  """
  def slicer({_, _, acc}, 0, 0), do: acc |> Enum.reverse()

  def slicer({@empty, [{item, right} | stack], acc}, 0, n),
    do: slicer({right, stack, [item | acc]}, 0, n - 1)

  def slicer({{left, key, value, _, right}, stack, acc}, 0, n),
    do: slicer({left, [{{key, value}, right} | stack], acc}, 0, n)

  def slicer({@empty, [{_item, right} | stack], acc}, m, n),
    do: slicer({right, stack, acc}, m - 1, n)

  def slicer({{left, key, value, size, right}, stack, acc}, m, n) when size > m,
    do: slicer({left, [{{key, value}, right} | stack], acc}, m, n)

  def slicer({{_, _, _, size, _}, stack, acc}, m, n), do: slicer({@empty, stack, acc}, m - size, n)

  def slice(%TreeMap{root: root, size: size}) do
    slicer = fn start, n -> slicer({root, [], []}, start, n) end
    {:ok, size, slicer}
  end
end
