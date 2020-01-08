require 'rest-client'
require 'json'

# open outputfile
outputfile='comp_list.csv'
outfile = File.open(outputfile, 'w')
outfile.puts('Component,Description')

# here is our jira instance
project_key = 'ABC'
# jira_url = 'https://simp-project.atlassian.net/rest/api/2/search?'
jira_url = 'https://simp-project.atlassian.net/rest/api/2/'

# find current sprint
# filter = "jql=\"Parent Link\"=SIMP-6063"
filter = "project/SIMP/components"

# set a max # results - defaults to 50 (we can switch this to a loop later)
total_comps = 1
ticket_count = 0
maxresults = 50

# while we have tickets still
while ticket_count < total_comps

  # call the code
  newfilter = filter
  puts "query is #{jira_url + newfilter}"
  response = RestClient.get(jira_url + newfilter)
  raise 'Error with the http request!' if response.code != 200

  data = JSON.parse(response.body)

  data.each do |comp|
    name = comp["name"]
    if comp["description"] == nil
      desc = ""
    else    
      desc = comp["description"]
    end
    # puts name, desc
    # write to files
    outfile.puts("#{name},\"#{desc}\"")
    ticket_count = ticket_count + 1

  end # while there are still tickets
  puts "component count is #{ticket_count}"
end
