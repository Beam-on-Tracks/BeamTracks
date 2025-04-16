defmodule Trackrunner.ToolValidatorTest do
  use ExUnit.Case
  alias Trackrunner.{ToolValidator, ToolContract}

  test "validates correct input" do
    contract = %ToolContract{
      name: "get_weather",
      mode: {:http, :post},
      target: "http://localhost:4000/weather",
      inputs: %{"location" => "string"},
      outputs: %{"temperature" => "number"},
      verb: :post
    }

    input = %{"location" => "Seattle"}

    assert ToolValidator.validate_input(contract, input) == :ok
  end

  test "fails on missing key" do
    contract = %ToolContract{
      name: "get_weather",
      mode: {:http, :post},
      target: "http://localhost:4000/weather",
      inputs: %{"location" => "string"},
      outputs: %{"temperature" => "number"},
      verb: :post
    }

    input = %{}

    assert {:error, _} = ToolValidator.validate_input(contract, input)
  end

  test "fails on wrong type" do
    contract = %ToolContract{
      name: "get_weather",
      mode: {:http, :post},
      target: "http://localhost:4000/weather",
      inputs: %{"location" => "string"},
      outputs: %{"temperature" => "number"},
      verb: :post
    }

    # wrong type
    input = %{"location" => 42}

    assert {:error, _} = ToolValidator.validate_input(contract, input)
  end
end
