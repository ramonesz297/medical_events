defmodule Core.Patients.Episodes.Validations do
  @moduledoc false

  import Core.Schema, only: [add_validations: 3]
  alias Core.Episode
  alias Core.Period
  alias Core.Reference

  def validate_period(%Episode{period: period} = episode) do
    now = Date.utc_today()

    period =
      add_validations(
        period,
        :start,
        date: [less_than_or_equal_to: now, message: "Start date of episode must be in past"]
      )

    period =
      if period.end do
        add_validations(
          period,
          :end,
          date: [less_than_or_equal_to: now, message: "End date must be in past"],
          date: [
            greater_than_or_equal_to: period.start,
            message: "End date must be greater than or equal the start date"
          ]
        )
      else
        period
      end

    %{episode | period: period}
  end

  def validate_period(%Episode{} = episode, nil), do: episode

  def validate_period(%Episode{} = episode, %{} = period) do
    validate_period(%{episode | period: Period.create(period)})
  end

  def validate_managing_organization(%Episode{managing_organization: managing_organization} = episode, client_id) do
    identifier =
      managing_organization.identifier
      |> add_validations(
        :value,
        value: [
          equals: client_id,
          message: "Managing_organization does not correspond to user's legal_entity"
        ],
        legal_entity: [
          status: "ACTIVE",
          messages: [
            status: "LegalEntity is not active"
          ]
        ]
      )

    %{episode | managing_organization: %{managing_organization | identifier: identifier}}
  end

  def validate_care_manager(%Episode{care_manager: care_manager} = episode, client_id) do
    identifier =
      care_manager.identifier
      |> add_validations(
        :value,
        employee: [
          type: "DOCTOR",
          status: "APPROVED",
          legal_entity_id: client_id,
          messages: [
            type: "Employee submitted as a care_manager is not a doctor",
            status: "Doctor submitted as a care_manager is not active",
            legal_entity_id: "Employee #{care_manager.identifier.value} doesn't belong to your legal entity"
          ]
        ]
      )

    codeable_concept = add_validations(identifier.type, :coding, reference: [path: "coding"])

    coding =
      Enum.map(
        codeable_concept.coding,
        &(&1
          |> add_validations(
            :code,
            value: [equals: "employee", message: "Only employee could be submitted as a care_manager"]
          )
          |> add_validations(
            :system,
            value: [equals: "eHealth/resources", message: "Submitted system is not allowed for this field"]
          ))
      )

    %{
      episode
      | care_manager: %{
          care_manager
          | identifier: %{identifier | type: %{codeable_concept | coding: coding}}
        }
    }
  end

  def validate_care_manager(%Episode{} = episode, nil, _), do: episode

  def validate_care_manager(%Episode{} = episode, %{} = reference, client_id) do
    validate_care_manager(%{episode | care_manager: Reference.create(reference)}, client_id)
  end

  def validate_referral_requests(%Episode{} = episode, client_id, excluded_ids \\ []) do
    referral_requests = episode.referral_requests || []
    now = DateTime.utc_now()

    referral_requests =
      Enum.map(referral_requests, fn referral ->
        identifier =
          if referral.identifier.value in excluded_ids do
            referral.identifier
          else
            referral.identifier
            |> add_validations(:value, service_request_reference: [client_id: client_id, datetime: now])
          end

        %{referral | identifier: identifier}
      end)

    %{episode | referral_requests: referral_requests}
  end

  def validate_referral_requests(%Episode{} = episode, references, client_id, excluded_ids) do
    references = if is_list(references), do: Enum.map(references, &Reference.create(&1)), else: references
    validate_referral_requests(%{episode | referral_requests: references}, client_id, excluded_ids)
  end
end
