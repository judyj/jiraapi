require 'rest-client'
require 'json'
require 'optparse'

# default days to pull 
days_back = 7

# get the days backif they were input
optsparse = OptionParser.new do |opts|
  opts.banner = "Usage: closed_pull -d days [options]"
  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end
  opts.on('-d', '--days NUMBER', 'Days back') do
    |s| puts "days is #{s}"
    days_back = s.strip
  end
end
optsparse.parse!

# set the date so we have a unique file
timenow = Time.new
pullfile = "tix_closed_#{timenow.year}-#{timenow.month}-#{timenow.day}.csv"

# first create two .csv files - one with the parent appended, the other without - ensure the field names are OK
parentpullfile = File.open(pullfile, 'w')
parentpullfile.puts('Issue id,Parent id,Summary,Issue Type,Story Points,Sprint,Description,Assignee,Fix Version, Component')

# here is our jira instance
project_key = 'ABC'
jira_url = 'https://simp-project.atlassian.net/rest/api/2/search?'

# find resolved within 7 days
filter = "jql=resolved%3e%2d#{days_back}d%20and%20status=closed"

# set a max # results -
total_issues = 1
ticket_count = 0
maxresults = 50

# while we have tickets still
while ticket_count < total_issues

  # call the code
  newfilter = "#{filter}&maxResults=#{maxresults}&startAt=#{ticket_count}"
  # puts "#{jira_url}#{filter}&maxResults=#{maxresults}&startAt=#{ticket_count}"
  puts "#{jira_url+newfilter}"
  response = RestClient.get(jira_url + newfilter)
  raise 'Error with the http request!' if response.code != 200

  data = JSON.parse(response.body)
  # puts "current data is #{data}"
  # find the number of tickets returned
  total_issues = data['total']

  data['issues'].each do |issue|
    points = issue['fields']['customfield_10005']
    points = points.to_i
    issuekey = issue['key']
    summary = issue['fields']['summary']
    desc = issue['fields']['description']
    # substitute apostrophe for quote
    unless desc.nil?
      temp = desc.tr('"', "\'")
      desc = temp
    end

    # see if it has a parent, and if so, display it"
    parent = if !issue['fields']['parent'].nil?
               issue['fields']['parent']['key']
             else
               "#{issuekey}."
             end

    # calculate the sprint by breaking the "sprint=" out of the sprint attributes string
    sprintdata = issue['fields']['customfield_10007']
    if sprintdata != nil
      idstring = sprintdata[0]
      # idstringname = idstring.slice(idstring.index('name='), idstring.size)
      idstringname = idstring["name"]
      # puts idstringname
      # comma = idstringname.index(',') - 1
      # sprintid = idstringname[5..comma]
    else
      sprintid = ''
    end

    # get type
    issuetype = if !issue['fields']['issuetype'].nil?
                  issue['fields']['issuetype']['name']
                else
                  ''
                end

    # get assignee
    assignee = if !issue['fields']['assignee'].nil?
                 issue['fields']['assignee']['name']
               else
                 ''
               end
    # get fixver
    if (issue['fields']['fixVersions'].length > 0) then
      fixverstring = issue['fields']['fixVersions'][0]
      fixver = fixverstring['name']
    else
      fixver = ''
    end

    # get component
    if (issue['fields']['components'].length > 0) then
      components = issue['fields']['components'][0]
      component = components['name']
    else
      component = ''
    end

    # write to files
    parentpullfile.puts("#{issuekey},#{parent},\"#{parent}/#{summary} (#{issuekey})\",#{issuetype},#{points},#{sprintid},\"#{desc}\",#{assignee},#{fixver},#{component}")
    ticket_count = ticket_count + 1

  end # while there are still tickets
  puts "ticket count is #{ticket_count}"
end
