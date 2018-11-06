defmodule Honeybadger.Logger do
  @moduledoc false

  @behaviour :gen_event

  require Logger

  alias Honeybadger.Utils

  def init(args) do
    Logger.warn("--- #{__MODULE__}.init(): args: #{inspect args}")
    {:ok, args}
  end

  ## Callbacks

  def handle_event({_type, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event(event, state) do
    Logger.warn("--- #{__MODULE__}.handle_event(): event #{inspect event}")
    handle_error(event)

    {:ok, state}
  end

  def handle_call({:configure, new_keys}, _state) do
    Logger.warn("--- #{__MODULE__}.handle_call(): :configure  #{inspect new_keys}")
    {:ok, :ok, new_keys}
  end

  def handle_call(request, _state) do
    exit({:bad_call, request})
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp handle_error({:error_report, _gl, {_pid, _type, [message | _]}}) when is_list(message) do
    Logger.warn("--- DX DX DX #{__MODULE__}.handle_error()")
    try do
      context =
        message
        |> get_in([:dictionary, :honeybadger_context])
        |> merge_metadata(get_in(message, [:dictionary, :logger_metadata]))

      Logger.warn("--- DX DX DX #{__MODULE__}.handle_error()  message[:error_info]: #{inspect message[:error_info]}")
      message[:error_info]
      |> filter_error()
      |> case do
           {_kind, {exception, stacktrace}, _stack} ->
               Honeybadger.notify(exception, context, stacktrace)

           {_kind, exception, stacktrace} ->
               Honeybadger.notify(exception, context, stacktrace)
         end

    rescue
      exception ->
        Logger.warn(fn ->
          error_type = Utils.module_to_string(exception.__struct__)
          reason = Exception.message(exception)

          "Unable to notify Honeybadger! #{error_type}: #{reason}"
        end)
    end
  end

  defp handle_error(_event) do
    :ok
  end

  defp filter_error({:error, %module_name{}, _stack} = error_info) do
    Logger.warn("--- #{__MODULE__}.filter_error()")
    filters = Honeybadger.get_env(:filter_sasl_errors)
    # TODO
    # unless module_name in filters do
    if not module_name in filters do
      IO.puts("--- PASS #{module_name}")
      Logger.warn("--- DX #{__MODULE__}.filter_error: PASS module_name: #{inspect module_name}")
      error_info
    else
      IO.puts("--- FILTER #{module_name}")
      Logger.warn("--- DX #{__MODULE__}.filter_error: FILTER module_name: #{inspect module_name}")
      nil
    end
  end

  defp filter_error(error_info), do: error_info

  defp merge_metadata(%{} = context, {_, metadata}) when is_list(metadata) do
    metadata
    |> Map.new()
    |> Map.merge(context)
  end

  defp merge_metadata(context, _md), do: context
end
