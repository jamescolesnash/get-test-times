require 'rest-client'
require 'json'
require 'pry'

class GetTestTimes
  def run
    url_array = get_log_urls_by_branch("clio-41844-selenium-logging")
    test_times = []
    for d in url_array
      test_times.push(get_test_times(d))
    end

    test_times.each do |p|
      puts p
    end
  end

  def get_log_urls_by_branch(branch_name)
    url = "http://api.buildkite.com/v2/organizations/clio/pipelines/clio-app/builds?branch=#{branch_name}"
    res = RestClient::Request.execute method: :get, url: url, user: "james.coles-nash@clio.com", password: "cx4RWa5NWo2G"
    json = JSON.parse(res)

    jobs = json[0]['jobs'].select { |a| a['name'].include? "70 Rspec js" }
    puts "found #{jobs.count} JS jobs"
    jobs.map { |d| d["log_url"] }
  end

  def get_test_times(url)
    puts "Getting test times from: #{url}"
    res = RestClient::Request.execute method: :get, url: url, user: "james.coles-nash@clio.com", password: "cx4RWa5NWo2G"
    json = JSON.parse(res)

    json['content'].split('---Test Times---')[1]
  end
end
