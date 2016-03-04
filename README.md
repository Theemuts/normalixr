A small project that allows you to normalize Ecto schemas. Currently,
two versions are available on Hex. Version 0.1.0 supports Ecto 1.1,
version 0.2.0 supports the Ecto 2 beta.

## Installation

The package can be installed as:

  1. Add Normalixr to your list of dependencies in `mix.exs`. If you use Ecto 1:

        def deps do
          [{:normalixr, "~> 0.1"}]
        end

     If you use Ecto 2:

        def deps do
          [{:normalixr, "~> 0.2"}]
        end

  2. Ensure Normalixr is started before your application:

        def application do
          [applications: [:normalixr]]
        end

## Documentation

All documentation can be found on [Hexdocs](https://hexdocs.pm/normalixr).