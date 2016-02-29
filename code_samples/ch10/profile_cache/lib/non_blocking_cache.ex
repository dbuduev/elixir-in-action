defmodule NonBlockingCache do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :ets_page_cache)
  end

  def init(_) do
    :ets.new(:ets_page_cache, [:set, :named_table, :protected])
    Process.flag(:trap_exit, true)
    {:ok, Map.new}
  end
  # The only function in the public interface of of the module
  # Usage: NonBlockingCache.cached(:index, fn -> :timer.sleep(100); "<html>...</html>" end)
  def cached(key, fun) do
    case :ets.lookup(:ets_page_cache, key) do
      [{^key, {:cached, cached}}] -> {:ok, cached}
      _ -> GenServer.call(:ets_page_cache, {:missing, key, fun})
    end
  end

  def handle_call({:missing, key, fun}, caller, state) do
    key_missing(key, fun, caller, state)
  end

  def handle_info({:missing_info, key, fun, caller}, state) do
    key_missing(key, fun, caller, state)
  end

  def handle_info({:response, key, caller, response}, state) do
    :ets.insert(:ets_page_cache, {key, {:cached, response}})
    GenServer.reply(caller, {:ok, response})
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, :normal}, state) do    
    {:noreply, Map.delete(state, pid)}
  end

  def handle_info({:EXIT, pid, reason}, state) do    
    {key, caller} = Map.fetch!(state, pid)
    :ets.delete(:ets_page_cache, key)
    GenServer.reply(caller, {:error, reason})
    {:noreply, Map.delete(state, pid)}
  end  
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp key_missing(key, fun, caller, state) do
    case :ets.lookup(:ets_page_cache, key) do
      [{^key, {:cached, cached}}] ->  
          GenServer.reply(caller, {:ok, cached})
          {:noreply, state}
      [{^key, {:requested, _}}] -> 
        Process.send_after(self(), {:missing_info, key, fun, caller}, 10)  # send after 10 ms
        {:noreply, state}
      _ -> {:noreply, cache_response(caller, key, fun, state)}
    end  
  end

  defp cache_response(caller, key, fun, state) do
    me = self()
    :ets.insert(:ets_page_cache, {key, {:requested, nil}})
    pid = spawn_link(fn -> send(me, {:response, key, caller, fun.()}) end)
    Map.put(state, pid, {key, caller})
  end  
end