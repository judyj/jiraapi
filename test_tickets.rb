#!/usr/bin/env ruby
require 'csv'
require 'rest-client'
require 'json'
require 'optparse'

# initialize
@ticketid = ""
inputfile = 'test.csv'
json_file = 'jira_in.json'
outputfile = 'test_tickets.csv'
lines = 0
userid = 'me@here.com:123456789012'
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
  opts.on('-s', '--sprint NUMBER', 'Input sprint number (Jira)') do
    |f| puts "sprint is #{s}"
    sprint = f.strip
  end
end
optsparse.parse!

# set up output file
outfile = File.open(outputfile,'w')
outfile.puts("Ticket, Component, Summary, Points, Description") 

# set up input file
CSV.foreach(inputfile) do |row|
  lines += 1
  puts "\n\n\n\n*** lines: #{lines} row: #{row}"
  proj = 'SIMP'
  summary = 'summary'
  desc = 'description'
  type = 'Sub-task'
  points = 0
  sprint = nil

  # get out the fields we need
  component = row[0]
  summary = row[1]
  el6 = row[2]
  el7 = row[3]
  desc = row[5]
  points = row[4]

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

  if points == nil then
    points = 0
  end
  tickets = "no"
  # loop for none, el6, el7 or both...
  while (tickets == "no")
    mydesc = desc
    # concatenate the EL version if necessary
    if (el6_tic)
      mydesc = "EL6-#{desc}"
    end
    if (el7_tic and !el6_tic) 
      mydesc = "EL7-#{desc}"
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

    # description
    if (mydesc != nil)
      mydesc = mydesc.gsub("\'","")
      mydesc = mydesc.gsub("\r","")
      mydesc = mydesc.gsub("{","")
      mydesc = mydesc.gsub("}","")
      mydesc = mydesc.gsub("\"","")
    else
      mydesc = " "
    end

    # if the summary field is too long, we gotta move it over to the description
    if (summary.size > 50)
      summary = summary[0..49]
      mydesc = "#{summary}-#{mydesc}"
    end
    # check 
    puts "component = #{component}, summary= #{summary}, desc= #{mydesc}, points=#{points}, type=#{type}"

    # set up output file
    json_line = 
    "{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"summary\",\"#{summary}\",\"points\",#{points},\"desc\",\"#{mydesc}\"}}"
    # here is our jira instance
    project_key = 'ABC'
    page_url ="https://simp-project.atlassian.net/rest/api/3/issue"
    options = " --user #{userid} --header 'Accept: application/json' --header 'Content-type: application/json'"
    data_fields = "--data '{\"fields\":{\"project\":{\"key\":\"SIMP\"},\"issuetype\":{\"name\":\"Story\"},\"components\":[{\"name\":\"#{component}\"}],\"customfield_10005\":#{points},\"summary\":\"#{summary}\",\"description\":{\"version\":1,\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"#{mydesc}\"}]}]}}}'"
    cmd = "curl -v --request POST --url '#{page_url}' #{options} #{data_fields} > #{resultfile}"

    # let us know the command (if it fails we can try it manually)    
    puts "cmd is #{cmd}"
    if (component != "Component")
      exit_val = true
    #   exit_val = system(cmd)
      puts "the result is #{exit_val}"
      if (exit_val == true)
        File.open(resultfile).each do |row|
          jsonrow = JSON.parse(row)
          puts "Your ticket is #{jsonrow['id']}, ticket #{jsonrow['key']}"
          @ticketid = jsonrow['key']
        end # line in file
      end # success
      outfile.puts("#{@ticketid},#{component},#{summary},#{points},#{mydesc}") 
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
