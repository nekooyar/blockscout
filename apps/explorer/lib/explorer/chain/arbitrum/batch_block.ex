defmodule Explorer.Chain.Arbitrum.BatchBlock do
  @moduledoc """
    Models a list of blocks related to a batch for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.BatchBlocks

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Arbitrum.{L1Batch, LifecycleTransaction}

  @optional_attrs ~w(confirm_id)a

  @required_attrs ~w(batch_number block_hash)a

  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          batch: %Ecto.Association.NotLoaded{} | L1Batch.t() | nil,
          block_hash: Hash.t(),
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          confirm_id: non_neg_integer() | nil,
          confirm_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil
        }

  @primary_key false
  schema "arbitrum_batch_l2_blocks" do
    belongs_to(:batch, L1Batch, foreign_key: :batch_number, references: :number, type: :integer)
    belongs_to(:block, Block, foreign_key: :block_hash, primary_key: true, references: :hash, type: Hash.Full)

    belongs_to(:confirm_transaction, LifecycleTransaction,
      foreign_key: :confirm_id,
      references: :id,
      type: :integer
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = items, attrs \\ %{}) do
    items
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> foreign_key_constraint(:confirm_id)
    |> unique_constraint(:block_hash)
  end
end
