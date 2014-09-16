#!/usr/bin/ruby

## ---------------------------------------------------------------------------
## Elemental Technologies Inc. Company Confidential Strictly Private
##
## ---------------------------------------------------------------------------
##                           COPYRIGHT NOTICE
## ---------------------------------------------------------------------------
## Copyright 2012 (c) Elemental Technologies Inc.
##
## Elemental Technologies owns the sole copyright to this software. Under
## international copyright laws you (1) may not make a copy of this software
## except for the purposes of maintaining a single archive copy, (2) may not
## derive works herefrom, (3) may not distribute this work to others. These
## rights are provided for information clarification, other restrictions of
## rights may apply as well.
##
## This is an unpublished work.
## ---------------------------------------------------------------------------
##                              WARRANTY
## ---------------------------------------------------------------------------
## Elemental Technologies Inc. MAKES NO WARRANTY OF ANY KIND WITH REGARD TO THE
## USE OF THIS SOFTWARE, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
## THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR
## PURPOSE.
## ---------------------------------------------------------------------------

##****************************************************************************
## Transfers outputs to a remote server via standard file transfer methods,
## such as FTP, SFTP, FTPS, FILE (local), etc.
##
## Version: 1.21 (version history at end of file)
##
## Required arguments:
## -- 1: Remote connection string: <protocol>://<user>:<password>@<host>:<port>/<path>
## -- 2: Job ID
## -- 3: Path to input file for job
## -- 4: PRE vs POST string (PRE-processing or POST-processing)
## -- 5: Number of outputs for job
## -- 6: #-delimited string for output file (first token is output path)
###########################################################################

##****************************************************************************
## Setup script options
begin
  require 'optparse'
  options = {}
  optparse = OptionParser.new do |opts|
    # Set a banner, displayed at the top of the help screen
    opts.banner = "Usage: file_transfer.rb [options] ..."

    # Define the options, and what they do
    options[:verbose] = false
    opts.on( '-v', '--verbose', 'Output more information.' ) do
      options[:verbose] = true
    end

    options[:delete_local] = false
    opts.on( '-x', '--delete-local', 'Delete the local copy of the file.' ) do
      options[:delete_local] = true
    end

    options[:validate] = false
    opts.on( '-c', '--validate', 'Validate the file, once the transfer is complete.' ) do
      options[:validate] = true
    end

    options[:attempts] = 2
    opts.on( '-a', '--attempts ATTEMPTS', 'Number of times to attempt to transfer a file.' ) do |attempts|
      options[:attempts] = attempts.to_i > 0 ? attempts.to_i : 2
    end

    options[:attempts_delay] = 30
    opts.on( '-d', '--attempts-delay SECONDS', 'Delay (in seconds) between subsequent transfer attempts.' ) do |delay|
      options[:attempts_delay] = delay.to_i > 0 ? delay.to_i : 30
    end

    # This displays the help screen, all programs are assume to have this option
    opts.on( '-h', '--help', 'Display this help screen.' ) do
      puts opts
      exit
    end
  end
  optparse.parse!
rescue Exception => err
  puts "RETURN MESSAGE: #{err.message}" unless err.message == "exit"
  Kernel.exit(false)
end


