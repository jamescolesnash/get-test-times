require 'rest-client'
require 'json'
require 'pry'
require 'csv'

class GetTestTimes
  $token = "e2203dc09d587b853d016919fda73c15aef42e92"
  $base_log_path = "log/"

  SPECIAL_PREFIXES = {
      query_string: "_",
      request_time: "_",
      host: "_",
      timestamp: "",
    }

  def run
    branch = ARGV[0] ? ARGV[0] : "master"
    build_amount = ARGV[1] ? ARGV[1] : "1"

    test_times_csv = get_test_times_by_branch(branch, build_amount)

    if test_times_csv.count == 0 
      puts "No test times found"
      exit
    end

    test_times_csv = test_times_csv.sort_by { |row| row['run_time'].to_f }.reverse!

    puts "10 slowest tests"
    (1..11).each do |i|
      puts "#{test_times_csv[i]['file_path']}, #{test_times_csv[i]['run_time']}"
    end

    test_times_csv.sort_by! { |row| row['inserts'].to_f }.reverse!

    puts "10 most inserts"
    (1..11).each do |i|
      puts "#{test_times_csv[i]['file_path']}, #{test_times_csv[i]['inserts']}"
    end
  end

  def get_test_times_by_branch(branch_name, amount = 1)
    builds = get_builds_by_branch(branch_name, amount)
    puts "Found #{builds.count} builds on #{branch_name}"

    csv = CSV::Table.new([])
    counter = 0
    builds.each do |build| 
      if build['state'] == "running"
        puts "#{build['message']} still running, skipping." 
        next 
      end
      jobs = build['jobs'].select { |a| a['name'].to_s.include? "Rspec" }
      puts "Found #{jobs.count} jobs on #{build['message']}"
      jobs.each do |job| 
        log_path = "#{$base_log_path}#{job['id']}"

        Dir.mkdir log_path if !File.directory?(log_path)
        path = Dir.glob("#{log_path}/*-test_times.log")

        if path.count == 0
          system "aws s3 cp s3://clio-buildkite-artifacts/#{job['id']}/log/ #{log_path} --exclude '*' --include '*-test_times.log' --recursive", :out => File::NULL
          path = Dir.glob("#{log_path}/*-test_times.log")
        end

        if path.count != 0
          puts "Reading: #{path.first}"

          CSV.foreach(path.first, headers: true) do |row| 
            csv << row
            counter += 1
          end 
        end
      end
    end
    csv
  end

  def get_builds_by_branch(branch_name, amount = 1)
    url = "http://api.buildkite.com/v2/organizations/clio/pipelines/clio-app/builds"
    params = {
      access_token: $token,
      branch: branch_name,
      per_page: amount,
      page: 1 }
    res = RestClient::Request.execute(method: :get, url: url, headers: { params: params })
    JSON.parse(res)
  end
end
