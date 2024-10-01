defimpl Collectable, for: TreeMap do

  @doc """
  Test membership

  ## Examples
      iex> Enum.into([{1, :a}, {3, :c}, {5, :e}, {7, :g}], TreeMap.build([{2, :b}, {4, :d}, {6, :f}])) |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;4 => d;5 => e;6 => f;7 => g;>"

      iex> {tree, fun} = Collectable.into(TreeMap.new())
      ...> fun.(tree, :halt)
      :ok

      iex> Enum.into([1], TreeMap.new())
      ** (ArgumentError) collecting into a TreeMopeap requires {key, value} tuples, got: 1
  """
  def into(tree) do
    collector_fun = fn
      tree, {:cont, {k, v}} -> TreeMap.put(tree, k, v)
      tree, :done -> tree
      _tree, :halt -> :ok
      _map_acc, {:cont, other} ->
        raise ArgumentError,
              "collecting into a TreeMopeap requires {key, value} tuples, got: #{inspect(other)}"
    end

    {tree, collector_fun}
  end
end
