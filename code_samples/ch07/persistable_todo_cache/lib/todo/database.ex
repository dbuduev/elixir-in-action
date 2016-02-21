defmodule Todo.Database do
  use GenServer
  @workers_num  3
  
  def start(db_folder) do
	IO.puts "Starting Todo.Database"	
	GenServer.start(__MODULE__, db_folder, name: :database_server)
  end

  def store(key, data) do
    GenServer.cast(:database_server, {:store, key, data})
  end

  def get(key) do
    GenServer.call(:database_server, {:get, key})
  end

  def init(db_folder) do
    File.mkdir_p(db_folder)
    state = 1..@workers_num |> Enum.reduce(HashDict.new, fn(i, acc) -> 
		{:ok, worker_id} = Todo.DatabaseWorker.start(db_folder)
		HashDict.put(acc, i, worker_id) end)
	IO.inspect state
	{:ok, state}
  end

  def handle_cast({:store, key, data}, workers) do
	worker_id = get_worker(workers, key)
	Todo.DatabaseWorker.store(worker_id, key, data)
    {:noreply, workers}
  end

  def handle_call({:get, key}, _, workers) do
	worker_id = get_worker(workers, key)
    data = Todo.DatabaseWorker.get(worker_id, key)
    {:reply, data, workers}
  end

  # Needed for testing purposes
  def handle_info(:stop, state), do: {:stop, :normal, state}
  def handle_info(_, state), do: {:noreply, state}

  defp key_to_index(key), do: :erlang.phash(key, @workers_num)
  defp get_worker(workers, key), do: HashDict.fetch!(workers, key_to_index(key))
end