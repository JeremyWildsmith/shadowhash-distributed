defmodule ShadowCli.Shadow do
  require Logger
  alias ShadowData.ResultBank
  alias ShadowData.WorkUnitParser
  alias ShadowData.PasswordGraph
  alias ShadowData.DictionaryWorkUnit
  alias ShadowCli.PasswordParse
  alias ShadowCli.ShadowParse
  alias ShadowData.DictionaryStreamWorkUnit
  alias ShadowData.BruteforceWorkUnit
  alias ShadowData.PasswordCharset
  alias ShadowData.Job
  alias ShadowData.JobBank
  alias ShadowData.Util

  defp resolve_charset(false), do: PasswordCharset.printable_mapping()
  defp resolve_charset(true), do: PasswordCharset.all_mapping()

  def process({:help}) do
    IO.puts("Shadow hash CLI command interface.")

    IO.puts("Usage is one of following forms:")
    IO.puts(" mix shadow_cli submit [<shadow_path>]")
    IO.puts(" mix shadow_cli status")
    IO.puts(" mix shadow_cli truncate-clients <num_clients>")

    IO.puts("\nSwitches valid for all verbs:")
    IO.puts(" --data-node    : Name of the data node where the scheduler, job and result bank are available")
    IO.puts(" --cookie       : Security cookie to use when connecting to the data-node.")
    IO.puts(" --interface    : IP Address to advertise to register with as a node (IP Datanode can address you by)")
    IO.puts(" --verbose      : Print verbose logging")

    IO.puts("\nsubmit verb - submit a bruteforce job to job bank")
    IO.puts(" <shadow_path> : Optional path to the linux shadow file containing hashed user passwords.")
    IO.puts(" --password    : Specify a password in a valid form inline to process with/without specifying a shadow file")
    IO.puts(" --dictionary <dictionary>  : Supply a dictionary of passwords that are attempted initially")
    IO.puts(" --user <user> : Supply a username, the passwords for which will be cracked.")
    IO.puts("                  Otherwise, attempts to crack all passwords in the shadow file.")
    IO.puts(" --all-chars   : Will also bruteforce with non-printable characters")

    IO.puts(" --get-results : Wait for the results and print them out once ready")

    IO.puts("\nstatus verb - Interrogate status of jobs / results")
    IO.puts(" --show-all     : Show all jobs (even suspended or inactive jobs.)")

    IO.puts("\ntruncate-clients verb - Remove clients registered on the system")
    IO.puts(" <num_clients>  : Maximum number of clients to keep connected to the system.")
  end

  def process({:trunc_clients, %{data_node: data_node, interface: interface, limit: limit, cookie: cookie}}) do
    connect_datanode(data_node, interface, cookie)

    r = ShadowData.Scheduler.truncate_clients(limit)

    IO.puts("Number of active clients: #{r}")
  end

  def process({:status, %{data_node: data_node, interface: interface, show_all: show_all, cookie: cookie}}) do
    connect_datanode(data_node, interface, cookie)

    active = ShadowData.Scheduler.list_active()

    all_jobs = ShadowData.JobBank.list_jobs()

    active_jobs =
      all_jobs
      |> Enum.filter(fn %{name: name} -> Map.has_key?(active, name) end)

    inactive_jobs =
      all_jobs
      |> Enum.filter(fn %{name: name} -> not Map.has_key?(active, name) end)

    IO.puts("Active Jobs (#{map_size(active)}/#{length(all_jobs)}):")

    print_jobs_collection(active, active_jobs)

    print_results(ShadowData.ResultBank.get_results())

    if show_all do
      IO.puts("Inactive Jobs:")

      print_jobs_collection(active, inactive_jobs)
    end
  end

  def process(
        {:submit,
         %{
           shadow: shadow,
           user: user,
           dictionary: dictionary,
           all_chars: all_chars,
           verbose: verbose,
           password: password,
           data_node: data_node,
           interface: interface,
           get_results: query_for_results,
           cookie: cookie
         }}
      ) do
    connect_datanode(data_node, interface, cookie)

    unless verbose do
      Logger.configure(level: :none)
    end

    job_names =
      load_passwords(user, shadow, password)
      |> process_passwords(dictionary, resolve_charset(all_chars))

    if query_for_results do
      IO.puts("Waiting for results...")
      get_results(job_names)
    end
  end

  defp get_results([]), do: nil

  defp get_results([current | remaining] = all) do
    case ResultBank.fetch(current) do
      nil ->
        get_results(all)
      r ->
        print_result_short(r)
        get_results(remaining)
    end
  end

  defp connect_datanode(data_node, interface, cookie) do
    Util.connect_datanode("shadow_cli", data_node, interface, cookie)
  end

  defp parse_job_status(%ShadowData.Job{current_work: current_work}) do
    total_jobs = current_work |> Enum.count()

    case List.first(current_work) do
      nil ->
        "Done"

      %BruteforceWorkUnit{begin: begin, last: last, charset: charset} when last == :inf ->
        "1/#{total_jobs} - Bruteforce \"#{PasswordGraph.from_index(begin, charset)}\" to infinity"

      %BruteforceWorkUnit{begin: begin, last: last, charset: charset} when last == :inf ->
        "1/#{total_jobs} - Bruteforce \"#{PasswordGraph.from_index(begin, charset)}\" to \"#{PasswordGraph.from_index(last, charset)}\""

      %DictionaryWorkUnit{names: names} ->
        "1/#{total_jobs} -> Dictionary Attack - Word \"#{List.first(names, "-")}\""
    end
  end

  defp print_job(
         active,
         %ShadowData.Job{
           name: name,
           life_time: life_time,
           results_reported: results_reported,
           elapsed: elapsed
         } = job
       ) do
    IO.puts(" - Job: #{name}")

    active_status = if Map.has_key?(active, name), do: "active", else: "inactive"
    worker_activity = Map.get(active, name, 0)

    IO.puts("    Work Pool: #{active_status}")
    IO.puts("    Worker Activity (past 1.5 mins): #{worker_activity}")
    IO.puts("    Total Elapsed Time: #{elapsed / 1_000_000}s")
    IO.puts("    Net Time Cost: #{life_time / 1_000_000}s")
    IO.puts("    Chunks Processed: #{results_reported}")
    IO.puts("    Effective Cost / Chunk: #{life_time / max(1, results_reported) / 1_000_000}s")
    IO.puts("    Current Progress: #{parse_job_status(job)}")
  end

  defp print_jobs_collection(active, jobs) do
    if length(jobs) > 0 do
      for job <- jobs do
        print_job(active, job)
      end
    else
      IO.puts(" - No jobs.")
    end

    IO.puts("\n")
  end

  defp print_result_short(%ResultBank.Result{result: result, elapsed: elapsed}) do
    IO.puts("Result :: plaintext=#{result} :: #{elapsed / 1_000_000}s")
  end

  defp print_results(results) do
    IO.puts("Posted Results:")

    for %{name: name, source: source, result: result, elapsed: elapsed} <- results do
      IO.puts("  - #{name}")
      IO.puts("      - Plaintext \\ Source: \"#{result}\" \\ \"#{source}\"")
      IO.puts("        Time: #{elapsed / 1_000_000}s")
    end
  end

  defp load_passwords(user, shadow, password) do
    pwd =
      unless is_nil(shadow) do
        case File.read(shadow) do
          {:ok, r} ->
            ShadowParse.extract_passwords(r, user)

          _ ->
            IO.puts(
              "Error reading from shadow file. It may not exist. No passwords will be collected from shadow file."
            )

            []
        end
      else
        []
      end

    unless is_nil(password) do
      pwd ++ [{"command_line_entry", password}]
    else
      pwd
    end
  end

  def process_passwords(pwd, dictionary, charset) do
    if pwd == [] do
      IO.puts("No user matching the search criteria was found. No attacks will be performed.")
      []
    else
      for {u, p} <- pwd,
          do: process_password_entry(u, p, dictionary, charset)
    end
  end

  defp _dictionary_entry_trim_newline(line) do
    if String.ends_with?(line, "\r\n") do
      {trimmed, _} = String.split_at(line, String.length(line) - 2)
      trimmed
    else
      if(String.ends_with?(line, "\n")) do
        {trimmed, _} = String.split_at(line, String.length(line) - 1)
        trimmed
      else
        line
      end
    end
  end

  defp dictionary(nil) do
    Logger.info(" - No dictionary file was supplied. Skipping dictionary attack.")
    []
  end

  defp dictionary(dictionary) do
    IO.puts(" - Dictionary provided: #{dictionary}.")

    if File.exists?(dictionary) do
      File.stream!(dictionary, :line)
      |> Stream.map(&_dictionary_entry_trim_newline/1)
    else
      IO.puts(" ! Unable to open dictionary file. It may not exist. Skipping")
      []
    end
  end

  def create_name(user) do
    "crack-#{user}-#{Util.unique_name()}"
  end

  def process_password_entry(user, pwd, dictionary, charset) do
    Logger.info("Attempting to recover password for user #{user}")
    %{hash: hash, algo: algo} = PasswordParse.parse(pwd)
    %{method: method} = algo

    Logger.info(" - Detected password type: #{Atom.to_string(method)}")
    Logger.info(" - Detected password hash: #{hash}")
    name = create_name(user)
    submit(name, algo, hash, dictionary, charset)

    name
  end

  defp chunk_dictionary_stream(next, current \\ []) do
    #{chunk, stream} = WorkUnitParser.take_work([next])
    #{chunk, stream} = WorkUnitParser.take_work(stream)

    #exit(0)
    case WorkUnitParser.take_work(next) do
      :empty -> current
      {chunk, stream} -> chunk_dictionary_stream(stream, [chunk | current])
    end
  end

  defp submit(name, algo, hash, dictionary, charset) do
    Logger.info("Submitting bruteforce job to job bank.")

    dictionary_work =
      chunk_dictionary_stream([%DictionaryStreamWorkUnit{stream: dictionary(dictionary)}])

    work =
      dictionary_work ++
        [
          %BruteforceWorkUnit{begin: 0, last: :inf, charset: charset}
        ]

    job = %Job{
      current_work: work,
      name: name,
      target: hash,
      algo: algo
    }

    IO.puts("Submitting job...")

    JobBank.commit(job)
  end
end
