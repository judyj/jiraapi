#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'rest-client'
require 'json'
require 'optparse'

# initialize
@ticketid = ''
inputfile = 'test.csv'
outputfile = 'test_tickets.csv'
lines = 0
userid = 'me@here.com:123456789012'
resultfile = 'putresult.json'
sprint = nil

# initialize the OSes in an array
os_type = ['', '', '', '', 'EL6', 'EL7', 'EL8', 'OEL6', 'OEL7', 'OEL8', 'RHEL7', 'RHEL7', 'RHEL8']

# get the filename and sprint if input by the user
optsparse = OptionParser.new do |opts|
  opts.banner = 'Usage: create_tickets [options]'
  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end
  opts.on('-f', '--input NAME', 'Input file or directory name') do |f|
    puts "input filename is #{f}"
    inputfile = f.strip
  end
  opts.on('-s', '--sprint NUMBER', 'Input sprint number (Jira)') do |s|
    puts "sprint is #{s}"
    sprint = s.strip
  end
end
optsparse.parse!

# set up output file
outfile = File.open(outputfile, 'w')
outfile.puts('Ticket, Component, Summary, Points, Description')

# set up input file
puts "inputfile is #{inputfile}"
CSV.foreach(inputfile) do |col|
  lines += 1
  puts "\n\n\n\n*** lines: #{lines} col: #{col}"
  proj = 'SIMP'
  type = 'Sub-task'
  points = 0

  # get out the fields we need
  component = col[0]
  summary = col[1]
  descr = col[2]
  points = col[3]

  # concat the component with the desc
  mydesc = if !component.nil? && !descr.nil?
             "(#{component})  #{descr}"
           else
             descr
           end

  # if no point value, make it zero
  points = 0 if points.nil?

  # summary - clean out values that will mess up the string
  if !summary.nil?
    summary = summary.gsub("\'", '')
    summary = summary.gsub("\r", '')
    summary = summary.gsub('{', '')
    summary = summary.gsub('}', '')
    summary = summary.gsub('"', ',')
  else
    summary = ' '
  end

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
  (4..13).each do |os|
    command_created = false
    if !col[os].nil? && ((col[os] == 'Y') || (col[os] == 'y'))
      prefix = os_type[os]
      summ_os = "#{prefix} - #{summ}"
      puts "component = #{component}, summary= #{summ}, desc= #{mydesc}, points=#{points}, type=#{type}"
      foundone = true
      command_created = true
    end

    # that last column does not exist, but just seeing if we had an O/S checked - if not, just do a ticket with no O/S
    if (os == 13) && (foundone == false)
      puts "component = #{component}, summary= #{summ_os}, desc= #{mydesc}, points=#{points}, type=#{type}"
      command_created = true
    end

    # skip header line!
    # command_created = true if component <=> "Component"

    # if we set up a command, let's do it
    next unless command_created == true

    puts "pushing this component = #{component}, summary= #{summ_os}, desc= #{mydesc}, points=#{points}, type=#{type}"

    # set up output line
    json_line =
      "{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"issuetype\":{\"name\":\"Story\"},\"components\":[{\"name\":\"#{component}\"}],  \"customfield_10005\":#{points},\"summary\":\"#{summ_os}\",\"description\":{\"version\":1,\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"#{mydesc}\"}]}]}}}"
#      "{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"summary\",\"#{summary}\",\"points\",#{points},\"desc\",\"#{mydesc}\"}}"

    # here is our jira instance
    project_key = proj
    page_url = 'https://simp-project.atlassian.net/rest/api/3/issue'
    options = " --user #{userid} --header 'Accept: application/json' --header 'Content-type: application/json'"
    data_fields = "--data '#{json_line}'"
    cmd = "curl -v --request POST --url '#{page_url}' #{options} #{data_fields} > #{resultfile}"

    # let us know the command (if it fails we can try it manually)
    puts "cmd is #{cmd}"
    exit_val = false
    #     exit_val = system(cmd)
    puts "the result is #{exit_val}"
    @ticketid = 'NONE'
    if exit_val == true
      File.open(resultfile).each do |row|
        jsonrow = JSON.parse(row)
        puts "Your ticket is #{jsonrow['id']}, ticket #{jsonrow['key']}"
        @ticketid = jsonrow['key']
      end
    end
    # success
    outfile.puts("#{@ticketid},#{component},#{summ_os},#{points},#{mydesc}")
  end
end
# while
