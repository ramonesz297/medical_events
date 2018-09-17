defmodule Core.Jobs.EpisodeCancelJob do
  @moduledoc """
  Struct for cancel episode request.
  _id is a binded Request id.
  """

  defstruct [
    :_id,
    :patient_id,
    :id,
    :request_params,
    :user_id,
    :client_id
  ]
end