##****************************************************************************
## Transfer Library for abstraction of server types
module TransferLibrary

  # Initialize server, based on a protocol string
  def self.init_server(protocol)
    case protocol.upcase
      when "FTP"  then FtpServer.new
      when "FTPA" then FtpaServer.new
      when "SFTP" then SftpServer.new # not yet implemented
      when "FTPS" then FtpsServer.new # not yet implemented
      when "FILE" then FileServer.new
    end
  end

  # Define the supported transfer protocols (e.g. FTP, SFTP, FTPS, FILE, etc)
  def self.supported_protocols
    return ["FTP","FTPA","FILE"]
  end

  # Abstract class to define required transfer server methods
  class TransferServer
    # changes the working directory on the remote server
    def chdir
      raise "this method should be overridden"
    end

    # closes the connection to the remote server
    def close
      raise "this method should be overridden"
    end

    # returns true if the server connection is valid
    def connected?
      raise "this method should be overridden"
    end

    # makes a directory on the remote server
    def mkdir
      raise "this method should be overridden"
    end

    # opens a connection to the remote server
    def open(host, port=nil, user=nil, pass=nil, verbose=false)
      raise "this method should be overridden"
    end

    # sends command to transfer the file
    def put(file)
      raise "this method should be overridden"
    end

    # returns true/false indicating whether the transferred file is valid
    def validate(file)
      raise "this method should be overridden"
    end
  end

  # FTP Server
  class FtpServer < TransferServer
    require 'net/ftp'

    def chdir(path)
      @server.chdir(path) unless path.nil?
    end

    def close
      @server.close unless @server.nil? || @server.closed?
    end

    def connected?
      begin
        @server.noop
      rescue
        return false
      end
      return true
    end

    def mkdir(dir)
      dir.split('/').each do |d|
        rdirs = @server.nlst
        @server.mkdir(d) unless rdirs.nil? || rdirs.include?(d)
        @server.chdir(d)
      end
      dir.split('/').each do |d|
        @server.chdir("..")
      end
    end

    def open(host, port=21, user=anonymous, pass=anonymous, verbose=false)
      # don't allow user or password to be nil
      user ||= "anonymous"
      pass ||= "anonymous"

      @server = Net::FTP.new
      port.nil? ? @server.connect(host) : @server.connect(host, port)
      @server.login(user, pass)
      @server.binary = true
      @server.passive = true
      @server.debug_mode = verbose
    end

    def put(file)
      @server.putbinaryfile(file)
    end

    def validate(file)
      local = file
      remote = "#{@server.pwd}/#{File.basename(file)}"

      # verify the file sizes match
      puts "file size: #{File.stat(local).size} --> #{@server.size(remote)}" if @server.debug_mode == true
      return false unless File.stat(local).size == @server.size(remote)

      return true
    end
  end

  # FTPA Server (FTP Server with Active Mode)
  class FtpaServer < FtpServer
    def open(host, port=21, user=anonymous, pass=anonymous, verbose=true)
      super(host, port, user, pass, verbose)
      @server.passive = false
    end
  end

  # SFTP Server
  class SftpServer < TransferServer
    # not yet supported
  end

  # FTPS Server
  class FtpsServer < TransferServer
    # not yet supported
  end


  # File Server - currently, local destinations only
  class FileServer < TransferServer
    require 'fileutils'

    attr_accessor :wd, :debug_mode

    def chdir(path)
      FileUtils.cd("#{@server.wd}/#{path}")
      @server.wd = "#{@server.wd}/#{path}"
    end

    def close
      @server = nil
    end

    def connected?
      true # local connection is always connected
    end

    def mkdir(dir)
      newdir = "#{@server.wd}/#{dir}"
      FileUtils.mkdir_p("#{newdir}", {:verbose => @server.debug_mode}) unless File.exists?("#{newdir}")
    end

    def open(host=localhost, port=nil, user=nil, pass=nil, verbose=false)
      # nothing really to do, since only local transfers are currently supported
      @server = self
      @server.wd = ""
      @server.debug_mode = verbose
    end

    def put(file)
      puts "COPY #{file} #{@server.wd}/" if @server.debug_mode == true
      FileUtils.cp(file, @server.wd)
    end

    def validate(file)
      local = file
      remote = "#{@server.wd}/#{File.basename(file)}"

      # verify the file exists
      puts "file existence: #{File.exists?(local)} --> #{File.exists?(remote)}" if @server.debug_mode == true
      return false unless File.exists?(local) && File.exists?(remote)

      # verify the file sizes match
      puts "file size: #{File.stat(local).size} --> #{File.stat(remote).size}" if @server.debug_mode == true
      return false unless File.stat(local).size == File.stat(remote).size

      # verify the checksums match
      puts "file cksum: #{`md5sum "#{local}"`.split(' ').first} --> #{`md5sum "#{remote}"`.split(' ').first}" if @server.debug_mode == true
      return false unless `md5sum "#{local}"`.split(' ').first == `md5sum "#{remote}"`.split(' ').first

      # if all checks pass, return true
      return true
    end
  end

