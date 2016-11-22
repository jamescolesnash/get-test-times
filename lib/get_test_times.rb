require 'rest-client'
require 'json'
require 'pry'
require 'gelf'
require 'digest/crc64'

class GetTestTimes
  $token = "e2203dc09d587b853d016919fda73c15aef42e92"
  $base_log_path = "log/"
  $graylog_host = "localhost"
  $graylog_port = 12201

  SPECIAL_PREFIXES = {
      query_string: "_",
      request_time: "_",
      host: "_",
      timestamp: "",
    }

  def run
    branch = ARGV[0] ? ARGV[0] : "master"

    url_array = get_log_urls_by_branch(branch)

    # test_times = ['Path,Name,Date,Order in Job,Job Id,Branch Id,Duration,Pass/Fail,Exception']
    test_times = []
    for url in url_array
      test_time_string = get_test_times(url.split('/')[11], url)
      test_times.push(test_time_string) if !test_times.include? test_time_string
    end

    flat_compact = test_times.flatten(1).compact()
    File.write("test_times_#{Time.now.to_f}.csv", flat_compact.join("\n"))

    gelf = GELF::Notifier.new($graylog_host, $graylog_port, "WAN")
    flat_compact.each do |value|
      gelf.notify!(gelf_attributes(value))
    end

  end

  def gelf_attributes(value)
    split = value.to_s.split(',')

    fingerprint = Digest::CRC64.hexdigest(split[2]).upcase
    gelf_attrs = {
      "version" => "1.1",
      "short_message" => "Selenium test time",
      "_type" => "test-time",
      "_fingerprint" => fingerprint,
    }
    prefix = "_testtimes_"
    gelf_attrs["#{prefix}path"]         = split[0]
    gelf_attrs["#{prefix}name"]         = split[1]
    gelf_attrs["timestamp"]             = split[2]
    gelf_attrs["#{prefix}order_in_job"] = split[3]
    gelf_attrs["#{prefix}job_id"]       = split[4]
    gelf_attrs["#{prefix}branch_id"]    = split[5]
    gelf_attrs["#{prefix}duration"]     = split[6]
    gelf_attrs["#{prefix}pass_fail"]    = split[7]
    gelf_attrs["#{prefix}exception"]    = split[8]
    gelf_attrs
  end

  def get_log_urls_by_branch(branch_name)
    url = "http://api.buildkite.com/v2/organizations/clio/pipelines/clio-app/builds"
    params = { access_token: $token, branch: branch_name }
    res = RestClient::Request.execute(method: :get, url: url, headers: { params: params })
    builds = JSON.parse(res)

    puts "Found #{builds.count} builds on #{branch_name}"

    all_jobs = []
    for build in builds
      jobs = build['jobs'].select { |a| a['name'].to_s.include? "70 Rspec js" }
      puts "Found #{jobs.count} jobs on commit #{build['commit']} - #{build['message']}"
      urls = jobs.map { |d| d["log_url"] }
      all_jobs.push(urls)
    end
    all_jobs.flatten(1)
  end

  def get_buildkite_log(url)
    params = {access_token: $token}
    res = RestClient::Request.execute(method: :get, url: url, headers: { params: params })
    JSON.parse(res)['content']
  end

  def get_test_times(guid, url)
    file_path = "#{$base_log_path}#{guid}"
    files = Dir["#{$base_log_path}*"]

    if files.include? file_path
      puts "Log for job #{guid} already downloaded, fetching from disk."
      content = File.read(file_path)
    else
      puts "Log for job #{guid} is not downloaded, downloading."
      content = get_buildkite_log(url)
      File.write(file_path, content)
    end

    return nil if !content.include? '---Test Times---'

    split = content.split('---Test Times---')

    return nil if split.count != 3

    split[1].split(/\r\n/).reject(&:empty?)
  end
end
