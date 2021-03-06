defmodule Core.Kafka.Consumer do
  @moduledoc false

  alias Core.Approvals.Consumer, as: ApprovalsConsumer
  alias Core.CacheHelper
  alias Core.Job
  alias Core.Jobs
  alias Core.Jobs.ApprovalCreateJob
  alias Core.Jobs.ApprovalResendJob
  alias Core.Jobs.DiagnosticReportPackageCancelJob
  alias Core.Jobs.DiagnosticReportPackageCreateJob
  alias Core.Jobs.EpisodeCancelJob
  alias Core.Jobs.EpisodeCloseJob
  alias Core.Jobs.EpisodeCreateJob
  alias Core.Jobs.EpisodeUpdateJob
  alias Core.Jobs.PackageCancelJob
  alias Core.Jobs.PackageCreateJob
  alias Core.Jobs.ServiceRequestCancelJob
  alias Core.Jobs.ServiceRequestCloseJob
  alias Core.Jobs.ServiceRequestCompleteJob
  alias Core.Jobs.ServiceRequestCreateJob
  alias Core.Jobs.ServiceRequestProcessJob
  alias Core.Jobs.ServiceRequestRecallJob
  alias Core.Jobs.ServiceRequestReleaseJob
  alias Core.Jobs.ServiceRequestUseJob
  alias Core.Mongo.Transaction
  alias Core.Patients
  alias Core.Patients.DiagnosticReports.Consumer, as: DiagnosticReportConsumer
  alias Core.Patients.Episodes.Consumer, as: EpisodesConsumer
  alias Core.ServiceRequests.Consumer, as: ServiceRequestsConsumer

  require Logger

  @status_failed_with_error Job.status(:failed_with_error)
  @status_pending Job.status(:pending)

  def consume(%PackageCreateJob{} = package_create_job) do
    do_consume(Patients, :consume_create_package, package_create_job)
  end

  def consume(%PackageCancelJob{} = package_cancel_job) do
    do_consume(Patients, :consume_cancel_package, package_cancel_job)
  end

  def consume(%EpisodeCreateJob{} = episode_create_job) do
    do_consume(EpisodesConsumer, :consume_create_episode, episode_create_job)
  end

  def consume(%EpisodeUpdateJob{} = episode_update_job) do
    do_consume(EpisodesConsumer, :consume_update_episode, episode_update_job)
  end

  def consume(%EpisodeCloseJob{} = episode_close_job) do
    do_consume(EpisodesConsumer, :consume_close_episode, episode_close_job)
  end

  def consume(%EpisodeCancelJob{} = episode_cancel_job) do
    do_consume(EpisodesConsumer, :consume_cancel_episode, episode_cancel_job)
  end

  def consume(%ServiceRequestCreateJob{} = service_request_create_job) do
    do_consume(ServiceRequestsConsumer, :consume_create_service_request, service_request_create_job)
  end

  def consume(%ServiceRequestUseJob{} = service_request_use_job) do
    do_consume(ServiceRequestsConsumer, :consume_use_service_request, service_request_use_job)
  end

  def consume(%ServiceRequestReleaseJob{} = service_request_release_job) do
    do_consume(ServiceRequestsConsumer, :consume_release_service_request, service_request_release_job)
  end

  def consume(%ServiceRequestCancelJob{} = service_request_cancel_job) do
    do_consume(ServiceRequestsConsumer, :consume_cancel_service_request, service_request_cancel_job)
  end

  def consume(%ServiceRequestCloseJob{} = service_request_close_job) do
    do_consume(ServiceRequestsConsumer, :consume_close_service_request, service_request_close_job)
  end

  def consume(%ServiceRequestRecallJob{} = service_request_recall_job) do
    do_consume(ServiceRequestsConsumer, :consume_recall_service_request, service_request_recall_job)
  end

  def consume(%ServiceRequestProcessJob{} = service_request_process_job) do
    do_consume(ServiceRequestsConsumer, :consume_process_service_request, service_request_process_job)
  end

  def consume(%ServiceRequestCompleteJob{} = service_request_complete_job) do
    do_consume(ServiceRequestsConsumer, :consume_complete_service_request, service_request_complete_job)
  end

  def consume(%ApprovalCreateJob{} = approval_create_job) do
    do_consume(ApprovalsConsumer, :consume_create_approval, approval_create_job)
  end

  def consume(%ApprovalResendJob{} = approval_resend_job) do
    do_consume(ApprovalsConsumer, :consume_resend_approval, approval_resend_job)
  end

  def consume(%DiagnosticReportPackageCreateJob{} = diagnostic_report_package_create_job) do
    do_consume(DiagnosticReportConsumer, :consume_create_package, diagnostic_report_package_create_job)
  end

  def consume(%DiagnosticReportPackageCancelJob{} = diagnostic_report_package_cancel_job) do
    do_consume(DiagnosticReportConsumer, :consume_cancel_package, diagnostic_report_package_cancel_job)
  end

  def consume(value) do
    Logger.warn(fn -> "unknown kafka event #{inspect(value)}" end)
    :ok
  end

  defp do_consume(module, fun, %{_id: id} = kafka_job) do
    case Jobs.get_by_id(id) do
      {:ok, %Job{status: @status_pending}} ->
        :ets.new(CacheHelper.get_cache_key(), [:set, :protected, :named_table])

        try do
          :ok = apply(module, fun, [kafka_job])
        rescue
          error ->
            Logger.warn(inspect(error) <> ". Job: " <> inspect(kafka_job) <> "Stacktrace: " <> inspect(__STACKTRACE__))

            :ok =
              %Transaction{patient_id: kafka_job.patient_id_hash}
              |> Jobs.update(id, @status_failed_with_error, inspect(error), 500)
              |> Transaction.flush()
        end

        :ets.delete(CacheHelper.get_cache_key())
        :ok

      {:ok, %Job{}} ->
        Logger.warn("Job with id = #{id} is already processed. Skipping.")
        :ok

      _ ->
        response = "Can't get request by id #{id}"
        Logger.warn(fn -> response end)
        :ok
    end
  end
end
