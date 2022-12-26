defmodule Kadena.Chainweb.Pact.CommandPayload do
  @moduledoc """
  `CommandPayload` struct definition.
  """

  alias Kadena.Utils.MapCase

  alias Kadena.Types.{
    Base16String,
    Cap,
    CapsList,
    ChainID,
    ContPayload,
    EnvData,
    ExecPayload,
    MetaData,
    NetworkID,
    OptionalCapsList,
    PactCode,
    PactDecimal,
    PactInt,
    PactPayload,
    PactTransactionHash,
    PactValue,
    PactValuesList,
    Proof,
    Rollback,
    Signer,
    Step
  }

  @behaviour Kadena.Chainweb.Pact.Type

  @type network_id :: NetworkID.t() | nil
  @type payload :: PactPayload.t()
  @type signers :: list(Signer.t())
  @type meta :: MetaData.t()
  @type nonce :: String.t()
  @type value :: network_id() | payload() | signers() | meta() | nonce()
  @type validation :: {:ok, value()} | {:error, Keyword.t()}
  @type valid_map :: {:ok, map()}
  @type valid_string :: {:ok, String.t()}
  @type valid_list :: {:ok, list()}
  @type map_return :: map() | nil
  @type string_value :: String.t() | nil
  @type pact_values :: PactValuesList.t()
  @type scheme :: :ed25519 | nil
  @type scheme_return :: :ED25519 | nil
  @type cap :: Cap.t()
  @type data :: EnvData.t() | nil
  @type proof :: Proof.t() | nil
  @type signer :: Signer.t()
  @type raw_value :: integer() | string_value() | boolean() | Decimal.t()
  @type clist :: CapsList.t() | nil
  @type addr :: Base16String.t() | nil
  @type pact_payload :: PactPayload.t()
  @type literal ::
          integer()
          | boolean()
          | String.t()
          | PactInt.t()
          | PactDecimal.t()
          | PactValuesList.t()

  @type t :: %__MODULE__{
          network_id: network_id(),
          payload: payload(),
          signers: signers(),
          meta: meta(),
          nonce: nonce()
        }

  defstruct [:network_id, :payload, :signers, :meta, :nonce]

  @impl true
  def new(args) do
    network_id = Keyword.get(args, :network_id)
    payload = Keyword.get(args, :payload)
    signers = Keyword.get(args, :signers, [])
    meta = Keyword.get(args, :meta)
    nonce = Keyword.get(args, :nonce)

    with {:ok, network_id} <- validate_network_id(network_id),
         {:ok, payload} <- validate_payload(payload),
         {:ok, signers} <- validate_signers(signers),
         {:ok, meta} <- validate_meta(meta),
         {:ok, nonce} <- validate_nonce(nonce) do
      %__MODULE__{
        network_id: network_id,
        payload: payload,
        signers: signers,
        meta: meta,
        nonce: nonce
      }
    end
  end

  @impl true
  def to_json!(%__MODULE__{
        network_id: network_id,
        payload: payload,
        signers: signers,
        meta: meta,
        nonce: nonce
      }) do
    with {:ok, payload} <- extract_payload(payload),
         {:ok, meta} <- extract_meta(meta),
         {:ok, network_id} <- extract_network_id(network_id),
         {:ok, signers} <- extract_signers_list(signers) do
      Jason.encode!(%{
        payload: payload,
        meta: meta,
        networkId: network_id,
        nonce: nonce,
        signers: signers
      })
    end
  end

  @spec validate_network_id(network_id :: network_id()) :: validation()
  defp validate_network_id(%NetworkID{} = network_id), do: {:ok, network_id}

  defp validate_network_id(network_id) do
    case NetworkID.new(network_id) do
      %NetworkID{} = network_id -> {:ok, network_id}
      _error -> {:error, [network_id: :invalid]}
    end
  end

  @spec validate_payload(payload :: payload()) :: validation()
  defp validate_payload(%PactPayload{} = payload), do: {:ok, payload}

  defp validate_payload(payload) do
    case PactPayload.new(payload) do
      %PactPayload{} = payload -> {:ok, payload}
      _error -> {:error, [payload: :invalid]}
    end
  end

  @spec validate_signers(signers :: signers()) :: validation()
  defp validate_signers([%Signer{} | _rest] = signers), do: {:ok, signers}
  defp validate_signers([] = signers), do: {:ok, signers}
  defp validate_signers(_signers), do: {:error, [signers: :invalid]}

  @spec validate_meta(meta :: meta()) :: validation()
  defp validate_meta(%MetaData{} = meta), do: {:ok, meta}
  defp validate_meta(nil), do: {:ok, MetaData.new([])}

  defp validate_meta(meta) do
    case MetaData.new(meta) do
      %MetaData{} = meta -> {:ok, meta}
      {:error, _reason} -> {:error, [meta: :invalid]}
    end
  end

  @spec validate_nonce(nonce :: nonce()) :: validation()
  defp validate_nonce(nonce), do: {:ok, to_string(nonce)}

  @spec extract_network_id(network_id()) :: valid_string()
  defp extract_network_id(%NetworkID{id: id}), do: {:ok, id}

  @spec extract_payload(pact_payload()) :: valid_map()
  defp extract_payload(%PactPayload{payload: %ExecPayload{} = exec_payload}) do
    %ExecPayload{code: %PactCode{code: code}, data: data} = exec_payload
    payload = %{exec: %{code: code, data: extract_data(data)}}
    {:ok, payload}
  end

  defp extract_payload(%PactPayload{
         payload: %ContPayload{
           data: data,
           pact_id: %PactTransactionHash{hash: hash},
           proof: proof,
           rollback: %Rollback{value: rollback},
           step: %Step{number: number}
         }
       }) do
    payload = %{
      cont: %{
        data: extract_data(data),
        pactId: hash,
        proof: extract_proof(proof),
        rollback: rollback,
        step: number
      }
    }

    {:ok, payload}
  end

  @spec extract_proof(proof()) :: string_value()
  defp extract_proof(nil), do: nil
  defp extract_proof(%Proof{value: proof}), do: proof

  @spec extract_data(data()) :: map_return()
  defp extract_data(nil), do: nil
  defp extract_data(%EnvData{data: data}), do: data

  @spec extract_meta(meta()) :: valid_map()
  defp extract_meta(%MetaData{
         creation_time: creation_time,
         ttl: ttl,
         gas_limit: gas_limit,
         gas_price: gas_price,
         sender: sender,
         chain_id: %ChainID{id: id}
       }) do
    %{
      chain_id: id,
      creation_time: creation_time,
      gas_limit: gas_limit,
      gas_price: gas_price,
      sender: sender,
      ttl: ttl
    }
    |> MapCase.to_camel!()
    |> (&{:ok, &1}).()
  end

  @spec extract_signers_list(signer_list :: signers()) :: valid_list()
  defp extract_signers_list(signer_list) do
    signers = Enum.map(signer_list, fn sig -> extract_signer_info(sig) end)
    {:ok, signers}
  end

  @spec extract_signer_info(signer()) :: map_return()
  defp extract_signer_info(%Signer{
         addr: addr,
         scheme: scheme,
         pub_key: %Base16String{value: pub_key},
         clist: %OptionalCapsList{clist: clist}
       }) do
    MapCase.to_camel!(%{
      addr: extract_addr(addr),
      scheme: extract_scheme(scheme),
      pub_key: pub_key,
      clist: extract_clist(clist)
    })
  end

  @spec extract_addr(addr()) :: string_value()
  defp extract_addr(nil), do: nil
  defp extract_addr(%Base16String{value: value}), do: value

  @spec extract_scheme(scheme()) :: scheme_return()
  defp extract_scheme(nil), do: nil
  defp extract_scheme(:ed25519), do: :ED25519

  @spec extract_clist(clist()) :: list()
  defp extract_clist(nil), do: []

  defp extract_clist(%CapsList{caps: caps}) do
    Enum.map(caps, fn cap -> extract_cap_info(cap) end)
  end

  @spec extract_cap_info(cap()) :: map_return()
  defp extract_cap_info(%Cap{name: name, args: args}) do
    %{name: name, args: extract_values(args)}
  end

  @spec extract_values(pact_values()) :: list()
  defp extract_values(%PactValuesList{pact_values: pact_values}) do
    Enum.map(pact_values, fn %PactValue{literal: pact_value} -> extract_value(pact_value) end)
  end

  @spec extract_value(literal()) :: raw_value()
  defp extract_value(%PactValuesList{} = pact_value), do: extract_values(pact_value)
  defp extract_value(%PactInt{raw_value: value}), do: value
  defp extract_value(%PactDecimal{raw_value: value}), do: value
  defp extract_value(value), do: value
end
