defmodule WebServer do
  def index do
    :timer.sleep(100)

    "<html>...</html>"
  end

  def fail do
    :timer.sleep(100)

    raise "Something went wrong"
  end
end