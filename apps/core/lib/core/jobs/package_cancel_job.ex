defmodule Core.Jobs.PackageCancelJob do
  @moduledoc """
  Struct for canceling package request.
  _id is a binded Request id.
  """

  defstruct [:_id, :patient_id, :patient_id_hash, :signed_data, :user_id, :client_id]
end
