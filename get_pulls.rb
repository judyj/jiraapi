# require 'octokit'
require 'rest-client'
require 'json'

# fetch user information
username = 'user'
access_token = 'myaccesstoken'
me = 'myghid'

# set up output file
listfile =  "all_pull_requests.csv"
$list_file = File.open(listfile, 'w')
$list_file.puts('Repo, PR owner, number, status')


start_page = 1
per_page = 10
pages = start_page
start_page = 1
done = false
pr_done = false

done = false
# Get date info
time = Time.new

datedata = "#{time.year}-#{time.month}-#{time.day}"

# create output files - one for stats and one for specific referrers
auth_result = JSON.parse(RestClient.get('https://api.github.com/user',
                         {:params => {:oauth_token => access_token} }) )

# check our rate limit
rlcommand = "https://api.github.com/rate_limit"
result = RestClient.get(rlcommand)

# puts "command is #{command}"

while done == false do
  # fetch repos
  command = "https://api.github.com/users/#{username}/repos"

  repo_result = JSON.parse(RestClient.get("#{command}",
      {:params => {:oauth_token => access_token, :per_page => per_page, :page => pages} }))
  puts "number of repos is #{repo_result.size}"
  if (repo_result.size <= 0) then
     done = true
  else
    # for each repo, get the data we need
    repo_result.each do |repo|
      reponame = repo["name"]
      puts "repo #{reponame}"

      pcommand = "https://api.github.com/repos/#{username}/#{reponame}/pulls"
      pr_done = false
      start_pr_page = 1
      pr_pages = start_pr_page
      per_pr_page = 50      
      while pr_done != true do
        # puts "running pr command #{pcommand} page #{pr_pages} per_page #{per_pr_page}"
        pull_result = JSON.parse(RestClient.get("#{pcommand}",
             {:params => {:oauth_token => access_token, :per_page => per_pr_page, :page => pr_pages, :state => "all"} }))
        numpulls = pull_result.size
        # if ((pull_result.size > 0) or (pull_result != nil)) then
        if (pull_result.size > 0) then
           pull_result.each do |pullr|
              prowner = pullr["user"]["login"]
              prstate = pullr["state"]
              prnumber = pullr["number"]
              $list_file.puts("#{reponame}, #{prowner}, #{prstate}, #{prnumber}")
           end
           # numpulls = pull_result["number"]
           puts "for #{reponame} the number of PRs is #{numpulls}"
        else
           puts "no pulls for #{reponame}"
           pr_done = true
        end
        pr_pages = pr_pages + 1
      end #pr_done
    end # results > 0
    pages = pages + 1
  end # each call
end # thanks!