end

##****************************************************************************
## Additional classes to abstract content formats

# A basic class to represent an HLS output, with a (m3u8) manifest file
# and individual segments
class HlsOutput
  @index
  @manifest
  @segments

  def initialize(index_file,playlist)
    @index = index_file
    @manifest = playlist
    load(@manifest) unless @manifest.nil?
  end

  def files
    a = Array.new
    a << @index
    a << @manifest
    a += @segments
    return a
  end

  def load(file)
    @segments = Array.new

    lines = File.readlines(file)
    lines.each do |line|
      if line =~ /^\s*\#/
        # skip comments
      else
        segment_path = "#{File.dirname(file)}/#{line.chomp!}"
        @segments << segment_path
      end
    end
  end

  def root
    return File.dirname(@index)
  end
end

# A basic class to represent a Microsoft Smooth output, with an index,
# manifest, and content file
class SmoothOutput
  @index
  @manifest
  @media

  def initialize(ism,ismc,ismv)
    @index = ism
    @manifest = ismc
    @media = ismv
  end

  def files
    a = Array.new
    a << @index
    a << @manifest
    a << @media
    return a
  end

  def root
    return File.dirname(@index)
  end
end

# A basic class to represent a Quicktime Reference file
class QtRefOutput
  @ref
  @sources

  def initialize(mov)
    @ref = mov
    load(@ref) unless @ref.nil?
  end

  def files
    a = Array.new
    a << @ref
    a += @sources
    return a
  end

  def load(file)
    @sources = `mediainfo \"#{@ref}\" | grep Source | sed -r 's/Source\\s+: (.*)/\\\"\\1\\\";/g' | tr -d '\\r\\n'`.split(/;/).delete_if{|x| x=="" or x.nil?}
    @sources.collect!{ |x| "#{File.dirname(@ref)}/#{x.gsub!(/^"(.*?)"$/,'\1')}" }
  end

  def root
    return File.dirname(@ref)
  end
end

##****************************************************************************
## Other helper classes

# Add an is_int? method to the String class
class String
  def is_int?
    self.to_i.to_s == self
  end
end


##****************************************************************************
## Main program
require 'rubygems'
require 'json'

