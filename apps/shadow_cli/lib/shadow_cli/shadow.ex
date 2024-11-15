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
    IO.puts("Shadow file parser and password cracker.")

    IO.puts("Usage is one of following forms:")
    IO.puts(" shadow_hash submit <shadow_path> [--user <username>]")
    IO.puts(" shadow_hash status")
    IO.puts(" shadow_hash truncate-clients <num_clients>")

    IO.puts(
      " <shadow_path> : The path to the linux shadow file containing hashed user passwords."
    )

    IO.puts(" --user <user>  : Supply a username, the passwords for which will be cracked.")
    IO.puts("                  Otherwise, attempts to crack all passwords in the shadow file.")
    IO.puts(" --all-chars    : Will also bruteforce with non-printable characters")

    IO.puts(
      " --dictionary <dictionary>  : Supply a dictionary of passwords that are attempted initially"
    )

    IO.puts(" --workers    <num_workers> : Max # of workers to allocate to submitted jobs.")
    IO.puts(" --verbose       : Print verbose logging")
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
           workers: workers,
           interface: interface,
           get_results: get_results,
           cookie: cookie
         }}
      ) do
    connect_datanode(data_node, interface, cookie)

    unless verbose do
      Logger.configure(level: :none)
    end

    job_names =
      load_passwords(user, shadow, password)
      |> process_passwords(dictionary, resolve_charset(all_chars), workers)

    if get_results do
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
    IO.puts("Connecting to datanode (#{data_node})")

    unless Node.alive?() do
      Node.start(String.to_atom("#{ShadowData.Util.unique_name("shadow_cli")}@#{interface}"))
    end

    if cookie !== nil, do: Node.set_cookie(String.to_atom(cookie))

    data_node_name = String.to_atom(data_node)

    r = Node.connect(data_node_name)

    if r !== true do
      IO.puts("Could not connect to data node...")
      exit(0)
    end

    :global.sync()
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

  defp print_result_short(%ResultBank.Result{name: name, elapsed: elapsed}) do
    IO.puts("Result :: #{name} :: #{elapsed / 1_000_000}s")
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

  def process_passwords(pwd, dictionary, charset, workers) do
    if pwd == [] do
      IO.puts("No user matching the search criteria was found. No attacks will be performed.")
      []
    else
      # IO.puts(" *** Bruteforce will be performed on the following users")

      # pwd |> Enum.each(fn {u, _} -> IO.puts("     - #{u}") end)

      for {u, p} <- pwd,
          do: process_password_entry(u, p, dictionary, charset, workers)
    end
  end

  defp _dictionary_entry_trim_newline(line) do
    if String.ends_with?(line, "\r\n") do
      {trimmed, _} = String.split_at(line, String.length(line) - 1)
      trimmed
    else
      if(String.ends_with?(line, "\n")) do
        {trimmed, _} = String.split_at(line, String.length(line))
        trimmed
      else
        line
      end
    end
  end

  defp dictionary(nil) do
    # IO.puts(" - No dictionary file was supplied. Skipping dictionary attack.")
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

  def process_password_entry(user, pwd, dictionary, charset, workers) do
    # IO.puts("Attempting to recover password for user #{user}")
    %{hash: hash, algo: algo} = PasswordParse.parse(pwd)
    # %{method: method} = algo

    # IO.puts(" - Detected password type: #{Atom.to_string(method)}")
    # IO.puts(" - Detected password hash: #{hash}")
    name = create_name(user)
    submit(name, algo, hash, dictionary, charset, workers)

    # {elapsed, password} = :timer.tc(__MODULE__, :crack, [algo, hash, dictionary, charset])

    # elapsed = elapsed / 1_000_000

    # case password do
    #  nil ->
    #    IO.puts("Password not found for user #{user} in #{elapsed} seconds")
    #
    #  plaintext ->
    #    IO.puts("Password cracked for #{user} in #{elapsed} seconds. Plaintext: \"#{plaintext}\"")
    # end

    name
  end

  defp chunk_dictionary_stream(next, current \\ []) do
    case WorkUnitParser.take_work([next]) do
      :empty -> current
      {chunk, stream} -> chunk_dictionary_stream(stream, [current | chunk])
    end
  end

  defp submit(name, algo, hash, dictionary, charset, workers) do
    Logger.info("Submitting bruteforce job to job bank.")
    # Scheduler.submit_job(self())

    dictionary_work =
      chunk_dictionary_stream(%DictionaryStreamWorkUnit{stream: dictionary(dictionary)})

    work =
      dictionary_work ++
        [
          %BruteforceWorkUnit{begin: 0, last: :inf, charset: charset}
        ]

    # Logger.info("Starting job WorkPool...")
    # {:ok, plaintext} = WorkPool.schedule(jobs, algo, hash, chunk_size)

    # Logger.info("Dismissing bruteforce job from job server.")
    # Scheduler.dismiss_job(self())

    # plaintext

    job = %Job{
      current_work: work,
      disabled: false,
      name: name,
      target: hash,
      algo: algo,
      max_workers: workers
    }

    IO.puts("Submitting job...")

    JobBank.commit(job)
  end
end
