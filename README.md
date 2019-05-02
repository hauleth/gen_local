# `gen_local`

Simple fake `gen_server` replacement that run process in synchronous way instead
of starting new background process. This can be useful in case of testing, when
we want to minimise amount of asynchronous things.

## Installation

Rebar3:

```erlang
{deps, [gen_local]}.
```

Mix:

```elixir
defp deps do
  [
    {:gen_local, "~> 1.0"}
  ]
end
```

## Usage

Just "start" your module using `gen_local` and then call methods using it's
interface, ex.:

```erlang
{ok, PidLike} = gen_local:start(my_module, []).

{ok, Reply, PidLike1} = gen_local:call(PidLike, foo)
```

## License

See [LICENSE](LICENSE) file.
