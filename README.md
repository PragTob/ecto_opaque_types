# ecto_opaque_types

Minimal reproduction for a `call_without_opaque` Dialyzer warning triggered by `Ecto.Multi` operations under OTP 28.

## Environment

- Erlang/OTP 28.4
- Elixir 1.19.5
- Ecto 3.13.5

The most important bit here is OTP 28 as it [tightened up handling](https://www.erlang.org/blog/highlights-otp-28/#nominal-types) of [opaque types](https://www.erlang.org/doc/system/opaques.html):

> Since Erlang/OTP 28, Dialyzer checks opaques in their defining module in the same way as nominals. Outside of the defining module, Dialyzer checks opaques for opacity violations.

## Reproducing the warning

```sh
mix deps.get
mix dialyzer
```

Expected output (on OTP 28):

```
lib/ecto_opaque_types.ex:13:call_without_opaque
Function call without opaqueness type mismatch.
...
```

<details>

  <summary>Full dialyzer output</summary>

```
ecto_opaque_types git:(main) ✗ mix dialyzer
Compiling 1 file (.ex)
Generated ecto_opaque_types app
Finding suitable PLTs
Checking PLT...
[:compiler, :crypto, :decimal, :ecto, :ecto_opaque_types, :eex, :elixir, :kernel, :logger, :stdlib, :telemetry]
PLT is up to date!
No :ignore_warnings opt specified in mix.exs and default does not exist.

Starting Dialyzer
[
  check_plt: false,
  init_plt: ~c"/Users/tpfeiffer/github/ecto_opaque_types/_build/dev/dialyxir_erlang-28.4_elixir-1.19.5_deps-dev.plt",
  files: [~c"/Users/tpfeiffer/github/ecto_opaque_types/_build/dev/lib/ecto_opaque_types/ebin/Elixir.EctoOpaqueTypes.beam"],
  warnings: [:unknown]
]
Total errors: 1, Skipped: 0, Unnecessary Skips: 0
done in 0m0.74s
lib/ecto_opaque_types.ex:9:contract_with_opaque
The @spec for EctoOpaqueTypes.build_multi/0 has an opaque
subtype %Ecto.Multi{
  :names => %MapSet{:map => MapSet.internal(_)},
  :operations => [
    {_,
     {:inspect, Keyword.t()}
     | {:merge,
        (map() -> %Ecto.Multi{:names => map(), :operations => [{_, _}], _ => _})
        | {atom(), atom(), [any()]}}
     | {:put, _}
     | {:run, (atom(), map() -> {:error, _} | {:ok, _})}
     | {:changeset,
        %Ecto.Changeset{
          :action => atom(),
          :changes => %{atom() => _},
          :constraints => [
            %{
              :constraint =>
                binary() | %Regex{:opts => [any()], :re_pattern => _, :source => binary()},
              :error_message => binary(),
              :error_type => atom(),
              :field => atom(),
              :match => :exact | :prefix | :suffix,
              :type => :check | :exclusion | :foreign_key | :unique
            }
          ],
          :data => nil | map(),
          :empty_values => _,
          :errors => Keyword.t({binary(), Keyword.t()}),
          :filters => %{atom() => _},
          :params => nil | %{binary() => _},
          :prepare => [(_ -> any())],
          :repo => atom(),
          :repo_opts => Keyword.t(),
          :required => [atom()],
          :types => %{
            atom() =>
              atom()
              | {:array | :assoc | :embed | :in | :map | :parameterized | :supertype | :try,
                 _}
          },
          :valid? => boolean(),
          :validations => Keyword.t()
        }, Keyword.t()}
     | {:delete_all,
        %Ecto.Query{
          :aliases => _,
          :assocs => _,
          :combinations => _,
          :distinct => _,
          :from => _,
          :group_bys => _,
          :havings => _,
          :joins => _,
          :limit => _,
          :lock => _,
          :offset => _,
          :order_bys => _,
          :prefix => _,
          :preloads => _,
          :select => _,
          :sources => _,
          :updates => _,
          :wheres => _,
          :windows => _,
          :with_ctes => _
        }, Keyword.t()}
     | {:update_all,
        %Ecto.Query{
          :aliases => _,
          :assocs => _,
          :combinations => _,
          :distinct => _,
          :from => _,
          :group_bys => _,
          :havings => _,
          :joins => _,
          :limit => _,
          :lock => _,
          :offset => _,
          :order_bys => _,
          :prefix => _,
          :preloads => _,
          :select => _,
          :sources => _,
          :updates => _,
          :wheres => _,
          :windows => _,
          :with_ctes => _
        }, Keyword.t()}
     | {:insert_all, atom() | binary() | {binary(), atom()}, [Keyword.t() | map()],
        Keyword.t()}}
  ]
} which is violated by the success typing.

Success typing:
() :: %Ecto.Multi{:names => %MapSet{:map => %{}}, :operations => []}

________________________________________________________________________________
done (warnings were emitted)
Halting VM with exit status 2
```

</details>

## Root cause

Root cause to the best of my understanding:

1. `MapSet.t(value)` is defined as `%MapSet{map: internal(value)}` where
   `internal(value)` is `@opaque` — so the `:map` field's type is opaque.
2. `Ecto.Multi.t()` is declared as a plain `@type` (not `@opaque`), even though
   the docs say "the struct should be considered opaque". Because it is not
   opaque, Dialyzer is allowed to look inside the struct and resolve its fields
   to concrete values.
3. OTP 28 tightened Dialyzer's opaque checking. When Dialyzer resolves
   `Ecto.Multi.new()` to its concrete form
   `%Ecto.Multi{names: %MapSet{map: %{}}, operations: []}`, it exposes the
   concrete `%{}` in place of the opaque `MapSet.internal(_)`.

## The fix

Probably make multis an opaque type?!

## Workaround (for downstream projects)

Add to `.dialyzer_ignore.exs`:

```elixir
[
  ~r/lib\/your_file\.ex:\d+:\d+:call_without_opaque/
]
```