begin
  raise "#{$0} Invalid arguments.  Verify that the script was called as a post-processing script." unless ARGV.length>=5 || ARGV.length==2
  puts "#{$0} #{ARGV.join(' ')}" if options[:verbose] == true

  # Get the transfer settings
  unless ARGV[0].is_int?
    conn_str = ARGV.shift

    # strip any trailing '/' characters
    if s = conn_str.match('(\/*)$')
      conn_str = conn_str[0..(conn_str.length-s[0].length-1)]
    end

    # parse the FTP connection string
    if m = conn_str.match('^(\S+)\:\/\/((\S+)\:(\S+)\@){0,1}((?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?)*\.?)(\:(6553[0-5]|655[0-2]\d|65[0-4]\d{2}|6[0-4]\d{3}|[1-5]\d{4}|[1-9]\d{0,3}))?(\/\S+)*$')
      # m[0] = full match, m[1] = protocal, m[2] = credentials, m[3] = username, m[4] = password, m[5] = hostname, m[6] = port string, m[7] = port, m[8] = path
      valid_creds = !(m.nil? || m[3].nil? || m[4].nil?)
      settings = { 'protocol' => m[1], 'host' => m[5], 'port' => m[7], 'path' => m[8].nil? ? nil : m[8][1..m[8].length], 'username' => valid_creds ? m[3] : nil, 'password' => valid_creds ? m[4] : nil }
    else
      settings = { 'protocol' => nil, 'host' => nil, 'port' => m[7], 'path' => nil, 'username' => nil, 'password' => nil }
    end
  end

  # Get the job-related command line arguments
  params = Hash.new
  if ARGV[0].is_int?
    jobId = ARGV.shift
    input = ARGV.shift
    mode = ARGV.shift
    numOutputs = ARGV.shift

    # Setup the params hash
    params = {
      "script_type" => "#{mode}",
      "output_groups" => []
    }

    # loop through the output strings and read the attributes
    outputs = Array.new
    ARGV.each_with_index do |arg, i|
      a = arg.split('#')
      outputs << {
        'output_path' => "#{a[0]}",
        'video' => { 'codec' => "#{a[1]}", 'bitrate' => "#{a[3]}", 'width' => "#{a[2].split('x')[0]}", 'height' => "#{a[2].split('x')[1]}" },
        'audio' => { 'codec' => "#{a[4]}", 'bitrate' => "#{a[5]}", 'sample_rate' => "" }
      }
    end
    params['output_groups'][0] = { 'name' => "Archive", 'outputs' => outputs }
  else
    json = ARGV.shift
    params = JSON.parse(json)
  end

  # Validate the command line arguments
  if settings['protocol'].nil? || settings['host'].nil?
    raise "#{$0}: Invalid remote connection string: #{conn_str}.  Please use the format: <protocol>://<username>:<password>@<host>:<port>/<path>"
  end
  unless TransferLibrary.supported_protocols.include?(settings['protocol'].upcase)
    raise "#{$0}: Invalid file transfer protocol specified (#{settings['protocol']}).  Valid protocols include: #{TransferLibrary.supported_protocols.join(', ')}"
  end
  if settings['host'].nil?
    raise "#{$0}: Invalid remote server host."
  end
  unless settings['port'].nil? || (settings['port'].is_int? && settings['port'].to_i > 0 && settings['port'].to_i < 65536 )
    raise "#{$0}: Invalid remote server port."
  end

  # Open the remote connection
  server = TransferLibrary.init_server(settings['protocol'])
  puts "connection to '#{settings['host']}' opened at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if options[:verbose] == true
  server.open(settings['host'], settings['port'], settings['username'], settings['password'], options[:verbose])
  server.mkdir(settings['path']) unless settings['path'].nil?
  server.chdir(settings['path']) unless settings['path'].nil?

  # process the outputs
  params['output_groups'].each do |og|
    next if (og['name'] =~ /^File.*/).nil?
    og['outputs'].each do |o|
      if File.exists?(o['output_path'])
        str = "transferring #{o['output_path']} to host #{settings['host']}/#{settings['path']} via #{settings['protocol'].upcase} "
        str += settings['username'].nil? || settings['password'].nil? ? "(anonymous)" : "(username=#{settings['username']}, password=#{'*'*(settings['password'].length)})"
        puts "#{str}" if options[:verbose] == true

        # Create an array of files to transfer
        root = String.new
        files = Array.new
        if File.extname(o['output_path']) =~ /m3u8/
          index = "#{File.dirname(o['output_path'])}/#{File.basename(input, File.extname(input))}.m3u8"
          while !File.exists?(index) && index != ""
            new_path = File.dirname(index).split('/')[0..-2].join('/')
            index = "#{new_path}/#{File.basename(input, File.extname(input))}.m3u8"
          end
          index = "#{File.dirname(o['output_path'])}/#{File.basename(input, File.extname(input))}.m3u8" if index==""
          playlist = o['output_path']
          hls = HlsOutput.new(index, playlist)
          root = hls.root
          files += hls.files

          audio_playlist = "#{File.dirname(playlist)}/#{File.basename(playlist,File.extname(playlist))}-audio#{File.extname(playlist)}"
          if File.exists?(audio_playlist)
            files += HlsOutput.new(index, audio_playlist).files
          end
        elsif File.extname(o['output_path']) =~ /ismv/
          index = "#{File.dirname(o['output_path'])}/#{File.basename(input, File.extname(input))}.ism"
          while !File.exists?(index) && index != ""
            new_path = File.dirname(index).split('/')[0..-2].join('/')
            index = "#{new_path}/#{File.basename(input, File.extname(input))}.ism"
          end
          index = "#{File.dirname(o['output_path'])}/#{File.basename(input, File.extname(input))}.ism" if index==""
          playlist = "#{File.dirname(index)}/#{File.basename(input, File.extname(input))}.ismc"
          content = o['output_path']
          smooth = SmoothOutput.new(index, playlist, content)
          root = smooth.root
          files += smooth.files
        elsif File.extname(o['output_path']) =~ /mov/
          qt = QtRefOutput.new(o['output_path'])
          root = qt.root
          files += qt.files
        else
          root = File.dirname(o['output_path'])
          files << o['output_path']
        end

        # Transfer the files, then delete the local copy
        files.each do |f|

          # Verify the transfer was successful
          attempts = 1
          until attempts > options[:attempts]
            begin
              # if the server connection was broken, reopen the connection
              unless server.connected?
                puts "#{$0}: Remote server connection appears to have been broken. Attempting to re-open connection at #{Time.now.strftime('%Y-%m-%d %H:%M%S')}."
                server.open(settings['host'], settings['port'], settings['username'], settings['password'], options[:verbose])
                server.mkdir(settings['path']) unless settings['path'].nil?
                server.chdir(settings['path']) unless settings['path'].nil?
              end

              if File.exists?(f)
                stats = File.lstat(f)
                puts "file stats: name=#{f}, size=#{stats.size}" if options[:verbose] == true
                tstart = Time.now

                unless root == File.dirname(f)
                  subdir = File.dirname(f.gsub("#{root}/",""))
                  server.mkdir(subdir)
                  server.chdir(subdir)
                  server.put(f) if File.exists?(f)
                  subdir.split('/').length.times do
                    server.chdir('..')
                  end

                else
                  server.put(f) if File.exists?(f)
                end

                tend = Time.now
                puts "transfer stats for #{f}: #{tend-tstart} secs" if options[:verbose] == true
              end

              if options[:validate] == true
                # wait a brief moment, to ensure the file is completely written
                sleep(2)
                break if server.validate(f)
              else
                break
              end
            rescue
            end
            puts "#{$0}: Transfer of file #{f} failed (attempt ##{attempts})... retrying transfer in #{options[:attempts_delay]} seconds." if options[:verbose] == true

            # wait a couple of seconds for the remote file to finish writing, since buffering
            # can cause a small delay of the final writes
            sleep(options[:attempts_delay])
            attempts = attempts+1
          end

          if attempts > options[:attempts]
            raise "#{$0}: File #{f} failed file transfer validation check. Please see sequencer.output for details."
          else
            # Delete the local copy
            File.delete(f) if File.exists?(f) && options[:delete_local] == true
          end
        end
      end
    end
  end

