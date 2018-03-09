# this does a pull of the closed tickets 
# one with parent/ one without
# the query is closed <= 16d
# (you may need to change it based on your sprint length - or just edit out what you don't need)
# you generally have to de-dupe it with what's already in there anyhow
#
require 'rest-client'
require 'json'

# first create two .csv files - one with the parent appended, the other without - ensure the field names are OK
pullfile = File.open("closedpull.csv", "w")
parentpullfile = File.open("closedpull_wparent.csv", "w")
pullfile.puts( "Issue id,Parent id,Summary,Issue Type,Story Points,Sprint,Description,Assignee")
parentpullfile.puts("Issue id,Parent id,Summary,Issue Type,Story Points,Sprint,Description,Assignee")

# here is our jira instance
project_key = "ABC"
jira_url = "https://simp-project.atlassian.net/rest/api/2/search?"

#find current sprint
filter = "jql=status%3dClosed%20and%20resolved%3e%2d16d"

# set a max # results - defaults to 50 (we can switch this to a loop later)
maxresults = 250
filter = "#{filter}&maxResults=#{maxresults}"

# call the code
response = RestClient.get(jira_url+filter)
if(response.code != 200)
  raise "Error with the http request!"
end

data = JSON.parse(response.body)
#puts "current data is #{data}"

data['issues'].each do |issue|
  points = issue['fields']['customfield_10005']
  points = points.to_i
  issuekey = issue['key']
  summary = issue['fields']['summary']
  desc = issue['fields']['description']
  if (desc != nil)
    temp = desc.gsub("\"","\'")
    desc = temp
  end

  # see if it has a parent, and if so, display it"
  if issue['fields']['parent'] != nil
    parent = issue['fields']['parent']['key']
  else
    parent = "#{issuekey}."
  end

  # calculate the sprint by breaking the "sprint=" out of the sprint attributes string 
  sprintdata = issue['fields']['customfield_10007']
  if sprintdata.size > 0
    idstring = sprintdata[0]
    idstringname = idstring.slice(idstring.index('name='),idstring.size)
    comma=idstringname.index(',')-1
    sprintid=idstringname[5..comma]
  else
    sprintid = ""
  end

  # get type
  if issue['fields']['issuetype'] != nil
    issuetype = issue['fields']['issuetype']['name']
  else
    issuetype = ""
  end

  # get assignee
  if issue['fields']['assignee'] != nil
    assignee = issue['fields']['assignee']['name']
  else
    assignee = ""
  end

  # get status
  if issue['fields']['status'] != nil
    status = issue['fields']['status']['name']
  else
    status = ""
  end
 
  # write to files 
  pullfile.puts( "#{issuekey},#{parent},\"#{summary} (#{issuekey})\",#{issuetype},#{points},#{sprintid},\"#{desc}\",#{assignee}" )
  parentpullfile.puts( "#{issuekey},#{parent},\"#{parent}/#{summary} (#{issuekey})\",#{issuetype},#{points},#{sprintid},\"#{desc}\",#{assignee}" )


  # here for later -- if we get stuck and need to find another issue attribute, use this as a starting point 
  issue['fields'].each do |ifield|
#    puts "field: #{ifield}"
#    puts "value: #issue['fields'][ifield]"
  end
end




