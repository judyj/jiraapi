#!/usr/bin/env ruby
# frozen_string_literal: true

#####################################################
#
# create_tix
# reads in a csv file
# creates a series of jira tickets based on column entries
# -f input file
# -s sprint number
#
#####################################################

require 'csv'
require 'rest-client'
require 'json'
require 'optparse'

# match a jira ticket's parent or blocker from original file to get jira id
def find_ticket(tikid)
  found = false
  # puts " number of tix is #{@tickets.length}"
  if @tickets.length.positive?
    @tickets.each do |ticket_entry|
      if ticket_entry['ticket_id'] == tikid
        found = true
        return ticket_entry['jira_id']
      end # match
    end # each site
  end # more than one
  return nil if found == false
end

# initialize
@jira_id = ''
inputfile = 'test.csv'
outputfile = 'test_tickets.csv'
lines = 0
userid = 'me@here.com:123456789012'
resultfile = 'putresult.json'
sprint = nil

@tickets = Array.new { {} }

# initialize the OSes in an array
os_type = ['', '', '', '', '', '', 'EL7', 'EL8', 'OEL7', 'OEL8', 'RHEL7', 'RHEL8']

# get the filename and sprint if input by the user
optsparse = OptionParser.new do |opts|
  opts.banner = 'Usage: create_tickets [options]'
  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end
  opts.on('-f', '--input NAME', 'Input file or directory name') do |f|
    inputfile = f.strip
  end
  opts.on('-s', '--sprint NUMBER', 'Input sprint number (Jira)') do |s|
    sprint = s.strip
  end
end
optsparse.parse!

# set up output file
outfile = File.open(outputfile, 'w')
outfile.puts('Ticket, Summary, Description, Component, Points, Parent, Jira ID')

# also write commands to a file in case it does not work, then we can try it mnaually to find the problem
cmdfile = File.open('commands.txt', 'w')

# set up input file
puts "inputfile is #{inputfile}"
CSV.foreach(inputfile) do |col|
  myticket = {}

  proj = 'SIMP'
  type = 'Story'
   points = 0

  # get out the fields we need
  ticket_id = col[0]
  summary = col[1]
  descr = col[2]
  component = col[3]
  blocker = col[4]
  points = col[5]

  # in case we need to edit description
  mydesc = descr

  # if no point value, make it zero
  points = 0 if points.nil?

  # see if the ticket ID has "." - if so it is a sub-task, if not, it is a task
  if ticket_id.include? '.'
    type = 'Sub-task'
    parent_id = ticket_id[0..ticket_id.index('.') - 1]
  else
    type = 'Story'
    parent_id = ''
  end
  # puts "ID is #{ticket_id}, parent is #{parent_id}"

  # summary - clean out values that will mess up the string
  summary = summary.gsub("\'", '')
  summary = summary.gsub("\r", '')
  summary = summary.gsub('{', '')
  summary = summary.gsub('}', '')
  summary = summary.gsub('"', ',')

  # description - clean out values that will mess up the string
  unless mydesc.nil?
    mydesc = mydesc.gsub("\'", '')
    mydesc = mydesc.gsub("\r", '')
    mydesc = mydesc.gsub('{', '')
    mydesc = mydesc.gsub('}', '')
    mydesc = mydesc.gsub('"', '')
  end

  # if the summary field is too long, we gotta move it over to the description
  if summary.size > 90
    summ = "#{summary[0..80]}..."
    mydesc = "#{summary}-#{mydesc}"
  else
    summ = summary
  end

  # check which O/Ses we're doing (if none found, make a generic ticket)
  foundone = false
  (6..11).each do |os|
    command_created = false
    if !col[os].nil? && ((col[os] == 'Y') || (col[os] == 'y'))
      prefix = os_type[os]
      summ_os = "#{prefix} - #{summ}"
      foundone = true
      command_created = true
    else
      summ_os = summ
    end

    # that last column does not exist, but just seeing if we had an O/S checked - if not, just do a ticket with no O/S
    if (os == 11) && (foundone == false)
      command_created = true
    end

    if type == 'Story'
      parentid = nil
      subtask = false
    else
      # for now
      subtask = true
      #      parentid = "TICKETFOR#{parent_id}"
      parentid = find_ticket(parent_id)
    end
 
    blockerid = find_ticket(blocker) unless blocker.nil?

    # skip header line!
    command_created = true if component <=> "Component"

    # if we set up a command, let's do it
    next unless command_created == true
#    puts "component=#{component}, summary=#{summ_os}, desc=#{mydesc}, points=#{points}, type=#{type}"

    # set up output line
    json_line = '{"fields":{"project":{"key":"SIMP"},'
    json_line += "\"issuetype\":{\"name\":\"#{type}\"},"
    json_line += "\"customfield_10005\":#{points},"
    json_line += "\"summary\":\"#{summ_os}\","
    json_line += "\"description\":{\"version\":1,\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"#{mydesc}\"}]}]}"
    json_line += "\"components\":[{\"name\":\"#{component}\"}]" unless component.nil?
    json_line += "\"parent\":{\"key\":\"#{parent_id}\"}" if subtask == true
    json_line = "#{json_line}}}"

    # here is our jira instance
    project_key = proj
    page_url = 'https://simp-project.atlassian.net/rest/api/3/issue'
    options = " --user #{userid} --header 'Accept: application/json' --header 'Content-type: application/json'"
    data_fields = "--data '#{json_line}'"
    cmd = "curl -v --request POST --url '#{page_url}' #{options} #{data_fields} > #{resultfile}"

    # save the command (if it fails we can try it manually)
    cmdfile.puts "cmd is #{cmd}"
    exit_val = false
    # exit_val = system(cmd)
    puts "command result is #{exit_val}"
    if exit_val == true
      File.open(resultfile).each do |row|
        jsonrow = JSON.parse(row)
        puts "Your ticket is #{jsonrow['id']}, ticket #{jsonrow['key']}"
        jira_id = jsonrow['key']
      end
    else
      jira_id = "SIMP-#{ticket_id}"
    end

    # save the parameters for later
    tickethash = {}
    tickethash['ticket_id'] = ticket_id
    tickethash['summary'] = summ_os
    tickethash['descr'] = descr
    tickethash['component'] = component
    tickethash['blocker'] = blocker
    tickethash['blocker_id'] = blocker
    tickethash['points'] = points
    tickethash['jira_id'] = jira_id
    tickethash['parent'] = parentid
    @tickets << tickethash
    lines += 1

    # success
    outfile.puts("#{ticket_id},#{summ_os},#{mydesc},#{component},#{points},#{parentid},#{jira_id},")
  end
  @tickets.each do |tic|
    puts tic
  end
end
# while
