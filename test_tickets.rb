#!/usr/bin/env ruby
require 'csv'
require 'rest-client'
require 'json'
require 'optparse'

# initialize
inputfile = 'test.csv'
json_file = 'jira_in.json'
lines = 0
userid = 'me@here.com:fffffffkFfffEff8ff9'
resultfile = 'putresult.json'

optsparse = OptionParser.new do |opts|
  opts.banner = "Usage: create_tickets [options]"
  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end
  opts.on('-f', '--input NAME', 'Input file or directory name') do
    |f| puts "input filename is #{f}"
    inputfile = f.strip
  end
end
optsparse.parse!


# set up input file
CSV.foreach(inputfile) do |row|
  lines += 1
  puts "\n\n\n\n*** lines: #{lines} row: #{row}"
  proj = 'SIMP'
  summary = 'summary'
  desc = 'description'
  type = 'Sub-task'
  points = 0

  # get out the fields we need
  component = row[0]
  summary = row[1]
  el6 = row[2]
  el7 = row[3]
  test = row[4]
  desc = row[5]

  # concat the component with the summary
  if component != nil
    test = "#{component}"
  end	

  # initialize
  el6_tic = false
  el7_tic = false

  # chck for el6 and el7
  if (el6 == 'y') or (el6 == 'Y')
    el6_tic = true
  end
  if (el7 == 'y') or (el7 == 'Y')
    el7_tic = true
  end
  if (el6_tic) != true and (el7_tic != true)
    no_el_flag = true
  end

  tickets = "no"
  # loop for none, el6, el7 or both...
  while (tickets == "no")
    # concatenate the EL version if necessary
    if (el6_tic)
      desc = "EL6-#{summary}"
    end
    if (el7_tic and !el6_tic) 
      desc = "EL7-#{summary}"
    end
    if summary != nil
      summary = summary.gsub("\'","")
      summary = summary.gsub("\r","")
      summary = summary.gsub("{","")
      summary = summary.gsub("}","")
      summary = summary.gsub("\"",",")
    else
      summary = " "
    end

    # if the summary field is too long, we gotta move it over to the description
    if (summary.size > 50)
      summary = summary[0..49]
      desc = "#{summary}-#{desc}"
    end

    # description
    if (desc != nil)
      desc = desc.gsub("\'","")
      desc = desc.gsub("\r","")
      desc = desc.gsub("{","")
      desc = desc.gsub("}","")
      desc = desc.gsub("\"","")
    else
      desc = " "
    end

    # points = row[3]
    points = '0'
    puts "component = #{component}, summary= #{summary}, desc= #{desc}, points=#{points}, type=#{type}"

    # set up output file
    json_line = 
    "{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"summary\",\"#{summary}\",\"points\",#{points},\"desc\",\"#{desc}\"}}"
    # here is our jira instance
    project_key = 'ABC'
    jira_url = 'https://simp-project.atlassian.net/rest/api/2/issue/'
    jira_line = "#{jira_url}#{json_line}"
    puts jira_line
    page_url ="https://simp-project.atlassian.net/rest/api/3/issue"
    options = " --user #{userid} --header 'Accept: application/json' --header 'Content-type: application/json'"
    data_fields = "--data '{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"issuetype\":{\"name\":\"Story\"},\"customfield_10005\":#{points},\"summary\":\"#{summary}\",\"description\":{\"version\":1,\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"#{desc}\"}]}]}}}'"
    cmd = "curl -v --request POST --url '#{page_url}' #{options} #{data_fields} > #{resultfile}"

    # let us know the command (if it fails we can try it manually)    
    puts "cmd is #{cmd}"
    if (component != "Component")
      # exit_val = system(cmd)
      rtn_val = false
      puts "the result is #{exit_val}"
      if (exit_val == true)
        File.open(resultfile).each do |row|
          jsonrow = JSON.parse(row)
          puts "Your ticket is #{jsonrow['id']}, ticket #{jsonrow['key']}"
        end # line in file
      end # success
    else # not header
      puts 'header line'
    end    

    # check the result of the command
    # we've done 1 or 2 puts
    if (el7_tic == true and el6_tic == true)
      el6_tic = false
      tickets = "no"
    else
      tickets = "yes"
    end
  end # while
end # done with file
