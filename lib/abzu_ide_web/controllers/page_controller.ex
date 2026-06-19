defmodule AbzuIdeWeb.PageController do
  use AbzuIdeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