rescue Exception => err
  puts "RETURN MESSAGE: #{err.message}\n#{err.backtrace.join("\n")}"
  Kernel.exit(false)
ensure
  # Close the remote connection
  unless server.nil?
    puts "connection to '#{settings['host']}' closed at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}" if options[:verbose] == true
    server.close
  end
end



##****************************************************************************
## Version history:
##  1.0   - initial version
##  1.1   - support anonymous FTP
##  1.2   - parse m3u8 playlist and upload segments
##  1.3   - allow path information to be specified for FTP
##  1.4   - support for local file copies
##  1.5   - adds verify method, to confirm file transfer was successful
##  1.6   - active FTP support (using FTPA as protocol)
##  1.7   - allow port to be specified for transfers
##  1.8   - adds support for transferring MS Smooth manifest files
##  1.9   - renames 'verify' method to 'validate'
##  1.10  - implements 'validate' method for FileServer transfers
##  1.11  - implements 'validate' method for FtpServer transfers
##  1.12  - implements retry logic in the event validation fails
##  1.13  - modifies options management
##  1.14  - modifies file listing method, to support Windows FTP servers
##  1.15  - adds support for command line options
##  1.16  - if transfer fails, verifies connection to server is valid
##  1.17  - added more logging to help with troubleshooting
##  1.18  - added support for passing output arguments via JSON
##  1.19  - support for Quicktime reference files
##  1.20  - (limited) support for subdirectories for Smooth and HLS outputs
##  1.21  - removed pwd references, due to issues on non-standard FTP servers
##
