defmodule JidoClaw.Forge.Resources.Event do
  use Ash.Resource,
    otp_app: :jido_claw,
    domain: JidoClaw.Forge.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "forge_events"
    repo JidoClaw.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:event_type, :data, :exec_session_sequence, :session_id]
    end

    read :for_session do
      argument :session_id, :uuid, allow_nil?: false
      argument :after, :utc_datetime_usec
      argument :event_types, {:array, :string}
      filter expr(session_id == ^arg(:session_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :string do
      allow_nil? false
      public? true
    end

    attribute :data, :map do
      allow_nil? true
      public? true
      default %{}
    end

    attribute :exec_session_sequence, :integer do
      allow_nil? true
      public? true
    end

    create_timestamp :timestamp
  end

  relationships do
    belongs_to :session, JidoClaw.Forge.Resources.Session do
      allow_nil? false
      public? true
    end
  end
end
