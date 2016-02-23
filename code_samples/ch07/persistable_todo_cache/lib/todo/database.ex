defmodule Todo.Database do
  use GenServer
  @workers_num  3
  
  def start_link(db_folder) do
	IO.puts "Starting Todo.Database"	
	GenServer.start_link(__MODULE__, db_folder, name: :database_server)
  end

  def init(db_folder) do
    File.mkdir_p(db_folder)
    state = 1..@workers_num |> Enum.reduce(HashDict.new, fn(i, acc) -> 
		{:ok, worker_id} = Todo.DatabaseWorker.start_link(db_folder)
		HashDict.put(acc, i - 1, worker_id) end)
	IO.inspect state
	{:ok, state}
  end
  
  def store(key, data) do
    get_worker(key) |> Todo.DatabaseWorker.store(key, data)
  end

  def get(key) do
	get_worker(key) |> Todo.DatabaseWorker.get(key)	
  end
  
  defp get_worker(key) do
    GenServer.call(:database_server, {:get_worker, key})
  end

  def handle_call({:get_worker, key}, _, workers) do
    {:reply, get_worker(workers, key), workers}
  end
  
  # Needed for testing purposes
  def handle_info(:stop, state), do: {:stop, :normal, state}
  def handle_info(_, state), do: {:noreply, state}

  defp key_to_index(key), do: :erlang.phash2(key, @workers_num)
  defp get_worker(workers, key), do: HashDict.fetch!(workers, key_to_index(key))
end