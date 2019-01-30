defmodule Core.ServiceRequestView do
  @moduledoc false

  alias Core.Patients.Encryptor
  alias Core.Reference
  alias Core.ReferenceView
  alias Core.ServiceRequest
  alias Core.UUIDView

  def render_service_request(%ServiceRequest{} = service_request) do
    service_request
    |> Map.take(~w(
      requisition
      status
      status_reason
      intent
      explanator_letter
      authored_on
      note
      patient_instruction
      expiration_date
    )a)
    |> Map.merge(%{
      id: to_string(service_request._id),
      category: ReferenceView.render(service_request.category),
      status_history: ReferenceView.render(service_request.status_history),
      code: ReferenceView.render(service_request.code),
      context: ReferenceView.render(service_request.context),
      requester: ReferenceView.render(service_request.requester),
      performer_type: ReferenceView.render(service_request.performer_type),
      reason_reference: ReferenceView.render(service_request.reason_reference),
      supporting_info: ReferenceView.render(service_request.supporting_info),
      permitted_episodes: ReferenceView.render(service_request.permitted_episodes),
      used_by: ReferenceView.render(service_request.used_by),
      patient:
        ReferenceView.render(
          Reference.create(%{
            "identifier" => %{
              "type" => %{
                "coding" => [%{"system" => "eHealth/resources", "code" => "patient"}],
                "text" => ""
              },
              "value" => UUIDView.render(Encryptor.decrypt(service_request.subject))
            }
          })
        )
    })
    |> Map.merge(ReferenceView.render_occurrence(service_request.occurrence))
  end
end