require 'socket'
require 'open3'
require 'open4'
#Synopsis https://github.com/djberg96/sys-proctable/wiki
require 'pp'
require 'sys/proctable'
include Sys
#Synopsis

class Cmd
  
  @@cmd_info = Hash.new
  @@state_decod = {"D" => "Uninterruptible sleep (usually IO)", 
             "R" => "Running or runnable (on run queue)",
             "S" => "Interruptible sleep (waiting for an event to complete)",
             "T" => "Stopped, either by a job control signal or because it is being traced.", 
             "W" =>"paging (not valid since the 2.6.xx kernel)", "X" => "dead (should never be seen)",
             "Z" => "Defunct (zombie) process, terminated but not reaped by its parent.",
             "<" => "; high-priority (not nice to other users)",
             "N" => "; low-priority (nice to other users)",
             "L" => "; has pages locked into memory (for real-time and custom IO)",
             "s" => "; is a session leader",
             "l" => "; is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)",
             "+" => "; is in the foreground process group"}
  def initialize(name, cmd)
    @cmd = cmd
    @name = name
    
    #@@cmd_info
    @out_end = nil
    @err_end = nil
    @pid = nil
    @inp = ""
    @out = ""
    @err = ""
    @name = ""
    @cmd_status = Hash.new
    @group_pid = Array.new
  end
private  
  def group_pid()
    ppid = @pid
    @group_pid.clear
    @group_pid << @pid
    print "\n def group_pid() @pid = ", @pid,"\n"
    ProcTable.ps do |process|  
      (ppid = process.pid) if process.pid ==  ppid  
      (ppid = process.pid; @group_pid << ppid) if process.ppid == ppid
    end
    
    print "51: def group_pid()  @group_pid = #{@group_pid}"
    @group_pid
  end
  
  
  
public
  
  def cmdStart() 
    @inp, @out, @err, wait_thr = Open3.popen3(@cmd)
    @inp.close
    print "\nsinc out: ", @out.sync, ";\n"
    @out.sync = true
    print "\nsinc out: ", @out.sync, ";\n"
    @pid = wait_thr[:pid] #pid process 
    print "\nPID: ", @pid, ";\n"
      
    @thread = Thread.new do      
      begin
        
        loop do
          Thread.current["out"] ||= "" 
          Thread.current["err"] ||= ""
          out_st = @out.stat
          err_st = @err.stat
          #print "\nblksiz out_st: ", out_st.blksize, "\n" 
          Thread.current["out"] += @out.read_nonblock out_st.blksize 
          Thread.current["err"] += @err.read_nonblock err_st.blksize 
          print "\nThread befor Thread.stop\n"
          #Thread.stop
          print "\nTrhead end\n"
        end
        
      rescue IO::WaitReadable
        IO.select [@out]
        retry
      rescue EOFError
        Thread.current["out"] = "\nEOFError\n"      
      end
    end
    
    print "\nEnd thread end method\n"
  end
  
  def inp
    @inp
  end
  
  def out
    begin       
      @out.closed? ? @out_end : (@thread.run; @thread["out"])      
    rescue ThreadError
      "@out error"      
    end
  end
  
  def err
    begin
      @err.closed? ? @err_end : (@thread.run; @thread["err"]) 
    rescue ThreadError
      "@err error"      
    end
  end
  
  def cmdStatus()
    #http://manpages.ubuntu.com/manpages/lucid/man1/ps.1.html
    #PROCESS STATE CODES
    print "\n118: def cmdStatus() @group_pid = ", @group_pid, ";\n" 
    group_pid if @group_pid[0].nil?
    print "\n120: def cmdStatus() @group_pid = ", @group_pid, ";\n" 
    status = "true"
    status = "false" if @group_pid[0].nil?
    
    print "\n126: cmdStatus @group_pid = ", @group_pid, "\n"
    #state = Hash.new #pid and their state 
    
    @cmd_status.clear
    print "\n@group_pid = ", @group_pid, "\n"
    @group_pid.each do |pid|
      print "\n@group_pid.each |#{pid}|; \n"
      ProcTable.ps do |process|  
        (@cmd_status[pid] = process.state; print "\n state #{process.state}; \n") if process.pid ==  pid        
      end
    end
    
    print "\n@cmd_status = ", @cmd_status, "\n"
    @cmd_status.each do |pid, st|
      print "\n@cmd_status.each do |#{pid}, #{st}|\n"
      
      st.each_char do |st_char|
        @@state_decod.each_pair do |key, value|
          if st_char == key
            @cmd_status[pid] += "\n#{st_char}: #{value}"            
            (status = "false") if (st_char == "X" or st_char == "Z")
            break
          end    
        end
      end
      
      
    end
    print "\n def cmdStatus() @cmd_status: ", @cmd_status, "\n"
    @cmd_status
    status ||= "false"
  end
  
  
  def cmdStop()  
    
    
    print "\n183: @pid = #{@pid}\n"
    
    print "\n161: Before kill @thread.status = ", @thread.status, "\n"   
    puts group_pid ##creat group of PID @@group_pid
    group_pid.reverse_each do |pid|
      begin
        break if pid == @pid
        print "\n165: group_pid.each do |#{pid}|\n"
        print "\n166: Input kill @thread.status = ", @thread.status, "\n"
        Process.kill("INT", pid)
      rescue Errno::ESRCH
        print "\npid there is not #{pid}\n"
      end
    end
    
    
    @group_pid.clear
    #@thread["out"] = ""
    #print "\n176: After kill @thread.status = ", @thread.status, "\n"
    print "\n180 Befor @thread.run; @thread.status = ", @thread.status, "\n"
    @thread.run
    @out_end = @thread["out"]
    @err_end = @thread["err"]
    @out.close
    @err.close       
    
    Process.kill("INT", @pid)
    
    
    @pid = nil
    
  end

  
  
end


vpn = Cmd.new(:vpn, "sudo openvpn --config /home/ubuntu/keys/client.conf")




server = TCPServer.open('localhost', 3001)

loop do
  client = server.accept
  puts client
  cmd, arg = client.gets.chomp.split
  #print "Gets: cmd: ", cmd, "; arg: ", arg;
  case cmd
    when "on"
      vpn.cmdStart
      client.puts "Thinking"
    when "off"
      vpn.cmdStop
      client.puts "Thinking"
    when "err"
      client.puts vpn.err
    when "out"
      client.puts vpn.out   
    when "status"
      client.puts vpn.cmdStatus   
    when "shutdown"
          client.close
    else
        
  end
  #print "Vpn.vpnStatus: ", Vpn.vpnStatus
  
  #client.puts "endResponse"
  client.close  
end
