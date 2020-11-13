require 'rest-client'
require 'json'

# here is our jira instance
project_key = 'ABC'
jira_url = 'https://simp-project.atlassian.net/rest/api/2/search?'

# find current sprint
filter = 'jql=project=SIMP'

# set a max # results - defaults to 50 (we can switch this to a loop later)
total_issues = 1
ticket_count = 0
maxresults = 50

# set up file for comments
pullfile =  "pull_requests.csv"
$pulls_file = File.open(pullfile, 'w')

# while we have tickets still
while ticket_count < total_issues

  # call the code
  newfilter = "#{filter}&maxResults=#{maxresults}&startAt=#{ticket_count}"
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
#    puts "issue is #{issue['id']} key is #{issue['key']}" 

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
      sprintid = idstring['name']
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

   # get status
    status =  issue['fields']['status']['name']

    # get fixver
    if (issue['fields']['fixVersions'].length > 0) then
      fixverstring = issue['fields']['fixVersions'][0]
      fixver = fixverstring['name']
    else
      fixver = ''
    end


    # see if we have at least one open PR
    if (issue['fields']['customfield_10300'].length > 0) then
      pr_stat = issue['fields']['customfield_10300'] 
    else
      pr_stat = ''
    end
    if (pr_stat.include?("OPEN")) then
      $pulls_file.puts "ticket #{issuekey} has at least one open PR"
      puts "ticket #{issuekey} has at least one open PR"
    end
    if ((status != "Closed") and (pr_stat.include?("MERGED"))) then
      $pulls_file.puts "ticket #{issuekey} has at least one closed PR and status = #{status}"
      puts "ticket #{issuekey} has at least one closed PR and status = #{status}"
    end
 
    # get comment
    # puts "comment is #{issue['comment']}"
    if (issue['comment'] != nil) then
      comment = issue['comment'] 
    else
      comment = ''
    end
    comment_url = "https://simp-project.atlassian.net/rest/api/2/issue/#{issuekey}/comment"
    comment_response = RestClient.get(comment_url)
    comment_data = JSON.parse(comment_response.body)
    if (comment_data['total'] > 0)
      comment_data['comments'].each do |comment| 
        temp = comment['body'].tr('"', "\'")
        comment_text = temp
        # $comment_file.puts("#{issuekey}, #{status}, #{comment['updated']}, \"#{comment['body']}\"")
      end
    else
      comment_text = ""
    end

    # if this is the first output, then open the file with the sprintname and write the header
    if (ticket_count == 0) then
      # first create two .csv files - one with the parent appended, the other without - ensure the field names are OK
      filesprint = sprintid.gsub(" ","_")
      filesprint = filesprint.gsub("__","_")
      pullfile =  "currentpull#{filesprint}.csv"
      $parentpullfile = File.open(pullfile, 'w')
      # $parentpullfile.puts('Issue id,Parent id,Summary,Issue Type,Story Points,Sprint,Description,Assignee,Fix Version')
     end

    # write to files
    # $parentpullfile.puts("#{issuekey},#{parent},\"#{parent}/#{summary} (#{issuekey})\",#{issuetype},#{points},#{sprintid},\"#{desc}\",#{assignee},#{fixver}")
    ticket_count = ticket_count + 1

  end # while there are still tickets
  puts "ticket count is #{ticket_count}"
end
