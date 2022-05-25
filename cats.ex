defmodule Cats do
  @moduledoc """
  This is the Cats simulation program. It simulates a number of cats and a human, who needs to feed his cats, since otherwise they will die.
  """

  @doc """
  Starts up the `Cats` simulation.

  `rand_min` controls the mininmum number of meows necessary to have a chance of the human responding.

  `rand_max` controls the number of meows that guarantee the human will respond.

  `speed` controls the speed of the simulation, don't make it less than 0_050, as that might break the simulation.
  """

  @doc since: "1.0.0"
  def start(rand_min \\ 15, rand_max \\ 50, speed \\ 0_050) do
    names =
      IO.gets("Enter names, separate them with a comma\n")
      |> String.split(",")

    names = [%{}] ++ names

    cats =
      Enum.reduce(names, fn name, cats ->
        # Change starting hp here
        Map.put(cats, String.trim(name), Enum.random(20..30))
      end)

    spawn(Cats, :chebureki, [])
    |> Process.register(:chebureki)

    Enum.map(cats, fn {name, hp} ->
      spawn(Cats, :listen, [name, hp, speed])
      |> Process.register(String.to_atom(name <> "cat"))
    end)

    spawn(Cats, :human, [1, rand_min, rand_max])
    |> Process.register(:human)
  end

  def listen(cat, health, speed) do
    receive do
      {name, hp} ->
        IO.puts("#{name} meows happily. It has #{hp} hp.")
        listen(name, hp, speed)
    after
      # Change this value to make the whole thing go faster or slower (Not lower than 0_050)
      speed ->
        starve(cat, health - 1)
        listen(cat, health - 1, speed)
    end
  end

  # Make sure to change the limits for normal and urgent meows together
  defp starve(name, hp) when hp <= 20 and hp > 5 do
    IO.puts("#{name} meowed! It has #{hp} hp.")
    send(:human, {:normal, name, hp})
  end

  defp starve(name, hp) when hp <= 5 and hp != 0 do
    IO.puts("#{name} urgently meowed! It has #{hp} hp.")
    send(:human, {:urgent, name, hp})
  end

  defp starve(name, hp) when hp == 0 do
    IO.puts("#{name} died.")
    send(:human, {:dead, name, hp})
  end

  defp starve(name, hp) do
    IO.puts("#{name} is full. It has #{hp} hp.")
    send(:human, {:full, name, hp})
  end

  def human(count, rand_min, rand_max) do
    receive do
      {type, name, hp} ->
        # If count is bigger than random, the human will react
        count = react(type, name, hp, count, Enum.random(rand_min..rand_max))
        human(count + 1, rand_min, rand_max)
    after
      2_000 ->
        IO.puts("\"Oh... All my cats are dead...\"")
        Process.exit(Process.whereis(:chebureki), :kill)
        :timer.sleep(2000)
        IO.puts("The human blew up the chebureki factory together with himself.\n The End.")
        :timer.sleep(50)
        Process.exit(self(), :kill)
    end
  end

  def chebureki() do
    receive do
      name ->
        IO.puts("Processing #{name} into cheburekis...")
        :timer.sleep(1000)
        send(:human, {:chebureki, name, Enum.random(20..30)})
        chebureki()
    end
  end

  defp react(:normal, name, hp, count, random) when count > random do
    # Change this to change how much to heal for a normal meow
    hp_by = Enum.random(20..30)
    send(String.to_atom(name <> "cat"), {name, hp + hp_by})
    IO.puts("I fed #{name}. It's hp is increased by #{hp_by}.")
    0
  end

  defp react(:urgent, name, hp, count, random) when count > random do
    # Change this to change how much to heal for an urgent meow
    hp_by = Enum.random(20..50)
    send(String.to_atom(name <> "cat"), {name, hp + hp_by})
    IO.puts("I fed #{name}. It's hp is increased by #{hp_by}.")
    0
  end

  defp react(:dead, name, _hp, count, _random) do
    IO.puts("Oh no! My cat #{name} died!")
    Process.exit(Process.whereis(String.to_atom(name <> "cat")), :kill)
    send(:chebureki, name)
    count
  end

  defp react(:chebureki, name, hp, count, _random) do
    IO.puts("\"Hey cats! I brought some #{name} cheburekis!\"")
    count + hp
  end

  defp react(:full, _, _, count, _) do
    count - 1
  end

  defp react(_, name, _, count, random) do
    IO.puts("\"Don't care.\" (#{name}, #{count} < #{random})")
    count
  end
end
